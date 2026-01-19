`timescale 1ns/1ns

module matmul_tb();

	localparam DATA_WIDTH = 32;
	localparam MAT_DIM_WIDTH = 3; /* 8x8 */
	//localparam MAT_DIM_WIDTH = 6;
	localparam MAT_DIM_SIZE = 2 ** MAT_DIM_WIDTH;
	localparam ADDR_WIDTH = MAT_DIM_WIDTH * 2;
	localparam MAT_SIZE = 2 ** ADDR_WIDTH;

	//localparam X_PATH = "../X.tv";
	//localparam Y_PATH = "../Y.tv";
	//localparam Z_PATH = "../Z.tv";

	localparam X_PATH = "../x.txt";
	localparam Y_PATH = "../y.txt";
	localparam Z_PATH = "../z.txt";

	localparam PERIOD = 10;

	logic 
		clk = 'b1,
		rst = 'b0,
		strt = 'b0,
		done;

	logic
		x_we = 'b0,
		y_we = 'b0;
	logic [ DATA_WIDTH-1 : 0 ] 
		x_w_data = 'b0,
		y_w_data = 'b0;
	logic [ MAT_DIM_WIDTH-1 : 0 ]
		x_w_bank_id = 'b0,
		y_w_bank_id = 'b0,
		x_w_bank_addr = 'b0,
		y_w_bank_addr = 'b0;

	logic [ ADDR_WIDTH-1 : 0 ] z_r_addr = 'b0;
	logic [ DATA_WIDTH-1 : 0 ] z_r_data; 

	matmul_top #(
		.DATA_WIDTH ( DATA_WIDTH ),
		.MAT_DIM_WIDTH ( MAT_DIM_WIDTH ),
		.MAT_DIM_SIZE ( MAT_DIM_SIZE ),
		.ADDR_WIDTH ( ADDR_WIDTH ), 
		.MAT_SIZE ( MAT_SIZE ) 
	) mm_top_inst
	(
		.clk ( clk ),
		.rst ( rst ),
		.strt ( strt ),
		.x_we( x_we ),
		.y_we( y_we ),
		.x_w_data ( x_w_data ),
		.y_w_data ( y_w_data ),
		.x_w_bank_id ( x_w_bank_id ),
		.y_w_bank_id ( y_w_bank_id ),
		.x_w_bank_addr ( x_w_bank_addr ),
		.y_w_bank_addr ( y_w_bank_addr ),
		.z_r_addr( z_r_addr ),
		.z_r_data( z_r_data ),
		.done( done )
	);

	always
	begin
		#(PERIOD/2);
		clk = 'b0;
		#(PERIOD/2);
		clk = 'b1;
	end

	logic [ DATA_WIDTH-1 : 0 ] 
		x_buf [ MAT_SIZE-1 : 0 ],
		y_buf [ MAT_SIZE-1 : 0 ],
		z_buf [ MAT_SIZE-1 : 0 ];
	
	logic[64] starttime = 0;

	initial
	begin
		#0;
		$readmemh( X_PATH, x_buf );
		$readmemh( Y_PATH, y_buf );
		$readmemh( Z_PATH, z_buf );

		/* Load X and Y */
		#PERIOD;
		for ( int i=0; i<MAT_DIM_SIZE; ++i )
		begin
			for ( int j=0; j<MAT_DIM_SIZE; ++j )
			begin
				@ ( negedge clk );
				x_w_data = x_buf[ i * MAT_DIM_SIZE + j ];
				y_w_data = y_buf[ i * MAT_DIM_SIZE + j ];
				/* X is read one row at a time, so each bank stores a 
 				 * column */
				x_w_bank_id   = j;
				x_w_bank_addr = i;
				y_w_bank_id   = i;
				y_w_bank_addr = j;
				x_we = 'b1;
				y_we = 'b1;
				@ ( negedge clk );
				x_we = 'b0;
				y_we = 'b0;
			end
		end

		$display( "@ %0d\tX, Y load complete", $time );
		starttime = $time;

		/* run MM */
		#PERIOD;
		@ ( negedge clk );
		rst = 'b1;
		@ ( negedge clk );
		rst = 'b0;
		strt = 'b1;
		@ ( negedge clk );
		strt = 'b0;

		wait ( done );
		$display(
			"@ %0d\tMatmul complete, took ~%0d cycles", 
			$time,
			($time - starttime) / (PERIOD)
		);

		/* inspect results in Z */
		#PERIOD;
		for ( int i=0; i<MAT_DIM_SIZE; ++i )
		begin
			for ( int j=0; j<MAT_DIM_SIZE; ++j )
			begin
				@ ( negedge clk );
				z_r_addr = i * MAT_DIM_SIZE + j;
				#PERIOD;
				@ ( negedge clk );
				$display( 
					"Z[%0d][%0d]: expected %0d, actual %0d", 
					i,
					j,
					z_buf[ z_r_addr ],
					z_r_data
				);
			end
		end

		$stop;
	end

endmodule

