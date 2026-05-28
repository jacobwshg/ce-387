
import globals_pkg::DWIDTH;
import globals_pkg::FRACWIDTH;

import weights_pkg::*;
import biases_pkg::*;

module layer #(
	parameter int ID = 0,

	parameter int DWIDTH = globals_pkg::DWIDTH,
	parameter int FRACWIDTH = globals_pkg::FRACWIDTH,

	parameter int INPUT_SZ  = globals_pkg::INPUT_SZ,
	parameter int OUTPUT_SZ = globals_pkg::L0_SZ,
	parameter int IDX_WIDTH = $clog2( INPUT_SZ>OUTPUT_SZ ? INPUT_SZ : OUTPUT_SZ  )+1,

	parameter logic signed [ DWIDTH-1:0 ]
		LAYER_BIASES  [ 0:OUTPUT_SZ-1 ] = biases_pkg::L0_BIASES,
	parameter logic signed [ 0:INPUT_SZ-1 ] [ DWIDTH-1:0 ]
		LAYER_WEIGHTS [ 0:OUTPUT_SZ-1 ] = weights_pkg::L0_WEIGHTS
)
(
	input logic clk,
	input logic rst,

	input logic signed [ DWIDTH-1:0 ] din,
	input logic in_empty,
	input logic out_full,

	output logic signed [ DWIDTH-1:0 ] dout,
	output logic in_rd_en,
	output logic out_wr_en
);

	function automatic logic signed [ DWIDTH-1:0 ]
	ReLU( input logic signed [ DWIDTH-1:0 ] x );
		return ( x>'sh0 ) ? x : 'sh0;
	endfunction;

	typedef enum logic [ 2:0 ] { S_FETCH, S_SEND, S_WAIT, S_OUT } state_t;
	state_t state, state_c;

	logic [ IDX_WIDTH-1:0 ]
		in_idx,  in_idx_c,
		out_idx, out_idx_c;

	// scatter uniformly across neurons
	logic signed [ DWIDTH-1:0 ]
		neur_din, neur_din_c;
	logic
		neur_in_valid,
		neur_out_ready;

	// neuron-specific
	logic signed [ DWIDTH-1:0 ]
		neur_win  [ 0:OUTPUT_SZ-1 ],
		neur_dout [ 0:OUTPUT_SZ-1 ],
		acc       [ 0:OUTPUT_SZ-1 ], acc_c [ 0:OUTPUT_SZ-1 ];
	logic [ 0:OUTPUT_SZ-1 ]
		neur_in_ready,
		neur_out_valid;

	genvar i;
	generate
		for ( i=0; i<OUTPUT_SZ; ++i )
		begin
			neuron #(
				.DWIDTH( DWIDTH ),
				.FRACWIDTH( FRACWIDTH ),
				.INPUT_SZ( INPUT_SZ ),
				.IDX_WIDTH( IDX_WIDTH ),
				.BIAS( LAYER_BIASES[ i ] )
			) neuron (
				.clk( clk ), .rst( rst ),

				.din( neur_din ), .win( neur_win[ i ] ),
				.in_valid( neur_in_valid ),
				.in_ready( neur_in_ready[ i ] ),

				.out_ready( neur_out_ready ),
				.dout     ( neur_dout[ i ] ),
				.out_valid( neur_out_valid[ i ] )
			);
		end
	endgenerate

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state    <= S_FETCH;
			in_idx   <= 'h0;
			out_idx  <= 'h0;
			neur_din <= 'sh0;
			acc      <= '{ default: 'sh0 };
		end
		else
		begin
			state    <= state_c;
			in_idx   <= in_idx_c;
			out_idx  <= out_idx_c;
			neur_din <= neur_din_c;
			acc      <= acc_c;
		end
	end

	always_ff @ ( posedge clk )
	begin: rd_weights

		for ( int i=0; i<OUTPUT_SZ; ++i )
		begin
			neur_win[ i ] <= LAYER_WEIGHTS[ i ][ in_idx ];
		end
	end: rd_weights

	always_comb
	begin
		dout      = 'sh0;
		in_rd_en  = 1'b0;
		out_wr_en = 1'b0;

		state_c   = state;
		in_idx_c  = in_idx;
		out_idx_c = out_idx;

		neur_in_valid = 'b0;
		neur_out_ready = 'b0;

		neur_din_c = neur_din;
		acc_c = acc;

		case ( state )
			S_FETCH:
			begin
				if ( !in_empty )
				begin
					in_rd_en = 1'b1;
					if ( ID > 0 )
					begin
						$display( "@ %0t layer %0d input %0d = %08h", $time, ID, in_idx, din );
					end
					neur_din_c = din;

					state_c = S_SEND;

					//
					// delay incrementing in_idx so that we have stable
					// weights based on current in_idx in S_SEND
					//
					//in_idx_c = in_idx + 1'h1;

					if ( in_idx_c == INPUT_SZ )
					begin
						state_c = S_OUT;
						in_idx_c = 'h0;
					end
				end
			end

			S_SEND:
			begin
				neur_in_valid = 1'b1;
				if ( & neur_in_ready )
				begin
					in_idx_c = in_idx + 1'h1;
					state_c = ( in_idx_c===INPUT_SZ ) ? S_WAIT : S_FETCH;
				end
			end

			S_WAIT:
			begin
				neur_out_ready = 1'b1;
				if ( & neur_out_valid )
				begin
					acc_c = neur_dout;

					in_idx_c  = 'h0;
					out_idx_c = 'h0;

					state_c = S_OUT;
				end
			end

			S_OUT:
			begin
				if ( !out_full )
				begin

					out_wr_en = 1'b1;
					/*
					 * Put final accumulated weighted sums through activation
					 * function and send downstream sequentially.
					 */ 
					dout = ReLU( $signed(acc[out_idx] ) );

					$display(
						"@ %0t layer %0d raw output %0d = %08h, dequant = %08h, relu = %08h",
						$time, ID, out_idx, acc[out_idx], $signed(acc[out_idx])>>>FRACWIDTH, dout
					);

					out_idx_c = out_idx + 1'h1;
					if ( out_idx_c == OUTPUT_SZ )
					begin

						$display( "@ %0t layer %0d returning to S_FETCH, final outputs:", $time, ID );
						foreach ( acc[ i ] )
						begin 
							$display( "\t\tacc[%0d]: %08h", i, acc[i] );
						end

						state_c = S_FETCH;
						out_idx_c = 'h0;
					end
				end
			end

			default:
			begin
				dout      = 'shx;
				in_rd_en  = 1'b0;
				out_wr_en = 1'b0;

				state_c   = S_FETCH;
				in_idx_c  = 'h0;
				out_idx_c = 'h0;

				neur_in_valid = 1'b0;
				neur_out_ready = 1'b0;

				neur_din_c = 'shX;
				acc_c = '{ default: 'shX };

			end

		endcase
		
	end

endmodule: layer

