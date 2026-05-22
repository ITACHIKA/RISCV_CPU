`timescale 1ns / 1ps
import riscv_pkg::*;
module riscv_cpu (
    input logic sysclk,
    input logic reset
);

logic reset_n;
logic clk;
assign reset_n = ~reset;
assign clk = sysclk;
logic [31:0] current_pc;
logic [31:0] next_pc;
logic [31:0] instr;

opcode_t opcode;
funct3_t funct3;
funct7_t funct7;
logic [4:0] rs1,rs2,rd;
imm_type_t imm_type;

logic reg_we;
logic mem_re;
logic mem_we;
wb_sel_t wb_sel;
alu_op_t alu_op;
pc_sel_t pc_sel;
logic illegal_instr;
alu_src_a_sel_t alu_src_a_sel;
alu_src_b_sel_t alu_src_b_sel;

logic [31:0] rs1_data, rs2_data;
logic [31:0] imm;
logic [31:0] alu_a, alu_b;
logic [31:0] alu_result;
logic [31:0] wb_data;

logic eq;
logic less_signed;
logic less_unsigned;

logic take;

comparator comparator(
    .a(alu_a),
    .b(alu_b),
    .eq(eq),
    .less_signed(less_signed),
    .less_unsigned(less_unsigned)
);

branch branch(
    .funct3(funct3),
    .eq(eq),
    .less_signed(less_signed),
    .less_unsigned(less_unsigned),
    .take(take)
);

pc pc(
    .clk(clk),
    .reset_n(reset_n),
    .next_pc(next_pc),
    .current_pc(current_pc)
);

imem imem(
    .addr(current_pc),
    .instruction(instr)
);

decode decode(
    .instruction(instr),
    .opcode(opcode),
    .imm_type(imm_type),
    .funct3(funct3),
    .funct7(funct7),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd)
);

control control(
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .funct3(funct3),
    .funct7(funct7),
    .opcode(opcode),

    .reg_we(reg_we),
    .mem_re(mem_re),
    .mem_we(mem_we),
    .wb_sel(wb_sel),
    .alu_op(alu_op),
    .pc_sel(pc_sel),
    .illegal_instr(illegal_instr),
    .alu_src_a_sel(alu_src_a_sel),
    .alu_src_b_sel(alu_src_b_sel)
);

registers registers(
    .clk(clk),
    .reset_n(reset_n),
    .rs1_addr(rs1),
    .rs2_addr(rs2),
    .rd_addr(rd),
    .rd_data(wb_data),
    .rd_we(reg_we),
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
);

imm_gen imm_gen(
    .instruction(instr),
    .imm_type(imm_type),
    .imm_out(imm)
);

alu alu(
    .a(alu_a),
    .b(alu_b),
    .alu_op(alu_op),
    .less_signed(less_signed),
    .less_unsigned(less_unsigned),
    .result(alu_result)
);

always_comb begin
    unique case(alu_src_a_sel)
        ALU_SRC_A_RS1: alu_a = rs1_data;
        ALU_SRC_A_PC: alu_a = current_pc;
        default: alu_a = 32'd0;
    endcase
end

always_comb begin
    unique case(alu_src_b_sel)
        ALU_SRC_B_RS2: alu_b = rs2_data;
        ALU_SRC_B_IMM: alu_b = imm;
        default: alu_b = 32'd0;
    endcase
end

always_comb begin
    unique case(wb_sel)
        WB_ALU: wb_data = alu_result;
        WB_MEM: wb_data = 32'd0;
        WB_PC: wb_data = current_pc + 4; //for JAL
        WB_CMP: wb_data = {31'd0, eq};
        default: wb_data = 32'd0;
    endcase
end

always_comb begin
    unique case(pc_sel)
        PC_NEXT: next_pc = current_pc + 4;
        PC_BRANCH: next_pc = take? (current_pc + imm):(current_pc+4);
        PC_JAL: next_pc = alu_result;
        PC_JALR: next_pc = alu_result & 32'hFFFF_FFFE;
        PC_TRAP: next_pc = 32'h0000_0000;
        default: next_pc = current_pc + 4;
    endcase
end

endmodule