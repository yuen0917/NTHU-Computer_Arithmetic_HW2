// ============================================================
// 64-bit Carry-Select Adder (Vivado will map to native CARRY4)
// ============================================================
module carry_sel_adder_64 (
	input  wire [63:0] a,
	input  wire [63:0] b,
	input  wire        cin,
	output wire [63:0] sum,
	output wire        cout
);
	parameter BLOCK_WIDTH = 16;  // Can be changed to 8 for more segments

	wire [3:0] carry;  // carry out for each 16-bit block

	// Block 0: low 16-bit, ripple directly use FPGA carry chain
	assign {carry[0], sum[15:0]} = a[15:0] + b[15:0] + cin;

	// Block 1~3: 48-bit, pre-calculate two cases
	genvar i;
	generate
		for (i = 1; i < 4; i = i + 1) begin : cs_block
			wire [BLOCK_WIDTH:0] sum0; // cin=0
			wire [BLOCK_WIDTH:0] sum1; // cin=1

			// Pre-calculate two cases
			assign {sum0[BLOCK_WIDTH], sum0[BLOCK_WIDTH - 1:0]} =
			       a[i * BLOCK_WIDTH +: BLOCK_WIDTH] +
			       b[i * BLOCK_WIDTH +: BLOCK_WIDTH] + 1'b0;

			assign {sum1[BLOCK_WIDTH], sum1[BLOCK_WIDTH-1:0]} =
			       a[i * BLOCK_WIDTH +: BLOCK_WIDTH] +
			       b[i * BLOCK_WIDTH +: BLOCK_WIDTH] + 1'b1;

			// Select based on the carry of the previous block
			assign {carry[i], sum[i * BLOCK_WIDTH +: BLOCK_WIDTH]} = carry[i - 1] ? sum1 : sum0;
		end
	endgenerate

	assign cout = carry[3];
endmodule
