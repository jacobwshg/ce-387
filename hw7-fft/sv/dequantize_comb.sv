
module dequantize_comb
#(
	parameter int DWIDTH = 32,
	parameter int FRACWIDTH = 14
)(
	input  logic signed [ DWIDTH-1:0 ] din,
	output logic signed [ DWIDTH-1:0 ] dout
);
	always_comb
	begin
		dout = $signed( din ) >>> FRACWIDTH;
		if ( din[ DWIDTH-1 ] && ( | din[ FRACWIDTH-1:0 ] ) )
		begin
			dout = dout + 1'h1;
		end
	end

endmodule: dequantize_comb

