// ============================================================
// 64-bit Ling Adder (h-carry) with 4-bit blocks + block-level Kogge-Stone
// ============================================================
module ling_adder_64 (
  input  wire [63:0] a,
  input  wire [63:0] b,
  input  wire        cin,
  output wire [63:0] sum,
  output wire        cout
);
  // 1) bit-level p,g,t
  // p: propagate, g: generate, t: transitive
  wire [63:0] p = a ^ b;
  wire [63:0] g = a & b;
  wire [63:0] t = a | b;

  // 2) 4-bit block P,G (16 blocks)
  localparam BLK = 4;
  localparam NB  = 64/BLK; // 16
  wire [NB-1:0] Pblk, Gblk;

  genvar bi;
  generate
    for (bi=0; bi<NB; bi=bi+1) begin : GEN_BLK_PG
      localparam integer L = bi*BLK;
      localparam integer H = L+BLK-1;

      wire [3:0] pp = p[H:L];
      wire [3:0] gg = g[H:L];

      assign Pblk[bi] = &pp; // p3 & p2 & p1 & p0

      // Gblk = g3 | p3 g2 | p3 p2 g1 | p3 p2 p1 g0
      assign Gblk[bi] = gg[3]
                      | (pp[3] & gg[2])
                      | (pp[3] & pp[2] & gg[1])
                      | (pp[3] & pp[2] & pp[1] & gg[0]);
    end
  endgenerate

  // 3) Block-level prefix (Kogge-Stone) to get carries into each block
  // prefix arrays
  wire [NB-1:0] Pg0 = Pblk;
  wire [NB-1:0] Gg0 = Gblk;

  // level k uses distance d = 2^k
  function integer POW2; input integer k; begin POW2 = (1<<k); end endfunction

  // mutable wires per level
  wire [NB-1:0] Pg1, Gg1, Pg2, Gg2, Pg3, Gg3, Pg4, Gg4;

  // level 1 (d=1)
  genvar i1;
  generate
    for (i1=0; i1<NB; i1=i1+1) begin : LVL1
      if (i1>=1) begin
        assign Gg1[i1] = Gg0[i1] | (Pg0[i1] & Gg0[i1-1]);
        assign Pg1[i1] = Pg0[i1] & Pg0[i1-1];
      end else begin
        assign Gg1[i1] = Gg0[i1];
        assign Pg1[i1] = Pg0[i1];
      end
    end
  endgenerate

  // level 2 (d=2)
  genvar i2;
  generate
    for (i2=0; i2<NB; i2=i2+1) begin : LVL2
      if (i2>=2) begin
        assign Gg2[i2] = Gg1[i2] | (Pg1[i2] & Gg1[i2-2]);
        assign Pg2[i2] = Pg1[i2] & Pg1[i2-2];
      end else begin
        assign Gg2[i2] = Gg1[i2];
        assign Pg2[i2] = Pg1[i2];
      end
    end
  endgenerate

  // level 3 (d=4)
  genvar i3;
  generate
    for (i3=0; i3<NB; i3=i3+1) begin : LVL3
      if (i3>=4) begin
        assign Gg3[i3] = Gg2[i3] | (Pg2[i3] & Gg2[i3-4]);
        assign Pg3[i3] = Pg2[i3] & Pg2[i3-4];
      end else begin
        assign Gg3[i3] = Gg2[i3];
        assign Pg3[i3] = Pg2[i3];
      end
    end
  endgenerate

  // level 4 (d=8)
  genvar i4;
  generate
    for (i4=0; i4<NB; i4=i4+1) begin : LVL4
      if (i4>=8) begin
        assign Gg4[i4] = Gg3[i4] | (Pg3[i4] & Gg3[i4-8]);
        assign Pg4[i4] = Pg3[i4] & Pg3[i4-8];
      end else begin
        assign Gg4[i4] = Gg3[i4];
        assign Pg4[i4] = Pg3[i4];
      end
    end
  endgenerate

  // block carry-in (h_in for each block)
  wire [NB:0] Hblk;  // Hblk[0]=cin, Hblk[i]=carry into block i
  assign Hblk[0] = cin;
  genvar ci;
  generate
    for (ci=1; ci<=NB; ci=ci+1) begin : GEN_HBLK
      // carry into block ci = prefix G/P of block ci-1 applied to cin
      assign Hblk[ci] = Gg4[ci-1] | (Pg4[ci-1] & cin);
    end
  endgenerate

  // 4) block-local Ling sum with h-carry
  genvar bj;
  generate
    for (bj=0; bj<NB; bj=bj+1) begin : GEN_BLOCK_SUM
      localparam integer L = bj*BLK;
      localparam integer H = L+BLK-1;

      wire [3:0] pp = p[H:L];
      wire [3:0] gg = g[H:L];
      wire [3:0] tt = t[H:L];

      // local h[-1]=Hblk[bj]
      wire       h_m1 = Hblk[bj];
      wire       h0   = gg[0] | (pp[0] & h_m1);
      wire       h1   = gg[1] | (pp[1] & gg[0]) | (pp[1] & pp[0] & h_m1);
      wire       h2   = gg[2] | (pp[2] & gg[1]) | (pp[2] & pp[1] & gg[0]) | (pp[2] & pp[1] & pp[0] & h_m1);
      wire       h3   = gg[3] | (pp[3] & gg[2]) | (pp[3] & pp[2] & gg[1]) | (pp[3] & pp[2] & pp[1] & gg[0]) | (pp[3] & pp[2] & pp[1] & pp[0] & h_m1);

      // sums: s[i] = p[i] ^ (h[i-1] & t[i-1]); with t[-1]=1
      assign sum[L+0] = pp[0] ^ (h_m1);
      assign sum[L+1] = pp[1] ^ (h0   & tt[0]);
      assign sum[L+2] = pp[2] ^ (h1   & tt[1]);
      assign sum[L+3] = pp[3] ^ (h2   & tt[2]);

    end
  endgenerate

  assign cout = Hblk[NB] & t[63];
endmodule
