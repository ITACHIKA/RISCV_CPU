// Five-stage RISC-V CPU core. Memories, address decoding, and peripherals are external.
`timescale 1ns / 1ps
import riscv_pkg::*;

module riscv_cpu (
    // Inputs
    input  logic        clk,
    input  logic        reset_n,
    input  logic        imem_req_ready_if,
    input  logic        imem_resp_valid_if,
    input  logic [31:0] imem_resp_data_if,
    input  logic [31:0] data_resp_rdata_wb,

    // Outputs
    output logic        imem_req_valid_if,
    output logic [31:0] imem_req_addr_if,
    output logic        imem_resp_ready_if,
    output logic        imem_flush_if,
    output logic        data_req_valid_mem,
    output logic        data_req_write_mem,
    output logic [31:0] data_req_addr_mem,
    output logic [31:0] data_req_wdata_mem,
    output logic [3:0]  data_req_wstrb_mem
);

if_id_reg_t  if_id_reg_q;
if_id_reg_t  if_id_reg_d;
id_ex_reg_t  id_ex_reg_q;
id_ex_reg_t  id_ex_reg_d;
ex_mem_reg_t ex_mem_reg_q;
ex_mem_reg_t ex_mem_reg_d;
mem_wb_reg_t mem_wb_reg_q;
mem_wb_reg_t mem_wb_reg_d;

// logic redirect_pc_request_ex;
// logic [31:0] redirect_next_pc_ex;
logic redirect_pc_request_mem;
logic [31:0] redirect_next_pc_mem;
logic load_use_stall_if;

rs_forward_mux_sel_t rs1_forward_mux_sel_ex;
rs_forward_mux_sel_t rs2_forward_mux_sel_ex;

logic [4:0]  rd_addr_wb;
logic [31:0] wb_data_wb;
logic [31:0] wb_forward_data_wb;
logic        wb_forward_valid_wb;
logic        rd_we_wb;

logic illegal_instr_id;
logic load_misalign_except_mem;
logic store_misalign_except_mem;
logic exception_core;

frontend_if frontend (
    // Inputs
    .clk              (clk),
    .reset_n          (reset_n),
    .stall_if           (load_use_stall_if),
    .redirect_request_mem(redirect_pc_request_mem),
    .redirect_pc_mem     (redirect_next_pc_mem),
    .imem_req_ready_if  (imem_req_ready_if),
    .imem_resp_valid_if (imem_resp_valid_if),
    .imem_resp_data_if  (imem_resp_data_if),

    .btb_feedback_pc_mem             (ex_mem_reg_q.pc),
    .btb_feedback_actual_target_mem  (ex_mem_reg_q.btb_target_pc),
    .btb_feedback_taken_mem          (ex_mem_reg_q.actual_taken),
    .btb_feedback_valid_mem          (ex_mem_reg_q.btb_update_valid && ex_mem_reg_q.valid),
    .btb_feedback_predict_type_mem   (ex_mem_reg_q.btb_update_type),

    // Outputs
    .imem_req_valid_if (imem_req_valid_if),
    .imem_req_addr_if  (imem_req_addr_if),
    .imem_resp_ready_if(imem_resp_ready_if),
    .imem_flush_if     (imem_flush_if),
    .if_id_reg_d    (if_id_reg_d)
);

decode_stage_id decode_stage (
    // Inputs
    .clk        (clk),
    .reset_n    (reset_n),
    .if_id_reg_q(if_id_reg_q),
    .rd_addr_wb  (rd_addr_wb),
    .rd_data_wb  (wb_data_wb),
    .rd_we_wb    (rd_we_wb),

    // Outputs
    .id_ex_reg_d  (id_ex_reg_d),
    .illegal_instr_id(illegal_instr_id)
);

execute_stage_ex execute_stage (
    // Inputs
    .id_ex_reg_q        (id_ex_reg_q),
    .ex_mem_reg_q       (ex_mem_reg_q), // need to connect ex_mem_reg_q to the execute stage for forwarding logic
    // .wb_data_wb             (wb_data_wb),
    .wb_data_wb             (wb_forward_data_wb), // use dedicated forwarding data, which doesn't include MEM forwarding
    .rs1_forward_mux_sel_ex (rs1_forward_mux_sel_ex),
    .rs2_forward_mux_sel_ex (rs2_forward_mux_sel_ex),

    // Outputs
    .ex_mem_reg_d         (ex_mem_reg_d)
    // .redirect_pc_request_ex(redirect_pc_request_ex),
    // .redirect_next_pc_ex   (redirect_next_pc_ex)
);

memory_stage_mem memory_stage (
    // Inputs
    .ex_mem_reg_q(ex_mem_reg_q),

    // Outputs
    .data_req_valid_mem    (data_req_valid_mem),
    .data_req_write_mem    (data_req_write_mem),
    .data_req_addr_mem     (data_req_addr_mem),
    .data_req_wdata_mem    (data_req_wdata_mem),
    .data_req_wstrb_mem    (data_req_wstrb_mem),
    .mem_wb_reg_d          (mem_wb_reg_d),
    .load_misalign_except_mem (load_misalign_except_mem),
    .store_misalign_except_mem(store_misalign_except_mem),
    .redirect_pc_request_mem(redirect_pc_request_mem),
    .redirect_next_pc_mem   (redirect_next_pc_mem)
);

writeback_stage_wb writeback_stage (
    // Inputs
    .mem_wb_reg_q   (mem_wb_reg_q),
    .data_resp_rdata_wb(data_resp_rdata_wb),

    // Outputs
    .rd_addr_wb(rd_addr_wb),
    .wb_data_wb(wb_data_wb),
    .wb_forward_data_wb(wb_forward_data_wb),
    .wb_forward_valid_wb(wb_forward_valid_wb),
    .rd_we_wb  (rd_we_wb)
);

hazard hazard (
    // Inputs
    .rs1_id       (id_ex_reg_d.rs1),
    .rs2_id       (id_ex_reg_d.rs2),
    .rs1_ex       (id_ex_reg_q.rs1),
    .rs2_ex       (id_ex_reg_q.rs2),
    .rd_ex        (id_ex_reg_q.rd),
    .rd_mem       (ex_mem_reg_q.rd),
    .rd_wb        (mem_wb_reg_q.rd),
    .reg_we_mem   (ex_mem_reg_q.reg_we),
    .reg_we_wb    (mem_wb_reg_q.reg_we),
    .wb_forward_valid_wb(wb_forward_valid_wb),
    .valid_id     (if_id_reg_q.valid),
    .valid_ex     (id_ex_reg_q.valid),
    .valid_mem    (ex_mem_reg_q.valid),
    .valid_wb     (mem_wb_reg_q.valid),
    .mem_rden_ex  (id_ex_reg_q.mem_re),
    .mem_rden_mem (ex_mem_reg_q.mem_re),
    .uses_rs1_id  (id_ex_reg_d.uses_rs1),
    .uses_rs2_id  (id_ex_reg_d.uses_rs2),
    .uses_rs1_ex  (id_ex_reg_q.uses_rs1),
    .uses_rs2_ex  (id_ex_reg_q.uses_rs2),

    // Outputs
    .rs1_forward_mux_sel(rs1_forward_mux_sel_ex),
    .rs2_forward_mux_sel(rs2_forward_mux_sel_ex),
    .load_use_stall_if  (load_use_stall_if)
);

pipeline_registers pipeline_regs (
    // Inputs
    .clk             (clk),
    .reset_n         (reset_n),
    .redirect_request_mem(redirect_pc_request_mem),
    .load_use_stall_if  (load_use_stall_if),
    .if_id_reg_d     (if_id_reg_d),
    .id_ex_reg_d     (id_ex_reg_d),
    .ex_mem_reg_d    (ex_mem_reg_d),
    .mem_wb_reg_d    (mem_wb_reg_d),

    // Outputs
    .if_id_reg_q (if_id_reg_q),
    .id_ex_reg_q (id_ex_reg_q),
    .ex_mem_reg_q(ex_mem_reg_q),
    .mem_wb_reg_q(mem_wb_reg_q)
);

assign exception_core = illegal_instr_id ||
                        load_misalign_except_mem ||
                        store_misalign_except_mem;

endmodule
