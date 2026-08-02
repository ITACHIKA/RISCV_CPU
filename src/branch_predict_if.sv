`timescale 1ns / 1ps
import riscv_pkg::*;
module branch_predict_if(
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic [31:0] pc,

    // Outputs
    output pc_predict_result_t branch_predict_result
);

always_comb begin
    // simple branch predictor: always predict not taken
    if(!reset_n) begin
        branch_predict_result.predict_taken = 1'b0;
        branch_predict_result.predicted_pc = 32'd0;
    end
    else begin
        branch_predict_result.predict_taken = 1'b0;
        branch_predict_result.predicted_pc = pc + 4;
    end
end

endmodule
