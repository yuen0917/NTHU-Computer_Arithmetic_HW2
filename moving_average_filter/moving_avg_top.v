// ============================================================
// Top-level wrapper for moving average filters (Verilog-2001)
// - Select filter type via parameter FILTER_TYPE
//   0 = Windowed Moving Average (buffer-based)
//   1 = Windowed Moving Average using SRL delay (Xilinx-friendly)
//   2 = Exponential Moving Average (EMA)
// - Pass-through common streaming interface
// - Parameters:
//     WIDTH     : data width (signed)
//     N         : window size (for windowed average)
//     SHIFT     : log2(N), used by SRL filter (ensure N == 2^SHIFT)
//     DO_ROUND  : rounding before right shift in SRL filter
//     K         : EMA shift (alpha = 1 / 2^K)
// ============================================================

module moving_avg_top #(
    parameter FILTER_TYPE = 2,    // 0=buffer, 1=SRL, 2=EMA
    parameter WIDTH       = 16,
    parameter N           = 16,
    parameter SHIFT       = 4,
    parameter DO_ROUND    = 0,
    parameter K           = 3
)(
    input                          clk,
    input                          rst_n,
    input                          in_valid,
    input       signed [WIDTH-1:0] in_sample,
    output                         out_valid,
    output      signed [WIDTH-1:0] out_sample
);

    // Wires for submodule outputs
    wire                     out_valid_w;
    wire signed [WIDTH-1:0]  out_sample_w;

    // Select filter implementation
    generate
        if (FILTER_TYPE == 0) begin : gen_win_buffer
            // Buffer-based windowed moving average
            moving_avg_filter #(
                .WIDTH (WIDTH),
                .N     (N)
            ) u_filter (
                .clk        (clk),
                .rst_n      (rst_n),
                .in_valid   (in_valid),
                .in_sample  (in_sample),
                .out_valid  (out_valid_w),
                .out_sample (out_sample_w)
            );
        end else if (FILTER_TYPE == 1) begin : gen_win_srl
            // SRL-based windowed moving average (ensure N == 2^SHIFT)
            moving_avg_srl_filter #(
                .WIDTH    (WIDTH),
                .N        (N),
                .SHIFT    (SHIFT),
                .DO_ROUND (DO_ROUND)
            ) u_filter (
                .clk        (clk),
                .rst_n      (rst_n),
                .in_valid   (in_valid),
                .in_sample  (in_sample),
                .out_valid  (out_valid_w),
                .out_sample (out_sample_w)
            );
        end else if (FILTER_TYPE == 2) begin : gen_ema
            // Exponential moving average
            moving_avg_ema_filter #(
                .WIDTH (WIDTH),
                .K     (K)
            ) u_filter (
                .clk        (clk),
                .rst_n      (rst_n),
                .in_valid   (in_valid),
                .in_sample  (in_sample),
                .out_valid  (out_valid_w),
                .out_sample (out_sample_w)
            );
        end else begin : gen_default
            // Default to buffer-based moving average on invalid FILTER_TYPE
            moving_avg_filter #(
                .WIDTH (WIDTH),
                .N     (N)
            ) u_filter (
                .clk        (clk),
                .rst_n      (rst_n),
                .in_valid   (in_valid),
                .in_sample  (in_sample),
                .out_valid  (out_valid_w),
                .out_sample (out_sample_w)
            );
        end
    endgenerate

    // Directly connect submodule outputs (no extra cycle of latency)
    assign out_valid  = out_valid_w;
    assign out_sample = out_sample_w;

endmodule



