
`timescale 1ns / 1ns

module fifo_tb
#(
	parameter int FIFO_DATA_WIDTH = 32,
	parameter int FIFO_BUFFER_SIZE = 4, 

	parameter int WR_DLY = 230,
	parameter int RD_DLY = 350,

	parameter int TEST_CNT = 32,

	parameter int TIMEOUT = 100000
)();

	localparam PERIOD = 10;

	int wr_cnt;
	int rd_cnt;

	logic clk, rst, wr_en, full, rd_en, empty;

	logic [FIFO_DATA_WIDTH-1:0] din, dout;

	fifo #(
		.DWIDTH ( FIFO_DATA_WIDTH ),
		.DEPTH ( FIFO_BUFFER_SIZE )
	) dut (
		.clk( clk ),
		.rst ( rst ),

		.wr_en ( wr_en ),
		.din   ( din ),
		.full  ( full ),

		.rd_en ( rd_en ),
		.dout  ( dout ),
		.empty ( empty )
	);

	initial
	begin: init_proc
		clk = 1'b0;
		rst = 1'b0;
		din = 'h0;
		wr_en = 1'b0;
		rd_en = 1'b0;
		rd_cnt = 'h0;
	end: init_proc

	always
	begin: clk_proc
		#( PERIOD/2 );
		clk = !clk;
	end: clk_proc

	initial
	begin: timeout_proc
		#TIMEOUT;
		$display( "@ %0t timeout", $time );
		$stop;
	end: timeout_proc

	initial
	begin: rst_proc
		#PERIOD;

		@( negedge clk );
		rst = 1'b1;

		#( PERIOD * 2 );
		@( negedge clk );
		rst = 1'b0;
	end: rst_proc

	initial
	begin: wr_proc

		@( posedge rst );
		@( negedge rst );

		for ( wr_cnt=0; wr_cnt<TEST_CNT; )
		begin
			@ ( negedge clk );
			wr_en = 'b0;
			din += 1'h1;

			#WR_DLY;
			@( negedge clk );

			if ( !full )
			begin
				$display( "@ %0t write %0d", $time, din );
				wr_en = 'b1;
				++wr_cnt;
			end
		end

	end: wr_proc

	initial
	begin: rd_proc

		@( posedge rst );
		@( negedge rst );

		while ( TEST_CNT > rd_cnt )
		begin
			@ ( negedge clk );
			rd_en = 'b0;

			#RD_DLY;
			@ ( negedge clk );

			if ( rd_cnt >= TEST_CNT )
				$finish;			

			if ( !empty )
			begin
				$display( "@ %0t \t\t\tread %0d", $time, dout );
				rd_en = 'b1;
				rd_cnt += 1'h1;
			end
		end

		$finish;

	end: rd_proc

endmodule

