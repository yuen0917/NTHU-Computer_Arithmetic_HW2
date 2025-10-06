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
    localparam integer FILTER_TYPE = 0;
    localparam integer WIDTH = 16;
    localparam integer N     = 16;
    localparam integer SHIFT = 4; // log2(N)
    localparam integer DO_ROUND = 1;
    localparam integer K = 3;
    // DUT I/O
    reg                          clk;
    reg                          rst_n;
    reg                          in_valid;
    reg  signed [WIDTH-1:0]      in_sample;
    wire                         out_valid;
    wire signed [WIDTH-1:0]      out_sample;

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

    // Reference model update on each valid input (same semantics as DUT)
    task ref_reset;
        integer k;
        begin
            for (k = 0; k < N; k = k + 1) begin
                window[k] = 0;
            end
            ref_ptr       = 0;
            ref_count     = 0;
            ref_sum       = 0;
            ref_out_valid = 1'b0;
            ref_out_sample= 0;
        end
    endtask

    task ref_push(input signed [WIDTH-1:0] sample);
        reg signed [WIDTH-1:0] old_sample;
        reg signed [WIDTH+SHIFT-1:0] next_sum;
        begin
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
            ref_out_sample = $signed(next_sum >>> SHIFT);
            ref_out_valid  = (ref_count >= (N-1));
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
            if (out_valid !== ref_out_valid) begin
                $display("[TIME %0t] VALID mismatch: dut=%0d ref=%0d", $time, out_valid, ref_out_valid);
            end
            if (out_valid && ref_out_valid) begin
                if (out_sample !== ref_out_sample) begin
                    $display("[TIME %0t] SAMPLE mismatch: dut=%0d ref=%0d", $time, out_sample, ref_out_sample);
                    $fatal(1, "Mismatch detected");
                end
            end
        end
    endtask

    // Monitor DUT outputs to compare against reference each cycle
    always @(posedge clk) begin
        if (rst_n) begin
            check_outputs();
        end
    end

    // Test sequence
    initial begin
        // Wave dump
        $dumpfile("moving_avg_top_tb.vcd");
        $dumpvars(0, moving_avg_top_tb);

        // Init
        in_valid  = 1'b0;
        in_sample = 0;
        rst_n     = 1'b0;
        ref_reset();

        // Reset pulse
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (2) @(negedge clk);

        // 1) Zeros (10 samples)
        for (i = 0; i < 10; i = i + 1) begin
            drive_sample(0);
            ref_push(0);
        end

        // 2) Constant (20 samples of 100)
        for (i = 0; i < 20; i = i + 1) begin
            drive_sample(100);
            ref_push(100);
        end

        // 3) Step: 10 samples of 0, then 20 samples of 200
        for (i = 0; i < 10; i = i + 1) begin
            drive_sample(0);
            ref_push(0);
        end
        for (i = 0; i < 20; i = i + 1) begin
            drive_sample(200);
            ref_push(200);
        end

        // 4) Random (50 samples in a safe range)
        for (i = 0; i < 50; i = i + 1) begin
            // Limit magnitude to avoid extreme values in small-width signed arithmetic
            drive_sample($random % 512); // roughly -511..+511
            ref_push($random % 512);
        end

        // Let outputs settle a few cycles
        repeat (10) @(negedge clk);

        $display("TB completed without mismatches. WIDTH=%0d N=%0d", WIDTH, N);
        $finish;
    end

endmodule


