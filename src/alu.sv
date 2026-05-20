`timescale 1ns / 1ps
import riscv_pkg::*;
module alu (
    input logic [31:0] a,
    input logic [31:0] b,
    input alu_op_t alu_op,
    input logic less_signed,
    input logic less_unsigned,
    output logic [31:0] result
);

always_comb begin
    result = 32'd0;
    unique case(alu_op)
        ALU_ADD: result = a+b;
        ALU_SUB: result = a-b;
        ALU_AND: result = a&b;
        ALU_OR: result = a|b;
        ALU_XOR: result = a^b;
        ALU_SLL: result = a << b[4:0];
        ALU_SRL: result = a >> b[4:0];
        ALU_SRA: result = $signed(a) >>> b[4:0];
        ALU_SLT: result = less_signed ? 32'd1 : 32'd0;
        ALU_SLTU: result = less_unsigned ? 32'd1 : 32'd0;
        ALU_COPY_B: result = b;
        default: result = 32'd0;
    endcase
end

endmodule