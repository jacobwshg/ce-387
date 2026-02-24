
module cordic #(
	parameter FRAC_WIDTH = 16'd14,
	// quantized constants based on FRAC_WIDTH
	parameter PI = 32'sd51472, // round( 3.14159265359 * (2**14) )
	parameter K  = 32'sd26981  // round( 1.646760258121 * (2**14) )
)
(
	input clk,
	input rst,

	input logic signed [ 31:0 ] in_dout,
	input logic in_empty,
	input logic out_full,

	output logic in_re,
	output logic signed [ 1:0 ] [ 15:0 ] out_din,
	output logic out_we
);

	localparam STAGE_CNT = 16;
	localparam I_SIN = 0;
	localparam I_COS = 1;

	localparam logic signed [ 31:0 ]
		TWO_PI  = PI << 1,
		HALF_PI = PI >> 1,
		K_INV   = ( ( 32'sd01<<FRAC_WIDTH ) << FRAC_WIDTH ) / K;
		//K_INV = 32'sd9949;

	typedef enum logic { FALSE = 1'b0, TRUE = 1'b1 } bool_t;

	logic [ 0:STAGE_CNT-1 ] [ 15:0 ] CORDIC_TABLE = 
		{
			16'h3243, 16'h1DAC, 16'h0FAD, 16'h07F5,
			16'h03FE, 16'h01FF, 16'h00FF, 16'h007F, 
			16'h003F, 16'h001F, 16'h000F, 16'h0007,
			16'h0003, 16'h0001, 16'h0000, 16'h0000
		};

	bool_t sh_en;

	logic signed [ 31:0 ] rad, rad_c;
	bool_t rad_large, rad_small;

	logic signed [ STAGE_CNT-1:0 ] [ 15:0 ] x_out, y_out, z_out;
	logic signed [ 15:0 ] x_in, y_in;

	genvar i;
	generate
		for ( i=0; i<STAGE_CNT; ++i )
		begin
			cordic_stage
			cordic_stage_inst (
				.clk( clk ),
				.rst( rst ),
				.sh_en( sh_en ),

				.x_in( i==0 ? x_in : x_out[i-1] ),
				.y_in( i==0 ? y_in : y_out[i-1] ),
				.z_in( i==0 ? $signed( rad[ 15:0 ] ) : z_out[i-1] ),
				.k( 16'(i) ),
				.c( CORDIC_TABLE[i] ),

				.x_out( x_out[i] ),
				.y_out( y_out[i] ),
				.z_out( z_out[i] )
			);
		end
	endgenerate

	/* single "run" state FSM */
	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			rad <= 'h0;
		end
		else
		begin
			rad <= rad_c;
		end
	end

	always_comb
	begin
		out_din[ I_COS ] = x_out[ STAGE_CNT-1 ];
		out_din[ I_SIN ] = y_out[ STAGE_CNT-1 ];

		in_re = FALSE;
		out_we = FALSE;

		x_in = K_INV;
		y_in = 'h0;

		rad_c = rad;
		/*
 		 * Use clocked rad for tests, because stage 0's z input uses rad 
 		 * for stability; if using rad_c, sh_en may turn on before rad is
 		 * updated, causing stage 0 to get wrong z
 		 */
		rad_large = rad > HALF_PI ? TRUE : FALSE;
		rad_small = rad < -HALF_PI ? TRUE : FALSE;

		/*
 		 * When "ready" ( both fifos mobile, buffered radian is in range 
 		 * [ -HALF_PI, HALF_PI ] ),
 		 * enable shifting stage 15's output out to downstream fifo
 		 * and shifting a new radian in from upstream fifo.
 		 *
 		 * Once a in-range rad_c is written to rad on clk edge,
 		 * there is one cycle during which:
 		 * - sh_en becomes high
 		 * - stage 0 computes its {x,y,z}_c based on our x_in, y_in, rad
 		 *
 		 * at the next clk edge, since sh_en is high, stage 0's results are 
 		 * pushed to {x,y,z}_out[0], at which point stage 1 begins using them
 		 * to compute its new results.
 		 */
		sh_en = ( | { rad_large, rad_small, in_empty, out_full } ) ? FALSE : TRUE;
		if ( sh_en )
		begin
			rad_c = in_dout;
			in_re = TRUE;
			out_we = TRUE;
		end

		/*
 		 * Save some cycles by testing rad_c directly, potentially batching updates
 		 * before writing to rad at next clk edge.
 		 *
 		 * This causes the critical path within each cycle to become longer.
 		 * We'll testbench to determine whether to favor clock frequency 
 		 * or cycle count.
 		 */
		if ( rad_c > PI )
		begin
			rad_c -= TWO_PI;
		end
		else if ( rad_c < -PI ) 
		begin
			rad_c += TWO_PI;
		end

		if ( rad_c > HALF_PI )
		begin
			rad_c -= PI;
			x_in = -x_in;
		end
		else if ( rad_c < -HALF_PI )
		begin
			rad_c += PI;
			x_in = -x_in;
		end

	end

endmodule: cordic

