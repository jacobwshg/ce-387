
module bg_subtract 
#(
	parameter THRESHOLD = 50
)
(
	input  logic		clock,
	input  logic		reset,

	input  logic		bg_sub_empty,
	input  logic [7:0]  bg_sub_dout,
	input  logic		frame_sub_empty,
	input  logic [7:0]  frame_sub_dout,
	input  logic		out_full,

	output logic		bg_sub_re,
	output logic		frame_sub_re,
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
		diff <= 8'h0;
	end else begin
		state <= state_c;
		diff <= diff_c;
	end
end

always_comb begin
	bg_sub_re    = 1'b0;
	frame_sub_re = 1'b0;

	out_we    = 1'b0;
	out_din   = 'h0;
	state_c   = state;
	diff_c    = diff;

	case (state)
		s0: begin
			if ( (!bg_sub_empty) && (!frame_sub_empty) )
			begin
				diff_c = 
					bg_sub_dout > frame_sub_dout
					? bg_sub_dout - frame_sub_dout
					: frame_sub_dout - bg_sub_dout; 
				diff_c = diff_c > THRESHOLD ? 8'hff : 8'h0;

				bg_sub_re    = 'b1;
				frame_sub_re = 'b1;

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
			bg_sub_re    = 'b0;
			frame_sub_re = 'b0;
			out_we      = 'b0;
			out_din     = 'h0;
			state_c     = s0;
			diff_c      = 'hx;
		end

	endcase
end

endmodule
