
`timescale 1 ns / 1 ns

module motion_detect_tb();

localparam string INFILE_BG    = "base.bmp";
localparam string INFILE_FRAME = "pedestrians.bmp";
localparam string OUTFILE      = "output.bmp";
localparam string CMPFILE      = "img_out.bmp";
localparam CLOCK_PERIOD = 10;

logic clock = 1'b1;
logic reset = '0;
logic start = '0;
logic done  = '0;

/*
logic		in_full;
logic		in_wr_en  = '0;
logic [23:0] in_din	= '0;
logic		out_rd_en;
logic		out_empty;
logic  [7:0] hl_out_dout;
*/

logic        bg_gs_we;
logic [23:0] bg_gs_din;
logic        frame_gs_we;
logic [23:0] frame_gs_din;
logic        frame_hl_we;
logic [23:0] frame_hl_din;
logic        hl_out_re;

logic        bg_gs_full;
logic        frame_gs_full;
logic        frame_hl_full;
logic        hl_out_empty;
logic [23:0] hl_out_dout;

logic   hold_clock	= '0;
logic   bg_gs_write_done = '0;
logic   frame_gs_write_done = '0;
logic   frame_hl_write_done = '0;
logic   out_read_done = '0;
integer out_errors	= '0;

localparam WIDTH  = 768;
localparam HEIGHT = 576;
localparam BMP_HEADER_SIZE = 54;
localparam BYTES_PER_PIXEL = 3;
localparam BMP_DATA_SIZE = WIDTH * HEIGHT * BYTES_PER_PIXEL;

motion_detect_top 
#(
	.WIDTH (WIDTH),
	.HEIGHT(HEIGHT)
) 
motion_detect_top_inst (
	.clock(clock),
	.reset(reset),

	.bg_gs_we    (bg_gs_we),
	.bg_gs_din   (bg_gs_din),
	.frame_gs_we (frame_gs_we),
	.frame_gs_din(frame_gs_din),
	.frame_hl_we (frame_hl_we),
	.frame_hl_din(frame_hl_din),
	.hl_out_re   (hl_out_re),

	.bg_gs_full   (bg_gs_full),
	.frame_gs_full(frame_gs_full),
	.frame_hl_full(frame_hl_full),
	.hl_out_empty (hl_out_empty),
	.hl_out_dout  (hl_out_dout)
);

always begin
	clock = 1'b1;
	#(CLOCK_PERIOD/2);
	clock = 1'b0;
	#(CLOCK_PERIOD/2);
end

initial begin
	@(posedge clock);
	reset = 1'b1;
	@(posedge clock);
	reset = 1'b0;
end

initial
begin : driver
	longint unsigned start_time, end_time;

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
	$display("@ %0t: Simulation completed.", end_time);
	$display("Total simulation cycle count: %0d", (end_time-start_time)/CLOCK_PERIOD);
	$display("Total error count: %0d", out_errors);

	// end the simulation
	$finish;
end

initial
begin : read_bg

	int infile_bg;
	int r;
	logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

	@(negedge reset);
	$display("@ %0t: Loading bg for grayscale %s...", $time, INFILE_BG);
	infile_bg       = $fopen(INFILE_BG, "rb");
	bg_gs_we = 1'b0;

	// Skip BMP header
	r = $fread(bmp_header, infile_bg, 0, BMP_HEADER_SIZE);

	// Read data from image file; kick off streaming
	for( int i_bg=0; i_bg<BMP_DATA_SIZE; ) 
	begin
		@(negedge clock);
		bg_gs_we = 1'b0;

		/////////
		//$display("@ %0t, i_bg: %0d\n", $time, i_bg);

		if ( !bg_gs_full )
		begin
			r = $fread(
				bg_gs_din, infile_bg, 
				BMP_HEADER_SIZE+i_bg, BYTES_PER_PIXEL
			);
			bg_gs_we = 1'b1;
			i_bg += BYTES_PER_PIXEL;
		end
	end

	@(negedge clock);
	bg_gs_we = 1'b0;
	$fclose(infile_bg);
	bg_gs_write_done = 1'b1;
end

initial
begin : read_gs_frame

	int infile_frame_gs;

	int r;

	logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

	@(negedge reset);
	$display("@ %0t: Loading frame for grayscale %s...", $time, INFILE_FRAME);

	infile_frame_gs = $fopen(INFILE_FRAME, "rb");
	frame_gs_we = 1'b0;

	r = $fread(bmp_header, infile_frame_gs, 0, BMP_HEADER_SIZE);

	for( int i_frame_gs=0; i_frame_gs<BMP_DATA_SIZE; ) 
	begin
		@(negedge clock);
		frame_gs_we = 1'b0;

		/////////
		//$display("@ %0t, i_frame_gs: %0d\n", $time, i_frame_gs);

		if ( !frame_gs_full )
		begin
			r = $fread(
				frame_gs_din, infile_frame_gs, 
				BMP_HEADER_SIZE+i_frame_gs, BYTES_PER_PIXEL
			);
			frame_gs_we = 1'b1;
			i_frame_gs += BYTES_PER_PIXEL;
		end
	end

	@ (negedge clock);
	frame_gs_we = 1'b0;
	$fclose(infile_frame_gs);
	frame_gs_write_done = 1'b1;
end 

initial
begin : read_hl_frame

	int infile_frame_hl;
	int r;
	logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

	@(negedge reset);
	$display("@ %0t: Loading frame for highlight %s...", $time, INFILE_FRAME);
	infile_frame_hl = $fopen(INFILE_FRAME, "rb");
	frame_hl_we = 1'b0;

	r = $fread(bmp_header, infile_frame_hl, 0, BMP_HEADER_SIZE);

	for( int i_frame_hl=0; i_frame_hl<BMP_DATA_SIZE; ) 
	begin
		@(negedge clock);
		frame_hl_we = 1'b0;

		/////////
		//$display("@ %0t, i_frame_hl: %0d\n", $time, i_frame_hl);

		if ( !frame_hl_full )
		begin
			r = $fread(
				frame_hl_din, infile_frame_hl, 
				BMP_HEADER_SIZE+i_frame_hl, BYTES_PER_PIXEL
			);
			frame_hl_we = 1'b1;
			i_frame_hl += BYTES_PER_PIXEL;
		end
	end

	@ (negedge clock);
	frame_hl_we = 1'b0;
	$fclose(infile_frame_hl);
	frame_hl_write_done = 1'b1;
end 

initial 
begin : write_hl
	int r;
	int outfile;
	int cmpfile;
	logic [23:0] cmp_dout;
	logic [7:0] bmp_header [0:BMP_HEADER_SIZE-1];

	@(negedge reset);
	@(negedge clock);

	$display("@ %0t: Comparing file %s...", $time, OUTFILE);
	
	outfile = $fopen(OUTFILE, "wb");
	cmpfile = $fopen(CMPFILE, "rb");
	hl_out_re = 1'b0;
	
	// Copy the BMP header
	r = $fread(bmp_header, cmpfile, 0, BMP_HEADER_SIZE);
	foreach ( bmp_header[i] )
	begin
		$fwrite(outfile, "%c", bmp_header[i]);
	end

	for ( int i=0; i<BMP_DATA_SIZE; )
	begin
		@(negedge clock);
		hl_out_re = 1'b0;

		/////////
		//$display("@ %0t, out i: %0d\n", $time, i);

		if ( !hl_out_empty )
		begin
			r = $fread(cmp_dout, cmpfile, BMP_HEADER_SIZE+i, BYTES_PER_PIXEL);

			if ( cmp_dout != hl_out_dout ) 
			begin
				out_errors += 1;
				$write(
					"@ %0t: %s(%0d): ERROR: actual %x !=  expected %x at address 0x%x.\n", 
					$time, OUTFILE, i+1, hl_out_dout, cmp_dout, i
				);
			end
			$fwrite(outfile, "%c%c%c", hl_out_dout[23:16], hl_out_dout[15:8], hl_out_dout[7:0]);
			hl_out_re = 1'b1;
			i += BYTES_PER_PIXEL;
		end
	end

	@(negedge clock);
	hl_out_re = 1'b0;
	$fclose(outfile);
	$fclose(cmpfile);
	out_read_done = 1'b1;
end

endmodule

