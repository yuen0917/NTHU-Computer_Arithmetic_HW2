// ============================================================
// 64-bit Ripple Carry Adder (Vivado will map to native CARRY4)
// ============================================================
module rca_adder_64 (
    input  wire [63:0] a,     // 64-bit input A
    input  wire [63:0] b,     // 64-bit input B
    input  wire        cin,   // carry input
    output wire [63:0] sum,   // 64-bit result
    output wire        cout   // final carry out
);
    // Use the '+' operator, Vivado will automatically derive the carry chain
    assign {cout, sum} = a + b + cin;

endmodule
