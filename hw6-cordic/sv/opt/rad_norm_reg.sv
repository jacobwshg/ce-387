
import globals_pkg::PI;
import globals_pkg::TWO_PI;
import globals_pkg::HALF_PI;
import globals_pkg::INV_K;

module rad_norm
(
	input logic clk,
	input logic rst,

	input  logic signed [ 31:0 ] din_rad,
	input  logic in_valid,
	output logic in_ready,

	input  logic out_ready,
	output logic signed [ 15:0 ] dout_sin,
	output logic signed [ 15:0 ] dout_cos,
	output logic out_valid
);

	enum logic [ 3:0 ]
	{
		S_INIT, S_DSPTCH,
		S_SUB_TWOPI, S_ADD_TWOPI, S_ADDSUB_PI,
		S_OUT
	} fsm_state_r, fsm_state_next;

	logic signed [ 31:0 ] rad, rad_r;
	logic signed [ 15:0 ]
		x, x_r, 
		y, y_r;

	logic signed [ 31:0 ]
		rad_p_2pi_r,
		rad_m_2pi_r,
		rad_p_halfpi_r,
		rad_m_halfpi_r;

	always_ff @( posedge clk )
	begin
		if ( rst )
		begin
			fsm_state_r <= S_INIT;
			x_r <= INV_K;
			y_r <= 'sh0;
			rad_r <= 'sh0;
		end
		else
		begin
			fsm_state_r <= fsm_state_next;
			x_r <= x;
			y_r <= y;
			rad_r <= rad;
		end

		if ( S_DSPTCH === fsm_state_r )
		begin
			rad_p_2pi_r <= rad_r + TWO_PI;
			rad_m_2pi_r <= rad_r - TWO_PI;
			rad_p_halfpi_r <= rad_r + HALF_PI;
			rad_m_halfpi_r <= rad_r - HALF_PI;
		end

	end

	always_comb
	begin
		fsm_state_next = fsm_state_r;

		rad = rad_r;
		in_ready = 1'b0;

		x = x_r;
		y = y_r;

		dout_sin = y_r;
		dout_cos = x_r;
		out_valid = 1'b0;

		case ( fsm_state_r )
			S_INIT:
			begin
				in_ready = 1'b1;
				if ( in_valid )
				begin
					fsm_state_next = S_DSPTCH;
					rad = din_rad;
				end
			end

			/*
			 * Interim state, allows predictive add/sub regs time to clock
			 * results based on rad_r clocked in S_INIT
			 */
			S_DSPTCH:
			begin
				if ( rad_r > PI )
				begin
					fsm_state_next = S_SUB_TWOPI;
				end
				else if ( rad_r < -PI )
				begin
					fsm_state_next = S_ADD_TWOPI;
				end
				else
				begin
					fsm_state_next = S_ADDSUB_PI;
				end
			end

			S_SUB_TWOPI:
			begin
				rad = rad_m_2pi_r;
				if ( rad_m_2pi_r <= PI )
				begin
					/*
					 * At the end of the current cycle, the current rad - 2pi
					 * will be clocked as the new rad
					 * At the end of the upcoming S_DSPTCH cycle, the new 
					 * predictive results based on the current rad - 2pi will be
					 * clocked
					 */
					fsm_state_next = S_DSPTCH;
				end
			end

			S_ADD_TWOPI:
			begin
				rad = rad_p_2pi_r;
				if ( rad_p_2pi_r >= -PI )
				begin
					fsm_state_next = S_DSPTCH;
				end
			end

			S_ADDSUB_PI:
			begin
				if ( rad_r > HALF_PI )
				begin
					rad = rad_m_halfpi_r;
					x = -x_r;
					y = -y_r;
				end
				else if ( rad_r < -HALF_PI );
				begin
					rad = rad_p_halfpi_r;
					x = -x_r;
					y = -y_r;
				end
				fsm_state_next = S_OUT;
			end

			S_OUT:
			begin
				out_valid = 1'b1;
				if ( out_ready )
				begin
					fsm_state_next = S_INIT;
					x = INV_K;
					y = 'sh0;
					rad = 'sh0; 
				end
			end

			default:
			begin
				fsm_state_next = S_INIT;
				x = INV_K;
				y = 'sh0;
				rad = 'sh0;
			end

		endcase
	end

endmodule: rad_norm

