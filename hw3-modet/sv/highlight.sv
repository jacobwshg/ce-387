
module highlight (
	input  logic		clock,
	input  logic		reset,

	input  logic		gs_sub_empty,
	input  logic [7:0]  gs_sub_dout,
	input  logic		frame_empty,
	input  logic [23:0] frame_dout,
	input  logic		out_full,

	output logic		gs_sub_re,
	output logic		frame_re,
	output logic		out_we,
	output logic [23:0] out_din
);

typedef enum logic [1:0] {s0, s1} state_t;
state_t state, state_c;

logic [23:0] hl, hl_c;

localparam HIGHLIGHT = 24'h0000ff;

always_ff @ (posedge clock, posedge reset)
begin
	if (reset == 1'b1) begin
		state <= s0;
		hl <= 'h0;
	end else begin
		state <= state_c;
		hl <= hl_c;
	end
end

always_comb
begin
	gs_sub_re = 'b0;
	frame_re  = 'b0;

	out_we    = 1'b0;
	out_din   = 'h0;

	state_c   = state;
	hl_c      = hl;

	case (state)
		s0:
		begin
			if ( (!gs_sub_empty) && (!frame_empty) )
			begin
				hl_c = gs_sub_dout == 8'hff ? HIGHLIGHT : frame_dout; 

				gs_sub_re = 'b1;
				frame_re  = 'b1;

				state_c = s1;
			end
		end

		s1: 
		begin
			if (out_full == 1'b0)
			begin
				out_din = hl;
				out_we = 'b1;

				state_c = s0;
			end
		end

		default:
		begin
			gs_sub_re = 'b0;
			frame_re  = 'b0;
			out_we    = 'b0;
			out_din   = 'h0;
			state_c   = s0;
			hl_c      = 'hx;
		end

	endcase
end

endmodule

