`timescale 1ns/1ps

// ============================================================
// Testbench for adders_top
// - Instantiates adders_top (RCA + CSA)
// - Drives identical inputs to both adders, then independent inputs
// - Checks results against a reference model (a + b + cin)
// - Cross-compares RCA vs CSA when inputs are identical
// ============================================================
// `include "rca_adder_64.v"
// `include "carry_sel_adder_64.v"
// `include "adders_top.v"

module adders_top_tb;

    // DUT I/O
    reg  [63:0] a_rca;
    reg  [63:0] b_rca;
    reg         cin_rca;

    reg  [63:0] a_csa;
    reg  [63:0] b_csa;
    reg         cin_csa;

    wire [63:0] sum_rca;
    wire        cout_rca;
    wire [63:0] sum_csa;
    wire        cout_csa;

    // Device Under Test
    adders_top #(
        .CSA_BLOCK_WIDTH(16)
    ) dut (
        .a_rca(a_rca),
        .b_rca(b_rca),
        .cin_rca(cin_rca),
        .a_csa(a_csa),
        .b_csa(b_csa),
        .cin_csa(cin_csa),
        .sum_rca(sum_rca),
        .cout_rca(cout_rca),
        .sum_csa(sum_csa),
        .cout_csa(cout_csa)
    );

    // Reference model: compute 65-bit result {carry,sum}
    function [64:0] ref_add;
        input [63:0] a;
        input [63:0] b;
        input        cin;
        begin
            ref_add = {1'b0, a} + {1'b0, b} + cin;
        end
    endfunction

    task check_pair_same_inputs(input [63:0] a, input [63:0] b, input cin);
        reg [64:0] exp;
        begin
            a_rca  = a; b_rca  = b; cin_rca  = cin;
            a_csa  = a; b_csa  = b; cin_csa  = cin;
            #1; // allow settle
            exp = ref_add(a, b, cin);
            if ({cout_rca, sum_rca} !== exp) begin
                $display("[RCA mismatch] a=%h b=%h cin=%0d exp={%0d,%h} got={%0d,%h}",
                         a, b, cin, exp[64], exp[63:0], cout_rca, sum_rca);
                $fatal(1);
            end
            if ({cout_csa, sum_csa} !== exp) begin
                $display("[CSA mismatch] a=%h b=%h cin=%0d exp={%0d,%h} got={%0d,%h}",
                         a, b, cin, exp[64], exp[63:0], cout_csa, sum_csa);
                $fatal(1);
            end
            // Cross-compare
            if ({cout_rca, sum_rca} !== {cout_csa, sum_csa}) begin
                $display("[Cross mismatch] RCA={%0d,%h} CSA={%0d,%h}", cout_rca, sum_rca, cout_csa, sum_csa);
                $fatal(1);
            end
        end
    endtask

    task check_pair_independent_inputs(
        input [63:0] a_r, input [63:0] b_r, input cin_r,
        input [63:0] a_c, input [63:0] b_c, input cin_c
    );
        reg [64:0] exp_r;
        reg [64:0] exp_c;
        begin
            a_rca = a_r; b_rca = b_r; cin_rca = cin_r;
            a_csa = a_c; b_csa = b_c; cin_csa = cin_c;
            #1;
            exp_r = ref_add(a_r, b_r, cin_r);
            exp_c = ref_add(a_c, b_c, cin_c);
            if ({cout_rca, sum_rca} !== exp_r) begin
                $display("[RCA mismatch] a=%h b=%h cin=%0d exp={%0d,%h} got={%0d,%h}",
                         a_r, b_r, cin_r, exp_r[64], exp_r[63:0], cout_rca, sum_rca);
                $fatal(1);
            end
            if ({cout_csa, sum_csa} !== exp_c) begin
                $display("[CSA mismatch] a=%h b=%h cin=%0d exp={%0d,%h} got={%0d,%h}",
                         a_c, b_c, cin_c, exp_c[64], exp_c[63:0], cout_csa, sum_csa);
                $fatal(1);
            end
        end
    endtask

    // Helpers to produce 64-bit random values using two 32-bit $random calls
    function [63:0] rand64;
        begin
            rand64 = { $random, $random };
        end
    endfunction

    integer i;

    initial begin
        // Wave dump
        $dumpfile("adders_top_tb.vcd");
        $dumpvars(0, adders_top_tb);

        // Init
        a_rca = 64'd0; b_rca = 64'd0; cin_rca = 1'b0;
        a_csa = 64'd0; b_csa = 64'd0; cin_csa = 1'b0;

        // 1) Edge cases with identical inputs
        check_pair_same_inputs(64'h0000_0000_0000_0000, 64'h0000_0000_0000_0000, 1'b0);
        check_pair_same_inputs(64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0001, 1'b0);
        check_pair_same_inputs(64'hFFFF_FFFF_FFFF_FFFF, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        check_pair_same_inputs(64'h8000_0000_0000_0000, 64'h8000_0000_0000_0000, 1'b0);
        check_pair_same_inputs(64'h7FFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0001, 1'b1);
        check_pair_same_inputs(64'hAAAA_AAAA_AAAA_AAAA, 64'h5555_5555_5555_5555, 1'b0);

        // 2) Random identical inputs
        for (i = 0; i < 200; i = i + 1) begin
            check_pair_same_inputs(rand64(), rand64(), $random & 1);
        end

        // 3) Independent inputs (RCA and CSA different)
        for (i = 0; i < 200; i = i + 1) begin
            check_pair_independent_inputs(
                rand64(), rand64(), $random & 1,
                rand64(), rand64(), $random & 1
            );
        end

        $display("adders_top_tb completed without mismatches.");
        $finish;
    end

endmodule


