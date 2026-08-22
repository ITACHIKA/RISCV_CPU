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
logic [31:0] current_pc_imem_if; // this is the pc that is being processed in imem, which is 1 cycle behind current_pc_if  
logic [31:0] next_pc_if;
logic [31:0] instr_if;
logic [31:0] redirect_next_pc_ex;
logic redirect_pc_request_ex;

logic imem_req_valid_if;
logic imem_resp_ready_if;
logic imem_req_ready_if;
logic imem_resp_valid_if;
logic imem_req_fire_if;
logic imem_resp_fire_if;

logic pc_update_enable_if;

assign imem_req_fire_if = imem_req_valid_if && imem_req_ready_if; // request is valid and imem is ready to accept
assign imem_resp_fire_if = imem_resp_valid_if && imem_resp_ready_if; // response is valid and CPU is ready to accept

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
logic uses_rs1_id, uses_rs2_id; // indicate if the instruction actually uses rs1 and rs2

logic [31:0] rs1_data_id, rs2_data_id;
logic [31:0] imm_id;
logic [31:0] alu_a_ex, alu_b_ex;
logic [31:0] alu_result_ex;
logic [31:0] wb_data;

logic eq_ex;
logic less_signed_ex;
logic less_unsigned_ex;

logic take_ex;

logic dmem_resolved_wren;
logic dmem_resolved_rden;
logic [31:0] mem_wdata;
logic [31:0] dmem_output_raw;
logic [31:0] dmem_output;
logic [3:0] wstrb;
logic load_misalign_except_mem;
logic store_misalign_except_mem;

//logic imem_rden_if;

if_id_reg_t if_id_reg_q, if_id_reg_d;
id_ex_reg_t id_ex_reg_q, id_ex_reg_d;
ex_mem_reg_t ex_mem_reg_q, ex_mem_reg_d;
mem_wb_reg_t mem_wb_reg_q, mem_wb_reg_d;

pc_predict_result_t pc_predict_result_if;
pc_predict_result_t pc_predict_result_imem_if; // delayed pc_predict_result to match the delay of current_pc_imem_if

rs_forward_mux_sel_t rs1_forward_mux_sel, rs2_forward_mux_sel;

// forwarding mux for RS1 and RS2
logic [31:0] alu_a_forward_result_ex, alu_b_forward_result_ex;

logic load_use_stall_if;

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

// calculates predicted next pc in same cycle
branch_predict_if branch_predict(
    // Inputs
    .clk           (clk),
    .reset_n       (reset_n),
    .current_pc    (current_pc_if),

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

    .valid_ex           (id_ex_reg_q.valid),

    // Outputs
    .redirect_pc_request(redirect_pc_request_ex),
    .redirect_next_pc   (redirect_next_pc_ex)
);

pc_if pc(
    // Inputs
    .clk(clk),
    .reset_n(reset_n),
    .next_pc(next_pc_if),
    .pc_update_enable(pc_update_enable_if),

    // Outputs
    .current_pc(current_pc_if)
);

imem_if imem(
    // Inputs
    .clk(clk),
    .reset_n(reset_n),
    .addr(current_pc_if),
    .req_valid(imem_req_valid_if),
    .resp_ready(imem_resp_ready_if),
    .flush(redirect_pc_request_ex),
    //.rden(imem_rden_if),

    // Outputs
    .instruction(instr_if),
    .req_ready(imem_req_ready_if),
    .resp_valid(imem_resp_valid_if)
);

assign imem_req_valid_if = !load_use_stall_if && !redirect_pc_request_ex; // only send request when not stalled
assign imem_resp_ready_if = !load_use_stall_if && !redirect_pc_request_ex;

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
    .memsign(memsign_id),
    .uses_rs1(uses_rs1_id),
    .uses_rs2(uses_rs2_id)
);

registers_id_wb registers(
    // Inputs
    .clk(clk),
    .reset_n(reset_n),
    .rs1_addr(rs1_id),
    .rs2_addr(rs2_id),
    .rd_addr(mem_wb_reg_q.rd), // have to use rd from wb stage, because the rd in decode stage may be overwritten by next instruction
    .rd_data(wb_data), //rd register data, not read data
    .rd_we(mem_wb_reg_q.reg_we && mem_wb_reg_q.valid), // write enable for rd register, only write when instruction is valid

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
    .wren(dmem_resolved_wren),
    .rden(dmem_resolved_rden),
    .addr(ex_mem_reg_q.alu_result),
    .wdata(mem_wdata),
    .wstrb(wstrb),

    // Outputs
    .rdata(dmem_output_raw)
);

lsu_mem lsu_mem(
    // Inputs
    .wren(dmem_resolved_wren),
    .rden(dmem_resolved_rden),
    .addr(ex_mem_reg_q.alu_result), // riscv load/store instruction always uses alu_result as address, addr = rs1 + imm
    .store_data(ex_mem_reg_q.rs2_data), // riscv store instruction always stores data from rs2
    // .mem_data(dmem_output_raw),
    .memsize(ex_mem_reg_q.memsize),
    // .memsign(ex_mem_reg_q.memsign),

    // Outputs
    .wstrb(wstrb),
    .mem_wdata(mem_wdata),
    // .load_data(dmem_output),
    .load_misalign_except(load_misalign_except_mem),
    .store_misalign_except(store_misalign_except_mem)
);

lsu_wb lsu_wb(
    // Inputs
    .mem_raw_data(dmem_output_raw),
    .mem_addr(mem_wb_reg_q.alu_result),
    .memsize(mem_wb_reg_q.memsize),
    .memsign(mem_wb_reg_q.memsign),
    .rden(mem_wb_reg_q.dmem_resolved_rden && mem_wb_reg_q.valid),

    // Outputs
    .load_data(dmem_output)
);

address_resolver_mem address_resolver_mem (
    // Inputs
    .addr     (ex_mem_reg_q.alu_result),
    .mmio_device_wren(ex_mem_reg_q.mem_we && ex_mem_reg_q.valid),
    .mmio_device_rden(ex_mem_reg_q.mem_re && ex_mem_reg_q.valid),

    // Outputs
    .dmem_resolved_wren(dmem_resolved_wren),
    .dmem_resolved_rden(dmem_resolved_rden)
);

hazard hazard (
    // Inputs
    .rs1_id             (rs1_id),
    .rs2_id             (rs2_id),
    .rs1_ex             (id_ex_reg_q.rs1),
    .rs2_ex             (id_ex_reg_q.rs2),
    .rd_ex              (id_ex_reg_q.rd), // for load-use hazard detection, need rd in EX stage   
    .rd_mem             (ex_mem_reg_q.rd),
    .rd_wb              (mem_wb_reg_q.rd),
    .reg_we_mem         (ex_mem_reg_q.reg_we),
    .reg_we_wb          (mem_wb_reg_q.reg_we),
    .valid_id           (if_id_reg_q.valid),
    .valid_ex           (id_ex_reg_q.valid),
    .valid_mem          (ex_mem_reg_q.valid),
    .valid_wb           (mem_wb_reg_q.valid),
    .mem_rden_ex        (id_ex_reg_q.mem_re), // for load-use hazard detection
    .mem_rden_mem       (ex_mem_reg_q.mem_re), // indicate if there is a load instruction in MEM stage
    .uses_rs1_id        (uses_rs1_id),
    .uses_rs2_id        (uses_rs2_id), // if rs1 and rs2 are actually being used in ID stage
    .uses_rs1_ex        (id_ex_reg_q.uses_rs1),
    .uses_rs2_ex        (id_ex_reg_q.uses_rs2), // used for general forwarding, not load-store detection

    // Outputs
    .rs1_forward_mux_sel(rs1_forward_mux_sel),
    .rs2_forward_mux_sel(rs2_forward_mux_sel),

    .load_use_stall_if  (load_use_stall_if)
);

logic exception;
assign exception = illegal_instr || load_misalign_except_mem || store_misalign_except_mem;

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
        if (redirect_pc_request_ex) begin
            if_id_reg_q <= '0; // flush IF/ID register
            id_ex_reg_q <= '0; // flush ID/EX register
            ex_mem_reg_q <= ex_mem_reg_d;
            mem_wb_reg_q <= mem_wb_reg_d; // MEM and WB stage proceed normally
        end
        else if(load_use_stall_if) begin
            if_id_reg_q <= if_id_reg_q; // stall IF/ID register
            id_ex_reg_q <= '0; // flush ID/EX register
            ex_mem_reg_q <= ex_mem_reg_d;
            mem_wb_reg_q <= mem_wb_reg_d; // MEM/WB proceed normally
        end
        else begin
            if_id_reg_q <= if_id_reg_d;
            id_ex_reg_q <= id_ex_reg_d;
            ex_mem_reg_q <= ex_mem_reg_d;
            mem_wb_reg_q <= mem_wb_reg_d;
        end
    end
end

always_comb begin
    if_id_reg_d.pcplus4 = current_pc_imem_if + 4;
    //if_id_reg_d.pc = current_pc_if;
    if_id_reg_d.pc = current_pc_imem_if; 
    // use the pc that is being processed in imem
    // so pc and actual instr is synchronized
    if_id_reg_d.instruction = instr_if;
    if_id_reg_d.predicted_pc = pc_predict_result_imem_if.predicted_pc; // predicted pc from branch predictor
    // if_id_reg_d.valid = imem_req_ready_if;
    if_id_reg_d.valid = imem_resp_fire_if; // valid when imem response is valid and CPU is ready to accept

    id_ex_reg_d.pc = if_id_reg_q.pc;
    id_ex_reg_d.pcplus4 = if_id_reg_q.pcplus4;
    id_ex_reg_d.rs1_data = rs1_data_id;
    id_ex_reg_d.rs2_data = rs2_data_id;
    id_ex_reg_d.rd = rd_id;
    id_ex_reg_d.imm = imm_id;
    id_ex_reg_d.rs1 = rs1_id;
    id_ex_reg_d.rs2 = rs2_id;
    id_ex_reg_d.uses_rs1 = uses_rs1_id;
    id_ex_reg_d.uses_rs2 = uses_rs2_id;
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
    // mem_wb_reg_d.mem_data = dmem_output; // no longer needed since dmem now returns data in WB stage rather than MEM stage
    mem_wb_reg_d.rs2_data = ex_mem_reg_q.rs2_data;
    mem_wb_reg_d.rd = ex_mem_reg_q.rd;
    mem_wb_reg_d.memsize = ex_mem_reg_q.memsize;
    mem_wb_reg_d.memsign = ex_mem_reg_q.memsign;
    // mem_wb_reg_d.mem_rden = ex_mem_reg_q.mem_re;
    mem_wb_reg_d.dmem_resolved_rden = dmem_resolved_rden; // resolved rden signal that indicate this instr reads from dmem specifically
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
        WB_MEM: wb_data = dmem_output; // now dmem output is processed by lsu_wb and available in WB stage
        WB_PC: wb_data = mem_wb_reg_q.pcplus4; //for JAL/R
        default: wb_data = 32'd0;
    endcase
end

// redirect have higher priority over load-use stall
always_comb begin
    next_pc_if = pc_predict_result_if.predicted_pc; // currently it is static prediction of always not taken
    if(redirect_pc_request_ex) begin
        next_pc_if = redirect_next_pc_ex;
    end
end

always_ff @(posedge clk) begin
    if(!reset_n) begin
        current_pc_imem_if <= 32'd0;
        pc_predict_result_imem_if <= '0;
    end
    else begin
        if(imem_req_fire_if) begin
            current_pc_imem_if <= current_pc_if; // update current_pc_imem to be 1 cycle behind current_pc_if
            pc_predict_result_imem_if <= pc_predict_result_if; // update pc_predict_result_imem to be 1 cycle behind pc_predict_result_if
        end
    end
end

// update pc when imem accepts a request, or request pc redirect
assign pc_update_enable_if = imem_req_fire_if || redirect_pc_request_ex;

endmodule
