
package biases_pkg;

localparam logic signed [ 0:9 ] [ 31:0 ] 
	LAYER0_BIASES =

{
	32'shFFFFDE52,
	32'shFFFFFE52,
	32'sh00003D46,
	32'sh0000275A,
	32'shFFFFFB48,
	32'sh00003A29,
	32'sh000016DA,
	32'sh00002B94,
	32'sh000034A7,
	32'sh000017CC
};

localparam logic signed [ 0:9 ] [ 31:0 ]
	LAYER1_BIASES = 
{
	32'sh0000006A,
	32'sh000022CB,
	32'sh00000064,
	32'sh000005E9,
	32'shFFFFF88C,
	32'sh00003354,
	32'sh00001042,
	32'sh000054C2,
	32'shFFFFD1B5,
	32'sh00000DD1
};

endpackage: biases_pkg

