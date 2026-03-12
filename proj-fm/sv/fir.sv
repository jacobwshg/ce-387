
import globals_pkg::*;
import quant_pkg::*;

module fir #(
	parameter int DWIDTH = 32,
	parameter int TAPS = 32,
	parameter int DECIM = 8,

	parameter int MUL_CNT = 4,

	parameter logic signed [ DWIDTH-1:0 ] X_COEFS [ 0:TAPS-1 ]
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

	typedef enum logic [ 1:0 ]
	{
		S_INIT, S_SHIFT_X, S_STALL, S_OUT_Y 
	} state_t;
	state_t state, state_c;

	/* shiftreg buffer */
	logic signed [ DWIDTH-1:0 ] x_sh [ 0:TAPS-1 ];

	// In S_SHIFT_X, in order to know whether to accumulate a value,
	// we need to know whether it is newly ahifted in. It's possible
	// that we are in S_SHIFT_X but don't shift every cycle due to 
	// upstream congestion. Thus we need to know whether shift was enabled
	// in the _previous_ cycle.
	// This is not an issue in S_STALL because the "stall" is because
	// we didn't cover all the existing values for the partial sums,
	// and we never stall due to waiting for upstream to be not empty.
	logic x_sh_en, x_sh_en_c;

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

		state_c = state;

		accs_c = accs;
		coef_rd_addrs_c = coef_rd_addrs;
		x_rd_addrs_c    = x_rd_addrs;

		x_sh_en_c = 1'b0;

		if ( state == S_OUT_Y )
		begin
			// Sum partial sums
			// y_out is combinational. So even if we're stuch in S_OUT_Y
			// due to downstream congestion, we'll simply compute the same 
			// y_out from the same accs without adding anything repeatedly.
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				// TODO: dequantize only before outputting to improving timing?
				// need to widen accs to avoid overflow 
				y_out += accs[ m ];
			end
		end
		else if ( x_sh_en || (state==S_STALL) )
		begin
			// Accumulate one product (for x and coef value at current read
			// addrs) into each partial sum
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				accs_c[ m ] = accs[ m ] + DEQUANT( coef_out[ m ] * x_out[ m ] );
			end
		end

		case ( state )
			S_INIT:
			begin
				for ( int m=0; m<MUL_CNT; ++m )
				begin
					accs_c[ m ]          = 'sh0;
					x_rd_addrs_c   [ m ] = m * MUL_STEP;
					coef_rd_addrs_c[ m ] = m * MUL_STEP + DECIM - 1;
				end

				if ( ~x_in_empty )
				begin
					x_in_rd_en = 1'b1;
					state_c = S_SHIFT_X;
				end
			end

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
					//   cycle 1: + x[8]  *coefs[12]
					//   cycle 2: + x[8]  *coefs[11]
					//   cycle 3: + x[8]  *coefs[10]
					//   cycle 4: + x[8]  *coefs[9]
					//   cycle 5: + x[8]  *coefs[8]
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
					// We have covered all values that we can in this state
					begin
						if ( MUL_STEP >= DECIM )
						begin
							// MUL_STEP fully covers DECIM; we already have
							// what we need for each partialsum and don't need
							// to stall
							state_c = S_OUT_Y;
						end
						else
						begin
							state_c = S_STALL;
							// Initialize read addrs for S_STALL:
							//   Prepare to read x and coefs at same addrs
							//   ( there is no shifing involved in S_STALL )
							//   and accumulate their products.
							//   The lowest addr we didn't touch by the end of
							//   S_SHIFT is at offset DECIM from step base. 
							//   we start there and move right through the
							//   step.
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
				// Finish up remaining values that were deeper
				// behind inside the step, such that we didn't
				// 	 capture them while camping out at step base
				//   in S_SHIFT_X.
				//
				// Continuing example above, for multiplier 1:
				//   cycle 6: + x[8+6=14]*coefs[14]
				//   cycle 7: + x[15]    *coefs[15]
				// 
				for ( int m=0; m<MUL_CNT; ++m )
				begin
					coef_rd_addrs_c[ m ] = coef_rd_addrs[ m ] + 1'h1;
					x_rd_addrs_c   [ m ] = x_rd_addrs   [ m ] + 1'h1;
				end
				if ( x_rd_addrs_c[ 0 ] == MUL_STEP )
				begin
					state_c = S_OUT_Y;
				end
			end

			S_OUT_Y:
			begin
				if ( ~y_out_full )
				begin
					// y_out has been made ready above the case block
					y_out_wr_en = 1'b1;
					state_c = S_INIT;
				end
			end
		endcase

		// If the _next_ cycle will be in S_SHIFT_X (this cycle is possibly S_INIT
		//   or S_SHIFT_X), it will need to know whether it can accumulate a fresh x value.
		// If this cycle sees that upstream is not empty, we ramp up for
		//   the next cycle by enabling shifting in a fresh value on the upcoming
		//   clk edge.
		x_sh_en_c = ( ~x_in_empty ) && ( state_c==S_SHIFT_X ); 

	end 

	always_ff @ ( posedge clk, posedge rst )
	begin
		for ( int m=0; m<MUL_CNT; ++m )
		begin
			// Register reads out of x and coefs to potentially
			// take advantage of memory primitives and save addr multiplexers
			//
			x_out   [ m ] <= x_sh   [ x_rd_addrs_c   [m] ];
			coef_out[ m ] <= X_COEFS[ coef_rd_addrs_c[m] ];
		end

		if ( rst )
		begin
			state <= S_INIT;

			x_sh_en <= 1'b0;

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

			x_sh_en <= x_sh_en_c;

			accs <= accs_c;
			// We are on clk edge.
			// If the prev cycle determined that we can shift in a new
			//   value ( x_sh_en_c asserted ), we do so, and clock x_sh_en_c
			//   into x_sh_en.
			// If the next cycle is in S_SHIFT_X, it will know this value is fresh 
			//   by looking at x_sh_en. 
			if ( x_sh_en_c ) 
			begin
				x_sh[ 0 ]        <= x_in;
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

