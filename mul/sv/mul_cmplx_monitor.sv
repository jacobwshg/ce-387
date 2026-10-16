
module mul_cmplx_monitor
#(
	parameter int MUL_STAGES = 2,
	parameter int INWIDTH = 32,
	parameter int OUT_HI_WIDTH = INWIDTH,
	parameter int OUT_HI_BITPOS_WIDTH = $clog2( OUT_HI_WIDTH ),

	parameter logic FINDMSB_USE_BSRCH = 1'b0
)
(
	input  logic clk,
	input  logic rst,

	input  logic in_valid,
	input  logic signed [ INWIDTH-1:0 ] a, b, c, d,
	input  logic [ OUT_HI_WIDTH-1:0 ] p1_hi, p2_hi, p3_hi,

	output logic out_valid,
	output logic
		p1_preadd_oflow,
		p2_preadd_oflow,
		p3_preadd_oflow,
	output logic [ OUT_HI_BITPOS_WIDTH-1:0 ]
		p1_oflow_msbpos,
		p2_oflow_msbpos,
		p3_oflow_msbpos
);
	// Used for determining how many cycles to delay p*_preadd_oflow to
	// synchronize with p*_oflow_msbpos.
	// If register mul_cmplx p* outputs again and derive 
	// p*_oflow_msbpos_tmp from them, then 2.
	// If derive MSB positions directly from mul_cmplx p*, then 1.
	localparam int POST_MUL_STAGES = 2;

	// 1 for inputs 
	localparam int MON_TOTAL_STAGES = 1 + MUL_STAGES + POST_MUL_STAGES;

	// clocked on same edge as input regs in mul_cmplx
	logic signed [ INWIDTH-1:0 ] a_r, b_r, c_r, d_r;
	logic signed [ INWIDTH:0 ] p1_preadd_sum, p2_preadd_sum, p3_preadd_sum;
	logic
		p1_preadd_oflow_tmp, 
		p2_preadd_oflow_tmp, 
		p3_preadd_oflow_tmp; 

	logic
		p1_preadd_oflow_dly_r [ 0:MON_TOTAL_STAGES-2 ],
		p2_preadd_oflow_dly_r [ 0:MON_TOTAL_STAGES-2 ],
		p3_preadd_oflow_dly_r [ 0:MON_TOTAL_STAGES-2 ];

	// clocked from mul_cmplx's p*; therefore
	// one edge after mul_cmplx's p*_r[ STAGES-1 ]
	logic [ OUT_HI_WIDTH-1:0 ]
		p1_hi_r,
		p2_hi_r,
		p3_hi_r;
	logic [ OUT_HI_BITPOS_WIDTH-1:0 ]
		p1_oflow_msbpos_tmp,
		p2_oflow_msbpos_tmp,
		p3_oflow_msbpos_tmp;

	logic [ OUT_HI_BITPOS_WIDTH-1:0 ]
		p1_oflow_msbpos_r,
		p2_oflow_msbpos_r,
		p3_oflow_msbpos_r;

	logic valid_dly_r [ 0:MON_TOTAL_STAGES-1 ];

	findmsb_comb #(
		.DWIDTH( OUT_HI_WIDTH ), .BITPOSWIDTH( OUT_HI_BITPOS_WIDTH ),
		.USE_BSRCH( FINDMSB_USE_BSRCH )
	) findmsb_p1_hi (
		.val( p1_hi_r ), .msb_pos( p1_oflow_msbpos_tmp )
	);

	findmsb_comb #(
		.DWIDTH( OUT_HI_WIDTH ), .BITPOSWIDTH( OUT_HI_BITPOS_WIDTH ),
		.USE_BSRCH( FINDMSB_USE_BSRCH )
	) findmsb_p2_hi (
		.val( p2_hi_r ), .msb_pos( p2_oflow_msbpos_tmp )
	);

	findmsb_comb #(
		.DWIDTH( OUT_HI_WIDTH ), .BITPOSWIDTH( OUT_HI_BITPOS_WIDTH ),
		.USE_BSRCH( FINDMSB_USE_BSRCH )
	) findmsb_p3_hi (
		.val( p3_hi_r ), .msb_pos( p3_oflow_msbpos_tmp )
	);

	always_ff @ ( posedge clk )
	begin
		if ( rst )
		begin
			valid_dly_r <= '{ default: 1'b0 };
		end
		else
		begin
			valid_dly_r[ 0 ] <= in_valid;
			valid_dly_r[ 1:MON_TOTAL_STAGES-1 ] <= valid_dly_r[ 0:MON_TOTAL_STAGES-2 ];
		end

		a_r <= a;
		b_r <= b;
		c_r <= c;
		d_r <= d;

		p1_preadd_oflow_dly_r[ 0 ] <= p1_preadd_oflow_tmp;
		p1_preadd_oflow_dly_r[ 1:MON_TOTAL_STAGES-2 ] <= p1_preadd_oflow_dly_r[ 0:MON_TOTAL_STAGES-3 ];
		p2_preadd_oflow_dly_r[ 0 ] <= p2_preadd_oflow_tmp;
		p2_preadd_oflow_dly_r[ 1:MON_TOTAL_STAGES-2 ] <= p2_preadd_oflow_dly_r[ 0:MON_TOTAL_STAGES-3 ];
		p3_preadd_oflow_dly_r[ 0 ] <= p3_preadd_oflow_tmp;
		p3_preadd_oflow_dly_r[ 1:MON_TOTAL_STAGES-2 ] <= p3_preadd_oflow_dly_r[ 0:MON_TOTAL_STAGES-3 ];

		p1_hi_r <= p1_hi;
		p2_hi_r <= p2_hi;
		p3_hi_r <= p3_hi;

		p1_oflow_msbpos_r <= p1_oflow_msbpos_tmp;
		p2_oflow_msbpos_r <= p2_oflow_msbpos_tmp;
		p3_oflow_msbpos_r <= p3_oflow_msbpos_tmp;
	end

	assign p1_preadd_sum = ( INWIDTH+1 )'( a_r ) + ( INWIDTH+1 )'( b_r );
	assign p2_preadd_sum = ( INWIDTH+1 )'( c_r ) + ( INWIDTH+1 )'( d_r );
	assign p3_preadd_sum = ( INWIDTH+1 )'( b_r ) - ( INWIDTH+1 )'( a_r );
	assign p1_preadd_oflow_tmp = p1_preadd_sum[ INWIDTH ];
	assign p2_preadd_oflow_tmp = p2_preadd_sum[ INWIDTH ];
	assign p3_preadd_oflow_tmp = p3_preadd_sum[ INWIDTH ];

	assign out_valid = valid_dly_r[ MON_TOTAL_STAGES-1 ];
	assign p1_preadd_oflow = p1_preadd_oflow_dly_r[ MON_TOTAL_STAGES-2 ];
	assign p2_preadd_oflow = p2_preadd_oflow_dly_r[ MON_TOTAL_STAGES-2 ];
	assign p3_preadd_oflow = p3_preadd_oflow_dly_r[ MON_TOTAL_STAGES-2 ];
	assign p1_oflow_msbpos = p1_oflow_msbpos_r;
	assign p2_oflow_msbpos = p2_oflow_msbpos_r;
	assign p3_oflow_msbpos = p3_oflow_msbpos_r;

endmodule: mul_cmplx_monitor

