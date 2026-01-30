
module subtract 
#(
	parameter THRESHOLD = 50
)
(
	input  logic		clock,
	input  logic		reset,

	input  logic		bg_gs_empty,
	input  logic [7:0]  bg_gs_dout,
	input  logic		frame_gs_empty,
	input  logic [7:0]  frame_gs_dout,
	input  logic		out_full,

	output logic		bg_gs_re,
	output logic		frame_gs_re,
	output logic		out_we,
	output logic [7:0]  out_din
);

typedef enum logic [1:0] {s0, s1} state_t;
state_t state, state_c;

logic [7:0] diff, diff_c;

always_ff @ (posedge clock, posedge reset)
begin
	if (reset == 1'b1) begin
		state <= s0;
		diff <= 'h0;
	end else begin
		state <= state_c;
		diff <= diff_c;
	end
end

always_comb begin
	bg_gs_re    = 1'b0;
	frame_gs_re = 1'b0;

	out_we    = 1'b0;
	out_din   = 'h0;
	state_c   = state;
	diff_c    = diff;

	case (state)
		s0: begin
			if ( (!bg_gs_empty) && (!frame_gs_empty) )
			begin
				diff_c = 
					bg_gs_dout > frame_gs_dout
					? bg_gs_dout - frame_gs_dout
					: frame_gs_dout - bg_gs_dout; 
				diff_c = diff_c > THRESHOLD ? 'hff : 'h0;

				bg_gs_re    = 'b1;
				frame_gs_re = 'b1;

				state_c = s1;
			end
		end

		s1: begin
			if (out_full == 1'b0)
			begin
				out_din = diff;
				out_we = 'b1;

				state_c = s0;
			end
		end

		default: begin
			bg_gs_re    = 'b0;
			frame_gs_re = 'b0;
			out_we      = 'b0;
			out_din     = 'h0;
			state_c     = s0;
			diff_c      = 'hx;
		end

	endcase
end

endmodule

