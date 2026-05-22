`timescale 1ns / 1ps
import riscv_pkg::*;
module control(
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input logic [4:0] rd,
    input funct3_t funct3,
    input funct7_t funct7,
    input opcode_t opcode,

    output logic    reg_we,
    output logic    mem_re,
    output logic    mem_we,
    output wb_sel_t wb_sel,
    output alu_op_t alu_op,
    output pc_sel_t pc_sel,
    output logic    illegal_instr,
    output alu_src_a_sel_t    alu_src_a_sel,
    output alu_src_b_sel_t    alu_src_b_sel,
    
    output mem_size_t memsize,
    output mem_sign_t memsign
);

(* keep = "true" *) logic debug;

always_comb begin
    debug = 1'b0;

    reg_we = 1'b0;
    mem_re = 1'b0;
    mem_we = 1'b0;
    wb_sel = WB_ALU;
    alu_op = ALU_INVALID;
    pc_sel = PC_NEXT;
    memsize = MEM_BYTE;
    memsign = MEM_SIGNED;
    illegal_instr = 1'b0;
    alu_src_a_sel = ALU_SRC_A_RS1;
    alu_src_b_sel = ALU_SRC_B_RS2;
    unique case(opcode)
        OPCODE_OP_IMM: begin
            reg_we = 1'b1;
            mem_re = 1'b0;
            mem_we = 1'b0;
            wb_sel = WB_ALU;
            pc_sel = PC_NEXT;
            alu_src_a_sel = ALU_SRC_A_RS1;
            alu_src_b_sel = ALU_SRC_B_IMM;
            unique case(funct3)
                F3_ADDI: alu_op = ALU_ADD;
                F3_SLTI: alu_op = ALU_SLT;
                F3_SLTIU: alu_op = ALU_SLTU;
                F3_XORI: alu_op = ALU_XOR;
                F3_ORI: alu_op = ALU_OR;
                F3_ANDI: alu_op = ALU_AND;
                F3_SLLI: begin
                    if(funct7==F7_SLLI)
                        alu_op = ALU_SLL;
                        else begin
                            alu_op = ALU_INVALID;
                            illegal_instr = 1'b1;
                        end
                end
                F3_SRLI: begin //also F3_SRAI
                    if(funct7==F7_SRLI)
                        alu_op = ALU_SRL;
                    else if(funct7==F7_SRAI)
                        alu_op = ALU_SRA;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end
                end
                default: begin
                    alu_op = ALU_INVALID;
                    illegal_instr = 1'b1;
                end
            endcase
        end
        OPCODE_OP: begin
            reg_we = 1'b1;
            mem_re = 1'b0;
            mem_we = 1'b0;
            wb_sel = WB_ALU;
            pc_sel = PC_NEXT;
            alu_src_a_sel = ALU_SRC_A_RS1;
            alu_src_b_sel = ALU_SRC_B_RS2;
            unique case(funct3)
                F3_ADD: begin // also F3_SUB
                    if(funct7 == F7_ADD)
                        alu_op = ALU_ADD;
                    else if(funct7 == F7_SUB)
                        alu_op = ALU_SUB;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end
                end
                F3_SLT: begin
                    if(funct7 == F7_SLT)
                        alu_op = ALU_SLT;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end
                end
                F3_SLTU: begin
                    if(funct7 == F7_SLTU)
                        alu_op = ALU_SLTU;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end
                end
                F3_XOR: begin
                    if(funct7 == F7_XOR)
                        alu_op = ALU_XOR;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end
                end
                F3_OR: begin
                    if(funct7 == F7_OR)
                        alu_op = ALU_OR;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end                    
                end
                F3_AND: begin
                    if(funct7 == F7_AND)
                        alu_op = ALU_AND;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end
                end
                F3_SLL: begin
                    if(funct7==F7_SLL)
                        alu_op = ALU_SLL;
                        else begin
                            alu_op = ALU_INVALID;
                            illegal_instr = 1'b1;
                        end
                end
                F3_SRL: begin //also F3_SRA
                    if(funct7==F7_SRL)
                        alu_op = ALU_SRL;
                    else if(funct7==F7_SRA)
                        alu_op = ALU_SRA;
                    else begin
                        alu_op = ALU_INVALID;
                        illegal_instr = 1'b1;
                    end
                end
                default: begin
                    alu_op = ALU_INVALID;
                    illegal_instr = 1'b1;
                end
            endcase           
        end
        OPCODE_LUI: begin
            reg_we = 1'b1;
            mem_re = 1'b0;
            mem_we = 1'b0;
            wb_sel = WB_ALU;
            pc_sel = PC_NEXT;
            alu_src_a_sel = ALU_SRC_A_RS1;
            alu_src_b_sel = ALU_SRC_B_IMM;
            alu_op = ALU_COPY_B;
        end
        OPCODE_BRANCH: begin
            pc_sel = PC_BRANCH;
        end
        OPCODE_AUIPC: begin
            reg_we = 1'b1;
            mem_re = 1'b0;
            mem_we = 1'b0;
            wb_sel = WB_ALU;
            pc_sel = PC_NEXT;
            alu_src_a_sel = ALU_SRC_A_PC;
            alu_src_b_sel = ALU_SRC_B_IMM;
            alu_op = ALU_ADD;
        end
        OPCODE_JAL: begin
            reg_we = 1'b1;
            mem_re = 1'b0;
            mem_we = 1'b0;
            wb_sel = WB_PC;
            pc_sel = PC_JAL;
            alu_src_a_sel = ALU_SRC_A_PC;
            alu_src_b_sel = ALU_SRC_B_IMM;
            alu_op = ALU_ADD;            
        end
        OPCODE_JALR: begin
            reg_we = 1'b1;
            mem_re = 1'b0;
            mem_we = 1'b0;
            wb_sel = WB_PC;
            pc_sel = PC_JALR;
            alu_src_a_sel = ALU_SRC_A_RS1;
            alu_src_b_sel = ALU_SRC_B_IMM;
            alu_op = ALU_ADD;
        end
        OPCODE_LOAD: begin
            reg_we = 1'b1;
            mem_re = 1'b1;
            mem_we = 1'b0;
            wb_sel = WB_MEM;
            pc_sel = PC_NEXT;
            alu_src_a_sel = ALU_SRC_A_RS1;
            alu_src_b_sel = ALU_SRC_B_IMM;
            alu_op = ALU_ADD;
            debug = 1'b1;
            unique case(funct3)
                F3_LB: begin
                    memsize = MEM_BYTE;
                    memsign = MEM_SIGNED;
                end
                F3_LH: begin
                    memsize = MEM_HALF;
                    memsign = MEM_SIGNED;
                end
                F3_LW: begin
                    memsize = MEM_WORD;
                    memsign = MEM_SIGNED;
                end
                F3_LBU: begin
                    memsize = MEM_BYTE;
                    memsign = MEM_UNSIGNED;
                end
                F3_LHU: begin
                    memsize = MEM_HALF;
                    memsign = MEM_UNSIGNED;
                end
            endcase
        end
        OPCODE_STORE: begin
            reg_we = 1'b0;
            mem_re = 1'b0;
            mem_we = 1'b1;
            wb_sel = WB_ALU;
            pc_sel = PC_NEXT;
            alu_src_a_sel = ALU_SRC_A_RS1;
            alu_src_b_sel = ALU_SRC_B_IMM;
            alu_op = ALU_ADD;
            unique case(funct3)
                F3_SB: begin
                    memsize = MEM_BYTE;
                    memsign = MEM_SIGNED;
                end
                F3_SH: begin
                    memsize = MEM_HALF;
                    memsign = MEM_SIGNED;
                end
                F3_SW: begin
                    memsize = MEM_WORD;
                    memsign = MEM_SIGNED;
                end
            endcase
        end
    endcase
end



endmodule