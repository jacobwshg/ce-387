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
  state_t nx_state;

  u16_t itercnt, r0, r1;
  u16_t nx_itercnt, nx_r0, nx_r1;

  logic done_c;
  u16_t dout_c;

  localparam FIB0 = 'd0;
  localparam FIB1 = 'd1;

  /* next state logic */
  always_comb
  begin
    nx_state = state;
    nx_itercnt = itercnt;
    nx_r0 = r0;
    nx_r1 = r1;
    case ( state )
      S_IDLE:
      begin
        nx_state = start? S_RUN: S_IDLE;
        //nx_itercnt = itercnt;
        //nx_r0 = r0;
        //nx_r1 = r1;
      end
      S_RUN:
      begin
        if ( done )
        begin
          nx_state = S_IDLE;
          //nx_itercnt = itercnt;
          //nx_r0 = r0;
          //nx_r1 = r1;
        end
        else
        begin
          //nx_state = S_RUN;
          nx_itercnt = itercnt + 1;
          nx_r0 = r1;
          nx_r1 = r0 + r1;
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
    done_c = (itercnt >= din);
    /* Design: keep DOUT to 0 and update to final result once.
     * 
     * Use DONE_C for latest done status. Since tb immediately samples DOUT 
     * when DONE is set, we want DOUT to be set at the exact same clock edge.
     * If we used DONE to compute DOUT_C, DOUT won't receive the update before
     * tb samples it.
     *
     * */
    dout_c = (done_c && (din > 0))? r1: FIB0;
  end

  /* state regs */
  always_ff @ (posedge clk, posedge reset)
  begin
    if ( reset ) 
    begin
      /* Implement reset signals */
      state <= S_IDLE;
      itercnt <= 'b1;
      r0 <= FIB0;
      r1 <= FIB1;
    end 
    else 
    begin
      /* Implement clocked signals */
      state <= nx_state;
      itercnt <= nx_itercnt;
      r0 <= nx_r0;
      r1 <= nx_r1; 
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

