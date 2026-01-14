`timescale 1ns/1ns

module fibonacci_tb;

  logic clk; 
  logic reset = 1'b0;
  logic [15:0] din = 16'h0;
  logic start = 1'b0;
  logic [15:0] dout;
  logic done;

  // instantiate your design
  fibonacci fib(clk, reset, din, start, dout, done);

  // Clock Generator
  always
  begin
    clk = 1'b0;
    #5;
    clk = 1'b1;
    #5;
  end

  /* software registers ( I also used to drive DIN ) */
  logic [16] i, r0, r1, nxt_r1;

  logic [64] starttime;

  initial
  begin
    #0;
    reset = 'b0;

    /* iteratively compute and test Fibonacci numbers within 16 bits */
    for (
      i = 0, r0 = 0, r1 = 1; 
      i < 25; 
      ++i
    )
    begin

      #10;
      reset = 'b1;
      #10;
      reset = 'b0;

      #10;
      din = i; // change
      start = 1'b1;
      starttime = $time;

      #10;
      start = 1'b0;

      // Wait until calculation is done	
      wait (done == 1'b1);

      // Display Result
      $display("-----------------------------------------");
      $display("Input: %d", din);
      $display("Software fib(%0d) = %0d", i, r0);
      if (dout === r0)
        $display("CORRECT RESULT: %0d, GOOD JOB!", dout);
      else
        $display("INCORRECT RESULT: %0d, SHOULD BE: %0d", dout, r0);
      $display("Time: %0d cycles", ($time - starttime)/10 );
      starttime = 'dz;

      /* hold output for wave inspection */
      #100;

      nxt_r1 = r0 + r1;
      r0 = r1;
      r1 = nxt_r1;
    end

    // Done
    $stop;
  end
endmodule

