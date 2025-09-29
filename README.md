# NTHU EE5410 Computer Arithmetic - Homework 2

## Problem Statement

Implement and evaluate the following RTL modules and their verification/synthesis flows:

- Moving Average Filter:
  - Design a parameterized moving average filter with defaults `WIDTH=16`, `N=16`.
  - Use a circular buffer and a running sum; output becomes valid after the first N samples.
  - Inputs/outputs are signed (2's complement). Implement division by N using arithmetic right shift (`>>> log2(N)`).
  - Provide a testbench to apply step/constant/random sequences and verify latency and correctness versus a software model.

- 64-bit Ripple Carry Adder (RCA):
  - Implement a 64-bit adder with carry-in and carry-out using the `+` operator.
  - Verify correctness across randomized vectors and edge cases.

- 64-bit Carry-Select Adder (CSA):
  - Implement a 64-bit CSA partitioned by `BLOCK_WIDTH` (default 16; other options like 8 are acceptable).
  - Pre-compute sums for `cin=0` and `cin=1` per block, then select based on the previous block's carry.
  - Verify correctness and compare timing/resource usage with RCA.

- Synthesis/Implementation (Vivado):
  - Add all RTL to a Vivado project, target the given FPGA device, and run synthesis/implementation.
  - Report timing (critical path/maximum frequency) and resource utilization.
  - For CSA, sweep `BLOCK_WIDTH` to discuss timing/area trade-offs.

- Deliverables:
  - RTL sources, self-checking testbenches, simulation scripts/waveforms.
  - A short report summarizing methodology, results (correctness, timing, resources), and discussion/analysis.

## HW2 Documentation (Moving Average and 64-bit Adders)

This repository contains the following Verilog modules:

- **moving_avg_filter**: N=16 moving average filter using a circular buffer and a running sum (signed data supported).
- **rca_adder_64**: 64-bit Ripple Carry Adder implemented with `+`; the synthesis tool (Vivado) infers the native CARRY chain.
- **carry_sel_adder_64**: 64-bit Carry-Select Adder. The lower 16 bits use ripple; the remaining blocks pre-compute for cin=0/1 and select via a mux.

---

## Repository Layout

- `moving_avg_filter.v`
- `rca_adder_64.v`
- `carry_sel_adder_64.v`
- `adders_top.v`
- `moving_avg_filter_tb.v`
- `adders_top_tb.v`
- `HW2_Vivado/`: Vivado project directory (tool-generated)
- `HW2.pdf`: Homework specification

---

## Module Details

### 1) moving_avg_filter

- **Parameters**:
  - `WIDTH`: data width (default 16)
  - `N`: window size (default 16). Internally uses `SHIFT = log2(N) = 4`; arithmetic right shift divides the sum by N.
- **Interface**:
  - `clk`: clock
  - `rst_n`: asynchronous active-low reset
  - `in_valid`: input sample valid (one sample per cycle when high)
  - `in_sample[WIDTH-1:0]`: signed input sample (2's complement)
  - `out_valid`: asserted once N samples have been accumulated; then valid every cycle
  - `out_sample[WIDTH-1:0]`: signed average output (2's complement)
- **Behavior**:
  - Maintains a length-N circular buffer `window` and a running sum `sum`.
  - On each `in_valid`: `sum = sum + new_sample - oldest_sample`; circular pointer increments.
  - `out_sample = sum >>> SHIFT` (arithmetic right shift to preserve sign).
  - `out_valid` is high starting from the N-th accepted sample.

Instantiation example:

```verilog
localparam WIDTH = 16;
localparam N     = 16;

wire                    out_valid;
wire signed [WIDTH-1:0] out_sample;

moving_avg_filter #(
    .WIDTH(WIDTH),
    .N(N)
) u_maf (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_sample(in_sample),
    .out_valid(out_valid),
    .out_sample(out_sample)
);
```

Recommended tests:

- Constant inputs (all zeros, constant value) to verify steady-state average.
- Step input to verify the first N-sample transient and steady-state behavior.
- Signed extremes (max/min) to check overflow behavior and sign handling.

---

### 2) rca_adder_64

- **Interface**:
  - `a[63:0]`, `b[63:0]`: operands
  - `cin`: carry in
  - `sum[63:0]`: sum output
  - `cout`: carry out
- **Implementation**:
  - `assign {cout, sum} = a + b + cin;` The synthesis tool infers the FPGA carry chain.

Instantiation example:

```verilog
wire [63:0] sum;
wire        cout;

rca_adder_64 u_rca (
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
);
```

---

### 3) carry_sel_adder_64

- **Parameter**:
  - `BLOCK_WIDTH`: block width (default 16; 8 is also possible as a timing/area trade-off)
- **Interface**:
  - `a[63:0]`, `b[63:0]`, `cin`, `sum[63:0]`, `cout`
- **Implementation**:
  - Lower 16 bits computed via ripple.
  - Remaining blocks pre-compute results for `cin=0` and `cin=1`, then select using the previous block's carry (carry-select).
- **Notes**:
  - `carry[3]` is the final `cout`.
  - Different `BLOCK_WIDTH` values change the critical path and resource usage.

Instantiation example:

```verilog
wire [63:0] sum;
wire        cout;

carry_sel_adder_64 #(
    .BLOCK_WIDTH(16)
) u_csa (
    .a(a),
    .b(b),
    .cin(cin),
    .sum(sum),
    .cout(cout)
);
```

---

### 4) adders_top

- **Purpose**:
  - Convenience top that instantiates both 64-bit adders for side-by-side comparison.
- **Parameter**:
  - `CSA_BLOCK_WIDTH`: block width for `carry_sel_adder_64` (default 16)
- **Interface**:
  - RCA inputs: `a_rca[63:0]`, `b_rca[63:0]`, `cin_rca`
  - CSA inputs: `a_csa[63:0]`, `b_csa[63:0]`, `cin_csa`
  - RCA outputs: `sum_rca[63:0]`, `cout_rca`
  - CSA outputs: `sum_csa[63:0]`, `cout_csa`

Instantiation example:

```verilog
wire [63:0] sum_rca, sum_csa;
wire        cout_rca, cout_csa;

adders_top #(
    .CSA_BLOCK_WIDTH(16)
) u_top (
    .a_rca(a_rca), .b_rca(b_rca), .cin_rca(cin_rca),
    .a_csa(a_csa), .b_csa(b_csa), .cin_csa(cin_csa),
    .sum_rca(sum_rca), .cout_rca(cout_rca),
    .sum_csa(sum_csa), .cout_csa(cout_csa)
);
```

---

## Simulation and Verification

You may use Icarus Verilog, Verilator, or Vivado Simulator.

- **Icarus Verilog examples (per testbench)**:
  - Moving average filter TB:
    - Compile: `iverilog -g2012 -o maf_tb.out moving_avg_filter.v moving_avg_filter_tb.v`
    - Run: `vvp maf_tb.out`
    - Waves: generates `moving_avg_filter_tb.vcd`
  - Adders top TB:
    - Compile: `iverilog -g2012 -o adders_tb.out rca_adder_64.v carry_sel_adder_64.v adders_top.v adders_top_tb.v`
    - Run: `vvp adders_tb.out`
    - Waves: generates `adders_top_tb.vcd`

- **Vivado Simulator**:
  - In `HW2_Vivado`, add a testbench and include the three RTL files in simulation sources.
  - Add `-sv` in simulation settings if using a SystemVerilog testbench.

Test recommendations:

- **Adders**: randomized (a, b, cin) compared against a software reference model; check `sum, cout`.
- **Filter**: compare with a software moving-average model, paying attention to `out_valid` latency and arithmetic right-shift sign behavior.

---

## Synthesis and Implementation (Vivado)

1. Open the `HW2_Vivado` project (or create a new one) and add the three RTL files.
2. Select the target FPGA device, then run Synthesis and Implementation.
3. For `carry_sel_adder_64`, experiment with different `BLOCK_WIDTH` values to evaluate timing/resource trade-offs.
4. Review timing reports and critical paths:
   - `rca_adder_64`: ripple carry chain.
   - `carry_sel_adder_64`: mux select delay + per-block adder delay.
   - `moving_avg_filter`: add/sub path and arithmetic shift (wiring for shift).

---

## Assumptions and Limitations

- `moving_avg_filter` defaults to `N=16` with `SHIFT=4`. If you change `N`, also change `SHIFT=log2(N)` and ensure `N` is a power of two.
- The accumulator width uses `SUM_WIDTH = WIDTH + SHIFT` to hold the N-sample sum. If `WIDTH` or `N` changes, reassess overflow safety.
- All data is expected to be in 2's complement.

---

## Version Control

- Include testbenches and scripts in version control. Avoid committing large Vivado intermediate artifacts (use `.gitignore`).

---

## License and Author Notes

- Source comments are in English for maintainability.
- If reusing or referencing, please cite the source and document modifications in your report.
