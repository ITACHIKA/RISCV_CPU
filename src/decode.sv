`timescale 1ns / 1ps
import riscv_pkg::*;
module decode(
    input logic [31:0] instruction,
    output opcode_t opcode,
    output imm_type_t imm_type,
    output funct3_t funct3,
    output funct7_t funct7,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [4:0] rd
);

always_comb begin
    opcode = instruction[6:0];
    funct3 = instruction[14:12];
    funct7 = instruction[31:25];
    rs1 = instruction[19:15];
    rs2 = instruction[24:20];
    rd = instruction[11:7];
    unique case(opcode)
        OPCODE_LOAD:   imm_type=IMM_I;
        OPCODE_OP_IMM: imm_type=IMM_I;
        OPCODE_OP:     imm_type=IMM_NONE; //R type
        OPCODE_STORE:  imm_type=IMM_S;
        OPCODE_BRANCH: imm_type=IMM_B;
        OPCODE_JAL:    imm_type=IMM_J;
        OPCODE_JALR:   imm_type=IMM_I;
        OPCODE_LUI:    imm_type=IMM_U;
        OPCODE_AUIPC:  imm_type=IMM_U;
        default: imm_type=IMM_NONE;
    endcase
end

endmodule