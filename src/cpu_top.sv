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
logic [31:0] pcplus4;
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

if_id_reg_t if_id_reg_q, if_id_reg_d;
id_ex_reg_t id_ex_reg_q, id_ex_reg_d;
ex_mem_reg_t ex_mem_reg_q, ex_mem_reg_d;
mem_wb_reg_t mem_wb_reg_q, mem_wb_reg_d;


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

always_comb begin
    if_id_reg_d.pcplus4 = current_pc + 4;
    if_id_reg_d.pc = current_pc;
    if_id_reg_d.instruction = instr;
end

decode decode(
    .instruction(if_id_reg_q.instruction),
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

    .reg_we(id_ex_reg_d.reg_we),
    .mem_re(id_ex_reg_d.mem_re),
    .mem_we(id_ex_reg_d.mem_we),
    .wb_sel(id_ex_reg_d.wb_sel),
    .alu_op(id_ex_reg_d.alu_op),
    .pc_sel(id_ex_reg_d.pc_sel),
    .illegal_instr(illegal_instr),
    .alu_src_a_sel(id_ex_reg_d.alu_src_a_sel),
    .alu_src_b_sel(id_ex_reg_d.alu_src_b_sel),

    .memsize(id_ex_reg_d.memsize),
    .memsign(id_ex_reg_d.memsign)
);

registers registers(
    .clk(clk),
    .reset_n(reset_n),
    .rs1_addr(rs1),
    .rs2_addr(rs2),
    .rd_addr(mem_wb_reg_q.rd), // have to use rd from wb stage, because the rd in decode stage may be overwritten by next instruction
    .rd_data(wb_data), //rd register data, not read data
    .rd_we(mem_wb_reg_q.reg_we),
    .rs1_data(id_ex_reg_d.rs1_data),
    .rs2_data(id_ex_reg_d.rs2_data)
);

imm_gen imm_gen(
    .instruction(if_id_reg_q.instruction),
    .imm_type(imm_type),
    .imm_out(id_ex_reg_d.imm)
);

alu alu(
    .a(alu_a),
    .b(alu_b),
    .alu_op(id_ex_reg_q.alu_op),
    .less_signed(less_signed),
    .less_unsigned(less_unsigned),
    .result(ex_mem_reg_d.alu_result)
);

dmem dmem(
    .clk(clk),
    .wren(ex_mem_reg_q.mem_we),
    .addr(ex_mem_reg_q.alu_result),
    .wdata(mem_wdata),
    .rdata(dmem_output_raw),
    .wstrb(wstrb)
);

lsu lsu(
    .wren(ex_mem_reg_q.mem_we),
    .addr(ex_mem_reg_q.alu_result), // riscv load/store instruction always uses alu_result as address, addr = rs1 + imm
    .store_data(ex_mem_reg_q.rs2_data), // riscv store instruction always stores data from rs2
    .mem_data(dmem_output_raw),
    .memsize(ex_mem_reg_q.memsize),
    .memsign(ex_mem_reg_q.memsign),
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

//pipeline registers
always_ff @(posedge clk) begin
    if(!reset_n) begin
        if_id_reg_q <= '0;
        id_ex_reg_q <= '0;
        ex_mem_reg_q <= '0;
        mem_wb_reg_q <= '0;
    end
    else begin
        if_id_reg_q <= if_id_reg_d;
        id_ex_reg_q <= id_ex_reg_d;
        ex_mem_reg_q <= ex_mem_reg_d;
        mem_wb_reg_q <= mem_wb_reg_d;
    end
end

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
    unique case(id_ex_reg_q.alu_src_a_sel)
        ALU_SRC_A_RS1: alu_a = id_ex_reg_q.rs1_data;
        ALU_SRC_A_PC: alu_a = id_ex_reg_q.pc;
        default: alu_a = 32'd0;
    endcase
end

always_comb begin
    unique case(id_ex_reg_q.alu_src_b_sel)
        ALU_SRC_B_RS2: alu_b = id_ex_reg_q.rs2_data;
        ALU_SRC_B_IMM: alu_b = id_ex_reg_q.imm;
        default: alu_b = 32'd0;
    endcase
end

always_comb begin
    unique case(mem_wb_reg_q.wb_sel)
        WB_ALU: wb_data = mem_wb_reg_q.alu_result;
        WB_MEM: wb_data = mem_wb_reg_q.mem_data;
        WB_PC: wb_data = mem_wb_reg_q.pcplus4; //for JAL
        WB_CMP: wb_data = {31'd0, eq};
        default: wb_data = 32'd0;
    endcase
end

logic [31:0] pcplusimm;

always_comb begin
    pcplusimm = id_ex_reg_q.pc + id_ex_reg_q.imm;
end

always_comb begin
    unique case(id_ex_reg_q.pc_sel)
        PC_NEXT: next_pc = current_pc + 4;
        PC_BRANCH: next_pc = take? (current_pc + imm):(current_pc+4);
        PC_JAL: next_pc = alu_result;
        PC_JALR: next_pc = alu_result & 32'hFFFF_FFFE;
        PC_TRAP: next_pc = 32'h0000_0000;
        default: next_pc = current_pc + 4;
    endcase
end

endmodule
