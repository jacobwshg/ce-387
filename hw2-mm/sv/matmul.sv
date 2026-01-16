/*
 * At any given clock edge in the run stage,
 * the X and Y read-addrs sampled by out regs and provided to bram
 * should be 1 ahead of the Z write-addr
 * */
module matmul
#(
	parameter DATA_WIDTH    = 32,
	/* default matrix dimension = 8 */
	parameter MAT_DIM_WIDTH = 6,
	parameter MAT_DIM_SIZE  = 2**MAT_DIM_WIDTH,
	/* default total matrix size = 8x8 = 64 */
	parameter ADDR_WIDTH    = MAT_DIM_WIDTH*2,
	parameter MAT_SIZE      = 2**ADDR_WIDTH
)
(
	input logic clk,
	input logic rst,
	input logic strt,
	input logic [ MAT_DIM_SIZE-1 : 0 ] [ DATA_WIDTH-1 : 0 ] x_r_row,
	input logic [ MAT_DIM_SIZE-1 : 0 ] [ DATA_WIDTH-1 : 0 ] y_r_col,
	output logic [ MAT_DIM_WIDTH-1 : 0 ] i,
	output logic [ MAT_DIM_WIDTH-1 : 0 ] j,
	output logic z_we,
	output logic [ ADDR_WIDTH-1 : 0 ] z_addr,
	output logic [ DATA_WIDTH-1 : 0 ] z_w_data,
	output logic done
);

	typedef enum logic [2]
	{
		S_IDLE, S_RUN
	} state_t;

	typedef logic [ DATA_WIDTH-1 : 0 ] data_t;
	typedef logic [ ADDR_WIDTH-1 : 0 ] addr_t;

	state_t state;
	state_t state_c;

	addr_t i_c, j_c, z_addr_c;

	data_t z_w_data_c;
	logic z_we_c, done_c;

	/*
	function addr_t
	idxs_to_addr(
		input addr_t irow,
		input addr_t icol
	);
		return irow * MAT_DIM_SIZE + icol;
	endfunction
	*/

	/* state and output regs */
	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_IDLE;

			i <= 'h0;
			j <= 'h0;
			z_addr <= 'h0;
			z_w_data <= 'h0;
			z_we <= 'b0;
			done <= 'h0;
		end
		else
		begin
			state <= state_c;

			i <= i_c;
			j <= j_c;
			z_addr <= z_addr_c;
			z_w_data <= z_w_data_c;
			z_we <= z_we_c;
			done <= done_c;
		end
	end

	/* next state and output logic */
	always_comb
	begin
		state_c = state;
		i_c = i;
		j_c = j;
		z_addr_c = z_addr;
		z_w_data_c = 'h0;
		z_we_c = 'b0;
		done_c = done;

		case ( state )
			S_IDLE:
			begin
				if ( strt )
				begin
					state_c = S_RUN;
				end
			end
			S_RUN:
			begin
				/* compute dot product of X row and Y col */
				$display(
					"MM Z[%0d][%0d]", 
					i, j
				);
				foreach ( x_r_row[k] )
				begin
					$display(
						"\tX row [%0d]: %0d, Y col [%0d]: %0d",
						k, x_r_row[k], k, y_r_col[k]
					);
					z_w_data_c += ( x_r_row[k] * y_r_col[k] );
				end
				/* use current indices to compute Z write addr*/
				//$display( z_w_data_c );
				z_addr_c = (i * MAT_DIM_SIZE) + j;
				z_we_c = 'b1;

				/* update X row idx and Y col idx to fetch in next cycle */
				j_c = j + 1;
				if ( j_c == MAT_DIM_SIZE )
				begin
					j_c = 0;
					i_c = i + 1;
				end
				if ( i_c == MAT_DIM_SIZE )
				begin
					done_c = 'b1;
					i_c = 0;
				end

				if ( done_c )
				begin
					state_c = S_IDLE;
					z_we_c = 'b0;
				end
			end
		endcase
	end

endmodule

