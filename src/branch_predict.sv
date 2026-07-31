`timescale 1ns / 1ps
import riscv_pkg::*;
module branch_predict(
    input logic clk,
    input logic reset_n,
    input logic [31:0] pc,
    output branch_predict_result_t predict_result
);

always_comb begin
    // simple branch predictor: always predict not taken
    predict_result.predict_taken = 1'b0;
    predict_result.predicted_pc = pc + 4;
end

endmodule