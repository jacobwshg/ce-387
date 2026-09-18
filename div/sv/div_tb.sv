
`timescale 1ns / 1ns

module div_tb
#(
	parameter int DWIDTH = 32,
	parameter int BITPOSWIDTH = $clog2( DWIDTH ),
	parameter int FINDMSB_USE_BSRCH = 1'b0,

	parameter int PERIOD = 10,

	parameter string INFILE_REAL = "in_real.txt",
	parameter string INFILE_IMAG = "in_imag.txt",

	parameter int TEST_CNT = 20,

	parameter int IN_DLY  = 0,
	parameter int OUT_DLY = 0,
	parameter int FIFO_DEPTH = 2,

	parameter int TIMEOUT = 100000


)();
	logic clk = 1'b0;
	logic rst = 1'b0;

	int
		infile_real = 0, infile_imag = 0;

	logic [ 0:1 ] [ DWIDTH-1:0 ] in_din = 'h0;
	logic in_full;
	logic in_wr_en = 1'b0;
	logic [ 0:1 ] [ DWIDTH-1:0 ] in_dout;
	logic in_empty;
	logic in_rd_en;

	logic [ DWIDTH-1:0 ] out_din;
	logic out_full;
	logic out_wr_en;
	logic [ DWIDTH-1:0 ] out_dout;
	logic out_empty;
	logic out_rd_en = 1'b0;

	logic pipe_en;

	logic dut_in_valid;
	logic dut_out_valid;

	logic done = 1'b0;

	logic [ 0:TEST_CNT-1 ] [ DWIDTH-1:0 ]
		test_n_vec = '{ default: 'h0 },
		test_d_vec = '{ default: 'h0 };

	/*
	fifo #(
		.DWIDTH( 2 * DWIDTH ),
		.DEPTH ( FIFO_DEPTH )
	) fifo_in (
		.clk( clk ), .rst( rst ),

		.wr_en( in_wr_en ),
		.din  ( in_din ),
		.full ( in_full ),

		.rd_en( in_rd_en ),
		.dout ( in_dout ),
		.empty( in_empty )
	);
	*/
	///*
	skidbuf #(
		.DWIDTH( 2 * DWIDTH )
	) fifo_in (
		.clk  ( clk ),
		.rst  ( rst ),
		.wr_en( in_wr_en ),
		.din  ( in_din ),
		.full ( in_full ),
		.rd_en( in_rd_en ),
		.dout ( in_dout ),
		.empty( in_empty )
	);
	//*/

	div #(
		.DWIDTH( DWIDTH ), .BITPOSWIDTH( BITPOSWIDTH ),
		.FINDMSB_USE_BSRCH( FINDMSB_USE_BSRCH )
	) dut (
		.clk( clk ), .rst( rst ),

		.n( in_dout[ 0 ] ), .d( in_dout[ 1 ] ),
		.in_empty( in_empty ), .in_rd_en( in_rd_en ),

		.out_full( out_full ),
		.q( out_din ),
		.out_wr_en( out_wr_en )
	);

	/*
	fifo #(
		.DWIDTH( 2 * DWIDTH ),
		.DEPTH ( FIFO_DEPTH )
	) fifo_out (
		.clk( clk ), .rst( rst ),

		.wr_en( out_wr_en ),
		.din  ( out_din ),
		.full ( out_full ),

		.rd_en( out_rd_en ),
		.dout ( out_dout ),
		.empty( out_empty )
	);
	*/
	///*
	skidbuf #(
		.DWIDTH( DWIDTH )
	) fifo_out (
		.clk( clk ),
		.rst( rst ),
		.wr_en( out_wr_en ),
		.din  ( out_din ),
		.full ( out_full ), 
		.rd_en( out_rd_en ), 
		.dout ( out_dout ),
		.empty( out_empty )
	);
	//*/

	assign dut_in_valid = !in_empty;

	initial
	begin: init_proc
		clk = 1'b0;
		done = 1'b0;
	end: init_proc

	always
	begin: clk_proc
		#( PERIOD/2 ); clk = ~clk;
	end: clk_proc

	initial
	begin: info_proc
		$display(
			"*** Sobel COMPUTE stage test, test %d col samples ***", 
			TEST_CNT
		);
	end: info_proc

	initial
	begin: rst_proc
		#0;  rst = 1'b0;
		@( negedge clk ); rst = 1'b1;
		@( negedge clk ); 
		@( negedge clk ); rst = 1'b0;
	end: rst_proc

	initial
	begin: timeout_proc
		#TIMEOUT;
		$display( "@ %0t timeout", $time );
		$stop;
	end: timeout_proc

	initial
	begin: gen_testvec_proc
		logic [ DWIDTH-1:0 ] n_gen, d_gen;

		#0;
		for ( int i=0; i<TEST_CNT; ++i )
		begin
			randomize( n_gen ); test_n_vec[ i ] = n_gen;
			//randomize( d_gen ); test_d_vec[ i ] = d_gen;
			/* Generate smaller divisors to test larger quotients */
			test_d_vec[ i ] =  $urandom_range( DWIDTH'( 1'h1 ) << ( DWIDTH/2 ) );
		end
	end: gen_testvec_proc

	initial
	begin: din_wr_proc

		#0;
		in_wr_en = 1'b0;
		in_din = '{ default: 'h0 };

		@( posedge rst );
		@( negedge rst );

		for ( int i=0; i<TEST_CNT; )
		begin
			@( negedge clk );
			in_wr_en = 1'b0;

			#IN_DLY;
			@( negedge clk );

			if ( !in_full )
			begin
				in_din = '{ default: 'hZ };

				if ( i < TEST_CNT )
				begin
					in_din[ 0 ] = test_n_vec[ i ];
					in_din[ 1 ] = test_d_vec[ i ];
					$display(
						"@ %0t [ %0d ] loading n = %0d, d = %0d into input FIFO",
						$time, i, in_din[ 0 ], in_din[ 1 ]
					);
					$display( "" );
				end

				in_wr_en = 1'b1;
				++i;
			end
		end

	end: din_wr_proc

	initial
	begin: dout_rd_proc

		logic [ DWIDTH-1:0 ] n_test, d_test;
		logic [ DWIDTH-1:0 ] q_ref;

		#0;
		done = 1'b0;
		out_rd_en = 1'b0;

		@( posedge rst );
		@( negedge rst );

		for ( int i=0; i<TEST_CNT; )
		begin
			@( negedge clk );
			out_rd_en = 1'b0;

			#OUT_DLY;
			@( negedge clk );

			if ( !out_empty )
			begin
				/* read test samples matching current output idx */
				n_test = test_n_vec[ i ];
				d_test = test_d_vec[ i ];
				q_ref  = n_test / d_test;

				$display( "@ %0t [ %0d ] ", $time, i );
				$display( "      n = %d / 0x%h / 0b%b", n_test, n_test, n_test );
				$display( "      d = %d / 0x%h / 0b%b", d_test, d_test, d_test );
				$display( "      ref q = %d / 0x%h / 0b%b", q_ref, q_ref, q_ref );
				$display( "      DUT q = %d / 0x%h / 0b%b", out_dout, out_dout, out_dout );
				if ( out_dout !== q_ref )
				begin
					$error( "      ( incorrect )" );
				end
				$display( "" );
				out_rd_en = 1'b1;
				++i;
			end
		end

		@( negedge clk );
		out_rd_en = 1'b0;

		done = 1'b1;

	end: dout_rd_proc

	initial
	begin: cleanup_proc
		@( posedge done );
		if ( 0!==infile_real ) $fclose( infile_real );	
		if ( 0!==infile_imag ) $fclose( infile_imag );	
		$stop;
	end: cleanup_proc

endmodule: div_tb

