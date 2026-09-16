
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

	std::int64_t n { n_ }, d { d_ }, q { 0 }, r { 0 };

	if ( d == 1 )
	{
		q = n;
		std::printf( "\t%ld / %ld = %ld ... %ld\n", n, d, q, r );
		return;
	}
	else if ( d == 0 )
	{
		r = n;
		std::printf( "\t%ld / %ld = %ld ... %ld\n", n, d, q, r );
		return;
	}

	const bool sgn_n { static_cast< bool >( ( n_>>63 ) & 0b1 ) };
	const bool sgn_d { static_cast< bool >( ( d_>>63 ) & 0b1 ) };
	if ( sgn_n ) { n = -n; }
	if ( sgn_d ) { d = -d; }
	bool sgn_q { static_cast< bool >( sgn_n ^ sgn_d ) };

	if ( n < d )
	{
		r = n;
		if ( sgn_q ) { r = -r; }
		std::printf( "\t%ld / %ld = %ld ... %ld\n", n, d, q, r );
		return;
	}

	const unsigned int n_msbpos	{ FindMSB::find_msb( n ) };
	const unsigned int d_msbpos	{ FindMSB::find_msb( d ) };

	for (
		int d_shamt = static_cast< int >( n_msbpos ) - d_msbpos;
		d_shamt >= 0; --d_shamt
	)
	{
		std::printf( "\t%ld / %ld ", n, d );
		Div::div_stage(
			d_shamt, d_msbpos, n, d, q, sgn_q,
			n, d, q, r, sgn_q
		);
		std::printf( "\t%ld ... %ld\n", q, r );
	}

	if ( sgn_q )
	{
		q = -q;
		r = r - d_;
	}
	std::printf( "%ld / %ld = %ld ... %ld\n", n_, d_, q, r );
	return;

}

static inline void
div_test( const std::int64_t n_, const std::int64_t d_ )
{
	std::printf( "Div test: %ld / %ld\n", n_, d_ );

	std::int64_t n { n_ }, d { d_ }, q { 0 }, r { 0 };

	const int status { Div::div( n, d, q, r ) };

}

int main( const int argc, const char *argv[] )
{
	//test_findmsb( 128 );

	if ( argc < 3 || argc > 4  )
	{
		std::fprintf( stderr, "Usage: div_stage_test <n> <d> [<iters>]\n" );
		return 2;
	}

	if ( argc == 3 )
	{
		std::int64_t n { std::atol( argv[ 1 ] ) };
		std::int64_t d { std::atol( argv[ 2 ] ) };
		div_test( n, d );
	}
	else if ( argc == 4 )
	{
		std::int64_t n { std::atol( argv[ 1 ] ) };
		std::int64_t d { std::atol( argv[ 2 ] ) };
		unsigned int iters { static_cast< unsigned int >( std::atoi( argv[ 3 ] ) ) };
		std::printf( "n: %ld, d: %ld, iters: %u\n", n, d, iters );
		div_stage_test( n, d, iters );
	}
}



