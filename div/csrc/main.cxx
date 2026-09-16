
#include "findmsb.h"
#include "div.h"

#include <cstdio>
#include <cstdint>
#include <cstdlib>

static inline void
test_findmsb( const unsigned int test_cnt )
{
	std::printf( "Find MSB test\n" );
	for ( unsigned int testid = 0; testid < test_cnt; ++testid )
	{
		const std::int64_t n { static_cast< std::int64_t >( testid ) };
		const unsigned int msb_pos_bsrch  { FindMSB::find_msb_bsrch( n ) };
		const unsigned int msb_pos_linear { FindMSB::find_msb_linear( n ) };

		std::printf(
			"\tn: %ld ( 0x%lx ), bsrch: %u, linear: %u\n",
			n, n, msb_pos_bsrch, msb_pos_linear
		);
	}
}

static inline void
div_stage_test( const std::int64_t n_, const std::int64_t d_, const unsigned int iters )
{
	std::printf( "Div stage test: %ld / %ld\n", n_, d_ );

	std::int64_t n { n_ }, d { d_ }, q {}, r {};
	bool sgn {};

	const bool sgn_n { static_cast< bool >( ( n_>>63 ) & 0b1 ) };
	const bool sgn_d { static_cast< bool >( ( d_>>63 ) & 0b1 ) };
	sgn = sgn_n ^ sgn_d;
	if ( sgn_n ) { n = -n; }
	if ( sgn_d ) { d = -d; }

	for ( unsigned int i { 0 }; i < iters; ++i )
	{
		std::printf( "\t%ld / %ld = ", n, d );
		Div::div_stage(
			n, d, q, sgn,
			n, d, q, r, sgn
		);
		std::printf( "\t%ld ... %ld\n", q, r );
	}


}

int main( const int argc, const char *argv[] )
{
	//test_findmsb( 128 );

	if ( argc < 4 )
	{
		std::fprintf( stderr, "Usage: div_stage_test <n> <d> <iters>\n" );
		return 2;
	}

	if ( argc >= 4 )
	{
		std::int64_t n { std::atol( argv[ 1 ] ) };
		std::int64_t d { std::atol( argv[ 2 ] ) };
		unsigned int iters { static_cast< unsigned int >( std::atoi( argv[ 3 ] ) ) };
		std::printf( "n: %ld, d: %ld, iters: %u\n", n, d, iters );
		div_stage_test( n, d, iters );
	}
}



