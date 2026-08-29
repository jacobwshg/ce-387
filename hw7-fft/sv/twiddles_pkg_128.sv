package twiddles_pkg;

	localparam int N = 128;
	localparam int STAGES = $clog2( N );

	localparam logic signed [ 0:( N/2-1 ) ] [ 0:1 ] [ 31:0 ]
		TWIDDLES [ 0:STAGES-1 ] = 
	'{
		'{
			0:'{32'sh00004000,32'sh00000000},
			default:'{32'sh00000000,32'sh00000000}
		},
		'{
			0:'{32'sh00004000,32'sh00000000},1:'{32'sh00000000,32'shffffc000},
			default:'{32'sh00000000,32'sh00000000}
		},
		'{
			0:'{32'sh00004000,32'sh00000000},1:'{32'sh00002d41,32'shffffd2bf},2:'{32'sh00000000,32'shffffc000},3:'{32'shffffd2bf,32'shffffd2bf},
			default:'{32'sh00000000,32'sh00000000}
		},
		'{
			0:'{32'sh00004000,32'sh00000000},1:'{32'sh00003b20,32'shffffe783},2:'{32'sh00002d41,32'shffffd2bf},3:'{32'sh0000187d,32'shffffc4e0},
			4:'{32'sh00000000,32'shffffc000},5:'{32'shffffe783,32'shffffc4e0},6:'{32'shffffd2bf,32'shffffd2bf},7:'{32'shffffc4e0,32'shffffe783},
			default:'{32'sh00000000,32'sh00000000}
		},
		'{
			0:'{32'sh00004000,32'sh00000000},1:'{32'sh00003ec5,32'shfffff384},2:'{32'sh00003b20,32'shffffe783},3:'{32'sh00003536,32'shffffdc72},
			4:'{32'sh00002d41,32'shffffd2bf},5:'{32'sh0000238e,32'shffffcaca},6:'{32'sh0000187d,32'shffffc4e0},7:'{32'sh00000c7c,32'shffffc13b},
			8:'{32'sh00000000,32'shffffc000},9:'{32'shfffff384,32'shffffc13b},10:'{32'shffffe783,32'shffffc4e0},11:'{32'shffffdc72,32'shffffcaca},
			12:'{32'shffffd2bf,32'shffffd2bf},13:'{32'shffffcaca,32'shffffdc72},14:'{32'shffffc4e0,32'shffffe783},15:'{32'shffffc13b,32'shfffff384},
			default:'{32'sh00000000,32'sh00000000}
		},
		'{
			0:'{32'sh00004000,32'sh00000000},1:'{32'sh00003fb1,32'shfffff9bb},2:'{32'sh00003ec5,32'shfffff384},3:'{32'sh00003d3e,32'shffffed6c},
			4:'{32'sh00003b20,32'shffffe783},5:'{32'sh00003871,32'shffffe1d5},6:'{32'sh00003536,32'shffffdc72},7:'{32'sh00003179,32'shffffd767},
			8:'{32'sh00002d41,32'shffffd2bf},9:'{32'sh00002899,32'shffffce87},10:'{32'sh0000238e,32'shffffcaca},11:'{32'sh00001e2b,32'shffffc78f},
			12:'{32'sh0000187d,32'shffffc4e0},13:'{32'sh00001294,32'shffffc2c2},14:'{32'sh00000c7c,32'shffffc13b},15:'{32'sh00000645,32'shffffc04f},
			16:'{32'sh00000000,32'shffffc000},17:'{32'shfffff9bb,32'shffffc04f},18:'{32'shfffff384,32'shffffc13b},19:'{32'shffffed6c,32'shffffc2c2},
			20:'{32'shffffe783,32'shffffc4e0},21:'{32'shffffe1d5,32'shffffc78f},22:'{32'shffffdc72,32'shffffcaca},23:'{32'shffffd767,32'shffffce87},
			24:'{32'shffffd2bf,32'shffffd2bf},25:'{32'shffffce87,32'shffffd767},26:'{32'shffffcaca,32'shffffdc72},27:'{32'shffffc78f,32'shffffe1d5},
			28:'{32'shffffc4e0,32'shffffe783},29:'{32'shffffc2c2,32'shffffed6c},30:'{32'shffffc13b,32'shfffff384},31:'{32'shffffc04f,32'shfffff9bb},
			default:'{32'sh00000000,32'sh00000000}
		},
		'{
			0:'{32'sh00004000,32'sh00000000},1:'{32'sh00003fec,32'shfffffcdd},2:'{32'sh00003fb1,32'shfffff9bb},3:'{32'sh00003f4e,32'shfffff69c},
			4:'{32'sh00003ec5,32'shfffff384},5:'{32'sh00003e14,32'shfffff074},6:'{32'sh00003d3e,32'shffffed6c},7:'{32'sh00003c42,32'shffffea71},
			8:'{32'sh00003b20,32'shffffe783},9:'{32'sh000039da,32'shffffe4a3},10:'{32'sh00003871,32'shffffe1d5},11:'{32'sh000036e5,32'shffffdf19},
			12:'{32'sh00003536,32'shffffdc72},13:'{32'sh00003367,32'shffffd9e1},14:'{32'sh00003179,32'shffffd767},15:'{32'sh00002f6b,32'shffffd506},
			16:'{32'sh00002d41,32'shffffd2bf},17:'{32'sh00002afa,32'shffffd095},18:'{32'sh00002899,32'shffffce87},19:'{32'sh0000261f,32'shffffcc99},
			20:'{32'sh0000238e,32'shffffcaca},21:'{32'sh000020e7,32'shffffc91b},22:'{32'sh00001e2b,32'shffffc78f},23:'{32'sh00001b5d,32'shffffc626},
			24:'{32'sh0000187d,32'shffffc4e0},25:'{32'sh0000158f,32'shffffc3be},26:'{32'sh00001294,32'shffffc2c2},27:'{32'sh00000f8c,32'shffffc1ec},
			28:'{32'sh00000c7c,32'shffffc13b},29:'{32'sh00000964,32'shffffc0b2},30:'{32'sh00000645,32'shffffc04f},31:'{32'sh00000323,32'shffffc014},
			32:'{32'sh00000000,32'shffffc000},33:'{32'shfffffcdd,32'shffffc014},34:'{32'shfffff9bb,32'shffffc04f},35:'{32'shfffff69c,32'shffffc0b2},
			36:'{32'shfffff384,32'shffffc13b},37:'{32'shfffff074,32'shffffc1ec},38:'{32'shffffed6c,32'shffffc2c2},39:'{32'shffffea71,32'shffffc3be},
			40:'{32'shffffe783,32'shffffc4e0},41:'{32'shffffe4a3,32'shffffc626},42:'{32'shffffe1d5,32'shffffc78f},43:'{32'shffffdf19,32'shffffc91b},
			44:'{32'shffffdc72,32'shffffcaca},45:'{32'shffffd9e1,32'shffffcc99},46:'{32'shffffd767,32'shffffce87},47:'{32'shffffd506,32'shffffd095},
			48:'{32'shffffd2bf,32'shffffd2bf},49:'{32'shffffd095,32'shffffd506},50:'{32'shffffce87,32'shffffd767},51:'{32'shffffcc99,32'shffffd9e1},
			52:'{32'shffffcaca,32'shffffdc72},53:'{32'shffffc91b,32'shffffdf19},54:'{32'shffffc78f,32'shffffe1d5},55:'{32'shffffc626,32'shffffe4a3},
			56:'{32'shffffc4e0,32'shffffe783},57:'{32'shffffc3be,32'shffffea71},58:'{32'shffffc2c2,32'shffffed6c},59:'{32'shffffc1ec,32'shfffff074},
			60:'{32'shffffc13b,32'shfffff384},61:'{32'shffffc0b2,32'shfffff69c},62:'{32'shffffc04f,32'shfffff9bb},63:'{32'shffffc014,32'shfffffcdd},
			default:'{32'sh00000000,32'sh00000000}
		}
	};

endpackage: twiddles_pkg

