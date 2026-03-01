
module fft #(
	DATA_CNT = 32,
	STAGE_CNT = $clog2( DATA_CNT ),
	DATA_WIDTH = 32
)
(
	input logic signed [ DATA_CNT-1:0 ] [ 1:0 ] [ DATA_WIDTH-1:0 ] din,
	input logic in_empty,
	input logic re_full,
	input logic im_full,

	output logic signed [ DATA_CNT-1:0 ] [ DATA_WIDTH-1:0 ] re_dout,
	output logic signed [ DATA_CNT-1:0 ] [ DATA_WIDTH-1:0 ] im_dout,
	output logic re_wr_en,
	output logic im_wr_en,
	output logic in_rd_en
);

	/*
	 * Actually only need at most DATA_CNT/2 instead of DATA_CNT twdl factors for each stage,
	 * since each butterfly takes a pair of inputs
	 */
	localparam logic signed [ STAGE_CNT-1:0 ] [ (DATA_CNT/2)-1:0 ] [ 1:0 ] [ DATA_WIDTH-1:0 ] twdls = 
	{
		{
			{32'sh00004000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00000000,32'shffffc000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00002d41,32'shffffd2bf}, {32'sh00000000,32'shffffc000}, {32'shffffd2bf,32'shffffd2bf},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00003b20,32'shffffe783}, {32'sh00002d41,32'shffffd2bf}, {32'sh0000187d,32'shffffc4e0},
			{32'sh00000000,32'shffffc000}, {32'shffffe783,32'shffffc4e0}, {32'shffffd2bf,32'shffffd2bf}, {32'shffffc4e0,32'shffffe783},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
			{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
		},
		{
			{32'sh00004000,32'sh00000000}, {32'sh00003ec5,32'shfffff384}, {32'sh00003b20,32'shffffe783}, {32'sh00003536,32'shffffdc72}, 
			{32'sh00002d41,32'shffffd2bf}, {32'sh0000238e,32'shffffcaca}, {32'sh0000187d,32'shffffc4e0}, {32'sh00000c7c,32'shffffc13b},
			{32'sh00000000,32'shffffc000}, {32'shfffff384,32'shffffc13b}, {32'shffffe783,32'shffffc4e0}, {32'shffffdc72,32'shffffcaca},
			{32'shffffd2bf,32'shffffd2bf}, {32'shffffcaca,32'shffffdc72}, {32'shffffc4e0,32'shffffe783}, {32'shffffc13b,32'shfffff384},
		}
	};

	logic signed [ STAGE_CNT-1:0 ] [ DATA_CNT-1:0 ] [ 1:0 ] [ DATA_WIDTH-1:0 ] xs;

/*
{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000},
{32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}, {32'sh00000000,32'sh00000000}
*/

endmodule: fft

