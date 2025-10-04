// ============================================================
// Two-level Block Carry-Lookahead Adder - Fixed 64-bit
// - 1st level: full 4-bit lookahead inside each block
// - 2nd level: lookahead across groups of 4 blocks
// ============================================================
module cla_adder_64 (
  input  wire [63:0] a,
  input  wire [63:0] b,
  input  wire        cin,
  output wire [63:0] sum,
  output wire        cout
);
  localparam integer WIDTH = 64;
  localparam integer BLK   = 4;   // inner lookahead block width
  localparam integer GRP   = 4;   // number of blocks per group in level-2
  localparam integer NB = WIDTH/BLK;       // number of blocks (16)
  localparam integer NG = NB/GRP;          // number of level-2 groups (4)

  // bitwise p,g
  wire [WIDTH-1:0] p = a ^ b;
  wire [WIDTH-1:0] g = a & b;

  // block-wise G,P (4-bit full lookahead per block)
  wire [NB-1:0] GP_block_G;
  wire [NB-1:0] GP_block_P;

  // carry-in to each block
  wire [NB:0] c_block;  // c_block[0] = cin
  assign c_block[0] = cin;

  // carry-in to each 4-block group (level-2)
  wire [NG:0] c_group;  // c_group[0] = cin
  assign c_group[0] = cin;

  // ---------- 4-bit block lookahead (G,P computation) ----------
  genvar bi, bj;
  generate
    for (bi = 0; bi < NB; bi = bi + 1) begin : GEN_BLK
      // indices of bits inside block
      wire [BLK-1:0] pp, gg;
      for (bj = 0; bj < BLK; bj = bj + 1) begin : GEN_BITIDX
        assign pp[bj] = p[bi * BLK + bj];
        assign gg[bj] = g[bi * BLK + bj];
      end

      // Full expansion for BLK=4:
      // P_block = p3&p2&p1&p0
      // G_block = g3 | (p3&g2) | (p3&p2&g1) | (p3&p2&p1&g0)
      // If you change BLK to 8, please rewrite the corresponding expansion or use general prefix.
      wire Pblk =  pp[3] &  pp[2] &  pp[1] &  pp[0];
      wire Gblk =  gg[3] |
                  (pp[3] & gg[2]) |
                  (pp[3] & pp[2] & gg[1]) |
                  (pp[3] & pp[2] & pp[1] & gg[0]);

      assign GP_block_P[bi] = Pblk;
      assign GP_block_G[bi] = Gblk;
    end
  endgenerate

  // ---------- Level-2 lookahead across each group of 4 blocks ----------
  // Perform 4-input lookahead on (G,P) for each group of 4 blocks to get group G,P,
  // then distribute c_group to the starting block of each group.
  wire [NG-1:0] GP_group_G, GP_group_P;

  generate
    genvar gi;
    for (gi = 0; gi < NG; gi = gi + 1) begin : GEN_GRP
      // block indices [base .. base+3]
      localparam integer base = gi*GRP;
      wire p0 = GP_block_P[base + 0];
      wire p1 = GP_block_P[base + 1];
      wire p2 = GP_block_P[base + 2];
      wire p3 = GP_block_P[base + 3];
      wire g0 = GP_block_G[base + 0];
      wire g1 = GP_block_G[base + 1];
      wire g2 = GP_block_G[base + 2];
      wire g3 = GP_block_G[base + 3];

      // group P/G for 4 blocks
      wire Pgrp = p3 & p2 & p1 & p0;
      wire Ggrp = g3 |
                  (p3 & g2) |
                  (p3 & p2 & g1) |
                  (p3 & p2 & p1 & g0);
      assign GP_group_P[gi] = Pgrp;
      assign GP_group_G[gi] = Ggrp;

      // carry into next group
      // c_group[gi+1] = Ggrp | (Pgrp & c_group[gi])
      assign c_group[gi+1] = Ggrp | (Pgrp & c_group[gi]);

      // now distribute carries to blocks inside this group
      // c_block[base]     = c_group[gi];
      // c_block[base+1]   = g0 | (p0 & c_block[base]);
      // c_block[base+2]   = g1 | (p1 & c_block[base+1]);
      // c_block[base+3]   = g2 | (p2 & c_block[base+2]);
      assign c_block[base+0] = c_group[gi];
      assign c_block[base+1] = g0 | (p0 & c_block[base+0]);
      assign c_block[base+2] = g1 | (p1 & c_block[base+1]);
      assign c_block[base+3] = g2 | (p2 & c_block[base+2]);
    end
  endgenerate

  // final carry-out = c_group[NG] can also be derived from the last block expansion, both are consistent
  assign cout = c_group[NG];

  // ---------- Intra-block sum: si = pi ^ ci ----------
  // Here we need carry-in for each bit. Intra-block 4-bit expansion:
  generate
    genvar kb;
    for (kb = 0; kb < NB; kb = kb + 1) begin : GEN_SUM_BLK
      wire c0 = c_block[kb + 0];
      // Expand intra-block carry for 4 bits of this block
      wire c1 = g[kb * BLK + 0] | (p[kb * BLK + 0] & c0);
      wire c2 = g[kb * BLK + 1] | (p[kb * BLK + 1] & c1);
      wire c3 = g[kb * BLK + 2] | (p[kb * BLK + 2] & c2);

      assign sum[kb * BLK + 0] = p[kb * BLK + 0] ^ c0;
      assign sum[kb * BLK + 1] = p[kb * BLK + 1] ^ c1;
      assign sum[kb * BLK + 2] = p[kb * BLK + 2] ^ c2;
      assign sum[kb * BLK + 3] = p[kb * BLK + 3] ^ c3;
    end
  endgenerate

endmodule
