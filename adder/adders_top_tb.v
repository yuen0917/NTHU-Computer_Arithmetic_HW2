`timescale 1ns/1ps

// ============================================================
// Testbench for adders_top (synchronous wrapper)
// - Drives inputs through registered interface (clk/rst_n)
// - Waits pipeline latency and checks against reference model
// - Parameterizable to test CSA or RCA implementation
// ============================================================

module adders_top_tb;

    // Clock/Reset
    reg clk;
    reg rst_n;

    // DUT I/O
    reg         a_bit_in;
    reg         b_bit_in;
    reg         cin_in;
    reg         start_in;
    wire [63:0] sum_out;
    wire        cout_out;
    wire        ready_out;

    // Device Under Test (set ADDER_TYPE: 0=RCA, 1=CSA, 2=Ling, 3=CLA, 4=Carry-Skip)
    localparam ADDER_TYPE_TB = 4;
    localparam ENABLE_STARTING_STATE_TB = 0;  // 1=enable STARTING state, 0=skip it
    adders_top #(
        .ADDER_TYPE(ADDER_TYPE_TB),
        .CSA_BLOCK_WIDTH(16),
        .ENABLE_STARTING_STATE(ENABLE_STARTING_STATE_TB)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .a_bit_in(a_bit_in),
        .b_bit_in(b_bit_in),
        .cin_in(cin_in),
        .start_in(start_in),
        .sum_out(sum_out),
        .cout_out(cout_out),
        .ready_out(ready_out)
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

    // Serial input test task
    task check_vector(input [63:0] a, input [63:0] b, input cin);
        reg [64:0] exp;
        integer i;
        integer timeout_cnt;
        reg ready_d;
        begin
            exp = ref_add(a, b, cin);

            // Reset inputs
            a_bit_in = 1'b0;
            b_bit_in = 1'b0;
            cin_in = cin;
            start_in = 1'b0;

            // Wait for ready state (ready_out should be low when idle)
            @(posedge clk);
            timeout_cnt = 0;
            while (ready_out && timeout_cnt < 10) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            if (timeout_cnt >= 10) begin
                $display("[ERROR] Timeout waiting for ready_out to go low");
                $fatal(1);
            end

            // Additional safety: wait one more cycle to ensure clean state
            @(posedge clk);

            // Start accumulation
            start_in = 1'b1;
            @(posedge clk);
            start_in = 1'b0;

            // Wait one cycle for state machine to transition to ACCUMULATING
            @(posedge clk);

            // Send 64 bits serially (LSB first)
            for (i = 0; i < 64; i = i + 1) begin
                a_bit_in = a[i];
                b_bit_in = b[i];
                @(posedge clk);
            end

            // Wait for ready_out assertion with timeout protection
            @(posedge clk);
            timeout_cnt = 0;
            while (!ready_out && timeout_cnt < 100) begin
                @(posedge clk);
                timeout_cnt = timeout_cnt + 1;
            end

            if (timeout_cnt >= 100) begin
                $display("[ERROR] Timeout waiting for ready_out assertion");
                $fatal(1);
            end

            // Check results immediately on ready assertion
            if ({cout_out, sum_out} !== exp) begin
                $display("[DUT mismatch] a=%h b=%h cin=%0d exp={%0d,%h} got={%0d,%h}",
                         a, b, cin, exp[64], exp[63:0], cout_out, sum_out);
                $fatal(1);
            end else begin
                $display("[PASS] a=%h b=%h cin=%0d result={%0d,%h}",
                         a, b, cin, cout_out, sum_out);
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
        a_bit_in = 1'b0; b_bit_in = 1'b0; cin_in = 1'b0; start_in = 1'b0;
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
    end

    // Main stimulus
    initial begin
        // Wave dump
        $dumpfile("../../../../../adders_top_tb.vcd");
        $dumpvars(0, adders_top_tb);

        // Wait for reset deassertion
        @(posedge rst_n);
        repeat(5) @(posedge clk);

        // 1) Edge cases
        $display("Starting edge case tests...");
        // Test with simple pattern to debug bit placement
        check_vector(64'h0000_0000_0000_0001, 64'h0000_0000_0000_0000, 1'b0);
        $display("First test completed, starting second test...");
        check_vector(64'hFFFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0001, 1'b0);
        check_vector(64'hFFFF_FFFF_FFFF_FFFF, 64'hFFFF_FFFF_FFFF_FFFF, 1'b1);
        check_vector(64'h8000_0000_0000_0000, 64'h8000_0000_0000_0000, 1'b0);
        check_vector(64'h7FFF_FFFF_FFFF_FFFF, 64'h0000_0000_0000_0001, 1'b1);
        check_vector(64'hAAAA_AAAA_AAAA_AAAA, 64'h5555_5555_5555_5555, 1'b0);

        // 2) Randoms
        $display("Starting random tests...");
        for (i = 0; i < 150; i = i + 1) begin
            check_vector(rand64(0), rand64(0), $random & 1);
        end

        $display("adders_top_tb completed without mismatches. ADDER_TYPE=%0d(0=RCA, 1=CSA, 2=Ling, 3=CLA, 4=Carry-Skip)", ADDER_TYPE_TB);
        $finish;
    end

endmodule


