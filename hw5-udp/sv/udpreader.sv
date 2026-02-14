
module udpreader
(
	input logic clk, 
	input logic rst

	input logic [ 7:0 ] in_dout,
	input logic in_rd_sof,

	output logic in_re,
	output logic out_we
)

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

	typedef enum logic [ 5:0 ]
	{
		S_WAIT_SOF,
		S_ETH_DST, S_ETH_SRC, S_ETH_PROT,
		S_IP_VER, S_IP_HDR, S_IP_TYPE, S_IP_LEN, S_IP_ID,
		S_IP_FLAG, S_IP_TIME, S_IP_PROT, S_IP_SUM, S_IP_SRC, S_IP_DST,
		S_UDP_DST, S_UDP_SRC, S_UDP_LEN, S_UDP_SUM,
		S_FINALIZE_SUM
	} state_t;

	typedef enum logic { FALSE, TRUE } bool_t;

	state_t state, state_c;

	logic [ 31:0 ] sum, sum_c;

	/* flag for whether current state participates in sum calculation */
	bool_t sum_state, sum_state_c;

	logic [ 31:0 ] i, i_c;

	/* buffer lower byte of every pair of bytes */
	logic [ 7:0 ] byte0, byte0_c;

	always_ff @ ( posedge clk, posedge rst )
	begin
		if ( rst )
		begin
			state <= S_WAIT_SOF;
			sum <= 32'h0;
			sum_state <= FALSE;
			i <= 32'h0;
			byte0 <= 8'h0;
		end
		else
		begin
			state <= state_c;
			sum <= sum_c;
			sum_state <= sum_state_c;
			i <= i_c;
			byte0 <= byte0_c;
		end
	end

	always_comb
	begin
		state_c = state;
		sum_c = sum;
		sum_state_c = sum_state;
		i_c = i;
		byte0_c = byte0;

		in_re = 1'b0;
		out_we = 1'b0;

		case ( state )
			S_WAIT_SOF:
			begin
				if ( ~in_empty )
				begin
					if ( in_rd_sof )
					begin
						state_c = S_ETH_DST;
					end
					else
					begin
						in_re = 1'b1;
					end
				end
			end

			S_ETH_DST:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					i_c = i + 1'h1;
					if ( i_c == ETH_DST_ADDR_BYTES )
					begin
						state_c = S_ETH_SRC;
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
					if ( i_c == ETH_PROTOCOL_BYTES )
					begin
						i_c = 1'h0;
						state_c = 
							( IP_PROTOCOL_DEF == 16'( { 8'(byte0), 8'(in_dout) } ) )
							? S_IP_VER
							: S_WAIT_SOF;
					end
					else
					begin
						byte0_c = in_dout;
					end
				end
			end

			S_IP_VER:
			begin
				if ( ~in_empty )
				begin
					in_re = 1'b1;
					//byte0_c = in_dout;
					state_c = 
						( IP_VERSION_DEF == (in_dout >> 4) )
						? S_IP_HDR
						: S_WAIT_SOF;
					i_c = 1'h0;
				end
			end

			S_IP_HDR:
			begin
				state_c = S_IP_TYPE;
				i_c = 1'h0;
			end

			

		endcase

		/*
		if ( sum_state & i[0] )
		begin
			sum_c = sum + 16'( { 8'(byte0), 8'(in_dout) } );
		end
		*/

	end

endmodule

