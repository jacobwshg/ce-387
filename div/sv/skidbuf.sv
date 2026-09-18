
module skidbuf
#(
	parameter DWIDTH = 32
)(
	input  logic clk,
	input  logic rst,

	input  logic wr_en,
	input  logic [ DWIDTH-1:0 ] din,
	output logic full,

	input  logic rd_en,
	output logic [ DWIDTH-1:0 ] dout,
	output logic empty
);

	typedef enum logic [ 2:0 ]
	{
		S_EMPTY, S_HALF_FULL, S_FULL
	} fsm_state_t;

	fsm_state_t
		//fsm_state,
		fsm_state_r;

	logic [ DWIDTH-1:0 ] main_r, skid_r;

	always_ff @ ( posedge clk )
	if ( rst )
	begin
		fsm_state_r <= S_EMPTY;
		main_r <= 'h0;
		skid_r <= 'h0;
	end
	else
	begin
		case ( fsm_state_r )
			S_EMPTY:
			begin
				if ( wr_en )
				begin
					main_r <= din;
					fsm_state_r <= S_HALF_FULL;	
				end
			end

			S_HALF_FULL:
			begin
				if ( wr_en && rd_en )
				begin
					main_r <= din;
				end
				else if ( wr_en && !rd_en )
				begin
					skid_r <= din;
					fsm_state_r <= S_FULL;
				end
				else if ( ( !wr_en ) && rd_en )
				begin
					fsm_state_r <= S_EMPTY;
				end
			end

			S_FULL:
			begin
				if ( rd_en )
				begin
					main_r <= skid_r;
					fsm_state_r <= S_HALF_FULL;
				end
			end

			default:
			begin
				fsm_state_r <= S_EMPTY;
			end
		endcase
	end

	assign dout = main_r;
	assign empty = ( S_EMPTY === fsm_state_r );
	assign full = ( S_FULL === fsm_state_r );

endmodule: skidbuf

