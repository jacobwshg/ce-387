
`timescale 1 ns / 1 ns

import globals_pkg::FRAME_WIDTH;
import globals_pkg::FRAME_HEIGHT;
import globals_pkg::COL_ID_WIDTH;
import globals_pkg::ROW_ID_WIDTH;
import globals_pkg::BYTE_WIDTH;
import globals_pkg::FIFO_DEPTH;

module edgedet_tb #(
	parameter string INFILE  = "image.bmp",
	parameter string OUTFILE = "sobel_output.bmp",
	parameter string CMPFILE = "stage2_sobel.bmp",

	parameter int CLOCK_PERIOD = 10,

	parameter int FRAME_WIDTH  = globals_pkg::FRAME_WIDTH,
	parameter int FRAME_HEIGHT = globals_pkg::FRAME_HEIGHT,
	parameter int COL_ID_WIDTH = globals_pkg::COL_ID_WIDTH,
	parameter int ROW_ID_WIDTH = globals_pkg::ROW_ID_WIDTH,

	parameter int DSPL_ERR_CNT = 10,

	parameter int TIMEOUT = 10000000

)();

	localparam BMP_HEADER_SIZE = 54;
	localparam BYTES_PER_PIXEL = 3;
	localparam BMP_DATA_SIZE = FRAME_WIDTH * FRAME_HEIGHT * BYTES_PER_PIXEL;


	logic clk = 1'b0;
	logic rst;

	logic in_wr_en = 1'b0;
	logic [ 0:2 ] [ 7:0 ] in_din;
	logic in_full;

	logic out_rd_en = 1'b0;
	logic [ 7:0 ] out_dout;
	logic out_empty;

	logic out_done = 1'b0;

	int err_cnt = 0;
	edgedet_top 
	#(
		.FRAME_WIDTH ( FRAME_WIDTH ),
		.FRAME_HEIGHT( FRAME_HEIGHT ),
		.COL_ID_WIDTH( COL_ID_WIDTH ),
		.ROW_ID_WIDTH( ROW_ID_WIDTH )
	) dut (
		.clk( clk ),
		.rst( rst ),

		.in_wr_en( in_wr_en ),
		.din( in_din ),
		.in_full( in_full ),

		.out_rd_en( out_rd_en ),
		.dout( out_dout ),
		.out_empty( out_empty )
	);

	initial
	begin: clk_proc
		#0; clk = 1'b0;
		while ( 1'b1 )
		begin
			#( CLOCK_PERIOD/2 ); clk = ~clk;
		end
	end: clk_proc

	initial 
	begin: rst_proc
		#0;

		@( negedge clk );
		rst = 1'b1;

		wait ( 10 * CLOCK_PERIOD );
		@( negedge clk );
		rst = 1'b0;

	end: rst_proc

	initial
	begin: timeout_proc
		#TIMEOUT;
		$display( "@%0t timeout", $time );
		$stop;
	end: timeout_proc

	initial
	begin: driver_proc
		time start_time, end_time;

		string diffcmd; 

		@( posedge rst );
		@( negedge rst );
		@( posedge clk );
		start_time = $time;

		// start
		$display("@ %0t: Beginning simulation...", start_time);

		wait( out_done );
		end_time = $time;

		// report metrics
		$display();
		$display("@ %0t: Simulation completed.", end_time);
		$display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
		$display( "Total error count: %0d", err_cnt );
	
		$display("---------------------------------------");
		$display("Output file diff:");
		$swrite( diffcmd, "diff %s %s", OUTFILE, CMPFILE );
		$display( "$ %s\n", diffcmd );
		$system( diffcmd );
		$display("\nEnd diff");

		// end the simulation
		$stop;

	end: driver_proc

	initial
	begin: input_proc

		int infile;
		int _rcnt;
		logic [ 0:BMP_HEADER_SIZE-1 ] [ 7:0 ] bmp_header;

		#0;
		$display( "@ %0t: Loading img %s...", $time, INFILE );
		infile = $fopen( INFILE, "rb" );
		in_wr_en = 1'b0;
		// Skip BMP header
		_rcnt = $fread( bmp_header, infile, 0, BMP_HEADER_SIZE );

		@( posedge rst );
		@( negedge rst );

		// Read data from image file; kick off streaming
		for ( int i=0; ; ) 
		begin
			@( negedge clk );
			in_wr_en = 1'b0;

			if ( !in_full )
			begin
				in_wr_en = 1'b1;
				in_din = 'h0;
				if ( i<BMP_DATA_SIZE )
				begin
					_rcnt = $fread( in_din, infile, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL );
					i += BYTES_PER_PIXEL;
				end
			end
		end

		@( negedge clk );
		in_wr_en = 1'b0;
		$fclose( infile );
	end: input_proc

	initial 
	begin: output_proc

		int _rcnt;
		int outfile;
		int cmpfile;
		logic [ 0:2 ] [ 7:0 ] cmp_dout;
		logic [ 0:BMP_HEADER_SIZE-1 ] [ 7:0 ] bmp_header;

		#0;
		out_done = 1'b0;
		out_rd_en = 1'b0;

		$display( "@ %0t: Comparing file %s...", $time, OUTFILE );
		outfile = $fopen( OUTFILE, "wb" );
		cmpfile = $fopen( CMPFILE, "rb" );
		// Copy the BMP header
		_rcnt = $fread( bmp_header, cmpfile, 0, BMP_HEADER_SIZE );
		foreach ( bmp_header[i] )
		begin
			$fwrite( outfile, "%c", bmp_header[i] );
		end

		@( posedge rst );
		@( negedge rst );

		for ( int i=0; i<BMP_DATA_SIZE; )
		begin
			@ ( negedge clk );
			out_rd_en = 1'b0;

			//$display("@ %0t, out i: %0d\n", $time, i);

			if ( !out_empty )
			begin
				_rcnt = $fread( cmp_dout, cmpfile, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL );

				if ( cmp_dout != { 3 { out_dout } } )
				begin
					err_cnt += 1;
					if ( err_cnt <= DSPL_ERR_CNT )
					begin
						$write(
							"@ %0t: %s(%0d): ERROR: actual { 3 { %x } } !=  expected %x at address 0x%x.\n", 
							$time, OUTFILE, i+1, out_dout, cmp_dout, i
						);
					end
				end
				$fwrite(
					outfile, "%c%c%c", 
					out_dout, out_dout, out_dout
				);
				out_rd_en = 1'b1;
				i += BYTES_PER_PIXEL;
			end
		end

		@( negedge clk );
		out_rd_en = 1'b0;
		$fclose( outfile );
		$fclose( cmpfile );

		//$stop;

		out_done = 1'b1;

	end: output_proc

endmodule: edgedet_tb

