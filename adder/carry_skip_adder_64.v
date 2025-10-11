// ============================================================
// Carry-Skip Adder - Fixed 64-bit with 8-bit blocks
// - Intra-block: ripple (explicit bit-level carry)
// - Inter-block: skip via block propagate P_blk = &p
// ============================================================
module carry_skip_adder_64 (
  input  wire [63:0] a,
  input  wire [63:0] b,
  input  wire        cin,
  output wire [63:0] sum,
  output wire        cout
);
  localparam integer WIDTH = 64;
  localparam integer BLK   = 8;
  localparam integer NB = WIDTH/BLK;

  wire [WIDTH-1:0] p = a ^ b;
  wire [WIDTH-1:0] g = a & b;

  // carry entering each block
  wire [NB:0] c_blk;
  assign c_blk[0] = cin;

  // block propagate & block ripple carry-out
  wire [NB-1:0] P_blk;
  wire [NB-1:0] Cout_blk;

  // Intra-block sum requires intra-block carry; we compute ripple and generate sum simultaneously
  genvar bi, j;
  generate
    for (bi = 0; bi < NB; bi = bi + 1) begin : GEN_BLK
      localparam integer base = bi*BLK;

      // Intra-block bit-level carry
      wire [BLK:0] c;    // c[0] = c_blk[bi]

      // Intra-block carry-in
      assign c[0] = c_blk[bi];

      // Intra-block ripple expansion and sum generation
      for (j = 0; j < BLK; j = j + 1) begin : GEN_BITS
        // c[j+1] = g[j] | (p[j] & c[j])
        assign c[j+1]           = g[base+j] | (p[base+j] & c[j]);
        assign sum[base + j]    = p[base+j] ^ c[j];
      end

      // Block propagate
      wire P_all = &p[base +: BLK];

      // Block ripple carry-out
      assign P_blk[bi]  = P_all;
      assign Cout_blk[bi] = c[BLK];

      // Inter-block skip: c_blk[bi+1] = (P_blk ? c_in : Cout_blk)
      assign c_blk[bi+1] = (P_all & c_blk[bi]) | ((~P_all) & Cout_blk[bi]);
    end
  endgenerate

  assign cout = c_blk[NB];
endmodule
