
#include <array>
#include <cstdio>
#include <cstdint>
#include <cstdlib>

static constexpr unsigned int FRAC_WIDTH { 14 };
static constexpr std::uint32_t FRAC_MASK { ( 1u << FRAC_WIDTH ) - 1 };

template < typename Num >
struct Complex
{
	Num real {};
	Num imag {};

	Complex( void ) = default;

	Complex( const Num &real_, const Num &imag_ ):
		real { real_ }, imag { imag_ }
	{}
};

static inline std::int32_t
dequantize( const std::int32_t x )
{
	std::int32_t res { x >> FRAC_WIDTH };

	if (
		( x < 0 ) && 
		0 != ( static_cast< std::uint32_t >( x ) & FRAC_MASK )
	)
	{
		res += 1;
	}

	return res;
}

static inline void
butterfly(
	const std::int32_t in1_real,
	const std::int32_t in1_imag,
	const std::int32_t in2_real,
	const std::int32_t in2_imag,
	const std::int32_t   w_real,
	const std::int32_t   w_imag,

	std::int32_t &out1_real,
	std::int32_t &out1_imag,
	std::int32_t &out2_real,
	std::int32_t &out2_imag
)
{
	std::int32_t
		p1 { in2_real * w_real },
		p2 { in2_real * w_imag },
		p3 { in2_imag * w_real },
		p4 { in2_imag * w_imag };

	std::printf(
		"p1 = in2 real * w real = %x\n"
		"p2 = in2 real * w imag = %x\n"
		"p3 = in2 imag * w real = %x\n"
		"p4 = in2 imag * w imag = %x\n\n",
		p1, p2, p3, p4
	);	

	p1 = dequantize( p1 );
	p2 = dequantize( p2 );
	p3 = dequantize( p3 );
	p4 = dequantize( p4 );

	std::printf(
		"p1 dq = %x\n"
		"p2 dq = %x\n"
		"p3 dq = %x\n"
		"p4 dq = %x\n\n",
		p1, p2, p3, p4
	);

	const std::int32_t
		v_real { p1 - p4 },
		v_imag { p2 + p3 };

	std::printf(
		"v = %x + %xj\n\n",
		v_real, v_imag
	);

	out1_real = in1_real + v_real;
	out1_imag = in1_imag + v_imag;
	out2_real = in1_real - v_real;
	out2_imag = in1_imag - v_imag;

}


static inline void
butterfly_k(
	const std::int32_t in1_real,
	const std::int32_t in1_imag,
	const std::int32_t in2_real,
	const std::int32_t in2_imag,
	const std::int32_t   w_real,
	const std::int32_t   w_imag,

	std::int32_t &out1_real,
	std::int32_t &out1_imag,
	std::int32_t &out2_real,
	std::int32_t &out2_imag
)
{
	std::int32_t
		p1 { (   w_real +   w_imag ) * in2_imag },
		p2 { ( in2_real + in2_imag ) *   w_real },
		p3 { (   w_imag -   w_real ) * in2_real };

	std::printf(
		"p1 = (   w_real +   w_imag ) * in2_imag = %x\n"
		"p2 = ( in2_real + in2_imag ) *   w_real = %x\n"
		"p3 = (   w_imag -   w_real ) * in2_real = %x\n",
		p1, p2, p3
	);	

	p1 = dequantize( p1 );
	p2 = dequantize( p2 );
	p3 = dequantize( p3 );

	std::printf(
		"p1 dq = %x\n"
		"p2 dq = %x\n"
		"p3 dq = %x\n\n",
		p1, p2, p3
	);

	const std::int32_t
		v_real { p2 - p1 },
		v_imag { p2 + p3 };

	std::printf(
		"v = %x + %xj\n\n",
		v_real, v_imag
	);

	out1_real = in1_real + v_real;
	out1_imag = in1_imag + v_imag;
	out2_real = in1_real - v_real;
	out2_imag = in1_imag - v_imag;

}

int
main( int argc, char *argv[] )
{
	if ( argc != 7 )
	{
		std::fprintf(
			stderr,
			"usage: butterfly <in1_real> <in1_imag> "
			"<in2_real> <in2_imag> <w_real> <w_imag>\n"
		);
		return 2;
	}

	std::printf( "FRAC WIDTH: %u\n\n", FRAC_WIDTH );

	Complex< std::int32_t > in1 {}, in2 {}, w {};

	std::sscanf( argv[ 1 ], "%x", &in1.real );
	std::sscanf( argv[ 2 ], "%x", &in1.imag );
	std::sscanf( argv[ 3 ], "%x", &in2.real );
	std::sscanf( argv[ 4 ], "%x", &in2.imag );
	std::sscanf( argv[ 5 ], "%x",   &w.real );
	std::sscanf( argv[ 6 ], "%x",   &w.imag );

	Complex< std::int32_t > out1 {}, out2 {};

	std::printf(
		"in1: %x + %xj\n"
		"in2: %x + %xj\n"
		"  w: %x + %xj\n\n",
		in1.real, in1.imag, in2.real, in2.imag, w.real, w.imag
	);

	std::printf( "4-multiplier:\n" );

	butterfly(
		in1.real, in1.imag, in2.real, in2.imag, w.real, w.imag,
		out1.real, out1.imag, out2.real, out2.imag
	);

	std::printf(
		"out1: %x + %xj\n"
		"out2: %x + %xj\n\n",
		out1.real, out1.imag, out2.real, out2.imag
	);

	std::printf( "3-multiplier:\n" );

	butterfly_k(
		in1.real, in1.imag, in2.real, in2.imag, w.real, w.imag,
		out1.real, out1.imag, out2.real, out2.imag
	);

	std::printf(
		"out1: %x + %xj\n"
		"out2: %x + %xj\n\n",
		out1.real, out1.imag, out2.real, out2.imag
	);

}

