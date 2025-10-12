// ============================================================
// Synchronous wrapper top for timing analysis of 64-bit adders
// - Select adder type via parameter ADDER_TYPE (0=RCA, 1=CSA, 2=Ling, 3=CLA, 4=Carry-Skip)
// - Serial input interface: 1-bit inputs accumulated over 64 cycles
// - Registers inputs and outputs to expose adder path clearly
// ============================================================

module adders_top #(
    parameter         ADDER_TYPE = 4,      // 0=RCA, 1=CSA, 2=Ling, 3=CLA, 4=Carry-Skip
    parameter integer CSA_BLOCK_WIDTH = 16, // CSA segment width (e.g., 16 or 8)
    parameter         ENABLE_STARTING_STATE = 1  // 1=enable STARTING state, 0=skip it
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        a_bit_in,           // Serial input for operand A (LSB first)
    input  wire        b_bit_in,           // Serial input for operand B (LSB first)
    input  wire        cin_in,             // Carry input
    input  wire        start_in,           // Start signal
    output reg  [63:0] sum_out,
    output reg         cout_out,
    output wire        ready_out           // Ready signal
);

    // Serial accumulation registers
    (* shreg_extract = "no" *) reg [63:0] a_r;
    (* shreg_extract = "no" *) reg [63:0] b_r;
    reg        cin_r;
    reg [6:0]  cycle_cnt;    // Counter for 64 cycles (0-63)
    reg        ready_q;

    // State machine states
    localparam IDLE         = 2'b00;
    localparam STARTING     = 2'b01;
    localparam ACCUMULATING = 2'b10;
    localparam COMPUTING    = 2'b11;

    reg   [1:0] state;        // Current state (need 2 bits for 4 states)
    reg   [1:0] next_state;   // Next state

    // Adder comb outputs
    wire [63:0] sum_w;
    wire        cout_w;


    // State machine: State transition logic (combinational)
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_in) begin
                    if (ENABLE_STARTING_STATE) begin
                        next_state = STARTING;
                    end else begin
                        next_state = ACCUMULATING;
                    end
                end else begin
                    next_state = IDLE;
                end
            end

            STARTING: begin
                if (ENABLE_STARTING_STATE) begin
                    next_state = ACCUMULATING;
                end else begin
                    next_state = IDLE;  // Should not reach here if disabled
                end
            end

            ACCUMULATING: begin
                if (cycle_cnt == 7'd63) begin
                    next_state = COMPUTING;
                end else begin
                    next_state = ACCUMULATING;
                end
            end

            COMPUTING: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // State machine: State register (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // State machine: Input accumulation and output logic (sequential)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all internal registers
            a_r       <= 64'd0;
            b_r       <= 64'd0;
            cin_r     <=  1'b0;
            cycle_cnt <=  7'd0;
            sum_out   <= 64'd0;
            cout_out  <=  1'b0;
            ready_q   <=  1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Initialize registers here if STARTING state is disabled
                    if (!ENABLE_STARTING_STATE && start_in) begin
                        a_r       <= 64'd0;
                        b_r       <= 64'd0;
                        cin_r     <= cin_in;
                        cycle_cnt <=  7'd0;
                    end
                    ready_q <= 1'b0;
                end

                STARTING: begin
                    // Initialize registers in STARTING state (only if enabled)
                    if (ENABLE_STARTING_STATE) begin
                        a_r       <= 64'd0;
                        b_r       <= 64'd0;
                        cin_r     <= cin_in;
                        cycle_cnt <=  7'd0;
                    end
                    ready_q <= 1'b0;
                end

                ACCUMULATING: begin
                    // Place incoming LSB-first bits at correct positions
                    a_r <= {a_bit_in, a_r[63:1]};
                    b_r <= {b_bit_in, b_r[63:1]};

                    if (cycle_cnt == 7'd63) begin
                        cycle_cnt <= 7'd0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 7'd1;
                    end
                    ready_q <= 1'b0;
                end

                COMPUTING: begin
                    // Capture adder results and assert ready
                    sum_out  <= sum_w;
                    cout_out <= cout_w;
                    ready_q  <= 1'b1;
                end

                default: begin
                    // Default case - reset all registers
                    a_r       <= 64'd0;
                    b_r       <= 64'd0;
                    cin_r     <=  1'b0;
                    cycle_cnt <=  7'd0;
                    sum_out   <= 64'd0;
                    cout_out  <=  1'b0;
                    ready_q   <=  1'b0;
                end
            endcase
        end
    end

    assign ready_out = ready_q;

    // Select adder implementation
    generate
        if (ADDER_TYPE == 0) begin : gen_rca
            rca_adder_64 u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end else if (ADDER_TYPE == 1) begin : gen_csa
            carry_sel_adder_64 #(
                .BLOCK_WIDTH(CSA_BLOCK_WIDTH)
            ) u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end else if (ADDER_TYPE == 2) begin : gen_ling
            ling_adder_64 u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end else if (ADDER_TYPE == 3) begin : gen_cla
            cla_adder_64 u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end else if (ADDER_TYPE == 4) begin : gen_carry_skip
            carry_skip_adder_64 u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end else begin : gen_default
            // Default to RCA for invalid ADDER_TYPE
            rca_adder_64 u_adder (
                .a   (a_r),
                .b   (b_r),
                .cin (cin_r),
                .sum (sum_w),
                .cout(cout_w)
            );
        end
    endgenerate

endmodule
