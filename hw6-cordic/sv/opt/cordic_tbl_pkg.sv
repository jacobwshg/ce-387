
package cordic_tbl_pkg;

	localparam int STAGE_CNT = 16;

	localparam logic signed [ 0:STAGE_CNT-1 ] [ 15:0 ]
		CORDIC_TABLE = 
	{
		16'h3243, 16'h1DAC, 16'h0FAD, 16'h07F5,
		16'h03FE, 16'h01FF, 16'h00FF, 16'h007F, 
		16'h003F, 16'h001F, 16'h000F, 16'h0007,
		16'h0003, 16'h0001, 16'h0000, 16'h0000
	};

endpackage: cordic_tbl_pkg

