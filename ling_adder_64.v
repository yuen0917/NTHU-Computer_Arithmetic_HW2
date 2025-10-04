// ============================================================
// Ling Adder (h-carry form) - Fixed 64-bit
// - h[i] = g[i] | (p[i] & h[i-1]);  h[-1] = cin
// - sum[i] = p[i] ^ (h[i-1] & t[i]); t = a|b
// - cout = h[63]
// ============================================================
module ling_adder_64 (
  input  wire [63:0] a,
  input  wire [63:0] b,
  input  wire        cin,
  output wire [63:0] sum,
  output wire        cout
);
  wire [63:0] p = a ^ b;
  wire [63:0] g = a & b;
  wire [63:0] t = a | b;

  wire [63:0] h;     // h[i] = carry of bit i (to the next bit), i.e., c[i+1]
  // h[-1] = cin; implemented using a feedforward signal
  wire h_m1 = cin;

  genvar i;
  generate
    for (i = 0; i < 64; i = i + 1) begin : GEN_H
      if (i == 0) begin
        assign h[i] = g[i] | (p[i] & h_m1);
      end else begin
        assign h[i] = g[i] | (p[i] & h[i-1]);
      end
    end
  endgenerate

  // sum[i] uses h[i-1]
  generate
    for (i = 0; i < 64; i = i + 1) begin : GEN_SUM
      if (i == 0) begin
        assign sum[i] = p[i] ^ (h_m1 & t[i]);
      end else begin
        assign sum[i] = p[i] ^ (h[i-1] & t[i]);
      end
    end
  endgenerate

  assign cout = h[63];
endmodule
