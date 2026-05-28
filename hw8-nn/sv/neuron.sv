
import globals_pkg::DWIDTH;
import globals_pkg::FRACWIDTH;
import globals_pkg::INPUT_SZ;

import quant_pkg::DEQUANT;

import biases_pkg::L0_BIASES;

module neuron #(
	parameter int DWIDTH = globals_pkg::DWIDTH,
	parameter int FRACWIDTH = globals_pkg::FRACWIDTH,
	parameter int INPUT_SZ = globals_pkg::INPUT_SZ,
	parameter int IDX_WIDTH = 16,
	parameter logic signed [ DWIDTH-1:0 ] BIAS = biases_pkg::L0_BIASES[ 0 ]
)(
	input logic clk,
	input logic rst,

	input  logic signed [ DWIDTH-1:0 ] din,
	input  logic signed [ DWIDTH-1:0 ] win,
	input  logic in_valid,
	output logic in_ready,

	input  logic out_ready,
	output logic signed [ DWIDTH-1:0 ] dout,
	output logic out_valid

);

	typedef enum logic [ 1:0 ] { S_MUL, S_ADD, S_OUT } state_t;
	state_t state, state_c;

	logic [ IDX_WIDTH-1:0 ] idx, idx_c;
	logic signed [ DWIDTH-1:0 ]
		prod, prod_c,
		acc, acc_c;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_MUL;
			idx   <= 'd0;
			prod  <= 'sh0;
			acc   <= BIAS; 
		end
		else
		begin
			state <= state_c;
			idx   <= idx_c;
			prod  <= prod_c;
			acc   <= acc_c;
		end
	end

	always_comb
	begin
		in_ready  = 1'b0;
		dout      = 'shX;
		out_valid = 1'b0;

		state_c = state;
		idx_c   = idx;
		prod_c  = prod;
		acc_c   = acc;

		case ( state )

			S_MUL:
			begin
				in_ready = 1'b1;

				if ( in_valid )
				begin
					prod_c  = din * win;
					idx_c   = idx + 1'h1;

					state_c = S_ADD;
				end
			end

			S_ADD:
			begin
				acc_c = acc + quant_pkg::DEQUANT( prod );
				state_c = ( idx === INPUT_SZ ) ? S_OUT : S_MUL;
			end

			S_OUT:
			begin
				dout = acc;
				out_valid = 1'b1;

				if ( out_ready )
				begin
					idx_c   = 'h0;
					acc_c   = 'sh0;
					state_c = S_MUL;
				end
			end

			default:
			begin
				in_ready  = 1'b0;
				dout      = 'shX;
				out_valid = 1'b0;

				state_c = S_MUL;
				idx_c   = 'h0;
				prod_c  = 'shX;
				acc_c   = 'shX;
			end

		endcase

	end

endmodule:neuron

