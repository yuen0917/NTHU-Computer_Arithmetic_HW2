// ============================================================
// Moving Average (All-in-One, SRL internal, Verilog-2001)
// - Exact N-point average, 1 sample/clock when in_valid=1
// - Synthesis (Vivado/Xilinx): per-bit SRLC32E delay of N
// - Simulation (any sim): behavioral shift (no vendor lib)
// - Option: rounding before >>> SHIFT
// - Require: N <= 32 and N == 2^SHIFT (set SHIFT manually)
// ============================================================

module moving_avg_srl_filter #(
  parameter WIDTH    = 16,
  parameter N        = 16,  // 1..32
  parameter SHIFT    = 4,   // log2(N) (e.g., N=16 -> SHIFT=4)
  parameter DO_ROUND = 1    // 1: add 0.5 LSB before shift, 0: no rounding
)(
  input                          clk,
  input                          rst_n,
  input                          in_valid,
  input       signed [WIDTH-1:0] in_sample,
  output reg                     out_valid,
  output reg  signed [WIDTH-1:0] out_sample
);

  // Accumulator bit width
  localparam SUM_WIDTH = WIDTH + SHIFT;

  // ============== SRL delay line: get x[n-N] = old_sample = dout = sample from N cycles ago ==============
  wire [WIDTH-1:0] old_sample_u;

`ifdef SYNTHESIS
  // Vivado synthesis path: one SRLC32E per bit
  genvar b;
  generate
      for (b = 0; b < WIDTH; b = b + 1) begin : g_srl
          SRLC32E #(
              .INIT(32'h00000000)
          ) u_srl (
              .Q   (old_sample_u[b]),     // Output bit delayed by (A+1) cycles
              .Q31 (),
              .A   (N-1),                 // Delay N cycles: A+1=N → A=N-1
              .CE  (in_valid),            // Shift-in only when in_valid=1
              .CLK (clk),
              .D   (in_sample[b])
          );
      end
  endgenerate
`else
  // Simulation path (behavioral, no vendor library)
  reg [WIDTH-1:0] shreg [0:N-1];
  integer i;
  assign old_sample_u = shreg[N-1];

  always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          for (i = 0; i < N; i = i + 1) begin
              shreg[i] <= {WIDTH{1'b0}};
          end
      end else if (in_valid) begin
          for (i = N-1; i > 0; i = i - 1) begin
              shreg[i] <= shreg[i-1];
          end
          shreg[0] <= in_sample;
      end
  end
`endif

  wire signed [WIDTH-1:0] old_sample = old_sample_u;

  // ============== Running Sum: sum + in - old ==============
  reg  signed [SUM_WIDTH-1:0] sum;

  wire signed [SUM_WIDTH-1:0] in_ext  = {{(SUM_WIDTH-WIDTH){in_sample[WIDTH-1]}},  in_sample};
  wire signed [SUM_WIDTH-1:0] old_ext = {{(SUM_WIDTH-WIDTH){old_sample[WIDTH-1]}}, old_sample};

  wire signed [SUM_WIDTH-1:0] next_sum = sum + in_ext - old_ext;

  // ============== Optional rounding then right shift ==============
  // Add 1 at bit position (SHIFT-1) for half-up rounding (round_add=0 if SHIFT==0)
  wire [SUM_WIDTH-1:0] round_add = (DO_ROUND && (SHIFT > 0))
                                   ? ({{(SUM_WIDTH-SHIFT){1'b0}}, 1'b1, {(SHIFT-1){1'b0}}})
                                   : {SUM_WIDTH{1'b0}};

  wire signed [SUM_WIDTH-1:0] next_sum_rnd = next_sum + round_add;

  // ============== Warm-up counter (assert out_valid after receiving N samples) ==============
  reg [SHIFT:0] warm_cnt;

  // ============== Sequential logic: update sum and output average ==============

  wire signed [SUM_WIDTH-1:0] avg_ext = next_sum_rnd >>> SHIFT;

  always @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          sum        <= {SUM_WIDTH{1'b0}};
          warm_cnt   <= { (SHIFT+1){1'b0} };
          out_valid  <= 1'b0;
          out_sample <= {WIDTH{1'b0}};
      end else if (in_valid) begin
          sum <= next_sum;

          // Average: arithmetic right shift (preserves sign)
          out_sample <= avg_ext[WIDTH-1:0];

          // Warm-up control
          if (warm_cnt < (N-1)) begin
              warm_cnt  <= warm_cnt + 1'b1;
              out_valid <= 1'b0;
          end else begin
              out_valid <= 1'b1;
          end
      end
  end

  // ============== Optional sanity checks (simulation-only, non-synthesizable) ==============
`ifndef SYNTHESIS
  initial begin
      if (N < 1 || N > 32) begin
          $display("ERROR: N(%0d) must be in 1..32.", N);
      end
      // Ensure SHIFT = log2(N) by design constraint
      // You may add additional checks for simulation hints (non-synthesizable):
      // e.g., N=16 and SHIFT=4 is consistent
  end
`endif

endmodule
