
module sobel (
	input  logic clk,
	input  logic rst,

	input  logic in_empty,
	input  logic [ 2:0 ] [ 7:0 ] in_dout,
	input  logic out_full,

	output logic in_rd_en,
	output logic out_wr_en,
	output logic [7:0] out_din
);

	typedef enum logic {S_READ, S_WRITE} state_t;
	state_t state, state_c;

	logic signed [9:0] 
		hgrad_c, vgrad_c,
		result_c;

	/* store grid in column-major order */
	signed logic [ 2:0 ][ 2:0 ][ 9:0 ] 
		grid, grid_c; 

	always_ff @ (posedge clk, posedge rst)
	begin
		if ( rst )
		begin
			state <= S_READ;
			grid <= 'h0;
		end
		else
		begin
			state <= state_c;
			grid <= grid_c;
		end
	end

	assign hgrad_c = 
		    - grid[0][0]
		+ ( -(grid[0][1] << 1) )
		+ ( - grid[0][2] )
		+     grid[2][0]
		+ (   grid[2][1] << 1 )
		+     grid[2][2];

	assign vgrad_c = 
		-   grid[0][0]
		+   grid[0][2]
		+(-(grid[1][0]<<1))
		+(  grid[1][2]<<1)
		+(- grid[2][0])
		+   grid[2][2];

	assign result_c = (
		( hgrad_c[9] ? -hgrad_c : hgrad_c )
		+ ( vgrad_c[9]? -vgrad_c : vgrad_c )
	) >> 1;

	always_comb
	begin
		in_rd_en  = 1'b0;
		out_wr_en = 1'b0;
		out_din   = 8'h0;
		state_c   = state;
		grid_c = grid;

		case (state)
			S_READ:
			begin
				if ( ~in_empty )
				begin
					grid_c[0] = grid[1];
					grid_c[1] = grid[2];
					grid_c[2] = 
					{
						10'(in_dout[0]), 
						10'(in_dout[1]), 
						10'(in_dout[2]) 
					};	

					in_rd_en = 1'b1;
					state_c = S_WRITE;
				end
			end

			S_WRITE:
			begin
				if ( ~out_full )
				begin
					out_din = (|result_c[9:8]) ? 8'hff: result_c[7:0];
					out_wr_en = 1'b1;
					state_c = S_READ;
				end
			end

			default:
			begin
				in_rd_en  = 1'b0;
				out_wr_en = 1'b0;
				out_din   = 8'h0;
				state_c   = S_READ;
				grid_c    = 'hX;
			end

		endcase
	end

endmodule

