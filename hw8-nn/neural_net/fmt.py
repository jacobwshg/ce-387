
from sys import argv, exit

if len( argv ) < 2:
	print( "usage: fmt.py <layer_idx (0-1)>" )
	exit( 2 )

try:

	DW = 32
	L = int( argv[1] )

	assert L in [ 0,1 ], "layer idx out of range"

	INFILE = f"layer_{L}_weights_biases.txt"
	OUTFILE = f"layer{L}_weights.sv"

	INPUT_SIZES = [ 784, 10 ]
	OUTPUT_SIZES = [ 10, 10 ]

	INPUT_SIZE = INPUT_SIZES[ L ]
	OUTPUT_SIZE = OUTPUT_SIZES[ L ]

	ELEMS_PER_LINE = 4

	with open( INFILE, "r" ) as infile:
		with open( OUTFILE, "w+" ) as outfile:

			hdr = f"localparam logic signed [ 0:{OUTPUT_SIZE-1} ] [ 0:{INPUT_SIZE-1} ] [ {DW-1}:0 ]"
			hdr += "\n\t"
			hdr += f"LAYER{L}_WEIGHTS ="
			hdr += "\n{\n"
			outfile.write( hdr )

			for i_neuron in range( OUTPUT_SIZE ):
				# begin neuron 
				outfile.write( "\t{\n" )
				for i_weight in range( INPUT_SIZE ):
					if i_weight % ELEMS_PER_LINE == 0:
						# start of line
						outfile.write( "\t\t" )

					line = infile.readline()
					#print( line )
					line = line.strip()
					outfile.write( "32'sh" + line )
					if ( i_weight + 1 < INPUT_SIZE ):
						outfile.write( ", " )

					if ( i_weight % ELEMS_PER_LINE == ELEMS_PER_LINE-1 ) \
					or ( i_weight + 1 == INPUT_SIZE ):
						# end of line or neuron
						outfile.write( "\n" )

				# end neuron
				outfile.write( "\t}" )
				if ( i_neuron+1 < OUTPUT_SIZE ):
					# not final neuron
					outfile.write( "," )
				outfile.write( "\n" )

			outfile.write( "};\n\n" )

except Exception as e:
	print( str(e) )

