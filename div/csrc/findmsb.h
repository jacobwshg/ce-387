
#ifndef FINDMSB_H_
#define FINDMSB_H_

#include <cstdio>
#include <cstdint>

namespace FindMSB
{
	static inline unsigned int
	find_msb_bsrch( const std::int64_t n_ );

	static inline unsigned int
	find_msb_linear( const std::int64_t n_ );

	static inline unsigned int 
	find_msb( const std::int64_t n_ );

}


static inline unsigned int 
FindMSB::
find_msb( const std::int64_t n_ )
{
	#ifdef FIND_MSB_BSRCH
	return find_msb_bsrch( n_ );
	#else
	return find_msb_linear( n_ );
	#endif
}

static inline unsigned int
FindMSB::
find_msb_bsrch( const std::int64_t n_ )
{
	std::int64_t n { n_ };

	unsigned int msb_pos { 0 };
	#pragma unroll
	for (
		int shamt = ( sizeof( n_ ) * 8 / 2 );
		shamt > 0; shamt /= 2
	)
	{
		const std::int64_t halfmsk { ( 1L << shamt ) - 1 };
		const std::int64_t
			top_half    { ( n >> shamt ) & halfmsk },
			bottom_half { n & halfmsk };
		//std::printf( "\t\tbsrch tophalf 0x%lx, bottomhalf 0x%lx\n", top_half, bottom_half );

		if ( 0 != top_half )
		{
			msb_pos += shamt;
			n = top_half;
		}
		else
		{
			n = bottom_half;
		}
	}
	return msb_pos;
}

static inline unsigned int
FindMSB::
find_msb_linear( const std::int64_t n_ )
{
	#pragma unroll
	for ( int shamt = 63; shamt > 0; --shamt )
	{
		std::int64_t n_sh { n_ >> shamt };

		if ( n_sh & 0b1 )
		{
			return static_cast< unsigned int >( shamt );
		}
	}
	return 0;
}

#endif

