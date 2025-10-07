`timescale 1ns/1ps

// ============================================================
// Testbench for moving_avg_top
// - Drives sequences: zeros, constant, step, random
// - Implements a reference model (same circular buffer + running sum)
// - Compares DUT output against reference on each out_valid
// ============================================================
// `include "moving_avg_top.v"

module moving_avg_top_tb;

    // Parameters (match DUT defaults)
    localparam integer FILTER_TYPE =  0;            // 0=buffer, 1=SRL, 2=EMA
    localparam integer WIDTH       = 16;            // data width
    localparam integer N           = 16;            // window size
    localparam integer SHIFT       =  4;            // log2(N)
    localparam integer DO_ROUND    =  0;            // 1: add 0.5 LSB before shift, 0: no rounding
    localparam integer K           =  3;            // alpha = 1/2^K = 1/8
    localparam integer REF_ACCW    = WIDTH + K + 1; // EMA reference state (used when FILTER_TYPE==2)

    // DUT I/O
    reg                     clk;
    reg                     rst_n;
    reg                     in_valid;
    reg  signed [WIDTH-1:0] in_sample;
    wire                    out_valid;
    wire signed [WIDTH-1:0] out_sample;

    // Instantiate DUT
    moving_avg_top #(
        .FILTER_TYPE(FILTER_TYPE),
        .WIDTH(WIDTH),
        .N(N),
        .SHIFT(SHIFT),
        .DO_ROUND(DO_ROUND),
        .K(K)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .in_sample(in_sample),
        .out_valid(out_valid),
        .out_sample(out_sample)
    );

    // Clock generation: 100 MHz
    initial clk = 1'b0;
    always #5 clk = ~clk; // 10ns period

    // Reference model state
    reg  signed [WIDTH-1:0]       window [0:N-1];
    reg         [SHIFT-1:0]       ref_ptr;
    reg         [SHIFT:0]         ref_count;
    reg  signed [WIDTH+SHIFT-1:0] ref_sum;
    reg  signed [WIDTH-1:0]       ref_out_sample;
    reg                           ref_out_valid;

    integer i;
    reg signed [WIDTH-1:0] rnd_sample; // moved out of unnamed block (Verilog-2001 compliant)

    // EMA reference state (used when FILTER_TYPE==2)
    reg signed [REF_ACCW-1:0] y_acc_ref;

    // Unified reference reset: choose by FILTER_TYPE
    task ref_reset_auto;
        integer k;
        begin
            if (FILTER_TYPE == 2) begin
                // EMA reset
                y_acc_ref      = {REF_ACCW{1'b0}};
                ref_out_valid  = 1'b0;
                ref_out_sample = {WIDTH{1'b0}};
            end else begin
                // Moving-average (buffer/SRL) reset
                for (k = 0; k < N; k = k + 1) begin
                    window[k] = 0;
                end
                ref_ptr        = 0;
                ref_count      = 0;
                ref_sum        = 0;
                ref_out_valid  = 1'b0;
                ref_out_sample = 0;
            end
        end
    endtask

    // Unified reference push: choose by FILTER_TYPE
    task ref_push_auto(input signed [WIDTH-1:0] sample);
        reg signed [WIDTH-1:0]       old_sample;
        reg signed [WIDTH+SHIFT-1:0] next_sum;
        reg        [WIDTH+SHIFT-1:0] round_add;
        reg signed [WIDTH+SHIFT-1:0] next_sum_rnd;
        reg signed [WIDTH+SHIFT-1:0] avg_ext;
        reg signed [REF_ACCW-1:0]    x_ext;
        reg signed [REF_ACCW-1:0]    diff;
        reg signed [REF_ACCW-1:0]    step;
        begin
            if (FILTER_TYPE == 2) begin
                // EMA behavior
                x_ext          = {{(REF_ACCW-WIDTH){sample[WIDTH-1]}}, sample};
                diff           = x_ext - y_acc_ref;
                step           = (diff >>> K);
                ref_out_sample = y_acc_ref[REF_ACCW-1 : (REF_ACCW-WIDTH)];
                y_acc_ref      = y_acc_ref + step;
                ref_out_valid  = 1'b1;
            end else begin
                // Moving-average (buffer/SRL) behavior
                old_sample = window[ref_ptr];
                next_sum   = ref_sum
                             + $signed({{(WIDTH+SHIFT-WIDTH){sample[WIDTH-1]}}, sample})
                             - $signed({{(WIDTH+SHIFT-WIDTH){old_sample[WIDTH-1]}}, old_sample});

                // write new sample
                window[ref_ptr] = sample;

                // advance pointer
                if (ref_ptr == N-1)
                    ref_ptr = 0;
                else
                    ref_ptr = ref_ptr + 1'b1;

                // update count up to N
                if (ref_count < N)
                    ref_count = ref_count + 1'b1;

                // update sum and outputs
                ref_sum        = next_sum;

                // match DUT rounding behavior
                if (DO_ROUND && (SHIFT > 0) && FILTER_TYPE == 1) begin
                    round_add  = {{(WIDTH+SHIFT-SHIFT){1'b0}}, 1'b1, {(SHIFT-1){1'b0}}};
                end else begin
                    round_add  = {(WIDTH+SHIFT){1'b0}};
                end

                // match DUT rounding behavior
                next_sum_rnd   = next_sum + $signed(round_add);
                avg_ext        = next_sum_rnd >>> SHIFT;
                ref_out_sample = avg_ext[WIDTH-1:0];
                ref_out_valid  = (ref_count >= (N-1));
            end
        end
    endtask

    // Drive one-cycle valid sample
    task drive_sample(input signed [WIDTH-1:0] sample);
        begin
            @(negedge clk);
            in_valid  <= 1'b1;
            in_sample <= sample;
            @(negedge clk);
            in_valid  <= 1'b0;
            in_sample <= 0;
        end
    endtask

    // Check DUT vs reference when out_valid is asserted
    task check_outputs;
        begin
            if (out_valid && ref_out_valid) begin
                if (out_sample !== ref_out_sample) begin
                    $display("[TIME %0t] SAMPLE mismatch: out_sample=%0h ref_out_sample=%0h i = %0d", $time, out_sample, ref_out_sample, i);
                    $fatal(1, "Mismatch detected");
                end else begin
                    $display("[TIME %0t] SAMPLE match: out_sample=%0h ref_out_sample=%0h i = %0d", $time, out_sample, ref_out_sample, i);
                end
            end
        end
    endtask

    // Monitor DUT outputs to compare against reference each cycle
    always @(negedge clk) begin
        if (rst_n) begin
          #1 check_outputs();
        end
    end

    // Test sequence
    initial begin
        // Wave dump
        $dumpfile("../../../../../moving_avg_top_tb.vcd");
        $dumpvars(0, moving_avg_top_tb);

        // Init
        in_valid  = 1'b0;
        in_sample = 0;
        rst_n     = 1'b0;
        ref_reset_auto();

        // Reset pulse
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        // 1) Zeros (10 samples)
        for (i = 0; i < 10; i = i + 1) begin
            drive_sample(0);
            ref_push_auto(0);
        end

        // 2) Constant (20 samples of 100)
        for (i = 0; i < 20; i = i + 1) begin
            drive_sample(100);
            ref_push_auto(100);
        end

        // 3) Step: 10 samples of 0, then 20 samples of 200
        for (i = 0; i < 10; i = i + 1) begin
            drive_sample(0);
            ref_push_auto(0);
        end
        for (i = 0; i < 20; i = i + 1) begin
            drive_sample(200);
            ref_push_auto(200);
        end

        // 4) Random (50 samples in a safe range)
        for (i = 0; i < 50; i = i + 1) begin
            // Limit magnitude to avoid extreme values in small-width signed arithmetic
            // Generate once per iteration to ensure DUT and reference see identical samples
            rnd_sample = $random;
            rnd_sample = rnd_sample % 512; // roughly -511..+511
            drive_sample(rnd_sample);
            ref_push_auto(rnd_sample);
        end

        // Let outputs settle a few cycles
        repeat (10) @(negedge clk);

        $display("TB completed without mismatches. WIDTH=%0d N=%0d", WIDTH, N);
        $finish;
    end

endmodule


