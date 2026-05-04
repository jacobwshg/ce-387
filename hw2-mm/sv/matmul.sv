/*
 * At any given clock edge in the run stage,
 * the X and Y read-addrs sampled by out regs and provided to bram
 * should be 1 ahead of the Z write-addr
 * */
module matmul
#(
	parameter DATA_WIDTH    = 32,
	parameter MAT_DIM_WIDTH = 3,
	parameter MAT_DIM_SIZE  = 2**MAT_DIM_WIDTH,
	parameter ADDR_WIDTH    = MAT_DIM_WIDTH*2,
	parameter MAT_SIZE      = 2**ADDR_WIDTH
)
(
	input logic clk,
	input logic rst,
	input logic strt,
	input logic [ DATA_WIDTH-1:0 ]
		x_rd_row [ 0:MAT_DIM_SIZE-1 ],
		y_rd_col [ 0:MAT_DIM_SIZE-1 ],
	/*
 	 * I and J are "requests" made respectively to the X and Y BRAMs.
 	 * In the next cycle, they will respectively return X's row I in X_R_ROW
 	 * and Y's column Y in Y_R_COL.
 	 */
	output logic [ MAT_DIM_WIDTH-1:0 ] 
		i, j,
	output logic z_wr_en,
	output logic [ ADDR_WIDTH-1:0 ] z_wr_addr,
	output logic [ DATA_WIDTH-1:0 ] z_wr_data,
	output logic done
);

	typedef enum logic [ 1:0 ]
	{
		S_IDLE, S_MUL, S_ADD
	} state_t;

	typedef logic [ DATA_WIDTH-1:0 ] data_t;
	/* keep overflow bit for internal addresses */
	typedef logic [ ADDR_WIDTH:0 ] addr_t;

	state_t state, state_c;

	addr_t i_ff, j_ff;
	addr_t i_c, j_c, z_wr_addr_c;

	// element-wise products
	logic [ DATA_WIDTH-1:0 ]
		prods   [ 0:MAT_DIM_SIZE-1 ],
		prods_c [ 0:MAT_DIM_SIZE-1 ];

	// don't use _c indices, so as to faciliatate 
	// X, Y BRAM inference
	assign i = i_ff[ MAT_DIM_WIDTH-1:0 ];
	assign j = j_ff[ MAT_DIM_WIDTH-1:0 ];

	logic done_c;

	/* state and output regs */
	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_IDLE;
			i_ff <= 'h0;
			j_ff <= 'h0;
			prods <= '{ default: 'h0 };
			z_wr_addr <= 'h0;
			done <= 1'b0;
		end
		else
		begin
			state <= state_c;
			i_ff <= i_c;
			j_ff <= j_c;
			prods <= prods_c;
			z_wr_addr <= z_wr_addr_c;
			done <= done_c;
		end
	end

	/* next state and output logic */
	always_comb
	begin
		state_c = state;
		i_c = i_ff;
		j_c = j_ff;

		prods_c = prods;

		z_wr_addr_c = z_wr_addr;
		z_wr_data = 'h0;
		z_wr_en = 'b0;

		done_c = done;

		case ( state )
			S_IDLE:
			begin
				if ( strt )
				begin
					state_c = S_MUL;
					i_c = 'h0;
					j_c = 'h0;
				end
			end

			S_MUL:
			begin
				prods_c = '{ default: 'h0 };
				/* compute X row dot Y col */
				foreach ( x_rd_row[ k ] )
				begin
					prods_c[ k ] = x_rd_row[ k ] * y_rd_col[ k ];
				end
				//$display( "@%0t, prods_c: %p", $time, prods_c );
				state_c = S_ADD;
			end

			S_ADD:
			begin
				z_wr_data = 'h0;
				foreach ( prods[ k ] )
				begin
					z_wr_data += prods[ k ];
				end
				//$display( "%08d", z_wr_data );

				z_wr_en = 1'b1;

				/* update X row idx and Y col idx to fetch in next cycle */
				if ( j_ff + 1'h1 === MAT_DIM_SIZE )
				begin
					j_c = 'h0;
					i_c = i_ff + 1'h1;
				end
				else
				begin
					j_c = j_ff + 1'h1;
				end

				//
				// because we are using clocked indices for X, Y and 
				// not reading ahead, let z write addr stay at 0 
				// for one more cycle
				//
				if ( i_ff>1'h0 || j_ff>1'h0 )
				begin
					z_wr_addr_c = z_wr_addr + 1'h1;
				end

				if ( i_c === MAT_DIM_SIZE && j_c > 0 )
				/* next Z write addr is past valid range */
				begin
					done_c = 1'b1;
				end

				if ( done_c )
				begin
					state_c = S_IDLE;
				end
				else
				begin
					state_c = S_MUL;
				end

			end
			default:
			begin
				state_c = S_IDLE;
				i_c = 'h0;
				j_c = 'h0;
				prods_c = '{ default: 'h0 };
				z_wr_addr_c = 'h0;
				z_wr_data = 'h0;
				done_c = 'b0;
			end
		endcase
	end

endmodule

