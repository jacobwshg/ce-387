
/*
 *   ( a+bi )( c+di )
 * = ac - bd + ( ad + bc )i
 * = ac + ad - bd - ad + ( ad + ac + bc - ac  )i
 * = ( c+d )a - ( a+b )d + ( ( c+d )a + ( b-a )c )i
 *
 */

module mul_cmplx
#(
	parameter int STAGES = 5,
	parameter int DWIDTH = 32
)
(
	input  logic clk, rst, wr_en,
	input  logic signed [ DWIDTH-1:0 ]
		a, b, c, d,
	output logic signed [ DWIDTH-1:0 ]
		p1, p2, p3
);

	logic signed [ DWIDTH-1:0 ]
		a_r, b_r, c_r, d_r;

	logic signed [ 0:STAGES-1 ] [ DWIDTH-1:0 ]
		p1_r, p2_r, p3_r;

	always_ff @ ( posedge clk )
	if ( wr_en )
	begin
		a_r <= a;
		b_r <= b;
		c_r <= c;
		d_r <= d;
	end

	always_ff @ ( posedge clk )
	if ( wr_en ) // maintain Fmax on Xilinx targets ( don't check retiming option )
	begin
		p1_r[ 0 ] <= ( a_r + b_r ) * d_r;
		p2_r[ 0 ] <= ( c_r + d_r ) * a_r;
		p3_r[ 0 ] <= ( b_r - a_r ) * c_r;
	end

	generate
		if ( STAGES > 1 )
		begin
			always_ff @ ( posedge clk )
			if ( wr_en ) // avoid data loss
			begin
				p1_r[ 1:STAGES-1 ] <= p1_r[ 0:STAGES-2 ];
				p2_r[ 1:STAGES-1 ] <= p2_r[ 0:STAGES-2 ];
				p3_r[ 1:STAGES-1 ] <= p3_r[ 0:STAGES-2 ];
			end
		end
	endgenerate

	assign p1 = p1_r[ STAGES-1 ];
	assign p2 = p2_r[ STAGES-1 ];
	assign p3 = p3_r[ STAGES-1 ];

endmodule: mul_cmplx

