
import cordic_tbl_pkg::CORDIC_TABLE;

module cordic_stage
#(
	parameter int STAGE = 0,
	parameter logic signed [ 15:0 ]
		C = CORDIC_TABLE[ 0 ] 
)
(
	input  logic clk,

	input  logic signed [ 15:0 ] x_in,
	input  logic signed [ 15:0 ] y_in,
	input  logic signed [ 15:0 ] z_in,
	input  logic in_valid,

	output logic signed [ 15:0 ] x_out, 
	output logic signed [ 15:0 ] y_out, 
	output logic signed [ 15:0 ] z_out, 
	output logic out_valid
);

	logic signed [ 15:0 ]
		x_r[ 0:2 ],
		y_r[ 0:2 ],
		z_r[ 0:2 ];
	logic signed d_r;

	logic signed [ 15:0 ]
		x_tana, x_tana_r,
		y_tana, y_tana_r,
		alpha_r;

	logic valid_r[ 0:2 ];

	always_ff @ ( posedge clk )
	begin

		x_r[ 0 ] <= x_in;
		y_r[ 0 ] <= y_in;
		z_r[ 0 ] <= z_in;
		d_r <= ( z_in >= 0 ) ? 1'sh0 : 1'sh1;
		valid_r[ 0 ] <= in_valid;

		x_r[ 1 ] <= x_r[ 0 ];
		y_r[ 1 ] <= y_r[ 0 ];
		z_r[ 1 ] <= z_r[ 0 ];
		x_tana_r <= ( 1'sh1===d_r ) ? ( -x_tana ) : x_tana;
		y_tana_r <= ( 1'sh1===d_r ) ? ( -y_tana ) : y_tana;
		alpha_r  <= ( 1'sh1===d_r ) ? ( -C ) : C;
		valid_r[ 1 ] <= valid_r[ 0 ];

		x_r[ 2 ] <= x_r[ 1 ] - y_tana_r;
		y_r[ 2 ] <= y_r[ 1 ] + x_tana_r;
		z_r[ 2 ] <= z_r[ 1 ] - alpha_r;
		valid_r[ 2 ] <= valid_r[ 1 ];

	end

	always_comb
	begin
		x_tana = x_r[ 0 ] >> STAGE;
		y_tana = y_r[ 0 ] >> STAGE;
	end

	assign x_out = x_r[ 2 ];
	assign y_out = y_r[ 2 ];
	assign z_out = z_r[ 2 ];
	assign out_valid = valid_r[ 2 ];

endmodule: cordic_stage

