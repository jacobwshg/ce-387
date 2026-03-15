`timescale 1ns/1ps

import globals_pkg::*;
import quant_pkg::*; 

module read_iq(
    input logic in_valid, 
    input logic [31:0] in, 
    output logic signed [DWIDTH-1:0] I, Q, 
    output logic out_valid
); 

assign out_valid = in_valid; 
assign I = QUANT($signed(in[15:0])); 
assign Q = QUANT($signed(in[31:16]));  

endmodule 