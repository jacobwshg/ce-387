
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

static inline int
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

static inline void mul_cmplx(
	const int a,
	const int b,
	const int c,
	const int d,
	int *out_real,
	int *out_imag
)
{
	if ( ( !out_real ) || !out_imag )
	{
		return;
	}
	int p1 = ( a + b ) * d;
	int p2 = ( c + d ) * a;
	int p3 = ( b - a ) * c;

	p1 = DEQUANTIZE_I( p1 );
	p2 = DEQUANTIZE_I( p2 );
	p3 = DEQUANTIZE_I( p3 );

	*out_real = p2 - p1;
	*out_imag = p2 + p3;

}

// Bit reversal
void bit_reversal( const Complex *in, Complex *out, const unsigned int N ) 
{
	// Precompute bit-reversed indices for the range [0, N-1]
	int bit_reversal_table[ N ];
	printf( "bit-reversal table\n" );
	for ( int i = 0; i < N; ++i )
	{
		int j = 0;
		int i_cpy = i;
		for ( int bit = 0; bit < log2( N ); ++bit )
		{
			j <<= 1;
			j |= i_cpy & 1;
			i_cpy >>= 1;
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
	const unsigned int stage, const unsigned int sampl_idx,
	const Complex *in1,  const Complex *in2,
	Complex *out1, Complex *out2,
	const Complex *w
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
		w_real = w->real,     w_imag = w->imag,
		in1_real = in1->real, in1_imag = in1->imag,
		in2_real = in2->real, in2_imag = in2->imag;

	int p1 = w_real * in2_real;
	int p2 = w_imag * in2_imag;
	int p3 = w_real * in2_imag;
	int p4 = w_imag * in2_real;

	p1 = DEQUANTIZE_I( p1 );
	p2 = DEQUANTIZE_I( p2 );
	p3 = DEQUANTIZE_I( p3 );
	p4 = DEQUANTIZE_I( p4 );

	Complex v =
	{
		p1 - p2,
		p3 + p4
	};

	/*
	Complex v = {};
	mul_cmplx(
		in2_real, in2_imag, w_real, w_imag,
		&v.real, &v.imag
	);
	*/
	
	out1->real = in1_real + v.real;
	out1->imag = in1_imag + v.imag;
	out2->real = in1_real - v.real;
	out2->imag = in1_imag - v.imag;

}

static inline void print_twiddles( const Complex **ctable, const unsigned int N );

static inline void fft_cleanup(
	Complex **x, Complex **ctable,
	const unsigned int stages
);

// FFT function with feed-forward memory allocation
void fft( Complex *in, Complex *out, const unsigned int N ) 
{
	assert( N > 0 );
	assert( !( N & ( N-1 ) ) ); // sanity check: power of 2

	const unsigned int HALF_N = N >> 1;

	const unsigned int STAGES = ( unsigned int ) log2( N );
	// N inputs + N per-stage outputs
	const unsigned int TOTAL_SIZE = N * ( STAGES + 1 );

	// inputs and intermediate/final results
	Complex *x[ 1 + STAGES ];
	memset( x, 0x0, sizeof x );
	// twiddle factors
	Complex *ctable[ STAGES ];
	memset( ctable, 0x0, sizeof ctable );
	for ( unsigned int i=0; i<=STAGES; ++i )
	{
		x[ i ] = ( Complex * ) malloc( N * sizeof( Complex ) );
		if ( !x[ i ] )
		{
			fprintf( stderr, "Failed to allocate results cache\n" );
			fft_cleanup( x, ctable, STAGES );
		}
	}

	unsigned int stg_twdl_cnt = 1;
	for ( unsigned int stage=0; stage<STAGES; ++stage )
	{
		if ( stage>0 ) { stg_twdl_cnt *= 2; }
		ctable[ stage ] = ( Complex * ) malloc( stg_twdl_cnt * sizeof( Complex ) );
		if ( !ctable[ stage ] )
		{
			fprintf( stderr, "Failed to allocate twiddle cache" );
			fft_cleanup( x, ctable, STAGES );
		}
	}

	// Bit-reversed stage 0 inputs 
	bit_reversal( in, x[ 0 ], N );

	printf( "Index bit-reversed inputs:\n" );
	for ( unsigned int i = 0; i < N; ++i )
	{
		printf(
			"\t%08x+%08xj\n", 
			 x[ 0 ][ i ].real, x[ 0 ][ i ].imag
		);
	}

	// OK

	/*
	 * step: distance between two samples in the same position within 
	 * their respective groups of overlapping butterflies.
	 * Example: in stage 2, every 4 butterflies overlap. the in1[0] of
	 * one group is 8 samples away from the in1[0] of the next group.
	 * Thus step = 8.
	 */
	unsigned int step = 1;
	// FFT computation across stages
	for ( unsigned int stage = 0; stage < STAGES; ++stage ) 
	{
		printf( "\n" );

	 	// step begins as 2 for stage 0, and doubles per stage
		step *= 2;
		/*
		 * In each stage, half step is the same as the number of twiddle factors
		 * needed for this stage
		 */
		const unsigned int half_step = step / 2;

		const float angle_step = -PI / half_step;
		for ( unsigned int j = 0; j < half_step; ++j )
		{
			// Calculate the twiddle factor
			const float angle = j * angle_step;
			Complex w = { QUANTIZE_F( cos( angle ) ), QUANTIZE_F( sin( angle ) ) };
			ctable[ stage ][ j ] = w;
		}

		/* step ( = butterfly group ) base idx */
		for ( unsigned int i = 0; i < N; i += step )
		{
			/* step-internal idx of a single complex value */
			for ( unsigned int j = 0; j < half_step; ++j ) 
			{
				// Calculate read and write addresses for the current value
				const unsigned int in1_idx  = i + j;
				const unsigned int in2_idx  = in1_idx + half_step;
				const unsigned int out1_idx = i + j;
				const unsigned int out2_idx = out1_idx + half_step;

				const Complex *w = &ctable[ stage ][ j ];

				// Perform the FFT stage operation
				butterfly(
					stage, i+j,
					&x[ stage ][ in1_idx ],    &x[ stage ][ in2_idx ],
					&x[ stage+1 ][ out1_idx ], &x[ stage+1 ][ out2_idx ],
					w
				);

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

		
		printf( "Stage %d outputs:\n", stage );
		for ( unsigned int i=0; i<N; ++i )
		{
			printf( "\t%08x+%08xj\n", x[ stage+1 ][ i ].real, x[ stage+1 ][ i ].imag );
		}

	}

	print_twiddles( ( const Complex ** ) ctable, N );

	// Copy final outputs
	for ( unsigned int i = 0; i < N; ++i )
	{
		out[ i ] = x[ STAGES ][ i ];
	}

	fft_cleanup( x, ctable, STAGES );

}

static inline void fft_cleanup(
	Complex **x, Complex **ctable,
	const unsigned int stages
)
{
	if ( x[ 0 ] )
	{
		free( x[ 0 ] );
		x[ 0 ] = NULL;
	}
	for ( unsigned int stage=0; stage<stages; ++stage )
	{
		if ( x[ stage+1 ] )    { free( x[ stage+1 ] ); x[ stage+1 ] = NULL; }
		if ( ctable[ stage ] ) { free( ctable[ stage ] ); ctable[ stage ] = NULL; }
	}

}

static inline void print_twiddles(
	const Complex **ctable,
	const unsigned int N
)
{

	char pathbuf[ 64 ];
	snprintf( pathbuf, sizeof pathbuf, "twiddles_pkg_%d.sv", N );
	FILE *f = fopen( pathbuf, "w" );
	if ( !f )
	{
		fprintf( stderr, "Failed to open twiddle file for writing\n" );
		return;
	}
	

	const unsigned int stages = ( unsigned int ) log2( N );
	fprintf( f, "package twiddles_pkg;\n\n" );
	fprintf( f, "\tlocalparam int N = %d;\n", N );
	fprintf( f, "\tlocalparam int STAGES = $clog2( N );\n\n" );
	fprintf(
		f,
		"\tlocalparam logic signed [ 0:( N/2-1 ) ] [ 0:1 ] [ 31:0 ]\n"
		"\t\tTWIDDLES [ 0:STAGES-1 ] = \n"
		"\t'{\n"
	);
	unsigned int half_step = 1;
	for ( unsigned int stage = 0; stage < stages; ++stage )
	{
		fprintf( f,"\t\t'{" );
		if ( stage > 0 ) { half_step *= 2; }
		for ( unsigned int id = 0; id < half_step; ++id ) 
		{
			const char *sep = ( id==0 ? "" : "," );
			const char *rowtab = ( id%4==0 ? "\n\t\t\t" : "" );
			fprintf(
				f,
				"%s%s%d:'{32'sh%08x,32'sh%08x}",
				sep, rowtab, id, ctable[ stage ][ id ].real, ctable[ stage ][ id ].imag
			);
		}
		fprintf( f,",\n\t\t\tdefault:'{32'sh00000000,32'sh00000000}" );
		fprintf( f,"\n\t\t}%s\n", ( stage==stages-1 ) ? "" : "," );
	}
	fprintf(
		f,
		"\t};\n\n"
		"endpackage: twiddles_pkg\n\n"
	);

	fclose( f );

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
	unsigned int N = 1;
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

	int myrand = 42;

	for ( unsigned int i = 0; i < N; ++i ) 
	{
		//double noise_real = ( ( rand() % 1000 ) / 1000.0 - 0.5 ) * NOISE_SCALE;
		//double noise_imag = ( ( rand() % 1000 ) / 1000.0 - 0.5 ) * NOISE_SCALE;
		double noise_real = ( ( myrand % 1000 ) / 1000.0 - 0.5 ) * NOISE_SCALE;
		double noise_imag = ( ( myrand % 1000 ) / 1000.0 - 0.5 ) * NOISE_SCALE;

		X[i].real = QUANTIZE_F(cos(2 * PI * i / N) + noise_real);  // Cosine wave + noise
		X[i].imag = QUANTIZE_F(sin(2 * PI * i / N) + noise_imag);  // Sine wave + noise
	}

	FILE *infile_real  = fopen( "in_real.txt", "w" );
	FILE *infile_imag  = fopen( "in_imag.txt", "w" );
	FILE *outfile_real = fopen( "cmp_real.txt", "w" );
	FILE *outfile_imag = fopen( "cmp_imag.txt", "w" );
	if (
		!infile_real || !infile_imag || !outfile_real || !outfile_imag
	)
	{
		goto badio;
	}

	// write input to file
	for ( unsigned int i = 0; i < N; ++i ) 
	{
		/////////////
		/*
		fprintf(infile_real, "%.4f\n", DEQUANTIZE_F(X[i].real));
		fprintf(infile_imag, "%.4f\n", DEQUANTIZE_F(X[i].imag));
		*/
		fprintf( infile_real, "%08x\n", X[i].real );
		fprintf( infile_imag, "%08x\n", X[i].imag );
	 }
	fclose( infile_real );
	fclose( infile_imag );

	// run FFT
	fft( X, Y, N );

	// write output to file
	for ( unsigned int i = 0; i < N; ++i ) 
	{
		///////////////////
		/*
		fprintf(outfile_real, "%.4f\n", DEQUANTIZE_F(Y[i].real));
		fprintf(outfile_imag, "%.4f\n", DEQUANTIZE_F(Y[i].imag));
		*/
		fprintf( outfile_real, "%08x\n", Y[i].real );
		fprintf( outfile_imag, "%08x\n", Y[i].imag );
	}
	fclose( outfile_real );
	fclose( outfile_imag );

	return 0;

	badio:
		if ( !infile_real ) { fprintf( stderr, "Unable to open real input file\n" ); }
		else fclose( infile_real );

		if ( !infile_imag ) { fprintf( stderr, "Unable to open imag input file\n" ); }
		else fclose( infile_imag );

		if ( !outfile_real ) { fprintf( stderr, "Unable to open real output file\n" ); }
		else fclose( outfile_real );

		if ( !outfile_imag ) { fprintf( stderr, "Unable to open imag output file\n" ); }
		else fclose( outfile_imag );

		return 2;
}

