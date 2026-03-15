`timescale 1ns/1ps

import globals_pkg::*;
import quant_pkg::*;

module fir #(
	parameter int DWIDTH = 32,
	parameter int TAPS = 32,
	parameter int DECIM = 8,

	parameter int MUL_CNT = 4,

	parameter logic signed [ DWIDTH-1:0 ] X_COEFS [ 0:TAPS-1 ] = '{default:0}
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

	localparam int MUL_STEP = TAPS / MUL_CNT;

	typedef enum logic [ 1:0 ]
	{
		S_INIT, S_SHIFT_X, S_STALL, S_OUT_Y 
	} state_t;
	state_t state, state_c;

	/* shiftreg buffer */
	logic signed [ DWIDTH-1:0 ] x_sh [ 0:TAPS-1 ];

	logic x_sh_en, x_sh_en_c;

	logic signed [ DWIDTH-1:0 ] accs [ 0:MUL_CNT-1 ], accs_c [ 0:MUL_CNT-1 ];

	logic signed [ $clog2( TAPS ):0 ]
		coef_rd_addrs   [ 0:MUL_CNT-1 ], 
		coef_rd_addrs_c [ 0:MUL_CNT-1 ],
		x_rd_addrs      [ 0:MUL_CNT-1 ], 
		x_rd_addrs_c    [ 0:MUL_CNT-1 ];

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
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				y_out += accs[ m ];
			end
		end
		else if ( x_sh_en || (state==S_STALL) )
		begin
			for ( int m=0; m<MUL_CNT; ++m )
			begin
				accs_c[ m ] = accs[ m ] + DEQUANT( X_COEFS[coef_rd_addrs[m]] * x_sh[x_rd_addrs[m]] );
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
					
					for ( int m=0; m<MUL_CNT; ++m )
					begin
						coef_rd_addrs_c[ m ] = coef_rd_addrs[ m ] - 1'h1;
					end

					if ( coef_rd_addrs[ 0 ] == 0 )
					begin
						x_in_rd_en = 1'b0; 
						
						if ( MUL_STEP == DECIM )
						begin
							state_c = S_OUT_Y;
						end
						else
						begin
							state_c = S_STALL;
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
					y_out_wr_en = 1'b1;
					state_c = S_INIT;
				end
			end
		endcase

		x_sh_en_c = ( ~x_in_empty ) && ( state_c==S_SHIFT_X ); 
	end 

	always_ff @ ( posedge clk, posedge rst )
	begin
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