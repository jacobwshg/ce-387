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

  state_t state;
  state_t nx_state;

  typedef logic[15:0] u16_t;
  u16_t counter, r0, r1;
  u16_t nx_counter, nx_r0, nx_r1;

  /* state regs */
  always_ff @ (posedge clk, posedge reset)
  begin
    if ( reset == 1'b1 ) 
    begin
      /* Implement reset signals */
      state <= S_IDLE;
      counter <= 16'd0;
      r0 <= 16'd0;
      r1 <= 16'd1;
    end 
    else 
    begin
      /* Implement clocked signals */
      state <= nx_state;
      counter <= nx_counter;
      r0 <= nx_r0;
      r1 <= nx_r1; 
    end
  end

  /* next state logic */
  always_comb
  begin
    nx_state = S_IDLE;
    nx_counter = 16'd0;
    nx_r0 = 16'd0;
    nx_r1 = 16'd1;
    unique case ( state )
      S_IDLE:
      begin
        nx_state = start? S_RUN: S_IDLE;
        nx_counter = counter;
        nx_r0 = r0;
        nx_r1 = r1;
      end
      S_RUN:
      begin
        if ( done )
        begin
          nx_state = S_IDLE;
          nx_counter = counter;
          nx_r0 = r0;
          nx_r1 = r1;
        end
        else
        begin
          nx_state = S_RUN;
          nx_counter = counter + 1;
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
    dout = r1;
    done = (counter >= din);
  end

endmodule

