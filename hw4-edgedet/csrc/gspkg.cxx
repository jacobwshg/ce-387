
#include <cstdio>
#include <cstdint>
#include <string_view>

int main( const int argc, const char *argv[] )
{
	static constexpr std::string_view GSPKG_PATH { "grayscale_pkg.sv" };

	FILE *f { std::fopen( GSPKG_PATH.data(), "w" ) };
	if ( !f )
	{
		std::fprintf( stderr, "Failed to open write file %s\n", GSPKG_PATH.data() );
		return 2;
	}

	std::fprintf( f, "\npackage grayscale_pkg;\n\n" );

	std::fprintf(
		f,
		"\tlocalparam logic [ 0:255*3-1 ] [ 7:0 ]\n"
		"\tGRAYSCALE_TBL = \n"
		"\t'{"
	);

	static constexpr unsigned int MAXSUM { 3*255 };

	unsigned int col_id { 0 };
	static constexpr unsigned int MAX_COL_ID = 5;

	for ( std::uint16_t sum { 0 }; sum <= MAXSUM; ++sum )
	{
		if ( 0 == col_id )
		{
			std::fprintf( f, "\n\t\t" );
		}
		std::fprintf( f, "%3d:8'd%03d, ", sum, sum/3 );

		++col_id;
		if ( col_id > MAX_COL_ID ) { col_id = 0; }
	}

	std::fprintf(
		f,
		"\n\t\tdefault: 'd0\n"
		"\t};\n"
		"\n"
	);

	std::fprintf( f, "endpackage: grayscale_pkg\n\n" );

	std::fclose( f );

}

