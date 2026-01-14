/*
 * At any given clock edge in the run stage,
 * the X and Y read-addrs sampled by out regs and provided to bram
 * should be 1 ahead of the Z write-addr
 * */

typedef enum logic
{
	FALSE = 'b0, TRUE = 'b1
} bool_t;

module matmul
#(
	parameter DATA_WIDTH    = 32,
	/* default matrix dimension = 64 */
	parameter MAT_DIM_WIDTH = 6,
	parameter MAT_DIM_SIZE  = 2**MAT_DIM_WIDTH,
	/* default matrix size = 64 * 64 = 4096 */
	parameter ADDR_WIDTH    = MAT_DIM_WIDTH*2,
	parameter MAT_SIZE      = 2**ADDR_WIDTH
)
(
	input logic clk,
	input logic rst,
	input logic strt,
	input logic [ DATA_WIDTH-1 : 0 ] x_r_data,
	input logic [ DATA_WIDTH-1 : 0 ] y_r_data,
	output logic [ ADDR_WIDTH-1 : 0 ] x_addr,
	output logic [ ADDR_WIDTH-1 : 0 ] y_addr,
	output logic [ ADDR_WIDTH-1 : 0 ] z_addr,
	output logic [ DATA_WIDTH-1 : 0 ] z_w_data,
	output bool_t z_we,
	output bool_t done
);

	typedef enum logic [2]
	{
		S_IDLE, S_RUN
	} state_t;
	typedef logic [ DATA_WIDTH-1 : 0 ] data_t;
	typedef logic [ ADDR_WIDTH-1 : 0 ] addr_t;

	state_t state;
	state_t state_c;

	/* auxiliary row/col idx regs and wires
	 * for computing addr outputs */
	addr_t i, j, k;
	addr_t i_c, j_c, k_c;

	addr_t x_addr_c, y_addr_c, z_addr_c;
	data_t z_w_data_c;
	bool_t z_we_c, done_c;

	function addr_t
	idxs_to_addr(
		input addr_t irow,
		input addr_t icol
	);
		return irow * MAT_DIM_SIZE + icol;
	endfunction

	/* next state logic */
	always_comb
	begin
		state_c = state;
		case ( state )
			S_IDLE:
			begin
				if ( strt )
					state_c = S_RUN;
			end
			S_RUN:
			begin
				if ( done_c )
					state_c = S_IDLE;
			end
		endcase
	end

	/* next output logic */
	always_comb
	begin
		x_addr_c = x_addr;
		y_addr_c = y_addr;
		z_addr_c = z_addr;
		i_c = i;
		j_c = j;
		k_c = k;
		z_w_data_c = z_w_data;
		z_we_c = z_we;
		done_c = done;
		case ( state )
			S_IDLE:
			begin
				z_we_c = FALSE;
				x_addr_c = 'h0;
				y_addr_c = 'h0;
				z_addr_c = 'h0;
				i_c = 'h0;
				j_c = 'h0;
				k_c = 'h0;
			end
			S_RUN:
			begin
				z_w_data_c = (x_r_data * y_r_data);
				if ( k )
				begin
					z_w_data_c += z_w_data;
				end
				z_addr_c = idxs_to_addr( i, j );
				//z_addr_c = ( i * MAT_DIM_SIZE ) + j;

				/*
 				 * Only write Z[I][J] if X's row I and Y's col J
 				 * have been completely iterated
 				 */
				k_c = k + 1;
				z_we_c = (k_c == MAT_DIM_SIZE)? TRUE: FALSE;
				if ( z_we_c )
				begin
					k_c = 0;
					j_c = j + 1;
				end

				if ( j_c == MAT_DIM_SIZE )
				begin
					j_c = 0;
					i_c = i + 1;
				end

				if ( i_c == MAT_DIM_SIZE )
				begin
					i_c = 0;
					done_c = TRUE;
					x_addr_c = 'h0;
					y_addr_c = 'h0;
				end
				else
				begin
					//x_addr_c = idxs_to_addr( i_c, k_c );
					//y_addr_c = idxs_to_addr( k_c, j_c );
					x_addr_c = ( i_c * MAT_DIM_SIZE ) + k_c;
					y_addr_c = ( k_c * MAT_DIM_SIZE ) + j_c;
				end
			end
		endcase
	end

	/* state regs */
	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_IDLE;
		end
		else
		begin
			state <= state_c;
		end
	end

	/* output regs */
	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			x_addr <= 0;
			y_addr <= 0;
			z_addr <= 0;
			i <= 0;
			j <= 0;
			k <= 0;
			z_w_data <= 0;
			z_we <= FALSE;
			done = FALSE;
		end
		else
		begin
			x_addr <= x_addr_c;
			y_addr <= y_addr_c;
			z_addr <= z_addr_c;
			i <= i_c;
			j <= j_c;
			k <= k_c;
			z_w_data <= z_w_data_c;
			z_we <= z_we_c;
			done = done_c;
		end
	end

endmodule

