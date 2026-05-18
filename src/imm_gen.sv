`timescale 1ns / 1ps
import riscv_pkg::*;

module imm_gen
(
    input logic [31:0] instruction,
    input imm_type_t imm_type,
    output logic [31:0] imm_out
);

always_comb begin
    unique case(imm_type)
        IMM_NONE: imm_out = 32'd0;
        IMM_I: imm_out = {{20{instruction[31]}}, instruction[31:20]};
        IMM_S: imm_out = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        IMM_B: imm_out = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
        IMM_U: imm_out = {instruction[31:12],{12{1'b0}}};
        IMM_J: imm_out = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20],instruction[30:21],1'b0};
        default: imm_out = 32'd0;
    endcase
end

endmodule