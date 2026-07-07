
module bsrch_32
(
	input  logic clk,
	input  logic [ 31:0 ] n,
	output logic [ 5:0 ] i_msb
);

	logic [ 31:0 ] n_ff;
	logic [ 5:0 ] i_msb_ff, i_msb_c;

	logic [ 15:0 ]
		msb_slice_16, msb_slice_8, 
		msb_slice_4, msb_slice_2;


	always_ff @ ( posedge clk )
	begin
		n_ff <= n;
		i_msb_ff <= i_msb_c;
	end

	assign i_msb = i_msb_ff;

	always_comb
	begin
		i_msb_c = 6'h0;
		{ msb_slice_16, msb_slice_8, msb_slice_4, msb_slice_2 } = '{ default: 'h0 };

		if ( | n_ff[ 31:16 ] )
		begin
			i_msb_c[ 4 ] = 1'b1;
			msb_slice_16[ 15:0 ] = n_ff[ 31:16 ];
		end
		else
		begin
			msb_slice_16[ 15:0 ] = n_ff[ 15:0 ];
		end

		if ( | msb_slice_16[ 15:8 ] )
		begin
			i_msb_c[ 3 ] = 1'b1;
			msb_slice_8[ 7:0 ] = msb_slice_16[ 15:8 ];
		end
		else
		begin
			msb_slice_8[ 7:0 ] = msb_slice_16[ 7:0 ];
		end

		if ( | msb_slice_8[ 7:4 ] )
		begin
			i_msb_c[ 2 ] = 1'b1;
			msb_slice_4[ 3:0 ] = msb_slice_8[ 7:4 ];
		end
		else
		begin
			msb_slice_4[ 3:0 ] = msb_slice_8[ 3:0 ];
		end

		if ( | msb_slice_4[ 3:2 ] )
		begin
			i_msb_c[ 1 ] = 1'b1;
			msb_slice_2[ 1:0 ] = msb_slice_4[ 3:2 ];
		end
		else
		begin
			msb_slice_2[ 1:0 ] = msb_slice_4[ 1:0 ];
		end

		if ( 1'b1 === msb_slice_2[ 1 ] )
		begin
			i_msb_c[ 0 ] = 1'b1;
		end

	end

endmodule: bsrch_32

