
`timescale 1 ns / 1 ns

module edge_detect_tb();

	localparam string INFILE  = "base.bmp";
	localparam string OUTFILE = "output.bmp";
	localparam string CMPFILE = "img_out.bmp";
	localparam CLOCK_PERIOD = 10;

	logic clock = 1'b1;
	logic reset = '0;
	logic start = '0;
	logic done  = '0;

	logic in_gs_we;
	logic [ 23:0 ] in_gs_din;
	logic sobel_out_re;

	logic in_gs_full;
	logic sobel_out_empty;
	logic [ 7:0 ] sobel_out_dout;

	logic   hold_clock	= '0;
	logic   in_write_done = '0;
	logic   out_read_done = '0;
	integer out_errors	= '0;

	localparam WIDTH  = 720;
	localparam HEIGHT = 540;
	localparam BMP_HEADER_SIZE = 54;
	localparam BYTES_PER_PIXEL = 3;
	localparam BMP_DATA_SIZE = WIDTH * HEIGHT * BYTES_PER_PIXEL;

	edge_detect_top 
	#(
		.WIDTH (WIDTH),
		.HEIGHT(HEIGHT)
	) 
	edge_detect_top_inst (
		.clock(clock),
		.reset(reset),

		.in_gs_we    ( in_gs_we ),
		.in_gs_din   ( in_gs_din ),
		.sobel_out_re( sobel_out_re ),

		.in_gs_full     ( in_gs_full ),
		.sobel_out_empty( sobel_out_empty ),
		.sobel_out_dout ( sobel_out_dout )
	);

	always begin
		clock = 1'b1;
		#(CLOCK_PERIOD/2);
		clock = 1'b0;
		#(CLOCK_PERIOD/2);
	end

	initial 
	begin
		@(posedge clock);
		reset = 1'b1;
		@(posedge clock);
		reset = 1'b0;
	end

	initial
	begin : driver
		time start_time, end_time;

		string diffcmd; 

		@(negedge reset);
		@(posedge clock);
		start_time = $time;

		// start
		$display("@ %0t: Beginning simulation...", start_time);
		start = 1'b1;
		@(posedge clock);
		start = 1'b0;

		wait(out_read_done);
		end_time = $time;

		// report metrics
		$display();
		$display("@ %0t: Simulation completed.", end_time);
		$display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
		$display("Total error count: %0d", out_errors);
	
		$display("---------------------------------------");
		$display("Output file diff:");
		$swrite( diffcmd, "diff %s %s", OUTFILE, CMPFILE );
		$display( "$ %s\n", diffcmd );
		$system( diffcmd );
		$display("\nEnd diff");

		// end the simulation
		$finish;
	end

	initial
	begin : read_img

		int infile;
		int _rcnt;
		logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

		@ ( negedge reset );
		$display( "@ %0t: Loading img %s...", $time, INFILE );
		infile = $fopen( INFILE, "rb" );
		in_gs_we = 1'b0;

		// Skip BMP header
		_rcnt = $fread( bmp_header, infile, 0, BMP_HEADER_SIZE );

		// Read data from image file; kick off streaming
		for( int i=0; i<BMP_DATA_SIZE; ) 
		begin
			@ ( negedge clock );
			in_gs_we = 1'b0;

			if ( !in_gs_full )
			begin
				_rcnt = $fread(
					in_gs_din, infile, 
					BMP_HEADER_SIZE+i, BYTES_PER_PIXEL
				);
				in_gs_we = 1'b1;
				i += BYTES_PER_PIXEL;
			end
		end

		@ ( negedge clock );
		in_gs_we = 1'b0;
		$fclose( infile );
		in_write_done = 1'b1;
	end

	initial 
	begin : write_img
		int _rcnt;
		int outfile;
		int cmpfile;
		logic [23:0] cmp_dout;
		logic [0:BMP_HEADER_SIZE-1] [7:0] bmp_header;

		@ ( negedge reset );
		@ ( negedge clock );

		$display( "@ %0t: Comparing file %s...", $time, OUTFILE );
	
		outfile = $fopen( OUTFILE, "wb" );
		cmpfile = $fopen( CMPFILE, "rb" );
		sobel_out_re = 1'b0;
	
		// Copy the BMP header
		_rcnt = $fread( bmp_header, cmpfile, 0, BMP_HEADER_SIZE );
		foreach ( bmp_header[i] )
		begin
			$fwrite( outfile, "%c", bmp_header[i] );
		end

		for ( int i=0; i<BMP_DATA_SIZE; )
		begin
			@ ( negedge clock );
			sobel_out_re = 1'b0;

		/////////
		//$display("@ %0t, out i: %0d\n", $time, i);

			if ( !sobel_out_empty )
			begin
				_rcnt = $fread(cmp_dout, cmpfile, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);

				if ( cmp_dout != { 3 { sobel_out_dout } } ) 
				begin
					out_errors += 1;
					/*
					$write(
						"@ %0t: %s(%0d): ERROR: actual { 3 { %x } } !=  expected %x at address 0x%x.\n", 
						$time, OUTFILE, i+1, sobel_out_dout, cmp_dout, i
					);
					*/
				end
				$fwrite(
					outfile, "%c%c%c", 
					sobel_out_dout, sobel_out_dout, sobel_out_dout
				);
				//$fwrite(outfile, "%u", hl_out_dout);
				sobel_out_re = 1'b1;
				i += BYTES_PER_PIXEL;
			end
		end

		@ ( negedge clock );
		sobel_out_re = 1'b0;
		$fclose( outfile );
		$fclose( cmpfile );
		out_read_done = 1'b1;
	end

endmodule

