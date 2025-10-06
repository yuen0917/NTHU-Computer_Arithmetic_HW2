// ============================================================
// Moving Average Filter (N=16, WIDTH=16)
// Interface:
//   - Synchronous, one-sample-per-cycle when in_valid=1
//   - Output becomes valid after the first N samples have been accepted
// Notes:
//   - Input/Output use 2's complement signed representation
//   - Division by N(=16) is implemented by arithmetic right shift (>>> 4)
// ============================================================

module moving_avg_filter #(
	parameter WIDTH = 16,
	parameter N = 16
)(
	input                          clk,
	input                          rst_n,
	input                          in_valid,
	input       signed [WIDTH-1:0] in_sample,
	output reg                     out_valid,
	output reg  signed [WIDTH-1:0] out_sample
);

	// For N=16, SHIFT = log2(N) = 4, so we can use arithmetic right shift to divide by N
	localparam SHIFT = 4;

	// Sum width: WIDTH + SHIFT (sufficient for accumulating N samples, avoid overflow in sum)
	localparam SUM_WIDTH = WIDTH + SHIFT;

	// Circular buffer to store the last N samples
	reg signed [WIDTH-1:0] window [0:N-1];

	// Pointer for circular buffer, counter for number of samples filled (0..N)
	reg [SHIFT-1:0] ptr;
	reg [SHIFT:0]   count; // can count up to N

	// Running sum of the current window (signed)
	reg signed [SUM_WIDTH-1:0] sum;

	// Combinational helpers
	wire signed [WIDTH-1:0] old_sample = window[ptr];
	wire signed [SUM_WIDTH-1:0] next_sum = sum + $signed({{(SUM_WIDTH-WIDTH){in_sample[WIDTH-1]}}, in_sample})
		                                         - $signed({{(SUM_WIDTH-WIDTH){old_sample[WIDTH-1]}}, old_sample});

	integer i;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			// Reset internal state
			for (i = 0; i < N; i = i + 1) begin
				window[i] <= {WIDTH{1'b0}};
			end
			ptr        <= {SHIFT{1'b0}};
			count      <= {(SHIFT+1){1'b0}};
			sum        <= {SUM_WIDTH{1'b0}};
			out_valid  <= 1'b0;
			out_sample <= {WIDTH{1'b0}};
		end else begin
			out_valid <= 1'b0; // default low; asserted only when producing output
			if (in_valid) begin
				// Update sum with incoming sample and outgoing (old) sample
				sum <= next_sum;

				// Write new sample into the circular buffer at ptr
				window[ptr] <= in_sample;

				// Advance pointer with wrap-around
				ptr <= ptr == N-1 ? {SHIFT{1'b0}} : ptr + 1'b1;

				// Increase count until it reaches N
				count <= count < N ? count + 1'b1 : count;

				// Produce output average based on the updated sum (includes current sample)
				// Arithmetic right shift preserves sign for 2's complement
				out_sample <= $signed(next_sum >>> SHIFT);

				// Output becomes valid once we have accumulated N samples
				out_valid <= count >= (N-1);
			end
		end
	end

endmodule

