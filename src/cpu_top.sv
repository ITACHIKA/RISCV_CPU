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

mem_size_t memsize;
mem_sign_t memsign;
logic [31:0] mem_wdata;
logic [31:0] dmem_output_raw;
logic [31:0] dmem_output;
logic [3:0] wstrb;
logic load_misalign_except;
logic store_misalign_except;

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
    .alu_src_b_sel(alu_src_b_sel),

    .memsize(memsize),
    .memsign(memsign)
);

registers registers(
    .clk(clk),
    .reset_n(reset_n),
    .rs1_addr(rs1),
    .rs2_addr(rs2),
    .rd_addr(rd),
    .rd_data(wb_data), //rd register data, not read data
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

dmem dmem(
    .clk(clk),
    .wren(mem_we),
    .addr(alu_result),
    .wdata(mem_wdata),
    .rdata(dmem_output_raw),
    .wstrb(wstrb)
);

lsu lsu(
    .wren(mem_we),
    .addr(alu_result),
    .store_data(rs2_data),
    .mem_data(dmem_output_raw),
    .memsize(memsize),
    .memsign(memsign),
    .wstrb(wstrb),
    .mem_wdata(mem_wdata),
    .load_data(dmem_output),
    .load_misalign_except(load_misalign_except),
    .store_misalign_except(store_misalign_except)
);

logic exception;
assign exception = illegal_instr || load_misalign_except || store_misalign_except;

// always_comb begin
//     if(reset_n && illegal_instr)
//         $error("Illegal instruction at PC = %h, instr = %h", current_pc, instr);
//     else if(reset_n && load_misalign_except)
//         $error("Load misalignment exception at PC = %h, addr = %h", current_pc, alu_result);
//     else if(reset_n && store_misalign_except)
//         $error("Store misalignment exception at PC = %h, addr = %h", current_pc, alu_result);
// end

logic [31:0] cycle_counter;
always_ff @(posedge clk) begin
    if(!reset_n) begin
        cycle_counter <= 32'd0;
    end
    else begin
        cycle_counter <= cycle_counter + 1'b1;
    end
end

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
        WB_MEM: wb_data = dmem_output;
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