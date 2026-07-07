
module bsrch_32
(
	input  logic clk,
	input  logic [ 31:0 ] n,
	output logic [ 5:0 ] i_msb
);

	logic [ 31:0 ] n_ff, n_tmp;
	logic [ 5:0 ] i_msb_ff, i_msb_c;

	always_ff @ ( posedge clk )
	begin
		n_ff <= n;
		i_msb_ff <= i_msb_c;
	end

	assign i_msb = i_msb_ff;

	always_comb
	begin
		n_tmp = n_ff;
		i_msb_c = 6'h0;

		if ( | n_tmp[ 31:16 ] )
		begin
			i_msb_c[ 4 ] = 1'b1;
			n_tmp[ 15:0 ] = n_tmp[ 31:16 ];
		end

		if ( | n_tmp[ 15:8 ] )
		begin
			i_msb_c[ 3 ] = 1'b1;
			n_tmp[ 7:0 ] = n_tmp[ 15:8 ];
		end

		if ( | n_tmp[ 7:4 ] )
		begin
			i_msb_c[ 2 ] = 1'b1;
			n_tmp[ 3:0 ] = n_tmp[ 7:4 ];
		end

		if ( | n_tmp[ 3:2 ] )
		begin
			i_msb_c[ 1 ] = 1'b1;
			n_tmp[ 1:0 ] = n_tmp[ 3:2 ];
		end

		if ( 1'b1 === n_tmp[ 1 ] )
		begin
			i_msb_c[ 0 ] = 1'b1;
		end

	end

endmodule: bsrch_32

