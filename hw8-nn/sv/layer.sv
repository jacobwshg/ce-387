
import weights_pkg::*;

module layer #(
	parameter int ID,

	parameter int DATA_WIDTH = 32,
	parameter int FRAC_WIDTH = 14,

	parameter int INPUT_SIZE = 10,
	parameter int OUTPUT_SIZE = 10,
	parameter int IDX_WIDTH = $clog2( INPUT_SIZE )+1,

	parameter logic signed [ 0:OUTPUT_SIZE-1 ] [ DATA_WIDTH-1:0 ]
		LAYER_BIASES,
	parameter logic signed [ 0:INPUT_SIZE-1 ] [ DATA_WIDTH-1:0 ]
		LAYER_WEIGHTS [ 0:OUTPUT_SIZE-1 ]
)
(
	input logic clk,
	input logic rst,

	input logic signed [ DATA_WIDTH-1:0 ] din,
	input logic in_empty,
	input logic out_full,

	output logic signed [ DATA_WIDTH-1:0 ] dout,
	output logic in_rd_en,
	output logic out_wr_en
);

	function automatic logic signed [ DATA_WIDTH-1:0 ]
	ReLU( input logic signed [ DATA_WIDTH-1:0 ] x );
		return ( x>'sh0 )? x: 'sh0;
	endfunction;

	typedef enum logic [ 1:0 ] { S_ACC, S_OUT } state_t;
	state_t state, state_c;

	logic [ IDX_WIDTH-1:0 ]
		in_idx, in_idx_c,
		out_idx, out_idx_c;

	logic signed [ 0:OUTPUT_SIZE-1 ] [ DATA_WIDTH-1:0 ]
		acc, acc_c, acc_neurons;

	genvar n;
	generate
		for ( n=0; n<OUTPUT_SIZE; ++n )
		begin
			neuron #(
				.DATA_WIDTH( DATA_WIDTH ),
				.FRAC_WIDTH( FRAC_WIDTH ),
				.INPUT_SIZE( INPUT_SIZE ),
				.IDX_WIDTH( IDX_WIDTH ),
				.WEIGHTS( LAYER_WEIGHTS[n] )
			) neuron_inst (
				.acc_in( acc[ n ] ),
				.din   ( din ),
				.in_idx( in_idx ),

				.acc_out( acc_neurons[ n ] )
			);
		end
	endgenerate

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state   <= S_ACC;
			in_idx  <= 'h0;
			out_idx <= 'h0;
			/*
			* layer handles weight sum init with biases
			* on behalf of neurons 
			*/
			acc     <= LAYER_BIASES;
		end
		else
		begin
			state   <= state_c;
			in_idx  <= in_idx_c;
			out_idx <= out_idx_c;
			acc     <= acc_c;
		end
	end

	always_comb
	begin
		dout = 'sh0;
		in_rd_en = 1'b0;
		out_wr_en = 1'b0;

		state_c   = state;
		in_idx_c  = in_idx;
		out_idx_c = out_idx;
		acc_c     = acc;

		case ( state )
			S_ACC:
			begin
				if ( ~in_empty )
				begin
					if ( ID > 0 )
					begin
						$display( "@ %0t layer %0d input %0d = %08h", $time, ID, in_idx, din );
					end

					in_rd_en = 1'b1;
					in_idx_c = in_idx + 1'h1;

					/*
					* Listen to neurons and update weighted sums with their
					* new results
					*/
					acc_c = acc_neurons;

					if ( in_idx_c == INPUT_SIZE )
					begin
						state_c = S_OUT;
						in_idx_c = 'h0;
					end
				end
			end

			S_OUT:
			begin
				if ( ~out_full )
				begin

					out_wr_en = 1'b1;
					out_idx_c = out_idx + 1'h1;
					/*
					* Put final accumulated weighted sums through activation
					* function and send downstream sequentially.
					* In this state, the live output `acc_neurons` stays out of
					* the acc_c <-> acc path.
					*/ 
					dout = ReLU( $signed(acc[out_idx])>>>FRAC_WIDTH );

					$display(
						"@ %0t layer %0d raw output %0d = %08h, dequant = %08h, relu = %08h",
						$time, ID, out_idx, acc[out_idx], $signed(acc[out_idx])>>>FRAC_WIDTH, dout
					);

					if ( out_idx_c == OUTPUT_SIZE )
					begin

					$display( "@ %0t layer %0d moving to S_ACC, final outputs:", $time, ID );
					foreach ( acc[i] )
					begin
						$display( "\t\tacc[%0d]: %08h", i, acc[i] );
					end

						state_c = S_ACC;
						out_idx_c = 'h0;
						acc_c = LAYER_BIASES;
					end
				end
			end

			default:
			begin
				dout      = 'shx;
				in_rd_en  = 1'b0;
				out_wr_en = 1'b0;
				state_c   = S_ACC;
				in_idx_c  = 'h0;
				out_idx_c = 'h0;
				for ( int i=0; i<OUTPUT_SIZE; ++i )
				begin
					acc_c = 'shx;
				end
			end

		endcase
		
	end

endmodule: layer

