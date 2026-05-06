
import globals_pkg :: DWIDTH;

module pipe_buf #(
	parameter int DWIDTH = globals_pkg::DWIDTH
)
(
	input  logic clk, rst,

	input  logic rd_en, wr_en,

	input  logic [ DWIDTH-1:0 ] din,
	output logic [ DWIDTH-1:0 ] dout,

	output logic full,
	output logic empty

);

	logic read, written;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			read    <= 1'b0;
			written <= 1'b0;
		end
		else
		begin
			if ( rd_en && full ) 
			begin
				read <= ~read;
			end
			if ( wr_en && !full )
			begin
				written <= ~written;
			end
		end
	end

	assign empty = 1'( read === written );
	assign full = !empty;

	always_ff @ ( posedge clk )
	begin
		if ( wr_en && !full ) 
		begin
			dout <= din;
		end
	end

endmodule: pipe_buf

