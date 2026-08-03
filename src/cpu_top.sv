`timescale 1ns / 1ps
import riscv_pkg::*;
module riscv_cpu (
    // Inputs
    input logic sysclk,
    input logic reset
);

logic reset_n;
logic clk;
assign reset_n = ~reset;
assign clk = sysclk;
logic [31:0] current_pc_if;
logic [31:0] next_pc_if;
logic [31:0] instr_if;
logic [31:0] redirect_next_pc_ex;
logic redirect_pc_request_ex;

logic imem_req_valid_if;
logic imem_resp_ready_if;
logic imem_req_ready_if;
logic imem_resp_valid_if;

opcode_t opcode_id;
funct3_t funct3_id;
funct7_t funct7_id;
logic [4:0] rs1_id,rs2_id,rd_id;
imm_type_t imm_type;

// control signals
logic reg_we_id;
logic mem_re_id;
logic mem_we_id;
wb_sel_t wb_sel_id;
alu_op_t alu_op_id;
pc_sel_t pc_sel_id;
logic illegal_instr;
alu_src_a_sel_t alu_src_a_sel_id;
alu_src_b_sel_t alu_src_b_sel_id;
mem_size_t memsize_id;
mem_sign_t memsign_id;

logic [31:0] rs1_data_id, rs2_data_id;
logic [31:0] imm_id;
logic [31:0] alu_a_ex, alu_b_ex;
logic [31:0] alu_result_ex;
logic [31:0] wb_data;

logic eq_ex;
logic less_signed_ex;
logic less_unsigned_ex;

logic take_ex;

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

pc_predict_result_t pc_predict_result_if;

rs_forward_mux_sel_t rs1_forward_mux_sel, rs2_forward_mux_sel;

// forwarding mux for RS1 and RS2
logic [31:0] alu_a_forward_result_ex, alu_b_forward_result_ex;

comparator_ex comparator(
    // Inputs
    .a(alu_a_ex),
    .b(alu_b_ex),

    // Outputs
    .eq(eq_ex),
    .less_signed(less_signed_ex),
    .less_unsigned(less_unsigned_ex)
);

branch_ex branch(
    // Inputs
    .funct3(id_ex_reg_q.funct3),
    .eq(eq_ex),
    .less_signed(less_signed_ex),
    .less_unsigned(less_unsigned_ex),

    // Outputs
    .take(take_ex)
);

branch_predict_if branch_predict(
    // Inputs
    .clk           (clk),
    .reset_n       (reset_n),
    .pc            (current_pc_if),

    // Outputs
    .branch_predict_result(pc_predict_result_if)
);

control_flow_resolver_ex control_flow_resolver (
    // Inputs
    .current_pc         (id_ex_reg_q.pc), // this pc must come from IF stage
    .predicted_next_pc  (id_ex_reg_q.predicted_pc), // this predicted pc must come from IF stage
    .branch_taken       (take_ex),
    .alu_result         (alu_result_ex),
    .imm                (id_ex_reg_q.imm),
    .pc_sel             (id_ex_reg_q.pc_sel),

    // Outputs
    .redirect_pc_request(redirect_pc_request_ex),
    .redirect_next_pc   (redirect_next_pc_ex)
);

pc_if pc(
    // Inputs
    .clk(clk),
    .reset_n(reset_n),
    .next_pc(next_pc_if),

    // Outputs
    .current_pc(current_pc_if)
);

assign imem_req_valid_if = 1'b1; // for a combinational imem, always valid request and ready for response
assign imem_resp_ready_if = 1'b1;

imem_if imem(
    // Inputs
    .addr(current_pc_if),
    .req_valid(imem_req_valid_if),
    .resp_ready(imem_resp_ready_if),

    // Outputs
    .instruction(instr_if),
    .req_ready(imem_req_ready_if),
    .resp_valid(imem_resp_valid_if)
);

decode_id decode(
    // Inputs
    .instruction(if_id_reg_q.instruction),

    // Outputs
    .opcode(opcode_id),
    .imm_type(imm_type),
    .funct3(funct3_id),
    .funct7(funct7_id),
    .rs1(rs1_id),
    .rs2(rs2_id),
    .rd(rd_id)
);

control_id control(
    // Inputs
    .rs1(rs1_id),
    .rs2(rs2_id),
    .rd(rd_id),
    .funct3(funct3_id),
    .funct7(funct7_id),
    .opcode(opcode_id),

    // Outputs
    .reg_we(reg_we_id),
    .mem_re(mem_re_id),
    .mem_we(mem_we_id),
    .wb_sel(wb_sel_id),
    .alu_op(alu_op_id),
    .pc_sel(pc_sel_id),
    .illegal_instr(illegal_instr),
    .alu_src_a_sel(alu_src_a_sel_id),
    .alu_src_b_sel(alu_src_b_sel_id),
    .memsize(memsize_id),
    .memsign(memsign_id)
);

registers_id_wb registers(
    // Inputs
    .clk(clk),
    .reset_n(reset_n),
    .rs1_addr(rs1_id),
    .rs2_addr(rs2_id),
    .rd_addr(mem_wb_reg_q.rd), // have to use rd from wb stage, because the rd in decode stage may be overwritten by next instruction
    .rd_data(wb_data), //rd register data, not read data
    .rd_we(mem_wb_reg_q.reg_we),

    // Outputs
    .rs1_data(rs1_data_id),
    .rs2_data(rs2_data_id)
);

imm_gen_id imm_gen(
    // Inputs
    .instruction(if_id_reg_q.instruction),
    .imm_type(imm_type),

    // Outputs
    .imm_out(imm_id)
);

alu_ex alu(
    // Inputs
    .a(alu_a_ex),
    .b(alu_b_ex),
    .alu_op(id_ex_reg_q.alu_op),
    .less_signed(less_signed_ex),
    .less_unsigned(less_unsigned_ex),

    // Outputs
    .result(alu_result_ex)
);

dmem_mem dmem(
    // Inputs
    .clk(clk),
    .wren(ex_mem_reg_q.mem_we),
    .addr(ex_mem_reg_q.alu_result),
    .wdata(mem_wdata),
    .wstrb(wstrb),

    // Outputs
    .rdata(dmem_output_raw)
);

lsu_mem lsu(
    // Inputs
    .wren(ex_mem_reg_q.mem_we),
    .addr(ex_mem_reg_q.alu_result), // riscv load/store instruction always uses alu_result as address, addr = rs1 + imm
    .store_data(ex_mem_reg_q.rs2_data), // riscv store instruction always stores data from rs2
    .mem_data(dmem_output_raw),
    .memsize(ex_mem_reg_q.memsize),
    .memsign(ex_mem_reg_q.memsign),

    // Outputs
    .wstrb(wstrb),
    .mem_wdata(mem_wdata),
    .load_data(dmem_output),
    .load_misalign_except(load_misalign_except),
    .store_misalign_except(store_misalign_except)
);

hazard hazard (
    // Inputs
    .rs1_ex             (id_ex_reg_q.rs1),
    .rs2_ex             (id_ex_reg_q.rs2),
    .rd_mem             (ex_mem_reg_q.rd),
    .rd_wb              (mem_wb_reg_q.rd),
    .reg_we_mem         (ex_mem_reg_q.reg_we),
    .reg_we_wb          (mem_wb_reg_q.reg_we),
    .valid_ex           (id_ex_reg_q.valid),

    // Outputs
    .rs1_forward_mux_sel(rs1_forward_mux_sel),
    .rs2_forward_mux_sel(rs2_forward_mux_sel)
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

always_comb begin
    if_id_reg_d.pcplus4 = current_pc_if + 4;
    if_id_reg_d.pc = current_pc_if;
    if_id_reg_d.instruction = instr_if;
    if_id_reg_d.predicted_pc = pc_predict_result_if.predicted_pc; // predicted pc from branch predictor
    if_id_reg_d.valid = imem_req_ready_if;

    id_ex_reg_d.pc = if_id_reg_q.pc;
    id_ex_reg_d.pcplus4 = if_id_reg_q.pcplus4;
    id_ex_reg_d.rs1_data = rs1_data_id;
    id_ex_reg_d.rs2_data = rs2_data_id;
    id_ex_reg_d.rd = rd_id;
    id_ex_reg_d.imm = imm_id;
    id_ex_reg_d.rs1 = rs1_id;
    id_ex_reg_d.rs2 = rs2_id;
    id_ex_reg_d.alu_src_a_sel = alu_src_a_sel_id;
    id_ex_reg_d.alu_src_b_sel = alu_src_b_sel_id;
    id_ex_reg_d.alu_op = alu_op_id;
    id_ex_reg_d.reg_we = reg_we_id;
    id_ex_reg_d.mem_re = mem_re_id;
    id_ex_reg_d.mem_we = mem_we_id;
    id_ex_reg_d.memsize = memsize_id;
    id_ex_reg_d.memsign = memsign_id;
    id_ex_reg_d.wb_sel = wb_sel_id;
    id_ex_reg_d.pc_sel = pc_sel_id;
    id_ex_reg_d.predicted_pc = if_id_reg_q.predicted_pc;
    id_ex_reg_d.funct3 = funct3_id;
    id_ex_reg_d.valid = if_id_reg_q.valid;

    ex_mem_reg_d.pcplus4 = id_ex_reg_q.pcplus4;
    ex_mem_reg_d.alu_result = alu_result_ex;
    // ex_mem_reg_d.rs2_data = id_ex_reg_q.rs2_data;
    ex_mem_reg_d.rs2_data = alu_b_forward_result_ex; // forward rs2 data from MEM stage for store instruction
    ex_mem_reg_d.rd = id_ex_reg_q.rd;
    ex_mem_reg_d.reg_we = id_ex_reg_q.reg_we;
    ex_mem_reg_d.mem_re = id_ex_reg_q.mem_re;
    ex_mem_reg_d.mem_we = id_ex_reg_q.mem_we;
    ex_mem_reg_d.memsize = id_ex_reg_q.memsize;
    ex_mem_reg_d.memsign = id_ex_reg_q.memsign;
    ex_mem_reg_d.wb_sel = id_ex_reg_q.wb_sel;
    ex_mem_reg_d.valid = id_ex_reg_q.valid;

    mem_wb_reg_d.pcplus4 = ex_mem_reg_q.pcplus4;
    mem_wb_reg_d.alu_result = ex_mem_reg_q.alu_result;
    mem_wb_reg_d.mem_data = dmem_output;
    mem_wb_reg_d.rs2_data = ex_mem_reg_q.rs2_data;
    mem_wb_reg_d.rd = ex_mem_reg_q.rd;
    mem_wb_reg_d.reg_we = ex_mem_reg_q.reg_we;
    mem_wb_reg_d.wb_sel = ex_mem_reg_q.wb_sel;
    mem_wb_reg_d.valid = ex_mem_reg_q.valid;
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

// need extra mux to choose forwarding from PC+4 or ALU result from MEM stage in the case of instruction uses RD following JAL/R
logic [31:0] mem_forward_result;

always_comb begin
    unique case(ex_mem_reg_q.wb_sel)
        WB_ALU: mem_forward_result = ex_mem_reg_q.alu_result;
        // WB_MEM: mem_forward_result = ex_mem_reg_q.mem_data; This is a load-use case
        WB_MEM: mem_forward_result = 32'd0; // This is a load-use case, we cannot forward the data from MEM stage since it's not ready until end of MEM stage
        WB_PC: mem_forward_result = ex_mem_reg_q.pcplus4; //for JAL/R
        default: mem_forward_result = 32'd0;
    endcase
end

always_comb begin
    unique case(rs1_forward_mux_sel)
        RS_FORWARD_NONE: alu_a_forward_result_ex = id_ex_reg_q.rs1_data;
        RS_FORWARD_MEM: alu_a_forward_result_ex = mem_forward_result;
        RS_FORWARD_WB: alu_a_forward_result_ex = wb_data;
        default: alu_a_forward_result_ex = 32'd0;
    endcase
end

always_comb begin
    unique case(rs2_forward_mux_sel)
        RS_FORWARD_NONE: alu_b_forward_result_ex = id_ex_reg_q.rs2_data;
        RS_FORWARD_MEM: alu_b_forward_result_ex = mem_forward_result;
        RS_FORWARD_WB: alu_b_forward_result_ex = wb_data;
        default: alu_b_forward_result_ex = 32'd0;
    endcase
end

always_comb begin
    unique case(id_ex_reg_q.alu_src_a_sel)
        ALU_SRC_A_RS1: alu_a_ex = alu_a_forward_result_ex;
        ALU_SRC_A_PC: alu_a_ex = id_ex_reg_q.pc;
        default: alu_a_ex = 32'd0;
    endcase
end

always_comb begin
    unique case(id_ex_reg_q.alu_src_b_sel)
        ALU_SRC_B_RS2: alu_b_ex = alu_b_forward_result_ex;
        ALU_SRC_B_IMM: alu_b_ex = id_ex_reg_q.imm;
        default: alu_b_ex = 32'd0;
    endcase
end

always_comb begin
    unique case(mem_wb_reg_q.wb_sel)
        WB_ALU: wb_data = mem_wb_reg_q.alu_result;
        WB_MEM: wb_data = mem_wb_reg_q.mem_data;
        WB_PC: wb_data = mem_wb_reg_q.pcplus4; //for JAL/R
        default: wb_data = 32'd0;
    endcase
end

always_comb begin
    next_pc_if = pc_predict_result_if.predicted_pc; // currently it is static prediction of always not taken
    if(redirect_pc_request_ex) begin
        next_pc_if = redirect_next_pc_ex;
    end
end

endmodule
