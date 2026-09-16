
#ifndef DIV_H_
#define DIV_H_

#include "findmsb.h"

#include <assert.h>
#include <cstdint>

namespace Div
{

	static inline void 
	div_stage(
		const unsigned int d_shamt,
		const unsigned int d_msbpos,
		const std::int64_t n_i, const std::int64_t d_i,
		const std::int64_t q_i,
		const bool sgn_i,

		std::int64_t &n_o, std::int64_t &d_o,
		std::int64_t &q_o, std::int64_t &r_o,
		bool &sgn_o
	);

	static inline int
	div(
		const std::int64_t n_i, const std::int64_t d_i,
		std::int64_t &q_o, std::int64_t &r_o
	);

}


static inline void
Div::div_stage(
	const unsigned int d_shamt,
	const unsigned int d_msbpos,
	const std::int64_t n_i, const std::int64_t d_i,
	const std::int64_t q_i,
	const bool sgn_i,

	std::int64_t &n_o, std::int64_t &d_o,
	std::int64_t &q_o, std::int64_t &r_o,
	bool &sgn_o
)
{
	// assume operand sign preprocessing
	assert( n_i >= 0 && d_i >= 0 );

	n_o = n_i;
	d_o = d_i;
	q_o = q_i;
	r_o = n_i;
	sgn_o = sgn_i;

	if ( d_msbpos + d_shamt >= sizeof( n_i )*8 )
	{
		/* d overflow after left shift */
		return;
	}

	std::int64_t n_tmp {};
	std::int64_t d_tmp {};

	d_tmp = ( d_i << d_shamt );
	if ( n_i < d_tmp )
	{
		return;
	}
	std::int64_t delta_q { std::int64_t{ 1 } << d_shamt };
	//std::printf( "\n\t\td shamt: %u, shifted d: %ld", d_shamt, d_tmp );
	n_tmp = n_i - d_tmp;

	n_o = n_tmp;
	q_o = q_i | delta_q;
	//std::printf( "\n\t\t new n>=0, q_o: %ld", q_o );
	r_o = n_tmp;
	return;

}

static inline int
Div::div(
	const std::int64_t n_i, const std::int64_t d_i,
	std::int64_t &q_o, std::int64_t &r_o
)
{
	if ( d_i == 1 )
	{
		q_o = n_i;
		return 0; 
	}
	if ( d_i == 0 )
	{
		// Div by zero
		r_o = n_i;
		return -1;
	}

	q_o = 0;
	r_o = 0;

	const bool sgn_n { static_cast< bool >( ( n_i>>63 ) & 0b1 ) };
	const bool sgn_d { static_cast< bool >( ( d_i>>63 ) & 0b1 ) };
	const bool sgn_q { static_cast< bool >( sgn_n ^ sgn_d ) };
	// unsigned
	std::int64_t n_u { n_i };
	std::int64_t d_u { d_i };
	if ( sgn_n ) { n_u = -n_u; }
	if ( sgn_d ) { d_u = -d_u; }

	std::int64_t n_tmp { n_u };
	std::int64_t d_tmp {};

	const unsigned int d_msb_pos = FindMSB::find_msb( d_u );

	for (
		int d_shamt=( ( sizeof n_u )*8-1-d_msb_pos );
		d_shamt >= 0; --d_shamt
	)
	{
		d_tmp = d_u << d_shamt;
		std::printf(
			"\tn: %ld, d: %ld, d shamt: %u, shifted d: %ld\n",
			n_tmp, d_u, d_shamt, d_tmp
		);
		if ( n_tmp < d_tmp )
		{
			continue;
		}
		if ( d_tmp < 0 )
		{
			continue;
		}
		n_tmp -= d_tmp;
		q_o |= ( std::int64_t{ 1 } << d_shamt );
	}

	r_o = n_tmp;
	if ( sgn_q )
	{
		q_o = -q_o;
		r_o = r_o - d_i;
	}

	std::printf( "%ld / %ld = %ld ... %ld\n", n_i, d_i, q_o, r_o );

	return 0;
}



#endif

