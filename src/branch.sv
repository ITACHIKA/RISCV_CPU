`timescale 1ns / 1ps
import riscv_pkg::*;
module branch(
    input funct3_t funct3,
    input logic eq,
    input logic less_signed,
    input logic less_unsigned,
    output logic take
);

always_comb begin
    unique case(funct3)
        F3_BEQ: take=eq;
        F3_BNE: take=~eq;
        F3_BLT: take=less_signed;
        F3_BGE: take=~less_signed;
        F3_BLTU: take=less_unsigned;
        F3_BGEU: take=~less_unsigned;
    endcase
end

endmodule