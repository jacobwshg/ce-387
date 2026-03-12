package constants_pkg;
	import globals_pkg::*;

	parameter int AUDIO_DECIM = 8;
	parameter int VOLUME_LEVEL = 1024;
	parameter int FM_DEMOD_GAIN = 758;

	parameter int IIR_COEFF_TAPS = 2;
	parameter logic signed [31:0] IIR_Y_COEFFS [0:1] = '{ 32'sd0, -32'sd666 };
	parameter logic signed [31:0] IIR_X_COEFFS [0:1] = '{ 32'sd178, 32'sd178 };

	parameter int CHANNEL_COEFF_TAPS = 20;
	parameter logic signed [31:0] CHANNEL_COEFFS_REAL [0:19] = '{
		32'h00000001, 32'h00000008, 32'hfffffff3, 32'h00000009, 32'h0000000b, 32'hffffffd3, 32'h00000045, 32'hffffffd3, 
		32'hffffffb1, 32'h00000257, 32'h00000257, 32'hffffffb1, 32'hffffffd3, 32'h00000045, 32'hffffffd3, 32'h0000000b, 
		32'h00000009, 32'hfffffff3, 32'h00000008, 32'h00000001
	};

	parameter int AUDIO_LPR_COEFF_TAPS = 32;
	parameter logic signed [31:0] AUDIO_LPR_COEFFS [0:31] = '{
		32'hfffffffd, 32'hfffffffa, 32'hfffffff4, 32'hffffffed, 32'hffffffe5, 32'hffffffdf, 32'hffffffe2, 32'hfffffff3, 
		32'h00000015, 32'h0000004e, 32'h0000009b, 32'h000000f9, 32'h0000015d, 32'h000001be, 32'h0000020e, 32'h00000243, 
		32'h00000243, 32'h0000020e, 32'h000001be, 32'h0000015d, 32'h000000f9, 32'h0000009b, 32'h0000004e, 32'h00000015, 
		32'hfffffff3, 32'hffffffe2, 32'hffffffdf, 32'hffffffe5, 32'hffffffed, 32'hfffffff4, 32'hfffffffa, 32'hfffffffd
	};

	parameter int AUDIO_LMR_COEFF_TAPS = 32;
	parameter logic signed [31:0] AUDIO_LMR_COEFFS [0:31] = '{
		32'hfffffffd, 32'hfffffffa, 32'hfffffff4, 32'hffffffed, 32'hffffffe5, 32'hffffffdf, 32'hffffffe2, 32'hfffffff3, 
		32'h00000015, 32'h0000004e, 32'h0000009b, 32'h000000f9, 32'h0000015d, 32'h000001be, 32'h0000020e, 32'h00000243, 
		32'h00000243, 32'h0000020e, 32'h000001be, 32'h0000015d, 32'h000000f9, 32'h0000009b, 32'h0000004e, 32'h00000015, 
		32'hfffffff3, 32'hffffffe2, 32'hffffffdf, 32'hffffffe5, 32'hffffffed, 32'hfffffff4, 32'hfffffffa, 32'hfffffffd
	};

	parameter int BP_PILOT_COEFF_TAPS = 32;
	parameter logic signed [31:0] BP_PILOT_COEFFS [0:31] = '{
		32'h0000000e, 32'h0000001f, 32'h00000034, 32'h00000048, 32'h0000004e, 32'h00000036, 32'hfffffff8, 32'hffffff98, 
		32'hffffff2d, 32'hfffffeda, 32'hfffffec3, 32'hfffffefe, 32'hffffff8a, 32'h0000004a, 32'h0000010f, 32'h000001a1, 
		32'h000001a1, 32'h0000010f, 32'h0000004a, 32'hffffff8a, 32'hfffffefe, 32'hfffffec3, 32'hfffffeda, 32'hffffff2d, 
		32'hffffff98, 32'hfffffff8, 32'h00000036, 32'h0000004e, 32'h00000048, 32'h00000034, 32'h0000001f, 32'h0000000e
	};

	parameter int BP_LMR_COEFF_TAPS = 32;
	parameter logic signed [31:0] BP_LMR_COEFFS [0:31] = '{
		32'h00000000, 32'h00000000, 32'hfffffffc, 32'hfffffff9, 32'hfffffffe, 32'h00000008, 32'h0000000c, 32'h00000002, 
		32'h00000003, 32'h0000001e, 32'h00000030, 32'hfffffffc, 32'hffffff8c, 32'hffffff58, 32'hffffffc3, 32'h0000008a, 
		32'h0000008a, 32'hffffffc3, 32'hffffff58, 32'hffffff8c, 32'hfffffffc, 32'h00000030, 32'h0000001e, 32'h00000003, 
		32'h00000002, 32'h0000000c, 32'h00000008, 32'hfffffffe, 32'hfffffff9, 32'hfffffffc, 32'h00000000, 32'h00000000
	};

	parameter int HP_COEFF_TAPS = 32;
	parameter logic signed [31:0] HP_COEFFS [0:31] = '{
		32'hffffffff, 32'h00000000, 32'h00000000, 32'h00000002, 32'h00000004, 32'h00000008, 32'h0000000b, 32'h0000000c, 
		32'h00000008, 32'hffffffff, 32'hxffffffee, 32'hffffffd7, 32'hffffffbb, 32'hffffff9f, 32'hffffff87, 32'hffffff76, 
		32'hffffff76, 32'hffffff87, 32'hffffff9f, 32'hffffffbb, 32'hffffffd7, 32'hxffffffee, 32'hffffffff, 32'h00000008, 
		32'h0000000c, 32'h0000000b, 32'h00000008, 32'h00000004, 32'h00000002, 32'h00000000, 32'h00000000, 32'hffffffff
	};

endpackage: constants_pkg