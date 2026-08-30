
module fft
#(
	parameter int DWIDTH = 32,
	parameter int N = 32,

	parameter logic DBG = 1'b0
)
(
	input  logic clk,
	input  logic rst,

	input  logic in_empty,
	input  logic signed [ DWIDTH-1:0 ] din_real,
	input  logic signed [ DWIDTH-1:0 ] din_imag,
	output logic in_rd_en,

	input  logic out_full,
	output logic signed [ DWIDTH-1:0 ] dout_real,
	output logic signed [ DWIDTH-1:0 ] dout_imag,
	output logic out_wr_en
);

	localparam int STAGES = $clog2( N );

	/*
 	 * Module:
	 * in fifo -> [
	 *   bit reverse buf 
	 *   -> fifo -> stage
	 *   -> ... 
	 *   -> fifo -> stage
	 * ] -> out fifo
	 */

	/*
	 * In each of the following buses, [ i ] matches the fifo that supplies stage
	 * i's input, thus stage i uses inputs at [ i ] and outputs at [ i+1 ]
	 * The output FIFO for the entire module exposes its din, full and wr_en,
	 * which are included at idx [ STAGE ] where applicable
	 */
	logic [ 0:STAGES-1 ] fifo_empty;
	logic [ 0:STAGES-1 ] fifo_rd_en;
	logic [ 0:STAGES   ] fifo_full;
	logic [ 0:STAGES   ] fifo_wr_en;
	logic signed [ 0:STAGES   ] [ DWIDTH-1:0 ]
		fifo_din_real,  fifo_din_imag;
	logic signed [ 0:STAGES-1 ] [ DWIDTH-1:0 ]
		fifo_dout_real, fifo_dout_imag;

	bit_reverse_buf #(
		.DWIDTH( DWIDTH ),
		.N( N )
	) brb (
		.clk( clk ),
		.rst( rst ),

		.in_empty( in_empty ),
		.din_real( din_real ),
		.din_imag( din_imag ),
		.in_rd_en( in_rd_en ),

		.out_full ( fifo_full[ 0 ] ),
		.dout_real( fifo_din_real[ 0 ] ),
		.dout_imag( fifo_din_imag[ 0 ] ),
		.out_wr_en( fifo_wr_en[ 0 ] )
	);

	assign fifo_full[ STAGES ] = out_full;
	assign dout_real = fifo_din_real[ STAGES ];
	assign dout_imag = fifo_din_imag[ STAGES ];
	assign out_wr_en = fifo_wr_en[ STAGES ];

	generate
		genvar i;
		for ( i=0; i<STAGES; ++i )
		begin
			skidbuf #(
				.DWIDTH( 2*DWIDTH )
			) stage_input_fifo (
				.clk( clk ), .rst( rst ),

				.wr_en( fifo_wr_en[ i ] ),
				.din  ( { fifo_din_real[ i ], fifo_din_imag[ i ] } ),
				.full ( fifo_full[ i ] ),

				.rd_en( fifo_rd_en[ i ] ),
				.dout ( { fifo_dout_real[ i ], fifo_dout_imag[ i ] } ),
				.empty( fifo_empty[ i ] )
			);
			fft_stage #(
				.DWIDTH( DWIDTH ),
				.N( N ),
				.STAGE( i ),
				.DBG( DBG )
			) stage (
				.clk( clk ), .rst( rst ),

				.in_empty( fifo_empty[ i ] ),
				.din_real( fifo_dout_real[ i ] ),
				.din_imag( fifo_dout_imag[ i ] ),
				.in_rd_en( fifo_rd_en[ i ] ),

				.out_full( fifo_full[ i+1 ] ),
				.dout_real( fifo_din_real[ i+1 ] ),
				.dout_imag( fifo_din_imag[ i+1 ] ),
				.out_wr_en( fifo_wr_en[ i+1 ] )
			);
		end
	endgenerate


endmodule: fft


