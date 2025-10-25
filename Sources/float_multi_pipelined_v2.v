// float_multi_pipelined_v2.v

module float_multi_pipelined_v2 (
  input  wire        clk,
  input  wire        rstn,       // active-low sync reset
  input  wire        valid_in,

  input  wire [15:0] num1,
  input  wire [15:0] num2,

  output reg         valid_out,
  output reg  [15:0] result,
  output reg         overflow,
  output reg         zero,
  output reg         NaN,
  output reg         precisionLost
);

  // -------------------------
  // S0: Decode + basic sums
  // -------------------------
  // decode
  wire sign1_s0, sign2_s0;
  wire [4:0] ex1_pre_s0, ex2_pre_s0;
  wire [9:0] fra1_s0, fra2_s0;
  assign {sign1_s0, ex1_pre_s0, fra1_s0} = num1;
  assign {sign2_s0, ex2_pre_s0, fra2_s0} = num2;

  // hidden-1 add for normals (same as original)
  wire [4:0] ex1_s0 = ex1_pre_s0 + {4'd0, ~|ex1_pre_s0};
  wire [4:0] ex2_s0 = ex2_pre_s0 + {4'd0, ~|ex2_pre_s0};

  // "float" vectors like original
  wire [20:0] float1_s0 = { |ex1_pre_s0, fra1_s0, 10'd0 }; // 1+10+10 = 21
  wire [10:0] float2_s0 = { |ex2_pre_s0, fra2_s0 };        // 1+10 = 11

  // exponent sums (same math/width/sign convention as original)
  wire [5:0] exSum_prebais_s0 = {1'b0, ex1_s0} + {1'b0, ex2_s0};   // 0..62
  wire [6:0] exSum_s0         = {1'b0, exSum_prebais_s0} - 7'd15;  // signed 7
  wire       exSum_sign_s0    = exSum_s0[6];
  wire [5:0] exSum_abs_s0     = exSum_sign_s0 ? (~exSum_s0[5:0] + 6'd1) : exSum_s0[5:0];

  // flags (as in original)
  wire zero_num_in_s0 = ~(|num1[14:0] & |num2[14:0]);
  wire NaN_s0         = (&num1[14:10] & |num1[9:0]) | (&num2[14:10] & |num2[9:0]);
  wire inf_num_s0     = (&num1[14:10] & ~|num1[9:0]) | (&num2[14:10] & ~|num2[9:0]);
  wire signR_s0       = sign1_s0 ^ sign2_s0;

  // S0 registers
  reg        v_s0;
  reg        signR_r0;
  reg [4:0]  ex1_pre_r0, ex2_pre_r0;
  reg [9:0]  fra1_r0, fra2_r0;
  reg [4:0]  ex1_r0, ex2_r0;
  reg [20:0] float1_r0;
  reg [10:0] float2_r0;
  reg [5:0]  exSum_prebais_r0;
  reg [6:0]  exSum_r0;
  reg        exSum_sign_r0;
  reg [5:0]  exSum_abs_r0;
  reg        zero_num_in_r0, NaN_r0, inf_num_r0;

  always @(posedge clk) begin
    if (!rstn) begin
      v_s0             <= 1'b0;
      signR_r0         <= 1'b0;
      ex1_pre_r0       <= 5'd0;
      ex2_pre_r0       <= 5'd0;
      fra1_r0          <= 10'd0;
      fra2_r0          <= 10'd0;
      ex1_r0           <= 5'd0;
      ex2_r0           <= 5'd0;
      float1_r0        <= 21'd0;
      float2_r0        <= 11'd0;
      exSum_prebais_r0 <= 6'd0;
      exSum_r0         <= 7'd0;
      exSum_sign_r0    <= 1'b0;
      exSum_abs_r0     <= 6'd0;
      zero_num_in_r0   <= 1'b0;
      NaN_r0           <= 1'b0;
      inf_num_r0       <= 1'b0;
    end else begin
      v_s0             <= valid_in;
      signR_r0         <= signR_s0;
      ex1_pre_r0       <= ex1_pre_s0;
      ex2_pre_r0       <= ex2_pre_s0;
      fra1_r0          <= fra1_s0;
      fra2_r0          <= fra2_s0;
      ex1_r0           <= ex1_s0;
      ex2_r0           <= ex2_s0;
      float1_r0        <= float1_s0;
      float2_r0        <= float2_s0;
      exSum_prebais_r0 <= exSum_prebais_s0;
      exSum_r0         <= exSum_s0;
      exSum_sign_r0    <= exSum_sign_s0;
      exSum_abs_r0     <= exSum_abs_s0;
      zero_num_in_r0   <= zero_num_in_s0;
      NaN_r0           <= NaN_s0;
      inf_num_r0       <= inf_num_s0;
    end
  end

  // -------------------------
  // S1: Partial products + adder tree -> res_full_preshift
  // -------------------------
  // replicate the original mid[] building (combinational inside S1)
  wire [20:0] mid_w [10:0];
  assign mid_w[0]  = (float1_r0 >> 10) & {21{float2_r0[0]}};
  assign mid_w[1]  = (float1_r0 >> 9 ) & {21{float2_r0[1]}};
  assign mid_w[2]  = (float1_r0 >> 8 ) & {21{float2_r0[2]}};
  assign mid_w[3]  = (float1_r0 >> 7 ) & {21{float2_r0[3]}};
  assign mid_w[4]  = (float1_r0 >> 6 ) & {21{float2_r0[4]}};
  assign mid_w[5]  = (float1_r0 >> 5 ) & {21{float2_r0[5]}};
  assign mid_w[6]  = (float1_r0 >> 4 ) & {21{float2_r0[6]}};
  assign mid_w[7]  = (float1_r0 >> 3 ) & {21{float2_r0[7]}};
  assign mid_w[8]  = (float1_r0 >> 2 ) & {21{float2_r0[8]}};
  assign mid_w[9]  = (float1_r0 >> 1 ) & {21{float2_r0[9]}};
  assign mid_w[10] =  float1_r0        & {21{float2_r0[10]}};

  // Balanced adder tree to 22-bit sum (avoid long fan-in)
  wire [21:0] s1_a0 = {1'b0, mid_w[0]}  + {1'b0, mid_w[1]};
  wire [21:0] s1_a1 = {1'b0, mid_w[2]}  + {1'b0, mid_w[3]};
  wire [21:0] s1_a2 = {1'b0, mid_w[4]}  + {1'b0, mid_w[5]};
  wire [21:0] s1_a3 = {1'b0, mid_w[6]}  + {1'b0, mid_w[7]};
  wire [21:0] s1_a4 = {1'b0, mid_w[8]}  + {1'b0, mid_w[9]};
  wire [21:0] s1_b0 = s1_a0 + s1_a1;
  wire [21:0] s1_b1 = s1_a2 + s1_a3;
  wire [21:0] s1_b2 = s1_a4 + {1'b0, mid_w[10]};
  wire [21:0] res_full_preshift_s1 = s1_b0 + s1_b1 + s1_b2;

  // upper/lower split exactly as original
  wire [11:0] float_res_preround_s1 = res_full_preshift_s1[21:10];
  wire [9:0]  dump_res_s1           = res_full_preshift_s1[9:0];

  // S1 registers (carry S0 context forward)
  reg        v_s1;
  reg        signR_r1;
  reg [6:0]  exSum_r1;
  reg        exSum_sign_r1;
  reg [5:0]  exSum_abs_r1;
  reg [5:0]  exSum_prebais_r1;
  reg        zero_num_in_r1, NaN_r1, inf_num_r1;

  reg [21:0] res_full_preshift_r1;
  reg [11:0] float_res_preround_r1;
  reg [9:0]  dump_res_r1;

  always @(posedge clk) begin
    if (!rstn) begin
      v_s1                 <= 1'b0;
      signR_r1             <= 1'b0;
      exSum_r1             <= 7'd0;
      exSum_sign_r1        <= 1'b0;
      exSum_abs_r1         <= 6'd0;
      exSum_prebais_r1     <= 6'd0;
      zero_num_in_r1       <= 1'b0;
      NaN_r1               <= 1'b0;
      inf_num_r1           <= 1'b0;

      res_full_preshift_r1 <= 22'd0;
      float_res_preround_r1<= 12'd0;
      dump_res_r1          <= 10'd0;
    end else begin
      v_s1                 <= v_s0;
      signR_r1             <= signR_r0;
      exSum_r1             <= exSum_r0;
      exSum_sign_r1        <= exSum_sign_r0;
      exSum_abs_r1         <= exSum_abs_r0;
      exSum_prebais_r1     <= exSum_prebais_r0;
      zero_num_in_r1       <= zero_num_in_r0;
      NaN_r1               <= NaN_r0;
      inf_num_r1           <= inf_num_r0;

      res_full_preshift_r1 <= res_full_preshift_s1;
      float_res_preround_r1<= float_res_preround_s1;
      dump_res_r1          <= dump_res_s1;
    end
  end

  // -------------------------
  // S2: Shift/normalize (per original), subnormal fix, rounding, pack
  // -------------------------
  // shift right by exSum_abs if exponent negative (keep same mapping)
  reg [21:0] res_full_r2;
  always @* begin
    if (exSum_sign_r1) begin
      case (exSum_abs_r1)
        6'h00: res_full_r2 = res_full_preshift_r1;
        6'h01: res_full_r2 = res_full_preshift_r1 >> 1;
        6'h02: res_full_r2 = res_full_preshift_r1 >> 2;
        6'h03: res_full_r2 = res_full_preshift_r1 >> 3;
        6'h04: res_full_r2 = res_full_preshift_r1 >> 4;
        6'h05: res_full_r2 = res_full_preshift_r1 >> 5;
        6'h06: res_full_r2 = res_full_preshift_r1 >> 6;
        6'h07: res_full_r2 = res_full_preshift_r1 >> 7;
        6'h08: res_full_r2 = res_full_preshift_r1 >> 8;
        6'h09: res_full_r2 = res_full_preshift_r1 >> 9;
        6'h0A: res_full_r2 = res_full_preshift_r1 >> 10;
        6'h0B: res_full_r2 = res_full_preshift_r1 >> 11;
        6'h0C: res_full_r2 = res_full_preshift_r1 >> 12;
        6'h0D: res_full_r2 = res_full_preshift_r1 >> 13;
        6'h0E: res_full_r2 = res_full_preshift_r1 >> 14;
        6'h0F: res_full_r2 = res_full_preshift_r1 >> 15;
        default: res_full_r2 = res_full_preshift_r1 >> 16;
      endcase
    end else begin
      res_full_r2 = res_full_preshift_r1;
    end
  end

  // float_res rounding like original: add dump_res[9]
  wire [11:0] float_res_r2 = float_res_preround_r1 + {11'd0, dump_res_r1[9]};

  // subNormal flag per original
  wire subNormal_r2 = ~|float_res_r2[11:10];

  // zero_calculated per original
  wire zero_calc_r2 = (subNormal_r2 & 1'b1 /* fraSub==0 checked below after fraSub set */)
                    | (exSum_sign_r1 & (~|res_full_r2[20:11]));

  // fraSub + exSubCor derived from res_full (same casex table)
  reg [9:0] fraSub_r2;
  reg [4:0] exSubCor_r2;
  always @* begin
    // defaults
    fraSub_r2   = 10'd0;
    exSubCor_r2 = 5'd0;
    casex(res_full_r2)
      22'b001xxxxxxxxxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[18:9];  exSubCor_r2 = 5'd1;  end
      22'b0001xxxxxxxxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[17:8];  exSubCor_r2 = 5'd2;  end
      22'b00001xxxxxxxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[16:7];  exSubCor_r2 = 5'd3;  end
      22'b000001xxxxxxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[15:6];  exSubCor_r2 = 5'd4;  end
      22'b0000001xxxxxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[14:5];  exSubCor_r2 = 5'd5;  end
      22'b00000001xxxxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[13:4];  exSubCor_r2 = 5'd6;  end
      22'b000000001xxxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[12:3];  exSubCor_r2 = 5'd7;  end
      22'b0000000001xxxxxxxxxxxx: begin fraSub_r2 = res_full_r2[11:2];  exSubCor_r2 = 5'd8;  end
      22'b00000000001xxxxxxxxxxx: begin fraSub_r2 = res_full_r2[10:1];  exSubCor_r2 = 5'd9;  end
      22'b000000000001xxxxxxxxxx: begin fraSub_r2 = res_full_r2[9:0];   exSubCor_r2 = 5'd10; end
      22'b0000000000001xxxxxxxxx: begin fraSub_r2 = {res_full_r2[8:0],  1'd0}; exSubCor_r2 = 5'd11; end
      22'b00000000000001xxxxxxxx: begin fraSub_r2 = {res_full_r2[7:0],  2'd0}; exSubCor_r2 = 5'd12; end
      22'b000000000000001xxxxxxx: begin fraSub_r2 = {res_full_r2[6:0],  3'd0}; exSubCor_r2 = 5'd13; end
      22'b0000000000000001xxxxxx: begin fraSub_r2 = {res_full_r2[5:0],  4'd0}; exSubCor_r2 = 5'd14; end
      22'b00000000000000001xxxxx: begin fraSub_r2 = {res_full_r2[4:0],  5'd0}; exSubCor_r2 = 5'd15; end
      22'b000000000000000001xxxx: begin fraSub_r2 = {res_full_r2[3:0],  6'd0}; exSubCor_r2 = 5'd16; end
      22'b0000000000000000001xxx: begin fraSub_r2 = {res_full_r2[2:0],  7'd0}; exSubCor_r2 = 5'd17; end
      22'b00000000000000000001xx: begin fraSub_r2 = {res_full_r2[1:0],  8'd0}; exSubCor_r2 = 5'd18; end
      22'b000000000000000000001x: begin fraSub_r2 = {res_full_r2[0],    9'd0}; exSubCor_r2 = 5'd19; end
      default: begin /* keep defaults */ end
    endcase
  end

  // ex_cannot_correct & fraSub_corrected (same as original)
  wire        ex_cannot_correct_r2 = ({1'b0, exSubCor_r2} > exSum_abs_r1); // preserves original strictness
  wire [4:0]  exSum_fault_r2       = exSubCor_r2 - exSum_abs_r1[4:0];

  reg  [9:0] fraSub_corrected_r2;
  always @* begin
    if (ex_cannot_correct_r2) begin
      case (exSum_fault_r2)
        5'h00: fraSub_corrected_r2 = fraSub_r2;
        5'h01: fraSub_corrected_r2 = (fraSub_r2 >> 1);
        5'h02: fraSub_corrected_r2 = (fraSub_r2 >> 2);
        5'h03: fraSub_corrected_r2 = (fraSub_r2 >> 3);
        5'h04: fraSub_corrected_r2 = (fraSub_r2 >> 4);
        5'h05: fraSub_corrected_r2 = (fraSub_r2 >> 5);
        5'h06: fraSub_corrected_r2 = (fraSub_r2 >> 6);
        5'h07: fraSub_corrected_r2 = (fraSub_r2 >> 7);
        5'h08: fraSub_corrected_r2 = (fraSub_r2 >> 8);
        5'h09: fraSub_corrected_r2 = (fraSub_r2 >> 9);
        default: fraSub_corrected_r2 = 10'h000;
      endcase
    end else begin
      fraSub_corrected_r2 = fraSub_r2;
    end
  end

  // final pack (exactly following original wiring)
  wire [9:0] float_res_fra_r2 = (float_res_r2[11]) ? float_res_r2[10:1] : float_res_r2[9:0];

  wire [4:0] exR_calc_r2 =
      exSum_r1[4:0]
    + {4'd0, float_res_r2[11]}
    + (~exSubCor_r2 & {5{subNormal_r2}})
    + {4'd0, subNormal_r2};

  wire [4:0] exR_r2 = (exR_calc_r2 | {5{ (inf_num_r1 | (~exSum_r1[6] & exSum_r1[5])) }})
                      & {5{ ~( (zero_num_in_r1
                                | ((subNormal_r2 & (fraSub_r2==10'd0)) // fraSub==0 check
                                   | (exSum_sign_r1 & (~|res_full_r2[20:11]))))
                               | exSum_sign_r1
                               | ex_cannot_correct_r2) }}; // mask as in original ORing

  wire [9:0] fraR_r2 =
      ((exSum_sign_r1) ? res_full_r2[20:11]
                       : ((subNormal_r2) ? fraSub_corrected_r2 : float_res_fra_r2))
      & {10{~( (zero_num_in_r1
                | ((subNormal_r2 & (fraSub_r2==10'd0))
                   | (exSum_sign_r1 & (~|res_full_r2[20:11]))))
               | (inf_num_r1 | (~exSum_r1[6] & exSum_r1[5])) )}};

  wire [15:0] result_r2 = { signR_r1, exR_r2, fraR_r2 };

  // flags (keep original formulas)
  wire overflow_r2     = inf_num_r1 | (~exSum_r1[6] & exSum_r1[5]);
  wire zero_calc_fix   = (subNormal_r2 & (fraSub_r2 == 10'd0))
                       | (exSum_sign_r1 & (~|res_full_r2[20:11]));
  wire zero_r2         = zero_num_in_r1 | zero_calc_fix;
  wire NaN_r2          = NaN_r1;
  wire precisionLost_r2= (|dump_res_r1) | (exSum_prebais_r1 < 6'd15);

  // S2 output registers
  reg v_s2;
  reg [15:0] result_r2q;
  reg        overflow_r2q, zero_r2q, NaN_r2q, precisionLost_r2q;

  always @(posedge clk) begin
    if (!rstn) begin
      v_s2              <= 1'b0;
      result_r2q        <= 16'd0;
      overflow_r2q      <= 1'b0;
      zero_r2q          <= 1'b0;
      NaN_r2q           <= 1'b0;
      precisionLost_r2q <= 1'b0;
    end else begin
      v_s2              <= v_s1;
      result_r2q        <= result_r2;
      overflow_r2q      <= overflow_r2;
      zero_r2q          <= zero_r2;
      NaN_r2q           <= NaN_r2;
      precisionLost_r2q <= precisionLost_r2;
      
      // Debug output for failed cases
      if (v_s1 && (num1 == 16'h4689 && num2 == 16'h0025) || (num1 == 16'h4489 && num2 == 16'h001d)) begin
        $display("[DEBUG] Time=%0t num1=0x%04h num2=0x%04h", $time, num1, num2);
        $display("  exSum_prebais_r1=%0d exSum_r1=%0d exSum_sign_r1=%b", exSum_prebais_r1, exSum_r1, exSum_sign_r1);
        $display("  res_full_preshift_r1=0x%06x float_res_preround_r1=0x%03x dump_res_r1=0x%03x", 
                 res_full_preshift_r1, float_res_preround_r1, dump_res_r1);
        $display("  res_full_r2=0x%06x float_res_r2=0x%03x subNormal_r2=%b", 
                 res_full_r2, float_res_r2, subNormal_r2);
        $display("  fraSub_r2=0x%03x exSubCor_r2=%0d ex_cannot_correct_r2=%b", 
                 fraSub_r2, exSubCor_r2, ex_cannot_correct_r2);
        $display("  fraSub_corrected_r2=0x%03x exR_calc_r2=%0d exR_r2=%0d", 
                 fraSub_corrected_r2, exR_calc_r2, exR_r2);
        $display("  fraR_r2=0x%03x result_r2=0x%04h precisionLost_r2=%b", 
                 fraR_r2, result_r2, precisionLost_r2);
        $display("  flags: overflow=%b zero=%b NaN=%b precisionLost=%b", 
                 overflow_r2, zero_r2, NaN_r2, precisionLost_r2);
      end
    end
  end

  // -------------------------
  // S3: Final register to align with valid_out
  // -------------------------
  always @(posedge clk) begin
    if (!rstn) begin
      valid_out     <= 1'b0;
      result        <= 16'd0;
      overflow      <= 1'b0;
      zero          <= 1'b0;
      NaN           <= 1'b0;
      precisionLost <= 1'b0;
    end else begin
      valid_out     <= v_s2;
      result        <= result_r2q;
      overflow      <= overflow_r2q;
      zero          <= zero_r2q;
      NaN           <= NaN_r2q;
      precisionLost <= precisionLost_r2q;
    end
  end

endmodule
