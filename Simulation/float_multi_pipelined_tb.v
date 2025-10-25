`timescale 1ns/1ps

module tb_fp16_mul;

  // clock/reset
  reg clk = 0;
  always #5 clk = ~clk;        // 100 MHz
  reg rstn;

  // DUT I/O
  reg  [15:0] num1, num2;
  reg         valid_in;
  wire        valid_out;
  wire [15:0] result;
  wire        overflow, zero, NaN, precisionLost;

  // === Instantiate DUTs ===
  // Pipelined version 
  float_multi_pipelined_v2 dut (
    .clk(clk),
    .rstn(rstn),
    .valid_in(valid_in),
    .num1(num1),
    .num2(num2),
    .valid_out(valid_out),
    .result(result),
    .overflow(overflow),
    .zero(zero),
    .NaN(NaN),
    .precisionLost(precisionLost)
  );

  // === Utilities ===

  // pack helper: {sign, exp[4:0], fra[9:0]} -> 16-bit half
  function [15:0] pack;
    input sign;
    input [4:0] exp;
    input [9:0] fra;
    begin
      pack = {sign, exp[4:0], fra[9:0]};
    end
  endfunction

  // scoreboard
  integer total = 0;
  integer pass  = 0;

  task check_pipe; // push one input beat and wait for valid_out
    input [15:0] exp_result;
    begin
      // one-cycle valid pulse
      @(negedge clk);
      valid_in <= 1'b1;
      @(negedge clk);
      valid_in <= 1'b0;

      // wait for valid_out
      wait (valid_out === 1'b1);
      @(posedge clk); // sample on clock edge with valid_out

      total = total + 1;
      if (result === exp_result) begin
        pass = pass + 1;
        $display("[%0t] PASS: exp=0x%04h got=0x%04h", $time, exp_result, result);
      end else begin
        $display("[%0t] FAIL: exp=0x%04h got=0x%04h  (num1=0x%04h num2=0x%04h) flags: O=%b Z=%b N=%b P=%b",
                 $time, exp_result, result, num1, num2, overflow, zero, NaN, precisionLost);
      end

      // hold a couple cycles for readability
      repeat (2) @(negedge clk);
    end
  endtask

  // === Stimulus ===
  reg [15:0] exp_result;

  initial begin
    // init
    rstn     = 1'b0;
    valid_in = 1'b0;
    num1     = 16'h0000;
    num2     = 16'h0000;

    // reset for a few cycles
    repeat (5) @(negedge clk);
    rstn = 1'b1;
    repeat (2) @(negedge clk);

    // ---------- Test cases (from your list) ----------

    // 1) Buggy case
    num1 = 16'h4689; num2 = 16'h0025; exp_result = 16'h00f2;
    check_pipe(exp_result);

    // 2)
    num1 = 16'h4489; num2 = 16'h001d; exp_result = 16'h0084;
    check_pipe(exp_result);

    // 3)
    num1 = 16'h1234; num2 = 16'h9876; exp_result = 16'h801b;
    check_pipe(exp_result);

    // 4)
    num1 = 16'h8216; num2 = 16'h20be; exp_result = 16'h8004;
    check_pipe(exp_result);

    // 5) Multiplication with precision lost
    num1 = pack(1'b0, 5'd21, 10'b00_1010_0101);
    num2 = pack(1'b0, 5'd4,  10'b00_1100_1100);
    exp_result = 16'h2992;
    check_pipe(exp_result);

    // 6) Multiplication without precision lost
    num1 = pack(1'b0, 5'd4,  10'b10_1000_00);  // 10'b10100000
    num2 = pack(1'b0, 5'd4,  10'b01_1000_00);  // 10'b01100000
    exp_result = 16'h0005; // same as 16'h5
    check_pipe(exp_result);

    // 7) Multiplication without precision lost different signs
    num1 = pack(1'b1, 5'd16, 10'b10_1100_00);  // 10'b10110000
    num2 = pack(1'b0, 5'd7,  10'b11_0000_00);  // 10'b11000000
    exp_result = 16'ha191;
    check_pipe(exp_result);

    // 8) Multiplication with Zero
    num1 = pack(1'b0, 5'd16, 10'b10_1100_00);  // 10'b10110000
    num2 = pack(1'b0, 5'd0,  10'b00_0000_00);
    exp_result = 16'h0000;
    check_pipe(exp_result);

    // 9) Multiplication with Infinite
    num1 = pack(1'b0, 5'd16, 10'b10_1100_00);
    num2 = pack(1'b0, 5'h1F, 10'b00_0000_00);
    exp_result = 16'h7c00;
    check_pipe(exp_result);

    // 10) Overflow
    num1 = pack(1'b0, 5'd16, 10'b10_1100_00);
    num2 = pack(1'b0, 5'd20, 10'b01_0110_00);  // 10'b01011000
    exp_result = 16'h5517;
    check_pipe(exp_result);

    // 11) 1 subnormal × 1 normal
    num1 = pack(1'b0, 5'd0,  10'b11_1000_00);  // 10'b11100000
    num2 = pack(1'b0, 5'd20, 10'b01_1000_00);  // 10'b01100000
    exp_result = 16'h0fa8;
    check_pipe(exp_result);

    // 12) 2 subnormal
    num1 = pack(1'b0, 5'd0,  10'b10_1110_00);  // 10'b10111000
    num2 = pack(1'b0, 5'd0,  10'b10_0000_00);  // 10'b10000000
    exp_result = 16'h0000;
    check_pipe(exp_result);

    // ---------- Summary ----------
    $display("=====================================");
    $display("Total: %0d, Pass: %0d, Fail: %0d", total, pass, total-pass);
    $display("=====================================");
    #50;
    $finish;
  end

endmodule
