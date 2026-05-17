`timescale 1ns / 1ps
import riscv_pkg::*;
module control(
    input logic [31:0] instruction,
    output imm_type_t imm_type,
    
);

logic [6:0] opcode;
logic [2:0] func3;
logic [6:0] func7;

always_comb begin
    opcode = instruction[6:0];
    func3 = instruction[14:12];
    func7 = instruction[31:25];
end



endmodule