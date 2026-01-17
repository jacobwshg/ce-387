/*
 * At any given clock edge in the run stage,
 * the X and Y read-addrs sampled by out regs and provided to bram
 * should be 1 ahead of the Z write-addr
 * */
module matmul
#(
	parameter DATA_WIDTH    = 32,
	parameter MAT_DIM_WIDTH = 2,
	parameter MAT_DIM_SIZE  = 2**MAT_DIM_WIDTH,
	parameter ADDR_WIDTH    = MAT_DIM_WIDTH*2,
	parameter MAT_SIZE      = 2**ADDR_WIDTH
)
(
	input logic clk,
	input logic rst,
	input logic strt,
	input logic [ MAT_DIM_SIZE-1 : 0 ] [ DATA_WIDTH-1 : 0 ] x_r_row,
	input logic [ MAT_DIM_SIZE-1 : 0 ] [ DATA_WIDTH-1 : 0 ] y_r_col,
	/*
 	 * I and J are "requests" made respectively to the X and Y BRAMs.
 	 * In the next cycle, they will respectively return X's row I in X_R_ROW
 	 * and Y's column Y in Y_R_COL.
 	 */
	output logic [ MAT_DIM_WIDTH-1 : 0 ] i,
	output logic [ MAT_DIM_WIDTH-1 : 0 ] j,
	output logic z_we,
	output logic [ ADDR_WIDTH-1 : 0 ] z_addr,
	output logic [ DATA_WIDTH-1 : 0 ] z_w_data,
	output logic done
);

	typedef enum logic [ 1:0 ]
	{
		S_IDLE, S_RUN
	} state_t;

	typedef logic [ DATA_WIDTH-1 : 0 ] data_t;
	/* keep overflow bit for internal addresses */
	typedef logic [ ADDR_WIDTH : 0 ] addr_t;

	state_t state;
	state_t state_c;

	addr_t i_o, j_o;
	addr_t i_c, j_c, z_addr_c;

	data_t z_w_data_c;
	logic z_we_c, done_c;

	assign i = i_o[ MAT_DIM_WIDTH-1 : 0 ];
	assign j = j_o[ MAT_DIM_WIDTH-1 : 0 ];

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

			i_o <= 'h0;
			j_o <= 'h0;
			z_addr <= 'h0;
			z_w_data <= 'h0;
			z_we <= 'b0;
			done <= 'h0;
		end
		else
		begin
			state <= state_c;

			i_o <= i_c;
			j_o <= j_c;

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
		i_c = i_o;
		j_c = j_o;
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
				foreach ( x_r_row[k] )
				begin
					z_w_data_c += ( x_r_row[k] * y_r_col[k] );
				end

				/* use X/Y read indices to backward compute Z write addr*/
				z_addr_c = (i_o * MAT_DIM_SIZE) + j_o - 1;
				z_we_c = 'b1;

				/* update X row idx and Y col idx to fetch in next cycle */
				j_c = j_o + 1;
				if ( j_c == MAT_DIM_SIZE )
				begin
					j_c = 0;
					i_c = i_o + 1;
				end

				if ( (i_c == MAT_DIM_SIZE) && (j_c > 0) )
				begin
					done_c = 'b1;
				end

				if ( done_c )
				begin
					state_c = S_IDLE;
				end

			end
			default:
			begin
				state_c = S_IDLE;
				i_c = 'hx;
				j_c = 'hx;
				z_addr_c = 'hx;
				z_w_data_c = 'hx;
				z_we_c = 'hx;
				done_c = 'hx;
			end
		endcase
	end

endmodule

