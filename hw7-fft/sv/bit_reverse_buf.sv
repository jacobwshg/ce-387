
module bit_reverse_buf #(
	parameter int N = 1024,
	parameter int DWIDTH = 32
)
(
	input logic clk,
	input logic rst,

	input  logic in_empty,
	input  logic signed [ DWIDTH-1:0 ] din_real,
	input  logic signed [ DWIDTH-1:0 ] din_imag,
	output logic in_rd_en,

	input  logic out_full,
	output logic signed [ DWIDTH-1:0 ] dout_real,
	output logic signed [ DWIDTH-1:0 ] dout_imag,
	output logic out_wr_en
);

	/* width of sample ID in frame */
	localparam int SAMPLE_ID_WIDTH = $clog2( N );

	/* combinational bit reversal */
	function automatic logic [ SAMPLE_ID_WIDTH-1:0 ]
	BITREVERSE( input logic [ SAMPLE_ID_WIDTH-1:0 ] id_in );
		logic [ SAMPLE_ID_WIDTH-1:0 ] id_out = 'h0;
		for ( int i=0; i<SAMPLE_ID_WIDTH; ++i )
		begin
			id_out[ SAMPLE_ID_WIDTH-1-i ] = id_in[ i ];
		end
		return id_out;
	endfunction

	logic [ SAMPLE_ID_WIDTH-1:0 ] buf_wr_addr, buf_rd_addr;
	logic [ 0:1 ] buf_banks_wr_en;
	logic [ 2*DWIDTH-1:0 ] buf_din;
	logic buf_rd_en;
	logic [ 0:1 ] [ 2*DWIDTH-1:0 ] buf_banks_dout;
	generate
		genvar i;
		for ( i=0; i<2; ++i )
		begin
			bram #(
				.DWIDTH( 2*DWIDTH ),
				.ADDR_WIDTH( SAMPLE_ID_WIDTH )
			) bitrev_buf_bank (
				.clk( clk ),
				.wr_addr( buf_wr_addr ),
				.rd_addr( buf_rd_addr ),
				.wr_en( buf_banks_wr_en[ i ] ),
				.rd_en( buf_rd_en ),
				.din ( buf_din ),
				.dout( buf_banks_dout[ i ] )
			);
		end
	endgenerate

	typedef enum logic [ 1:0 ]
	{
		S_FRAME_RUN, S_FRAME_DONE
	} frame_state_t;

	logic both_framedone;

	frame_state_t wr_frame_state_next, wr_frame_state_r;
	logic wr_pipe_en;

	/*
	 * wr_new_sample_id_next: to be clocked into wr_sample_id_r on next edge, 
	 * matches sample presented by input in next cycle 
	 */
	logic [ SAMPLE_ID_WIDTH:0 ] wr_sample_id_next;

	/* wr_new_sample_id_r: matches sample i, currently presented by input */
	logic [ SAMPLE_ID_WIDTH:0 ] wr_sample_id_r;
	/*
	 * wr_addr: bit-reversed, generated from wr_sample_id_r, matches sample
	 * i, to be clocked into wr_addr_r on the same edge as sample i clocks
	 * into din_r
	 */
	logic [ SAMPLE_ID_WIDTH-1:0 ] wr_addr;
	logic wr_frame_parity;
	logic wr_banksel; 
	logic wr_valid;

	/*
	 * Clocked signals that represent/match sample i-1, to be clocked into
 	 * buffer 
 	 */
	logic [ 2*DWIDTH-1:0 ] din_r;
	logic [ SAMPLE_ID_WIDTH-1:0 ] wr_addr_r;
	logic wr_frame_parity_r;
	logic wr_banksel_r;
	logic wr_valid_r;

	always_ff @ ( posedge clk )
	begin: wr_reg

		if ( rst ) wr_frame_state_r <= S_FRAME_RUN;
		else       wr_frame_state_r <= wr_frame_state_next;

		if ( rst )
		begin
			wr_sample_id_r <= 'h0;
			wr_banksel_r = 1'h0;
			wr_frame_parity_r <= 1'b0;
		end
		else if ( wr_pipe_en )
		begin
			wr_sample_id_r <= wr_sample_id_next;
			wr_banksel_r <= wr_banksel;
			wr_frame_parity_r <= wr_frame_parity;
		end

		if ( wr_pipe_en )
		begin
			/*
			 * clock input sample to break comb path between input decode
			 * and bitrev buffer encode
			 */
			din_r <= { $unsigned( din_real ), $unsigned( din_imag ) };
			wr_valid_r <= wr_valid;
			wr_addr_r <= wr_addr;
		end

	end: wr_reg

	always_comb
	begin: wr_comb

		wr_pipe_en = ( S_FRAME_RUN===wr_frame_state_r );
		in_rd_en = wr_pipe_en && !in_empty;

		wr_addr         = BITREVERSE( wr_sample_id_r[ SAMPLE_ID_WIDTH-1:0 ] );
		wr_frame_parity = wr_sample_id_r[ SAMPLE_ID_WIDTH ];
		wr_sample_id_next = wr_sample_id_r + 1'( in_rd_en );
		/*
		 * If the sample presented by input is frame-initial, update its
		 * matching bank select
		 */
		wr_banksel = (
			( wr_frame_parity !== wr_frame_parity_r ) ? 
			( !wr_banksel_r ) :
			wr_banksel_r
		);
		wr_valid = in_rd_en;

		buf_din = din_r;
		buf_wr_addr = wr_addr_r;
		buf_banks_wr_en[ 0:1 ] = { 1'b0, 1'b0 };
		if ( wr_valid_r && wr_pipe_en )
		begin
			buf_banks_wr_en[ wr_banksel_r ] = 1'b1;
		end

		wr_frame_state_next = wr_frame_state_r;
		case ( wr_frame_state_r )
			S_FRAME_RUN:
			begin
				if ( wr_frame_parity !== wr_frame_parity_r )
				begin
					wr_frame_state_next = S_FRAME_DONE;
				end
			end
			S_FRAME_DONE:
			begin
				if ( both_framedone )
				begin
					wr_frame_state_next = S_FRAME_RUN;
				end
			end	
		endcase

	end: wr_comb

	frame_state_t rd_frame_state_next, rd_frame_state_r;
	logic rd_pipe_en;

	/* Match sample i+1 ( idx in written bank, not order of input arrival ) */
	//logic [ SAMPLE_ID_WIDTH:0 ] rd_addr_next;

	/* Match sample i */
	logic [ SAMPLE_ID_WIDTH:0 ] rd_addr_r;
	logic rd_frame_parity;
	logic rd_banksel;
	//logic rd_valid;

	/* Match sample i-1 */
	logic rd_frame_parity_r;
	logic rd_banksel_r;
	logic rd_valid_r;

	/* Match sample i-2 */
	logic [ 0:1 ] [ 2*DWIDTH-1:0 ] banks_dout_r;
	logic rd_banksel_dly_r;
	logic rd_valid_dly_r;

	assign both_framedone = (
		( S_FRAME_DONE===wr_frame_state_r ) &&
		( S_FRAME_DONE===rd_frame_state_r )
	);

	always_ff @( posedge clk )
	begin: rd_reg

		if ( rst ) rd_frame_state_r <= S_FRAME_DONE;
		else       rd_frame_state_r <= rd_frame_state_next;

		if ( rst )
		begin
			rd_addr_r <= 'h0;

			rd_frame_parity_r <= 1'b0;
			rd_banksel_r <= 1'h0;
			rd_valid_r <= 1'b0;

		end
		else if ( rd_pipe_en )
		begin
			rd_addr_r <= rd_addr_r + 1'h1;

			rd_frame_parity_r <= rd_frame_parity;
			rd_banksel_r <= rd_banksel;
			rd_valid_r <= 1'b1;
		end

		if ( rd_pipe_en )
		begin
			banks_dout_r[ 0:1 ] <= buf_banks_dout[ 0:1 ];
			rd_banksel_dly_r <= rd_banksel_r;
		end

		if ( rst )
		begin
			rd_valid_dly_r <= 1'b0;
		end
		else
		case ( rd_frame_state_r )
			S_FRAME_RUN:
			begin
				rd_valid_dly_r <= rd_valid_r;
			end
			S_FRAME_DONE:
			// read at most once
			if ( rd_valid_dly_r && out_wr_en )
			begin
				rd_valid_dly_r <= 1'b0;
			end
		endcase

	end: rd_reg

	always_comb
	begin: rd_comb

		rd_pipe_en = ( S_FRAME_RUN===rd_frame_state_r ) && !out_full;

		rd_frame_parity = rd_addr_r[ SAMPLE_ID_WIDTH ];
		rd_banksel = (
			( rd_frame_parity !== rd_frame_parity_r ) ?
			( !rd_banksel_r ) :
			rd_banksel_r
		);
		buf_rd_addr = rd_addr_r[ SAMPLE_ID_WIDTH-1:0 ];
		buf_rd_en = rd_pipe_en;

		/*
		 * mux both bank outputs right before output to avoid adding to addr
		 * decode comb path; note this extends output path
		 */
		dout_real = $signed( banks_dout_r[ rd_banksel_dly_r ][ 2*DWIDTH-1:DWIDTH ] );
		dout_imag = $signed( banks_dout_r[ rd_banksel_dly_r ][   DWIDTH-1:0      ] );
		// allow write ( flush ) after entering FRAME_DONE state as well
		out_wr_en = rd_valid_dly_r && !out_full;

		rd_frame_state_next = rd_frame_state_r;
		case ( rd_frame_state_r )
			S_FRAME_RUN:
			begin
				/*
				 * if rd_frame_parity_r matches a frame-final sample,
				 * this sample is being decoded over the current cycle and
				 * will clock into banks_dout_r ( along with garbage in the
				 * alternate bank ) on the upcoming edge; thus state should
				 * change to DONE on the upcoming edge too
				 *
				 */
				if ( rd_frame_parity !== rd_frame_parity_r )
				begin
					rd_frame_state_next = S_FRAME_DONE;
				end
			end
			S_FRAME_DONE:
			begin
				if ( both_framedone )
				begin
					rd_frame_state_next = S_FRAME_RUN;
				end
			end
		endcase

	end: rd_comb

endmodule: bit_reverse_buf

