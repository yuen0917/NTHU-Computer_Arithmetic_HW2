# NTHU EE5410 Computer Arithmetic - Homework 2

## Problem Statement

1) Moving Average Filter (N = 16)
    - Input: 16-bit signed (2's complement). Output: 16-bit signed (2's complement).
    - Average over the most recent 16 samples.
      a) List the filter specification and state your design optimization goal. Provide evaluation procedure and results.
      b) Provide a simple estimation of performance and complexity of your designed filter.

2) 64-bit Adder
    - Build an adder for two 64-bit signed integers with the lowest possible critical-path delay.

## Modules

- Moving-average Filters
  - `moving_avg_filter`: Windowed average, circular buffer + running sum.
  - `moving_avg_srl_filter`: Windowed average using Xilinx SRL (`SRLC32E`) delay; optional rounding.
  - `moving_avg_ema_filter`: Exponential moving average (EMA), `alpha = 1/2^K`.
- Moving-average Wrapper
  - `moving_avg_top`: Selects among filters via `FILTER_TYPE` (0=buffer, 1=SRL, 2=EMA).
- 64-bit Adders
  - `rca_adder_64`: 64-bit ripple-carry adder.
  - `carry_sel_adder_64`: 64-bit carry-select adder.
  - `carry_skip_adder_64`: 64-bit carry-skip adder (8-bit blocks).
  - `cla_adder_64`: 64-bit two-level carry-lookahead adder (4-bit blocks, grouped by 4).
  - `ling_adder_64`: 64-bit Ling-style adder (h-carry form).
- 64-bit Adder Wrapper
  - `adders_top`: Convenience top instantiating adders.

## Key Parameters and Constraints

- Moving-average
  - Windowed filters:
    - `WIDTH` (default 16), `N` (default 16), `SHIFT = log2(N)`(default 4).
    - SRL constraints: `N` (default 16) and must satisfy `N == 2^SHIFT`.
    - `DO_ROUND` (SRL): 1 → add 0.5 LSB before shift (round half up); 0 → truncate.
  - EMA:
    - `K` controls smoothing (`alpha = 1/2^K`), single-cycle latency, no warm-up.

- 64-bit Adders
  - `ADDER_TYPE` (for wrapper): 0=RCA, 1=CSA, 2=Ling, 3=CLA, 4=Carry-Skip.
  - `CSA_BLOCK_WIDTH`: 16 or 8 (for carry-select adder segmentation).
  - All adders operate on signed 64-bit inputs; `adders_top` provides a unified, registered interface for timing analysis.

## Quick Simulation (Icarus Verilog)

- Moving-average top TB (select implementation via `FILTER_TYPE`)

```text
iverilog -g2005 -o ma_tb.out \
  moving_avg_filter.v moving_avg_srl_filter.v moving_avg_ema_filter.v \
  moving_avg_top.v moving_avg_top_tb.v
vvp ma_tb.out
```

- 64-bit adders top TB

```text
iverilog -g2005 -o adders_tb.out \
  rca_adder_64.v carry_sel_adder_64.v carry_skip_adder_64.v \
  cla_adder_64.v ling_adder_64.v adders_top.v adders_top_tb.v
vvp adders_tb.out
```

- Waveform output: `moving_avg_top_tb.vcd`, `adders_top_tb.vcd`

## How to Select Filter / Adder

- In `moving_avg_top_tb.v` set:
  - `FILTER_TYPE`: 0=buffer, 1=SRL, 2=EMA
  - For SRL: set consistent `N` and `SHIFT` (e.g., N=16, SHIFT=4, and ensure `N == 2^SHIFT`) and choose `DO_ROUND`.
- In `adders_top_tb.v` set:
  - `ADDER_TYPE`: 0=RCA, 1=CSA, 2=Ling, 3=CLA, 4=Carry-Skip.
  - `CSA_BLOCK_WIDTH`: 16 or 8 (for carry-select adder segmentation).

## Vivado Notes

- Add these files to simulation/synthesis:
  - Filters: `moving_avg_filter.v`, `moving_avg_srl_filter.v`, `moving_avg_ema_filter.v`, `moving_avg_top.v`, `moving_avg_top_tb.v`
  - Adders: `rca_adder_64.v`, `carry_sel_adder_64.v`, `carry_skip_adder_64.v`, `cla_adder_64.v`, `ling_adder_64.v`, `adders_top.v`, `adders_top_tb.v`
  - Constraints: `HW2_constraint.xdc`
- On Xilinx devices, SRL version infers `SRLC32E`; behavioral model is used in generic simulation.

## Repository Layout (condensed)

- Filters: `moving_avg_filter.v`, `moving_avg_srl_filter.v`, `moving_avg_ema_filter.v`, `moving_avg_top.v`
- Adders: `rca_adder_64.v`, `carry_sel_adder_64.v`, `carry_skip_adder_64.v`, `cla_adder_64.v`, `ling_adder_64.v`, `adders_top.v`
- Testbench: `moving_avg_top_tb.v`, `adders_top_tb.v`
- Docs/Proj: `HW2.pdf`
- Constraints: `HW2_constraint.xdc`
- Xilinx Project: `HW2_adders_vivado/`, `HW2_moving_avg_filter_vivado/`

## License/Notes

- Source comments are in English. Use, cite, and document modifications as needed.
