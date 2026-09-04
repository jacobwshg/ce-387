
`timescale 1ns / 1ns

module fifo_async_tb
#(
	parameter int DWIDTH = 32,
	parameter int FIFO_DEPTH = 8, 

	parameter int WR_PERIOD = 10,
	parameter int WR_DLY = 0,

	parameter int RD_PERIOD = 20,
	parameter int RD_DLY = 100,

	parameter int TEST_CNT = 32,

	parameter int TIMEOUT = 100000
)();

	int wr_cnt;
	int rd_cnt;

	logic wr_clk;
	logic rd_clk;
	logic wr_rst;
	logic rd_rst;

	logic wr_en;
	logic [ DWIDTH-1:0 ] din; 
	logic full;

	logic rd_en;
	logic [ DWIDTH-1:0 ] dout;
	logic empty;


	fifo #(
		.DWIDTH( DWIDTH ),
		.DEPTH ( FIFO_DEPTH )
	) dut (
		.wr_clk( wr_clk ),
		.wr_rst( wr_rst ),
		.wr_en ( wr_en ),
		.din   ( din ),
		.full  ( full ),

		.rd_clk( rd_clk ),
		.rd_rst( rd_rst ),
		.rd_en ( rd_en ),
		.dout  ( dout ),
		.empty ( empty )
	);

	initial
	begin: init_proc
		wr_clk = 1'b0;
		rd_clk = 1'b0;

		wr_rst = 1'b0;
		rd_rst = 1'b0;

		din = 'h0;

		wr_cnt = 0;		
		rd_cnt = 0;

		wr_en = 1'b0;
		rd_en = 1'b0;
	end: init_proc

	always
	begin: wr_clk_proc
		#( WR_PERIOD/2 );
		wr_clk = !wr_clk;
	end: wr_clk_proc

	always
	begin: rd_clk_proc
		#( RD_PERIOD/2 );
		rd_clk = !rd_clk;
	end: rd_clk_proc

	initial
	begin: timeout_proc
		#TIMEOUT;
		$display( "@ %0t timeout", $time );
		$stop;
	end: timeout_proc

	initial
	begin: wr_rst_proc

		//@( posedge wr_clk );
		@( negedge wr_clk );
		wr_rst = 1'b1;

		#( WR_PERIOD * 10 );
		@( negedge wr_clk );
		wr_rst = 1'b0;
	end: wr_rst_proc

	initial
	begin: rd_rst_proc

		//@( posedge rd_clk );
		@( negedge rd_clk );
		rd_rst = 1'b1;

		#( RD_PERIOD * 10 );
		@( negedge rd_clk );
		rd_rst = 1'b0;
	end: rd_rst_proc

	initial
	begin: wr_proc

		@( posedge wr_rst );
		@( negedge wr_rst );

		for ( wr_cnt=0; wr_cnt<TEST_CNT; )
		begin
			@ ( negedge wr_clk );
			wr_en = 'b0;

			#WR_DLY;
			@( negedge wr_clk );
			din += 1'h1;

			if ( !full )
			begin
				$display( "@ %0t write %0d", $time, din );
				wr_en = 'b1;
				wr_cnt += 1'h1;
			end
		end

	end: wr_proc

	initial
	begin: rd_proc

		@( posedge rd_rst );
		@( negedge rd_rst );

		while ( TEST_CNT > rd_cnt )
		begin
			@ ( negedge rd_clk );
			rd_en = 'b0;

			#RD_DLY;
			@ ( negedge rd_clk );

			if ( rd_cnt >= TEST_CNT )
				$finish;			

			if ( !empty )
			begin
				$display( "@ %0t \t\t\tread %0d", $time, dout );
				rd_en = 'b1;
				rd_cnt += 1'h1;
			end
		end

		$stop;

	end: rd_proc

endmodule: fifo_async_tb

