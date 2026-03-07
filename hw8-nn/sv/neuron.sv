
module neuron #(
	parameter int FRAC_WIDTH = 14,
	parameter int INPUT_SIZE = 784,
	parameter int DATA_WIDTH = 32,
	parameter int IDX_WIDTH = 16
)(
	input logic clk,
	input logic rst,

	input logic in_empty,
	input logic out_full,

	input logic signed [ DATA_WIDTH-1:0 ] din,
	input logic signed [ DATA_WIDTH-1:0 ] win,
	input logic in_valid,

	output logic signed [ DATA_WIDTH-1:0 ] dout,
	output logic in_rd_en,
	output logic out_wr_en
);

	localparam logic signed [ DATA_WIDTH-1:0 ] Q_STEP = 1 << FRAC_WIDTH;

	function automatic logic signed [ DATA_WIDTH-1:0 ]
	DEQUANT( input logic signed [ DATA_WIDTH-1:0 ] x );
		if ( x[DATA_WIDTH-1] && ( -x < Q_STEP ) )
		begin
			return 'sd0;
		end
		return ( x + ( Q_STEP>>1 ) ) >>> FRAC_WIDTH;
	endfunction

	typedef enum logic [ 1:0 ] { S_ACC, S_OUT } state_t;
	state_t state, state_c;

	logic [ IDX_WIDTH-1:0 ] idx, idx_c;
	logic signed [ DATA_WIDTH-1:0 ] acc, acc_c;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_ACC;
			idx <= 'd0;
			acc <= 'sh0;
		end
		else
		begin
			state <= state_c;
			idx <= idx_c;
			acc <= acc_c;
		end
	end

	always_comb
	begin
		dout = 'sh0;
		in_rd_en = 1'b0;
		out_wr_en = 1'b0;

		state_c = state;
		idx_c = idx;
		acc_c = acc;

		case ( state )
		S_ACC:
		begin
			if ( ~in_empty )
			begin
				in_rd_en = 1'b1;
				if ( in_valid )
				begin
					idx_c = idx + 2'd1;
					acc_c = acc + DEQUANT( din * win );

					if ( idx_c == INPUT_SIZE )
					begin
						state_c = S_OUT;
					end

				end
			end
		end

		S_OUT:
		begin
			dout = acc >>> FRAC_WIDTH;
			if ( ~out_full )
			begin
				out_wr_en = 1'b1;
				idx_c = 'd0;
				acc_c = 'sh0;
				state_c = S_ACC;
			end
		end

		default:
		begin
			dout = 'shx;
			in_rd_en = 1'b0;
			out_wr_en = 1'b0;
			state_c = S_ACC;
			idx_c = 'd0;
			acc_c = 'shx;
		end
		endcase

	end

endmodule:neuron

