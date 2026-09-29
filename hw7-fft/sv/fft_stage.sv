
module fft_stage #(
	parameter int DWIDTH = 32,
	parameter int FRACWIDTH = 14,
	parameter int N = 256,
	parameter int STAGE = 1,

	parameter logic USE_PIPE = 1'b1,
	parameter int MUL_STAGES = 2,

	parameter logic DBG = 1'b0
)(
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

	generate
		if ( USE_PIPE )
		begin
			fft_stage_pipe #(
				.DWIDTH( DWIDTH ), .FRACWIDTH( FRACWIDTH ),
				.N( N ), .STAGE( STAGE ),
				.MUL_STAGES( MUL_STAGES ),
				.DBG( DBG )
			) stage (
				.clk( clk ), .rst( rst ),

				.in_empty( in_empty ),
				.din_real( din_real ), .din_imag( din_imag ),
				.in_rd_en( in_rd_en ),

				.out_full( out_full ),
				.dout_real( dout_real ), .dout_imag( dout_imag ),
				.out_wr_en( out_wr_en )
			);
		end
		else
		begin
			logic signed [ 1:0 ] [ DWIDTH-1:0 ] stage_din;
			logic signed [ 1:0 ] [ DWIDTH-1:0 ] stage_dout;
			assign stage_din[ 0 ] = din_real;
			assign stage_din[ 1 ] = din_imag;
			assign dout_real = stage_dout[ 0 ];
			assign dout_imag = stage_dout[ 1 ];
			fft_stage_fsm #(
				.DWIDTH( DWIDTH ),
				.N( N ), .STAGE( STAGE )
			) stage (
				.clk( clk ), .rst( rst ),

				.in_empty( in_empty ),
				.din( stage_din ),
				.in_rd_en( in_rd_en ),

				.out_full( out_full ),
				.dout( stage_dout ),
				.out_wr_en( out_wr_en )
			);
		end
	endgenerate

endmodule: fft_stage

