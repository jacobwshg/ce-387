
module udpreader
(
	input logic clock, 
	input logic reset,

	input logic in_empty,
	input logic [ 7:0 ] in_dout,
	//input logic in_rd_sof,
	input logic out_full,

	output logic in_re,
	output logic out_we,
	output logic [ 7:0 ] out_din,

	output logic done,
	output logic sum_true
);

	localparam PCAP_HEADER_BYTES      = 24;
	localparam PCAP_DATA_HEADER_BYTES = 16;

	localparam ETH_DST_ADDR_BYTES     = 6;
	localparam ETH_SRC_ADDR_BYTES     = 6;
	localparam ETH_PROTOCOL_BYTES     = 2;

	localparam IP_VERSION_BYTES       = 1;
	localparam IP_HEADER_BYTES        = 1;
	localparam IP_TYPE_BYTES          = 1;
	localparam IP_LENGTH_BYTES        = 2;
	localparam IP_ID_BYTES            = 2;
	localparam IP_FLAG_BYTES          = 2;
	localparam IP_TIME_BYTES          = 1;
	localparam IP_PROTOCOL_BYTES      = 1;
	localparam IP_CHECKSUM_BYTES      = 2;
	localparam IP_SRC_ADDR_BYTES      = 4;
	localparam IP_DST_ADDR_BYTES      = 4;

	localparam UDP_DST_PORT_BYTES     = 2;
	localparam UDP_SRC_PORT_BYTES     = 2;
	localparam UDP_LENGTH_BYTES       = 2;
	localparam UDP_CHECKSUM_BYTES     = 2;

	localparam IP_PROTOCOL_DEF        = 'h0800;
	localparam IP_VERSION_DEF         = 'h4;
	localparam IP_HEADER_LENGTH_DEF   = 'h5;
	localparam IP_TYPE_DEF            = 'h0;
	localparam IP_FLAGS_DEF           = 'h4;

	localparam TIME_TO_LIVE           = 'he;
	localparam UDP_PROTOCOL_DEF       = 'h11;

	typedef enum logic [ 7:0 ]
	{
		S_PCAP_HDR, S_PCAP_DATA_HDR,
		//S_WAIT_SOF,
		S_ETH_DST, S_ETH_SRC, S_ETH_PROT,
		S_IP_VER, S_IP_HDR, S_IP_TYPE, S_IP_LEN, S_IP_ID,
		S_IP_FLAG, S_IP_TIME, S_IP_PROT, S_IP_SUM, S_IP_SRC, S_IP_DST,
		S_UDP_DST, S_UDP_SRC, S_UDP_LEN, S_UDP_SUM, S_UDP_DATA,
		S_VERIFY_SUM
	} state_t;

	typedef enum logic { FALSE = 1'b0, TRUE = 1'b1 } bool_t;

	state_t state, state_c;

	/* flag for whether current state participates in sum calculation */
	bool_t sum_state, sum_state_c;

	logic [ 31:0 ]
		sum, sum_c;
	logic [ 15:0 ]
		ref_sum, ref_sum_c;

	logic [ 31:0 ] i, i_c;

	/* buffer lower byte of every pair of bytes */
	logic [ 7:0 ] bytebuf, bytebuf_c;

	logic [ 31:0 ] udp_data_len, udp_data_len_c;

	logic done_c, sum_true_c;

	always_ff @ ( posedge clock, posedge reset )
	begin
		if ( reset )
		begin
			//state <= S_WAIT_SOF;
			state <= S_PCAP_HDR;
			sum <= 32'h0;
			ref_sum <= 16'h0;
			sum_state <= FALSE;
			i <= 32'h0;
			bytebuf <= 8'h0;
			udp_data_len <= 32'd0;
			done <= 1'b0;
			sum_true <= 1'b0;
		end
		else
		begin
			state <= state_c;
			//$display( "@%0t, state %0d", $time, state_c );
			sum <= sum_c;
			ref_sum <= ref_sum_c;
			sum_state <= sum_state_c;
			i <= i_c;
			bytebuf <= bytebuf_c;
			udp_data_len <= udp_data_len_c;
			done <= done_c;
			sum_true <= sum_true_c;
		end
	end

	always_comb
	begin
		state_c = state;
		sum_c = sum;
		ref_sum_c = ref_sum;
		sum_state_c = sum_state;
		i_c = i;
		bytebuf_c = bytebuf;
		udp_data_len_c = udp_data_len;

		in_re = 1'b0;
		out_we = 1'b0;
		out_din = 8'h0;

		done_c = done;
		sum_true_c = sum_true;

		if ( sum_state & ~in_empty )
		begin
			bytebuf_c = in_dout;
			if ( i[0] )
			begin
				sum_c = sum + 16'( { 8'( bytebuf ), 8'( in_dout ) } );
			end
		end

		case ( state )
			S_PCAP_HDR:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( PCAP_HEADER_BYTES == i_c )
					begin
						state_c = S_PCAP_DATA_HDR;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_PCAP_DATA_HDR:
			begin
				sum_c = 32'h0;
				ref_sum_c = 16'h0;
				done_c = 1'b0;
				sum_true_c = 1'b0;
				udp_data_len_c = 32'h0;

				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( PCAP_DATA_HEADER_BYTES == i_c )
					begin
						state_c = S_ETH_DST;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			/*
			S_WAIT_SOF:
			begin
				sum_c = 32'h0;
				ref_sum_c = 16'h0;
				i_c = 1'h0;
				if ( ~in_empty )
				begin
					if ( in_rd_sof )
					begin
						state_c = S_ETH_DST;
						sum_state_c = FALSE;
					end
					else
					begin
						in_re = 1'b1;
					end
				end
			end
			*/

			S_ETH_DST:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( i_c == ETH_DST_ADDR_BYTES )
					begin
						state_c = S_ETH_SRC;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_ETH_SRC:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( i_c == ETH_SRC_ADDR_BYTES )
					begin
						state_c = S_ETH_PROT;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_ETH_PROT:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					bytebuf_c = in_dout;
					if (
						( 1'h1 == i ) 
						& ( IP_PROTOCOL_DEF != 16'( { 8'(bytebuf), 8'(in_dout) } ) )
					)
					begin
						//state_c = S_WAIT_SOF;
						state_c = S_VERIFY_SUM;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end

					if ( ETH_PROTOCOL_BYTES == i_c )
					begin
						state_c = S_IP_VER;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_VER:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if (
						( 1'h0 == i ) 
						& ( IP_VERSION_DEF != (in_dout >> 4) )
					)
					begin
						//state_c = S_WAIT_SOF;
						state_c = S_VERIFY_SUM;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end

					if ( IP_VERSION_BYTES == i_c )
					begin
						state_c = S_IP_HDR;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_HDR:
			begin
				state_c = S_IP_TYPE;
				sum_state_c = FALSE;
				i_c = 1'h0;
			end

			S_IP_TYPE:		
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( IP_TYPE_BYTES == i_c )
					begin
						state_c = S_IP_LEN;
						sum_state_c = TRUE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_LEN:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;

					if ( i[0] )
					begin
						sum_c = sum_c - 'd20;
					end

					if ( IP_LENGTH_BYTES == i_c )
					begin
						state_c = S_IP_ID;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_ID:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( IP_ID_BYTES == i_c )
					begin
						state_c = S_IP_FLAG;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_FLAG:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( IP_FLAG_BYTES == i_c )
					begin
						state_c = S_IP_TIME;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end


			S_IP_TIME:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( IP_TIME_BYTES == i_c )
					begin
						state_c = S_IP_PROT;
						/* Even though IP protocol technically participates in
						 * checksum, it doesn't follow the byte-pair pattern */
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_PROT:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;

					if ( 1'h1 == i_c )
					begin
						sum_c = sum + 8'( in_dout );
						if ( UDP_PROTOCOL_DEF != in_dout )
						begin
							//state_c = S_WAIT_SOF;
							state_c = S_VERIFY_SUM;
							sum_state_c = FALSE;
							i_c = 1'h0;
						end
					end

					if ( IP_PROTOCOL_BYTES == i_c )
					begin
						state_c = S_IP_SUM;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_SUM:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( IP_CHECKSUM_BYTES == i_c )
					begin
						state_c = S_IP_SRC;
						sum_state_c = TRUE;
						i_c = 1'h0;
					end
				end
			end

			S_IP_SRC:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;

					if ( IP_SRC_ADDR_BYTES == i_c )
					begin
						state_c = S_IP_DST;
						sum_state_c = TRUE;
						i_c = 1'h0;
					end
				end
			end


			S_IP_DST:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;

					if ( IP_DST_ADDR_BYTES == i_c )
					begin
						state_c = S_UDP_DST;
						sum_state_c = TRUE;
						i_c = 1'h0;
					end
				end
			end

			S_UDP_DST:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;

					if ( UDP_DST_PORT_BYTES == i_c )
					begin
						state_c = S_UDP_SRC;
						sum_state_c = TRUE;
						i_c = 1'h0;
					end
				end
			end

			S_UDP_SRC:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;

					if ( UDP_SRC_PORT_BYTES == i_c )
					begin
						state_c = S_UDP_LEN;
						sum_state_c = TRUE;
						i_c = 1'h0;
					end
				end
			end

			S_UDP_LEN:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;

					if ( 2'h2 == i_c )
					begin
						/* Compute full UDP packet length */
						udp_data_len_c = 32'( { 8'( bytebuf ), 8'( in_dout ) } );
					end
					if ( UDP_LENGTH_BYTES == i_c )
					begin
						state_c = S_UDP_SUM;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_UDP_SUM:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					bytebuf_c = in_dout;
					if ( 1'h1 == i )
					begin
						/* Extract reference checksum in packet */
						ref_sum_c = 16'( { 8'( bytebuf ), 8'( in_dout ) } );
						//$display( "REF SUM: %h", ref_sum_c );
					end
					if ( UDP_CHECKSUM_BYTES == i_c )
					begin

						//$display( "checksum without udp data: %h", sum_c );

						/* Compute final UDP payload length */
						udp_data_len_c = 
							udp_data_len
							- (
								UDP_CHECKSUM_BYTES 
								+ UDP_LENGTH_BYTES 
								+ UDP_DST_PORT_BYTES 
								+ UDP_SRC_PORT_BYTES
							);
						//$display( "udp data length: %0d", udp_data_len_c );
						state_c = S_UDP_DATA;
						sum_state_c = TRUE;
						i_c = 1'h0;
					end
				end
			end

			S_UDP_DATA:
			begin
				if ( ~in_empty )
				begin
					if ( ~out_full )
					begin
						out_din = in_dout;
						out_we = 1'b1;
						in_re = 1'b1;
						i_c = i + 1'h1;

						//$write( "%c", in_dout );

					end

					if ( i[0] )
					begin
						//$display( "%h", sum_c );
					end

					if ( udp_data_len == i_c )
					begin
						//$display( "%h", ref_sum );
						/* If data length is odd, then for the final byte pair, 
 						 * concatenate the fresh byte (instead of buffered)
 						 * with a zero byte */
						if ( udp_data_len[0] )
						begin
							sum_c = sum + 16'( { 8'( in_dout ), 8'h0 } );
						end
						state_c = S_VERIFY_SUM;
						sum_state_c = FALSE;
						i_c = 1'h0;
					end
				end
			end

			S_VERIFY_SUM:
			begin
				/* While sum is longer than 16 bits, remain in state and add halves */
				if ( | sum[ 31:16 ] )
				begin
					sum_c = sum[ 15:0 ] + sum[ 31:16 ];
					//$display( "SUM: %h", sum_c );
				end
				else
				begin
					//$display( "\n\n" );
					sum_c = ~sum;
					//$display( "%h, %h", ref_sum, sum_c[15:0] );
					sum_true_c = ( sum_c[15:0] == ref_sum );
					done_c = 1'b1;

					state_c = S_PCAP_DATA_HDR;
					sum_state_c = FALSE;
					i_c = 1'h0;
				end
			end

			default:
			begin
				//state_c = S_WAIT_SOF;
				state_c = S_PCAP_HDR;
				sum_c = 32'hx;
				ref_sum_c = 16'hx;
				sum_state_c = FALSE;
				i_c = 32'hx;
				bytebuf_c = 8'hx;
				udp_data_len_c = 32'hx;

				in_re = 1'b0;
				out_we = 1'b0;
				out_din = 8'hx;

				done_c = 1'b0;
				sum_true_c = 1'b0;
			end

		endcase

	end

endmodule

