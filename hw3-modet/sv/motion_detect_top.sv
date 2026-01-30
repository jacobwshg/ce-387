
module motion_detect_top 
#(
	parameter WIDTH  = 768,
	parameter HEIGHT = 576
)
(
	input  logic		clock,
	input  logic		reset,

	input  logic		bg_in_we,
	input  logic [23:0] bg_in_din,
	input  logic		frame_in_we,
	input  logic [23:0] frame_in_din,
	input  logic		hl_out_re,

	output logic		bg_in_full,
	output logic		frame_in_full,
	output logic		out_empty,
	output logic [7:0]  hl_out_dout
);

logic [23:0] bg_in_dout;
logic        bg_in_empty;
logic        bg_in_re;
fifo #(
	.FIFO_BUFFER_SIZE(64),
	.FIFO_DATA_WIDTH(24)
) bg_in_fifo (
	.reset(reset),
	.wr_clk(clock),
	.wr_en(bg_in_we),
	.din(bg_in_din),
	.full(bg_in_full),
	.rd_clk(clock),
	.rd_en(bg_in_re),
	.dout(bg_in_dout),
	.empty(bg_in_empty)
);

logic [23:0] frame_in_dout;
logic        frame_in_empty;
logic        frame_in_re;
fifo #(
	.FIFO_BUFFER_SIZE(64),
	.FIFO_DATA_WIDTH(24)
) frame_in_fifo (
	.reset(reset),
	.wr_clk(clock),
	.wr_en(frame_in_we),
	.din(frame_in_din),
	.full(frame_in_full),
	.rd_clk(clock),
	.rd_en(frame_in_re),
	.dout(frame_in_dout),
	.empty(frame_in_empty)
);


logic [7:0]  hl_out_din;
logic        hl_out_full;
logic        hl_out_we;
fifo #(
	.FIFO_BUFFER_SIZE(64),
	.FIFO_DATA_WIDTH(24)
) hl_out_fifo (
	.reset(reset),
	.wr_clk(clock),
	.wr_en(out_we),
	.din(hl_out_din),
	.full(hl_out_full),
	.rd_clk(clock),
	.rd_en(hl_out_re),
	.dout(hl_out_dout),
	.empty(hl_out_empty)
);

logic [7:0] bg_gs_din;
logic bg_gs_we;
logic bg_gs_full;
logic [7:0] bg_gs_dout;
logic bg_gs_re;
logic bg_gs_empty;
fifo #(
	.FIFO_BUFFER_SIZE(64),
	.FIFO_DATA_WIDTH(8)
) bg_gs_fifo (
	.reset(reset),
	.wr_clk(clock),
	.wr_en(bg_gs_we),
	.din(bg_gs_din),
	.full(bg_gs_full),
	.rd_clk(clock),
	.rd_en(bg_gs_re),
	.dout(bg_gs_dout),
	.empty(bg_gs_empty)
);

logic [7:0] frame_gs_din;
logic frame_gs_we;
logic frame_gs_full;
logic [7:0] frame_gs_dout;
logic frame_gs_re;
logic frame_gs_empty;
fifo #(
	.FIFO_BUFFER_SIZE(64),
	.FIFO_DATA_WIDTH(8)
) frame_gs_fifo (
	.reset(reset),
	.wr_clk(clock),
	.wr_en(frame_gs_we),
	.din(frame_gs_din),
	.full(frame_gs_full),
	.rd_clk(clock),
	.rd_en(frame_gs_re),
	.dout(frame_gs_dout),
	.empty(frame_gs_empty)
);

logic [7:0] sub_hl_din;
logic sub_hl_we;
logic sub_hl_full;
logic [7:0] sub_hl_dout;
logic sub_hl_re;
logic sub_hl_empty;
fifo #(
	.FIFO_BUFFER_SIZE(64),
	.FIFO_DATA_WIDTH(8)
) sub_hl_fifo (
	.reset(reset),
	.wr_clk(clock),
	.wr_en(sub_hl_we),
	.din(sub_hl_din),
	.full(sub_hl_full),
	.rd_clk(clock),
	.rd_en(sub_hl_re),
	.dout(sub_hl_dout),
	.empty(sub_hl_empty)
);

logic [23:0] frame_hl_din;
logic frame_hl_we;
logic frame_hl_full;
logic [23:0] frame_hl_dout;
logic frame_hl_re;
logic frame_hl_empty;
fifo #(
	.FIFO_BUFFER_SIZE(64),
	.FIFO_DATA_WIDTH(24)
) frame_hl_fifo (
	.reset(reset),
	.wr_clk(clock),
	.wr_en(frame_hl_we),
	.din(frame_hl_din),
	.full(frame_hl_full),
	.rd_clk(clock),
	.rd_en(frame_hl_re),
	.dout(frame_hl_dout),
	.empty(frame_hl_empty)
);

grayscale #(
) bg_gs_inst (
	.clock(clock),
	.reset(reset),

	.in_empty(bg_in_empty),
	.in_dout(bg_in_dout),
	.out_full(bg_gs_full),

	.in_rd_en(bg_in_re),
	.out_wr_en(bg_gs_we)
	.out_din(bg_gs_din),
);

grayscale #(
) frame_gs_inst (
	.clock(clock),
	.reset(reset),

	.in_empty(frame_in_empty),
	.in_dout(frame_in_dout),
	.out_full(frame_gs_full),

	.in_rd_en(frame_in_re),
	.out_wr_en(frame_gs_we)
	.out_din(frame_gs_din),
);

subtract #( .THRESHOLD( 50 ) ) 
sub_inst (
	.clock( clock ),
	.reset( reset ),

	.bg_gs_empty( bg_gs_empty ),
	.bg_gs_dout( bg_gs_dout ),
	.frame_gs_empty( frame_gs_empty ),
	.frame_gs_dout( frame_gs_dout ),
	.out_full( sub_hl_full ),

	.bg_gs_re( bg_gs_re ),
	.frame_gs_re( frame_gs_re ),
	.out_we( sub_hl_we ),
	.out_din( sub_hl_din )
);

highlight 
hl_inst(
	.clock( clock ),
	.reset( reset ),

	.gs_sub_empty( sub_hl_empty ),
	.gs_sub_dout( sub_hl_dout ),
	.frame_empty( frame_hl_empty ),
	.frame_dout( frame_hl_dout ),
	.out_full( hl_out_full ),

	.gs_sub_re( sub_hl_re ),
	.frame_re( frame_hl_re ),
	.out_we( hl_out_we ),
	.out_din( hl_out_din )
);

endmodule

