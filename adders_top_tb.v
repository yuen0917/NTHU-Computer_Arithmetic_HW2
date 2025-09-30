`timescale 1ns/1ps

// ============================================================
// Testbench for adders_top (synchronous wrapper)
// - Drives inputs through registered interface (clk/rst_n)
// - Waits pipeline latency and checks against reference model
// - Parameterizable to test CSA or RCA implementation
// ============================================================
// `include "rca_adder_64.v"
// `include "carry_sel_adder_64.v"
// `include "adders_top.v"

module adders_top_tb;

    // Clock/Reset
    reg clk;
    reg rst_n;

    // DUT I/O
    reg  [63:0] a_in;
    reg  [63:0] b_in;
    reg         cin_in;
    wire [63:0] sum_out;
    wire        cout_out;

    // Device Under Test (set USE_CSA=1 to test CSA, 0 for RCA)
    localparam USE_CSA_TB = 0;
    adders_top #(
        .USE_CSA(USE_CSA_TB),
        .CSA_BLOCK_WIDTH(16)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .a_in(a_in),
        .b_in(b_in),
        .cin_in(cin_in),
        .sum_out(sum_out),
        .cout_out(cout_out)
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

    // Single-DUT check with registered pipeline (2-cycle latency)
    task check_vector(input [63:0] a, input [63:0] b, input cin);
        reg [64:0] exp;
        begin
            exp = ref_add(a, b, cin);
            a_in = a; b_in = b; cin_in = cin;
            @(posedge clk); // input registered
            @(posedge clk); // output registered
            if ({cout_out, sum_out} !== exp) begin
                $display("[DUT mismatch] a=%h b=%h cin=%0d exp={%0d,%h} got={%0d,%h}",
                         a, b, cin, exp[64], exp[63:0], cout_out, sum_out);
                $fatal(1);
            end
        end
    endtask

    // Helpers to produce 64-bit random values using two 32-bit $random calls
    // Some tools require functions to have at least one input; use a dummy input.
    function [63:0] rand64;
        input dummy;
        begin
            rand64 = { $random, $random };
        end
    endfunction

    integer i;

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100MHz
    end

    // Reset
    initial begin
        rst_n = 1'b0;
        a_in = 64'd0; b_in = 64'd0; cin_in = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
    end

    // Main stimulus
    initial begin
        // Wave dump
        $dumpfile("adders_top_tb.vcd");
        $dumpvars(0, adders_top_tb);

        // Wait for reset deassertion
        @(posedge rst_n);
        @(posedge clk);

        // 1) Edge cases
        check_vector(64'h0000_0000_0000_0000, 64'h0000_0000_0000_0000, 1'b0);
        check_vector(64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0001, 1'b0);
        check_vector(64'hFFFF_FFFF_FFFF_FFFF, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        check_vector(64'h8000_0000_0000_0000, 64'h8000_0000_0000_0000, 1'b0);
        check_vector(64'h7FFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0001, 1'b1);
        check_vector(64'hAAAA_AAAA_AAAA_AAAA, 64'h5555_5555_5555_5555, 1'b0);

        // 2) Randoms
        for (i = 0; i < 400; i = i + 1) begin
            check_vector(rand64(0), rand64(0), $random & 1);
        end

        $display("adders_top_tb completed without mismatches. USE_CSA=%0d(0=RCA, 1=CSA)", USE_CSA_TB);
        $finish;
    end

endmodule


