// ============================================================
// Top module that instantiates both 64-bit adders for comparison/testing
// - rca_adder_64: Ripple Carry Adder
// - carry_sel_adder_64: Carry-Select Adder (parameterized block width)
//
// Interface:
//   a[63:0], b[63:0], cin  -> common inputs
//   sum_rca[63:0], cout_rca -> outputs from RCA
//   sum_csa[63:0], cout_csa -> outputs from CSA
//
// Notes:
//   This top is intended for simulation/verification or quick on-chip comparison.
//   Timing/resource analysis should still be done on each module separately.
// ============================================================
// `include "rca_adder_64.v"
// `include "carry_sel_adder_64.v"

module adders_top #(
    parameter integer CSA_BLOCK_WIDTH = 16  // can be set to 8 for more segments
) (
    // RCA inputs
    input  wire [63:0] a_rca,
    input  wire [63:0] b_rca,
    input  wire        cin_rca,

    // CSA inputs
    input  wire [63:0] a_csa,
    input  wire [63:0] b_csa,
    input  wire        cin_csa,

    // RCA outputs
    output wire [63:0] sum_rca,
    output wire        cout_rca,

    // CSA outputs
    output wire [63:0] sum_csa,
    output wire        cout_csa
);

    // Ripple Carry Adder instance
    rca_adder_64 u_rca (
        .a   (a_rca),
        .b   (b_rca),
        .cin (cin_rca),
        .sum (sum_rca),
        .cout(cout_rca)
    );

    // Carry-Select Adder instance
    carry_sel_adder_64 #(
        .BLOCK_WIDTH(CSA_BLOCK_WIDTH)
    ) u_csa (
        .a   (a_csa),
        .b   (b_csa),
        .cin (cin_csa),
        .sum (sum_csa),
        .cout(cout_csa)
    );

endmodule


