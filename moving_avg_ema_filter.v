// ============================================================
// Exponential Moving Average (EMA) with alpha = 1/8
// - Ultra low resource, 1-cycle latency, no warm-up window
// - Not an exact N-point average (but similar smoothing)
// ============================================================
module moving_avg_ema_filter #(
  parameter integer WIDTH = 16,
  parameter integer K     = 3   // alpha = 1/2^K = 1/8
)(
  input  wire                     clk,
  input  wire                     rst_n,
  input  wire                     in_valid,
  input  wire signed [WIDTH-1:0]  in_sample,
  output reg                      out_valid,
  output reg  signed [WIDTH-1:0]  out_sample
);
  localparam integer ACCW = WIDTH + K + 1; // guard bits
  reg signed [ACCW-1:0] y_acc;

  // target: y += (x - y) >> K
  wire signed [ACCW-1:0] x_ext = {{(ACCW-WIDTH){in_sample[WIDTH-1]}}, in_sample};
  wire signed [ACCW-1:0] diff  = x_ext - y_acc;
  wire signed [ACCW-1:0] step  = (diff >>> K);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      y_acc     <= {ACCW{1'b0}};
      out_valid <= 1'b0;
      out_sample<= {WIDTH{1'b0}};
    end else if (in_valid) begin
      y_acc     <= y_acc + step;
      out_sample<= y_acc[ACCW-1 -: WIDTH]; // can be changed to rounding or saturation
      out_valid <= 1'b1;
    end
  end
endmodule
