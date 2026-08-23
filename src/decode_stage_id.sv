// Decode stage, immediate generation, and architectural register file.
`timescale 1ns / 1ps
import riscv_pkg::*;

module decode_stage_id (
    // Inputs
    input  logic        clk,
    input  logic        reset_n,
    input  if_id_reg_t  if_id_reg_q,
    input  logic [4:0]  rd_addr_wb,
    input  logic [31:0] rd_data_wb,
    input  logic        rd_we_wb,

    // Outputs
    output id_ex_reg_t  id_ex_reg_d,
    output logic        illegal_instr_id
);

opcode_t opcode_id;
funct3_t funct3_id;
funct7_t funct7_id;
logic [4:0] rs1_id;
logic [4:0] rs2_id;
logic [4:0] rd_id;
imm_type_t imm_type_id;

logic reg_we_id;
logic mem_re_id;
logic mem_we_id;
wb_sel_t wb_sel_id;
alu_op_t alu_op_id;
pc_sel_t pc_sel_id;
alu_src_a_sel_t alu_src_a_sel_id;
alu_src_b_sel_t alu_src_b_sel_id;
mem_size_t memsize_id;
mem_sign_t memsign_id;
logic uses_rs1_id;
logic uses_rs2_id;

logic [31:0] rs1_data_id;
logic [31:0] rs2_data_id;
logic [31:0] imm_id;

decoder_id decoder (
    // Inputs
    .instruction(if_id_reg_q.instruction),

    // Outputs
    .opcode  (opcode_id),
    .imm_type(imm_type_id),
    .funct3  (funct3_id),
    .funct7  (funct7_id),
    .rs1     (rs1_id),
    .rs2     (rs2_id),
    .rd      (rd_id)
);

control_id control (
    // Inputs
    .rs1   (rs1_id),
    .rs2   (rs2_id),
    .rd    (rd_id),
    .funct3(funct3_id),
    .funct7(funct7_id),
    .opcode(opcode_id),

    // Outputs
    .reg_we       (reg_we_id),
    .mem_re       (mem_re_id),
    .mem_we       (mem_we_id),
    .wb_sel       (wb_sel_id),
    .alu_op       (alu_op_id),
    .pc_sel       (pc_sel_id),
    .illegal_instr(illegal_instr_id),
    .alu_src_a_sel(alu_src_a_sel_id),
    .alu_src_b_sel(alu_src_b_sel_id),
    .memsize      (memsize_id),
    .memsign      (memsign_id),
    .uses_rs1     (uses_rs1_id),
    .uses_rs2     (uses_rs2_id)
);

registers_id_wb registers (
    // Inputs
    .clk     (clk),
    .reset_n (reset_n),
    .rs1_addr(rs1_id),
    .rs2_addr(rs2_id),
    .rd_addr (rd_addr_wb),
    .rd_data (rd_data_wb),
    .rd_we   (rd_we_wb),

    // Outputs
    .rs1_data(rs1_data_id),
    .rs2_data(rs2_data_id)
);

imm_gen_id imm_gen (
    // Inputs
    .instruction(if_id_reg_q.instruction),
    .imm_type  (imm_type_id),

    // Outputs
    .imm_out(imm_id)
);

always_comb begin
    id_ex_reg_d               = '0;
    id_ex_reg_d.pc            = if_id_reg_q.pc;
    id_ex_reg_d.pcplus4       = if_id_reg_q.pcplus4;
    id_ex_reg_d.rs1_data      = rs1_data_id;
    id_ex_reg_d.rs2_data      = rs2_data_id;
    id_ex_reg_d.rd            = rd_id;
    id_ex_reg_d.imm           = imm_id;
    id_ex_reg_d.rs1           = rs1_id;
    id_ex_reg_d.rs2           = rs2_id;
    id_ex_reg_d.uses_rs1      = uses_rs1_id;
    id_ex_reg_d.uses_rs2      = uses_rs2_id;
    id_ex_reg_d.alu_src_a_sel = alu_src_a_sel_id;
    id_ex_reg_d.alu_src_b_sel = alu_src_b_sel_id;
    id_ex_reg_d.alu_op        = alu_op_id;
    id_ex_reg_d.reg_we        = reg_we_id;
    id_ex_reg_d.mem_re        = mem_re_id;
    id_ex_reg_d.mem_we        = mem_we_id;
    id_ex_reg_d.memsize       = memsize_id;
    id_ex_reg_d.memsign       = memsign_id;
    id_ex_reg_d.wb_sel        = wb_sel_id;
    id_ex_reg_d.pc_sel        = pc_sel_id;
    id_ex_reg_d.predicted_pc  = if_id_reg_q.predicted_pc;
    id_ex_reg_d.funct3        = funct3_id;
    id_ex_reg_d.valid         = if_id_reg_q.valid;
end

endmodule
