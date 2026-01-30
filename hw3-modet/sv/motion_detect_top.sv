
module motion_detect_top 
#(
	parameter WIDTH  = 768,
	parameter HEIGHT = 576
)
(
	input  logic		clock,
	input  logic		reset,

	input  logic		bg_gs_we,
	input  logic [23:0] bg_gs_din,
	input  logic		frame_gs_we,
	input  logic [23:0] frame_gs_din,
	input  logic		frame_hl_we,
	input  logic [23:0] frame_hl_din,
	input  logic		hl_out_re,

	output logic		bg_gs_full,
	output logic		frame_gs_full,
	output logic		frame_hl_full,
	output logic		hl_out_empty,
	output logic [23:0] hl_out_dout
);

localparam FIFO_SIZE = 32;

logic [23:0] bg_gs_dout;
logic        bg_gs_empty;
logic        bg_gs_re;

logic [23:0] frame_gs_dout;
logic        frame_gs_empty;
logic        frame_gs_re;

logic [23:0] hl_out_din;
logic        hl_out_full;
logic        hl_out_we;

logic [7:0] bg_sub_din;
logic bg_sub_we;
logic bg_sub_full;
logic [7:0] bg_sub_dout;
logic bg_sub_re;
logic bg_sub_empty;

logic [7:0] frame_sub_din;
logic frame_sub_we;
logic frame_sub_full;
logic [7:0] frame_sub_dout;
logic frame_sub_re;
logic frame_sub_empty;

logic [7:0] sub_hl_din;
logic sub_hl_we;
logic sub_hl_full;
logic [7:0] sub_hl_dout;
logic sub_hl_re;
logic sub_hl_empty;

logic [23:0] frame_hl_dout;
logic frame_hl_re;
logic frame_hl_empty;

fifo #(
	.FIFO_BUFFER_SIZE(FIFO_SIZE),
	.FIFO_DATA_WIDTH(24)
) bg_gs_fifo (
	.reset (reset),
	.wr_clk(clock),
	.wr_en (bg_gs_we),
	.din   (bg_gs_din),
	.full  (bg_gs_full),
	.rd_clk(clock),
	.rd_en (bg_gs_re),
	.dout  (bg_gs_dout),
	.empty (bg_gs_empty)
);

fifo #(
	.FIFO_BUFFER_SIZE(FIFO_SIZE),
	.FIFO_DATA_WIDTH(24)
) frame_gs_fifo (
	.reset (reset),
	.wr_clk(clock),
	.wr_en (frame_gs_we),
	.din   (frame_gs_din),
	.full  (frame_gs_full),
	.rd_clk(clock),
	.rd_en (frame_gs_re),
	.dout  (frame_gs_dout),
	.empty (frame_gs_empty)
);

fifo #(
	.FIFO_BUFFER_SIZE(FIFO_SIZE),
	.FIFO_DATA_WIDTH(24)
) hl_out_fifo (
	.reset (reset),
	.wr_clk(clock),
	.wr_en (hl_out_we),
	.din   (hl_out_din),
	.full  (hl_out_full),
	.rd_clk(clock),
	.rd_en (hl_out_re),
	.dout  (hl_out_dout),
	.empty (hl_out_empty)
);

fifo #(
	.FIFO_BUFFER_SIZE(FIFO_SIZE),
	.FIFO_DATA_WIDTH(8)
) bg_sub_fifo (
	.reset (reset),
	.wr_clk(clock),
	.wr_en (bg_sub_we),
	.din   (bg_sub_din),
	.full  (bg_sub_full),
	.rd_clk(clock),
	.rd_en (bg_sub_re),
	.dout  (bg_sub_dout),
	.empty (bg_sub_empty)
);

fifo #(
	.FIFO_BUFFER_SIZE(FIFO_SIZE),
	.FIFO_DATA_WIDTH(8)
) frame_sub_fifo (
	.reset (reset),
	.wr_clk(clock),
	.wr_en (frame_sub_we),
	.din   (frame_sub_din),
	.full  (frame_sub_full),
	.rd_clk(clock),
	.rd_en (frame_sub_re),
	.dout  (frame_sub_dout),
	.empty (frame_sub_empty)
);

fifo #(
	.FIFO_BUFFER_SIZE(FIFO_SIZE),
	.FIFO_DATA_WIDTH(8)
) sub_hl_fifo (
	.reset (reset),
	.wr_clk(clock),
	.wr_en (sub_hl_we),
	.din   (sub_hl_din),
	.full  (sub_hl_full),
	.rd_clk(clock),
	.rd_en (sub_hl_re),
	.dout  (sub_hl_dout),
	.empty (sub_hl_empty)
);

fifo #(
	.FIFO_BUFFER_SIZE(FIFO_SIZE),
	.FIFO_DATA_WIDTH(24)
) frame_hl_fifo (
	.reset (reset),
	.wr_clk(clock),
	.wr_en (frame_hl_we),
	.din   (frame_hl_din),
	.full  (frame_hl_full),
	.rd_clk(clock),
	.rd_en (frame_hl_re),
	.dout  (frame_hl_dout),
	.empty (frame_hl_empty)
);

grayscale #(
) bg_gs_inst (
	.clock(clock),
	.reset(reset),

	.in_empty (bg_gs_empty),
	.in_dout  (bg_gs_dout),
	.out_full (bg_sub_full),

	.in_rd_en (bg_gs_re),
	.out_wr_en(bg_sub_we),
	.out_din  (bg_sub_din)
);

grayscale #(
) frame_gs_inst (
	.clock(clock),
	.reset(reset),

	.in_empty (frame_gs_empty),
	.in_dout  (frame_gs_dout),
	.out_full (frame_sub_full),

	.in_rd_en (frame_gs_re),
	.out_wr_en(frame_sub_we),
	.out_din  (frame_sub_din)
);

bg_subtract #( .THRESHOLD( 50 ) ) 
bg_sub_inst (
	.clock( clock ),
	.reset( reset ),

	.bg_sub_empty   ( bg_sub_empty ),
	.bg_sub_dout    ( bg_sub_dout ),
	.frame_sub_empty( frame_sub_empty ),
	.frame_sub_dout ( frame_sub_dout ),
	.out_full       ( sub_hl_full ),

	.bg_sub_re   ( bg_sub_re ),
	.frame_sub_re( frame_sub_re ),
	.out_we      ( sub_hl_we ),
	.out_din     ( sub_hl_din )
);

highlight 
hl_inst(
	.clock( clock ),
	.reset( reset ),

	.gs_sub_empty( sub_hl_empty ),
	.gs_sub_dout ( sub_hl_dout ),
	.frame_empty ( frame_hl_empty ),
	.frame_dout  ( frame_hl_dout ),
	.out_full    ( hl_out_full ),

	.gs_sub_re( sub_hl_re ),
	.frame_re ( frame_hl_re ),
	.out_we   ( hl_out_we ),
	.out_din  ( hl_out_din )
);

endmodule
