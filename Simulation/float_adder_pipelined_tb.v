`timescale 1ns / 1ps
//`include "Sources/float_adder_pipelined.v"

module float_adder_pipelined_tb();
  // Clock and reset signals
  reg clk, rstn;
  
  // Test signals
  reg [15:0] num1, num2;
  reg valid_in;
  wire [15:0] result;
  wire valid_out, overflow, zero, NaN, precisionLost;
  
  // Result analysis signals
  wire [9:0] res_fra, expected_fra;
  wire res_sign, expected_sign;
  wire [4:0] res_exp, expected_exp;
  reg [15:0] result_expected;
  
  // Test case counter
  reg [7:0] test_case;
  
  // Result checking
  wire correct;
  assign correct = (result_expected == result);
  assign {res_sign, res_exp, res_fra} = result;
  assign {expected_sign, expected_exp, expected_fra} = result_expected;

  // Instantiate pipelined adder
  float_adder_pipelined uut(
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

  // Clock generation
  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 100MHz clock
  end
  
  // Test sequence
  initial begin
    // Initialize signals
    rstn = 0;
    valid_in = 0;
    num1 = 16'h0;
    num2 = 16'h0;
    result_expected = 16'h0;
    test_case = 0;
    
    // Reset sequence - 더 긴 리셋
    #50 rstn = 1;
    #50;  // 리셋 후 충분한 대기 시간
    
    // Test case 1: Bug case
    test_case = 1;
    valid_in = 1;
    num1 = 16'hc0b0;
    num2 = 16'h1cc0;
    result_expected = 16'hc0ae;
    #50  // 5 클럭 사이클 대기 (pipelined 구조용)
    valid_in = 0;  // Valid 신호 리셋
    #20
    
    // Test case 2
    test_case = 2;
    valid_in = 1;
    num1 = 16'h00e0;
    num2 = 16'h5060;
    result_expected = 16'h5060;
    #100  // 10 클럭 사이클 대기 (pipelined 구조용)
    valid_in = 0;
    #50   // Valid 리셋 후 대기
    
    // Test case 3
    test_case = 3;
    valid_in = 1;
    num1 = 16'h29a8;
    num2 = 16'he1f9;
    result_expected = 16'he1f9;
    #100  // 10 클럭 사이클 대기 (pipelined 구조용)
    valid_in = 0;
    #50   // Valid 리셋 후 대기
    
    // Test case 4
    test_case = 4;
    valid_in = 1;
    num1 = 16'h54a5;
    num2 = 16'h1cc0;
    result_expected = 16'h54a5;
    #100  // 10 클럭 사이클 대기 (pipelined 구조용)
    valid_in = 0;
    #50   // Valid 리셋 후 대기
    
    // Test case 5
    test_case = 5;
    valid_in = 1;
    num1 = 16'h00b8;
    num2 = 16'h0080;
    result_expected = 16'h0138;
    #100  // 10 클럭 사이클 대기 (pipelined 구조용)
    valid_in = 0;
    #50   // Valid 리셋 후 대기
    
    // Addition with precision lost
    test_case = 6;
    num1 = {1'b0, 5'd21, 10'b10100101};
    num2 = {1'b0, 5'd14, 10'b11001100};
    result_expected = 16'h54ae;
    #20
    
    // Addition of two numbers with same exp
    test_case = 7;
    num1 = {1'b0, 5'd4, 10'b10100000};
    num2 = {1'b0, 5'd4, 10'b01101100};
    result_expected = 16'h1486;
    #20
    
    // Addition without precision lost
    test_case = 8;
    num1 = {1'b0, 5'd10, 10'b11100000};
    num2 = {1'b0, 5'd12, 10'b01101001};
    result_expected = 16'h31a1;
    #20
    
    // Addition different signs without precision lost
    test_case = 9;
    num1 = {1'b0, 5'd5, 10'b10101100};
    num2 = {1'b1, 5'd6, 10'b00101101};
    result_expected = 16'h935c;
    #20
    
    // Addition different signs without precision lost
    test_case = 10;
    num1 = {1'b1, 5'd13, 10'b00001100};
    num2 = {1'b0, 5'd13, 10'b11101100};
    result_expected = 16'h2b00;
    #20
    
    // Addition different signs without precision lost
    test_case = 11;
    num1 = {1'b1, 5'd30, 10'b10101010};
    num2 = {1'b0, 5'd30, 10'b10101100};
    result_expected = 16'h5400;
    #20
    
    // Zero flag
    test_case = 12;
    num1 = {1'b1, 5'd25, 10'b10011101};
    num2 = {1'b0, 5'd25, 10'b10011101};
    result_expected = 16'h8000;
    #20
    
    // NaN flag
    test_case = 13;
    num1 = {1'b0, 5'b10001, 10'b11111111};
    num2 = {1'b0, 5'b11111, 10'b11111111};
    result_expected = 16'h7cff;
    #20
    
    // Overflow flag
    test_case = 14;
    num1 = {1'b0, 5'b11110, 10'b1111111111};
    num2 = {1'b0, 5'b11110, 10'b1111111111};
    result_expected = 16'h7c00;
    #20
    
    // Overflow flag
    test_case = 15;
    num1 = {1'b0, 5'b11111, 10'b0000000000};
    num2 = {1'b0, 5'b10010, 10'b1110000011};
    result_expected = 16'h7c00;
    #20
    
    // Stop simulation
    valid_in = 0;
    #50 $finish;
  end
  
  // Monitor for debugging - valid_out의 rising edge에서만 출력
  reg prev_valid_out;
  always @(posedge clk) begin
    if (valid_out && !prev_valid_out) begin  // Rising edge만 감지
      $display("=== Test case %d ===", test_case);
      $display("Input: num1=%h, num2=%h", num1, num2);
      $display("Result: %h, Expected: %h, Correct: %b", result, result_expected, correct);
      $display("Flags: overflow=%b, zero=%b, NaN=%b, precisionLost=%b", 
               overflow, zero, NaN, precisionLost);
      $display("Valid signals: valid_in=%b, valid_out=%b", valid_in, valid_out);
      $display("");
    end
    prev_valid_out <= valid_out;
  end
  
endmodule
