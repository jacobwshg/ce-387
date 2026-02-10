
module grayscale (
	input  logic		clock,
	input  logic		reset,

	input  logic		in_empty,
	input  logic [23:0] in_dout,
	input  logic		out_full,

	output logic		in_rd_en,
	output logic		out_wr_en,
	output logic [7:0]  out_din
);

typedef enum logic { S_RD, S_WR } state_t;
state_t state, state_c;

logic [7:0] gs, gs_c;

always_ff @ (posedge clock, posedge reset)
begin
	if ( reset )
	begin
		state <= S_RD;
		gs    <= 8'h0;
	end else begin
		state <= state_c;
		gs    <= gs_c;
	end
end

always_comb
begin
	in_rd_en  = 1'b0;
	out_wr_en = 1'b0;
	out_din   = 8'b0;
	state_c   = state;
	gs_c      = gs;

	case (state)
		S_RD:
		begin
			if ( ~in_empty )
			begin
				gs_c = 8'(
					(
						$unsigned({2'b0, in_dout[23:16]}) 
						+ $unsigned({2'b0, in_dout[15:8]}) 
						+ $unsigned({2'b0, in_dout[7:0]})
					)
				);
				in_rd_en = 1'b1;
				state_c = S_WR;
			end
		end

		S_WR:
		begin
			if ( ~out_full )
			begin
				out_din = gs / $unsigned(10'd3);
				out_wr_en = 1'b1;
				state_c = S_RD;
			end
		end

		default:
		begin
			in_rd_en  = 1'b0;
			out_wr_en = 1'b0;
			out_din   = 8'b0;
			state_c   = S_RD;
			gs_c      = 8'hX;
		end

	endcase
end

endmodule
