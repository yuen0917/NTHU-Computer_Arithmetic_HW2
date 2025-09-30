// ============================================================
// Synchronous wrapper top for timing analysis of 64-bit adders
// - Select between CSA and RCA via parameter USE_CSA
// - Registers inputs and outputs to expose adder path clearly
// ============================================================

module adders_top #(
    parameter USE_CSA = 1,               // 1 = carry-select, 0 = ripple
    parameter integer CSA_BLOCK_WIDTH = 16 // CSA segment width (e.g., 16 or 8)
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] a_in,
    input  wire [63:0] b_in,
    input  wire        cin_in,
    output reg  [63:0] sum_out,
    output reg         cout_out
);

    // Input registers
    reg [63:0] a_r;
    reg [63:0] b_r;
    reg        cin_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r  <= 64'd0;
            b_r  <= 64'd0;
            cin_r<= 1'b0;
        end else begin
            a_r  <= a_in;
            b_r  <= b_in;
            cin_r<= cin_in;
        end
    end

    // Adder comb outputs
    wire [63:0] sum_w;
    wire        cout_w;

    // Select adder implementation
    generate
        if (USE_CSA) begin : gen_csa
            carry_sel_adder_64 #(
                .BLOCK_WIDTH(CSA_BLOCK_WIDTH)
            ) u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end else begin : gen_rca
            rca_adder_64 u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end
    endgenerate

    // Output registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_out  <= 64'd0;
            cout_out <= 1'b0;
        end else begin
            sum_out  <= sum_w;
            cout_out <= cout_w;
        end
    end

endmodule

