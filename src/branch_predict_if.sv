`timescale 1ns / 1ps
import riscv_pkg::*;
module branch_predict_if(
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic [31:0] pc,

    // Outputs
    output branch_predict_result_t branch_predict_result
);

always_comb begin
    // simple branch predictor: always predict not taken
    branch_predict_result.predict_taken = 1'b0;
    branch_predict_result.predicted_pc = pc + 4;
end

endmodule
