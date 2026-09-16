
#ifndef DIV_H_
#define DIV_H_

#include "findmsb.h"

#include <assert.h>
#include <cstdint>

namespace Div
{

	static inline void 
	div_stage(
		const std::int64_t n_i, const std::int64_t d_i,
		const std::int64_t q_i,
		const bool sgn_i,

		std::int64_t &n_o, std::int64_t &d_o,
		std::int64_t &q_o, std::int64_t &r_o,
		bool &sgn_o
	);

}


static inline void
Div::div_stage(
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

	const unsigned int
		n_msb_pos { FindMSB::find_msb( n_i ) },
		d_msb_pos { FindMSB::find_msb( d_i ) };

	std::printf( "\n\t\tn: %ld, d: %ld", n_i, d_i );
	std::printf( "\n\t\tn msb pos: %u, d msb pos: %u", n_msb_pos, d_msb_pos );

	if ( n_i < d_i )
	{
		n_o = n_i;
		d_o = d_i;
		q_o = q_i;
		r_o = n_i;
		sgn_o = sgn_i;
		return;
	}

	std::int64_t n_tmp {};
	std::int64_t d_tmp {};

	const unsigned int d_shamt { n_msb_pos - d_msb_pos };
	d_tmp = ( d_i << d_shamt );

	std::printf( "\n\t\td shamt: %u, shifted d: %ld", d_shamt, d_tmp );

	n_tmp = n_i - d_tmp;

	if ( n_tmp >= 0 )
	{
		n_o = n_tmp;
		d_o = d_i;
		q_o = q_i | ( 1 << d_shamt );
		r_o = n_tmp;
		sgn_o = sgn_i;
		return;
	}

	d_tmp >>= 1;
	n_tmp = n_i - d_tmp;
	/*
	 * Suppose that n_i < ( d_i<<shamt ), with both sides having the same MSB pos.
	 * Then n_i > ( d_i<<( shamt-1 ) ), because its MSB pos is higher.
	 */
	n_o = n_tmp;
	d_o = d_i;
	q_o = q_i | ( ( 1<<d_shamt ) >> 1 );
	r_o = n_tmp;
	sgn_o = sgn_i;
	return;

}

#endif

