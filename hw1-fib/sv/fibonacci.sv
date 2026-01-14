module fibonacci(
  input logic clk, 
  input logic reset,
  input logic [15:0] din,
  input logic start,
  output logic [15:0] dout,
  output logic done
);

  typedef enum logic [1:0] 
  {
    S_IDLE, 
    S_RUN
  }
  state_t;

  typedef logic [15:0] u16_t;

  state_t state;
  state_t state_c;

  u16_t itercnt, r0, r1;
  u16_t itercnt_c, r0_c, r1_c;

  logic done_c;
  u16_t dout_c;

  localparam FIB0 = 'd0;
  localparam FIB1 = 'd1;

  /* next state logic */
  always_comb
  begin
    state_c = state;
    itercnt_c = itercnt;
    r0_c = r0;
    r1_c = r1;

    case ( state )
      S_IDLE:
      begin
        if ( start )
          state_c = S_RUN;
          itercnt_c = din;
      end
      S_RUN:
      begin
        /*
         * For transition back to S_IDLE, use latest DONE_C; don't wait for 
         * DONE to reflect DONE_C in the next cycle. In that case, although TB 
         * will instantaneously sample DOUT = R0 = fib(DIN) as desired, R0 
         * will update for one more cycle (down the `else` branch) and 
         * settle to fib(DIN+1), which will also propagate to DOUT.
         */
        if ( done_c )
          state_c = S_IDLE;
        else
        begin
          itercnt_c = itercnt - 1;
          r0_c = r1;
          r1_c = r0 + r1;
        end
      end
      default:
      begin
      end
    endcase
  end

  /* output logic */
  always_comb
  begin
    done_c = (itercnt == 0);
    /* Design: keep DOUT_C (and thus DOUT) to 0 and update to final result once.
     * 
     * Use DONE_C for latest done status. Since TB immediately samples DOUT 
     * when DONE is set, we want DOUT to be set by DOUT_C at the exact same 
     * clock edge when DONE is set by DONE_C.  If we used DONE to compute 
     * DOUT_C, DOUT wouldn't receive the update before TB samples it.
     *
     * */
    dout_c = done_c? r0: 'b0;
  end

  /* state regs */
  always_ff @ (posedge clk, posedge reset)
  begin
    if ( reset ) 
    begin
      /* Implement reset signals */
      state <= S_IDLE;
      itercnt <= 'd0;
      r0 <= FIB0;
      r1 <= FIB1;
    end 
    else 
    begin
      /* Implement clocked signals */
      state <= state_c;
      itercnt <= itercnt_c;
      r0 <= r0_c;
      r1 <= r1_c; 
    end
  end

  /* output regs */
  always_ff @ (posedge clk, posedge reset)
  begin
    if (reset)
    begin
        dout <= 'b0;
        done <= 'b0;
    end
    else
    begin
        dout <= dout_c;
        done <= done_c;
    end
  end

endmodule

