
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#include <string.h>
#include <assert.h>

// quantization
#define BITS            14
#define QUANT_VAL       (1 << BITS)
#define QUANTIZE_F(f)   (int)(((float)(f) * (float)QUANT_VAL))
#define QUANTIZE_I(i)   (int)((int)(i) * (int)QUANT_VAL)

//#define DEQUANTIZE_I(i) (int)(((int)(i) + (QUANT_VAL/2)) / (int)QUANT_VAL)

#define DEQUANTIZE_F(i) (float)((float)(i) / (float)QUANT_VAL)

#define PI 3.14159265358979323846

inline int
DEQUANTIZE_I( const int i )
{
	int dq = i >> BITS;
	//
	// add 1 if `i` both is negative and has any set fraction bits
	// important: test `i` itself and not `dq`
	//
	if ( i<0 && ( ( i & ( QUANT_VAL-1 ) ) != 0 ) )
	{
		++dq;
	}
	return dq;
}

typedef struct
{
	int real;
	int imag;
} Complex;


// Bit reversal
void bit_reversal( Complex *in, Complex *out, int N ) 
{
	// Precompute bit-reversed indices for the range [0, N-1]
	int bit_reversal_table[ N ];
	printf( "bit-reversal table\n" );
	for ( int i = 0; i < N; ++i )
	{
		int j = 0;
		int ii = i;
		for ( int bit = 0; bit < log2( N ); ++bit )
		{
			j <<= 1;
			j |= ii & 1;
			ii >>= 1;
		}
		bit_reversal_table[ i ] = j;
		//std::cout << (i == 0 ? "[" : ",") << bit_reversal_table[i] << (i == N-1 ? "]\n" : "");
		printf( "%s%d%s\n", ( i == 0 ? "[" : "," ), bit_reversal_table[ i ], ( i == N-1 ? "]\n" : "" ) );
	}

	// Use the computed table for reordering
	for ( int i = 0; i < N; i++ )
	{
		out[ bit_reversal_table[ i ] ] = in[ i ];
	}
}

// FFT stage operation (butterfly computation)
void butterfly(
	const int stage, const int sampl_idx,
	Complex *in1,  Complex *in2,
	Complex *out1, Complex *out2,
	Complex *w
) 
{
	/*
	Complex v =
	{
		DEQUANTIZE_I(w.real * in2->real) - DEQUANTIZE_I(w.imag * in2->imag),
		DEQUANTIZE_I(w.real * in2->imag) + DEQUANTIZE_I(w.imag * in2->real)
	};
	*/

	const int
		w_re = w->real, w_im = w->imag,
		in1_re = in1->real, in1_im = in1->imag,
		in2_re = in2->real, in2_im = in2->imag;

	const int prod_wr_i2r_qq = w_re * in2_re;
	const int prod_wr_i2i_qq = w_re * in2_im;
	const int prod_wi_i2i_qq = w_im * in2_im;
	const int prod_wi_i2r_qq = w_im * in2_re;

	const int prod_wr_i2r = DEQUANTIZE_I( prod_wr_i2r_qq );
	const int prod_wr_i2i = DEQUANTIZE_I( prod_wr_i2i_qq );
	const int prod_wi_i2i = DEQUANTIZE_I( prod_wi_i2i_qq );
	const int prod_wi_i2r = DEQUANTIZE_I( prod_wi_i2r_qq );

	Complex v =
	{
		prod_wr_i2r - prod_wi_i2i,
		prod_wr_i2i + prod_wi_i2r,
	};
	
	out1->real = in1_re + v.real;
	out1->imag = in1_im + v.imag;
	out2->real = in1_re - v.real;
	out2->imag = in1_im - v.imag;

	/////////
	/*
	if ( stage == 0 )
	{

	printf( "stage 1 butterfly:\n" );
	printf( "\tw = %08x + %08xj\n", w_re, w_im );
	printf( "\tin1 = %08x + %08xj\n", in1_re, in1_im );
	printf( "\tin2 = %08x + %08xj\n", in2_re, in2_im );

	//printf( "\tr*r: %08x, dq: %08x", prod_wr_i2r_qq, prod_wr_i2r );
	//printf( "\tr*i: %08x, dq: %08x", prod_wr_i2i_qq, prod_wr_i2i );
	//printf( "\ti*i: %08x, dq: %08x", prod_wi_i2i_qq, prod_wi_i2i );
	//printf( "\ti*r: %08x, dq: %08x\n", prod_wi_i2r_qq, prod_wi_i2r );

	printf( "\tv.real = %08x - %08x = %08x\n", prod_wr_i2r, prod_wi_i2i, v.real );
	printf( "\tv.imag = %08x + %08x = %08x\n", prod_wr_i2i, prod_wi_i2r, v.imag );
	printf( "\tout1 = %08x + %08xj\n", out1->real, out1->imag );
	printf( "\tout2 = %08x + %08xj\n", out2->real, out2->imag );
	
	}
	*/
}

// FFT function with feed-forward memory allocation
void fft( Complex *in, Complex *out, const int N ) 
{
	assert( N > 0 );
	assert( !( N & ( N-1 ) ) ); // sanity check: power of 2

	const int HALF_N = N >> 1;

	const int NUM_STAGES = log2( N );
	const int TOTAL_SIZE = N * (NUM_STAGES + 1);

	Complex x[ TOTAL_SIZE ];
	Complex ctable[ NUM_STAGES ][ HALF_N ];

	memset( ctable, 0x0, sizeof ctable );

	// Stage 0: Bit-reversed input stored in stage 0 memory
	bit_reversal( in, x, N );

	// OK

	// reordered inputs
	for ( int i = 0; i < N; ++i )
	{
		printf("X[%d] = %08x + %08xj\n", i, x[i].real, x[i].imag);
	}

	// FFT computation across stages
	for ( int stage = 0; stage < NUM_STAGES; ++stage ) 
	{
		printf( "\n" );

		//
		// base offsets w.r.t. all samples and intermediate values
		//
		const int read_offset  = stage * N;
		// this stage's outputs are next stage's inputs
		const int write_offset = read_offset + N; 

		// step size doubles per stage
		const int step = 1 << ( stage + 1 );
		const int half_step = step / 2;

		for ( int j = 0; j < half_step; ++j )
		{
			// Calculate the twiddle factor
			const float angle_step = -PI / half_step;
			float angle = j * angle_step;
			Complex w = { QUANTIZE_F( cos( angle ) ), QUANTIZE_F( sin( angle ) ) };
			ctable[ stage ][ j ] = w;
		}

		/* step ( = butterfly group ) idx */
		for ( int i = 0; i < N; i += step )
		{
			/* step-internal idx of a single complex value */
			for ( int j = 0; j < half_step; ++j ) 
			{
				// Calculate read and write addresses for the current value
				const int in1_idx  = read_offset  + i + j;
				const int in2_idx  = in1_idx + half_step;
				const int out1_idx = write_offset + i + j;
				const int out2_idx = out1_idx + half_step;

				Complex *const w = &ctable[ stage ][ j ];

				// Perform the FFT stage operation
				butterfly(
					stage, i+j,
					&x[ in1_idx ], &x[ in2_idx ],
					&x[ out1_idx ], &x[ out2_idx ],
					w
				);

				//////////////////
				/*
				printf(
					"Stage %d, i=%d, j=%d: "
					"W = %08x + %08xj, "
					"X[%d] = %08x + %08xj, "
					"X[%d] = %08x + %08xj, "
					"X[%d] = %08x + %08xj, "
					"X[%d] = %08x + %08xj\n",
					stage+1, i, j,
					w->real, w->imag,
					in1_idx,  x[ in1_idx  ].real, x[ in1_idx  ].imag,
					in2_idx,  x[ in2_idx  ].real, x[ in2_idx  ].imag,
					out1_idx, x[ out1_idx ].real, x[ out1_idx ].imag,
					out2_idx, x[ out2_idx ].real, x[ out2_idx ].imag
				);
				*/
			}
		}
	}

	//////////////////////
	///*
	// Print the twiddle factor table for SystemVerilog
	printf( "package twdls_pkg;\n\n" );
	printf( "\tlocalparam int N_MAX     = %d;\n", N );
	printf( "\tlocalparam int STAGE_MAX = $clog2( N_MAX );\n\n", N );
	printf(
		"\tlocalparam logic signed [ 0:STAGE_MAX-1 ] [ 0:( N_MAX/2 )-1 ] [ 0:1 ] [ 31:0 ]\n"
		"\t\tTWDLS=\n"
		"\t'{\n"
	);
	for ( int i = 0; i < NUM_STAGES; i++ )
	{
		printf( "\t\t'{" );
		for ( int j = 0; j < HALF_N; ++j ) 
		{
			printf(
				"%s%s{32'sh%08x,32'sh%08x}",
				( j==0 ? "" : ", " ), ( j%4 ? "" : "\n\t\t\t" ), ctable[ i ][ j ].real, ctable[ i ][ j ].imag
			);
		}
		printf( "\n\t\t}%s\n", ( i==NUM_STAGES-1 ) ? "" : "," );
	}
	printf(
		"\t};\n\n"
		"endpackage: twdls_pkg\n\n"
	);
	//*/

	// Copy final output 
	const int OUT_OFFSET = NUM_STAGES * N;
	for ( int i = 0; i < N; ++i )
	{
		out[ i ] = x[ OUT_OFFSET + i ];
	}
}

// Main function
int main( int argc, char *argv[] )
{
	int N_ = 0;
	if ( argc < 2 )
	{
		fprintf( stderr, "Usage: fft <N>\n" );
		return 2;
	}
	N_ = atoi( argv[1] );

	if ( N_ > 4096 )
	{
		fprintf( stderr, "Number of inputs too large: %d\n", N_ );
		exit( 2 );
	}
	int N = 1;
	N_ >>= 1;
	while ( N_ > 0 )
	{
		N <<= 1;
		N_ >>= 1;
	}
	printf( "Adjusted number of inputs: %d\n", N );

	Complex X[N];
	Complex Y[N];

	// Seed the random number generator
	srand(time(NULL));

	// Randomization scale factor (adjust to control noise level)
	const double NOISE_SCALE = 0.05; 

	for ( int i = 0; i < N; ++i ) 
	{
		double noise_real = ( ( rand() % 1000 ) / 1000.0 - 0.5 ) * NOISE_SCALE;
		double noise_imag = ( ( rand() % 1000 ) / 1000.0 - 0.5 ) * NOISE_SCALE;

		X[i].real = QUANTIZE_F(cos(2 * PI * i / N) + noise_real);  // Cosine wave + noise
		X[i].imag = QUANTIZE_F(sin(2 * PI * i / N) + noise_imag);  // Sine wave + noise
	}

	FILE *infile_re  = fopen( "../sim/infile_re.txt", "w" );
	FILE *infile_im  = fopen( "../sim/infile_im.txt", "w" );
	FILE *outfile_re = fopen( "../sim/outfile_re.txt", "w" );
	FILE *outfile_im = fopen( "../sim/outfile_im.txt", "w" );
	if (
		!infile_re || !infile_im || !outfile_re || !outfile_im
	)
	{
		goto badio;
	}

	// write input to file
	for ( int i = 0; i < N; ++i ) 
	{
		/////////////
		/*
		fprintf(infile_re, "%.4f\n", DEQUANTIZE_F(X[i].real));
		fprintf(infile_im, "%.4f\n", DEQUANTIZE_F(X[i].imag));
		*/
		fprintf( infile_re, "%08x\n", X[i].real );
		fprintf( infile_im, "%08x\n", X[i].imag );
	 }
	fclose( infile_re );
	fclose( infile_im );

	// run FFT
	fft( X, Y, N );

	// write output to file
	for ( int i = 0; i < N; ++i ) 
	{
		///////////////////
		/*
		fprintf(outfile_re, "%.4f\n", DEQUANTIZE_F(Y[i].real));
		fprintf(outfile_im, "%.4f\n", DEQUANTIZE_F(Y[i].imag));
		*/
		fprintf( outfile_re, "%08x\n", Y[i].real );
		fprintf( outfile_im, "%08x\n", Y[i].imag );
	}
	fclose( outfile_re );
	fclose( outfile_im );

	return 0;

	badio:
		if ( !infile_re ) { fprintf( stderr, "Unable to open real input file\n" ); }
		else fclose( infile_re );

		if ( !infile_im ) { fprintf( stderr, "Unable to open imag input file\n" ); }
		else fclose( infile_im );

		if ( !outfile_re ) { fprintf( stderr, "Unable to open real output file\n" ); }
		else fclose( outfile_re );

		if ( !outfile_im ) { fprintf( stderr, "Unable to open imag output file\n" ); }
		else fclose( outfile_im );

		return 2;
}

