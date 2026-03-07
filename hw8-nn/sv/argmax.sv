
module argmax #(
	DATA_WIDTH = 32,
	IDX_WIDTH  = 16
)(
	input logic clk,
	input logic rst,

	input logic in_empty, 
	input logic in_valid,
	input logic signed [ DATA_WIDTH-1:0 ] din,

	output logic in_rd_en,
	output logic signed [ DATA_WIDTH-1:0 ] max,
	output logic [ IDX_WIDTH-1:0 ] i_max
);

	logic [ IDX_WIDTH-1:0 ] idx, idx_c, i_max_c;
	logic [ DATA_WIDTH-1:0 ] max_c;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			idx <= 'd0;
			max <= $signed( 1'b1 << (DATA_WIDTH-1) );
			i_max <= 'd0;
		end
		else
		begin
			idx <= idx_c;
			max <= max_c;
			i_max <= i_max_c;
		end
	end

	always_comb
	begin
		idx_c = idx;
		max_c = max;
		i_max_c = i_max;
		if ( ~in_empty )
		begin
			in_rd_en = 1;
			if ( in_valid )
			begin
				idx_c = idx + 1;
				if ( din > max )
				begin
					max_c = din;
					i_max_c = idx;
				end
			end
		end
	end

endmodule: argmax

