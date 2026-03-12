
import globals_pkg::*;
import quant_pkg::*;

module fir #(
	parameter int DWIDTH = 32,
	parameter int TAPS = 32,
	parameter int DECIM = 8,

	parameter int MUL_CNT = 4,

	parameter logic signed [ DWIDTH-1:0 ] X_COEFS [ 0:TAPS-1 ],
)(
	input logic clk,
	input logic rst,

	input logic signed [ DWIDTH-1:0 ] x_in,
	input logic x_in_empty,
	input logic y_out_full,

	output logic signed [ DWIDTH-1:0 ] y_out,
	output logic x_in_rd_en,
	output logic y_out_wr_en
);

	//localparam int MUL_STEP = (TAPS + MUL_CNT-1) / MUL_CNT;
	//localparam int TAPS_PADDED = MUL_CNT * MUL_STEP;

	// TODO: Assume _for now_ that TAPS is a multiple of MUL_CNT
	localparam int MUL_STEP = TAPS / MUL_CNT;

	typedef enum logic [ 2:0 ]
	{
		S_SHIFT_X, S_STALL, S_SHIFT_Y 
	} state_t;
	state_t state, state_c;

	/* shiftreg buffer */
	logic signed [ DWIDTH-1:0 ] x_sh [ 0:TAPS-1 ];

	logic signed [ 0:MUL_CNT-1 ] [ DWIDTH-1:0 ]
		// Each multiplier takes charge of a partial sum
		// for a section of MUL_STEP taps
		accs, accs_c,
		x_out,
		coef_out;

	// Addrs into x and coefs for registered reads
	logic signed [ $clog2( TAPS ):0 ]
		coef_rd_addrs, coef_rd_addrs_c,
		x_rd_addrs, x_rd_addrs_c;

	always_comb
	begin
		y_out = 'sh0;
		x_in_rd_en = 1'b0;
		y_out_wr_en = 1'b0;

		state = state_c;

		accs_c = accs;
		coef_rd_addrs_c = coef_rd_addrs;
		x_rd_addrs_c    = x_rd_addrs;

		if ( state == S_SHIFT_Y )
		begin
			// Sum partial sums
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				y_out += accs_c[ m ];
			end
		end
		else
		begin
			// Accumulate one product (for x and coef value at current read
			// addrs) into each partial sum
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				accs_c[ m ] = accs[ m ] + DEQUANT( coef_out[ m ] * x_out[ m ] ] );
			end
		end

		case ( state )
			S_SHIFT_X:
			begin
				if ( ~x_in_empty )
				begin
					x_in_rd_en = 1'b1;
					//
					// For x, "camp out" at step base addr to wait for
					// newly shifted-in value ( hold x_rd_addrs ).
					//
					// For coefs, preemptively use higher addr inside step 
					// (initially base + DECIM-1) and decrement, so that 
					// we pair each shifted-in value with the coef they 
					// _end up_ with at end of decimation phase.
					//
					// Example
					//   TAPS=32, DECIM=6, MUL_CNT=4
					//   MUL_STEP = TAPS/MUL_CNT = 8
					// Multiplier 1:
					//   cycle 0: x[1*8=8]*coefs[8+6-1=13]
					//   cycle 1: + x[8]    *coefs[12]
					//   cycle 2: + x[8]    *coefs[11]
					//   cycle 3: + x[8]    *coefs[10]
					//   cycle 4: + x[8]    *coefs[9]
					//   cycle 5: + x[8]    *coefs[8]
					// By now, this actually comes out as 
					//     x[13]*coefs[13] + ... + x[0]*coefs[0]
					//   because earlier-arriving values are shifted in.
					//   x[8] at cycle 0 is actually x[13] at cycle 5.
					//
					// Since there are 2 more values in the partial sum
					// but we ran out of the decimation phase's
					// provisioned cycles, we handle the extra values in
					// S_STALL.
					//
					for ( int m=0; m<MUL_CNT; ++m )
					begin
						coef_rd_addrs_c[ m ] = coef_rd_addrs[ m ] - 1'h1;
					end
					if ( coef_rd_addrs[ 0 ] == 0 )
					begin
						if ( MUL_STEP >= DECIM )
						begin
							// MUL_STEP fully covers DECIM; we already have
							// what we need for each partialsum and don't need
							// to stall
							state_c = S_SHIFT_Y;
						end
						else
						begin
							// Finish up remaining values that were deeper
							// behind inside the step, such that we didn't
							// 	 capture them while camping out at step base
							//   in S_SHIFT_X
							state_c = S_STALL;
							// Initialize read addrs for S_STALL:
							//   Prepare to reading x and coefs at same positions 
							//   ( there is no shifing involved in S_STALL )
							//   and accumulate their products.
							for ( int m=0; m<MUL_CNT; ++m )
							begin
								coef_rd_addrs_c[ m ] = m*MUL_STEP + DECIM;
								x_rd_addrs_c   [ m ] = m*MUL_STEP + DECIM;
							end
						end
					end
				end
			end

			S_STALL:
			begin
				// Continuing example above:
				// cycle 6: x[8+6=14]*coefs[14]
				// cycle 7: x[15]    *coefs[15]
				// 
				for ( int m=0; m<MUL_CNT; ++m )
				begin
					coef_rd_addrs_c[ m ] = coef_rd_addrs[ m ] + 1'h1;
					x_rd_addrs_c   [ m ] = x_rd_addrs   [ m ] + 1'h1;
				end
				if ( x_rd_addrs_c[ m ] == MUL_STEP )
				begin
					state_c = S_SHIFT_Y;
				end
			end

			S_SHIFT_Y:
			begin
				if ( ~y_out_full )
				begin
					// y_out has been made ready above the case block
					y_out_wr_en = 1'b1;
					state_c = S_SHIFT_X;
					for ( int m=0; m<MUL_CNT; ++m )
					begin
						accs_c[ m ]          = 'sh0;
						x_rd_addrs_c   [ m ] = m * MUL_STEP;
						coef_rd_addrs_c[ m ] = m * MUL_STEP + DECIM - 1;
					end
				end
			end
		endcase

	end 

	always_ff @ ( posedge clk, posedge rst )
	begin
		for ( int m=0; m<MUL_CNT; ++m )
		begin
			// Register reads out of x and coefs to potentially
			// take advantage of memory primitives and save addr multiplexers
			x_out   [ m ] <= x_sh   [ x_rd_addrs_c   [m] ];
			coef_out[ m ] <= X_COEFS[ coef_rd_addrs_c[m] ];
		end

		if ( rst )
		begin
			state <= S_SHIFT_X;
			accs <= '{ default: 'sh0 };
			x_sh <= '{ default: 'sh0 };
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				x_rd_addrs[ m ]    <= m * MUL_STEP;
				coef_rd_addrs[ m ] <= m * MUL_STEP + DECIM - 1;
			end
		end
		else
		begin
			state <= state_c;
			accs <= accs_c;
			if ( (state == S_SHIFT_X) && ~in_empty )
			begin
				x_sh[ 0 ] <= x_in;
				x_sh[ 1:TAPS-1 ] <= x_sh[ 0:TAPS-2 ];
			end
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				x_rd_addrs   [ m ] <= x_rd_addrs_c   [ m ];
				coef_rd_addrs[ m ] <= coef_rd_addrs_c[ m ];
			end
		end
	end

endmodule: fir

