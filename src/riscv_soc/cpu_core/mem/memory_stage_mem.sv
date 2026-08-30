// MEM-stage request generation. Memory storage and address decoding live outside the core.
`timescale 1ns / 1ps
import riscv_pkg::*;

module memory_stage_mem (
    // Inputs
    input  ex_mem_reg_t ex_mem_reg_q,

    // Outputs
    output logic        data_req_valid_mem,
    output logic        data_req_write_mem,
    output logic [31:0] data_req_addr_mem,
    output logic [31:0] data_req_wdata_mem,
    output logic [3:0]  data_req_wstrb_mem,
    output mem_wb_reg_t mem_wb_reg_d,
    output logic        load_misalign_except_mem,
    output logic        store_misalign_except_mem,

    output logic                  redirect_pc_request_mem,
    output logic [31:0]           redirect_next_pc_mem
);

logic mem_read_mem;
logic mem_write_mem;

assign mem_read_mem        = ex_mem_reg_q.mem_re && ex_mem_reg_q.valid;
assign mem_write_mem       = ex_mem_reg_q.mem_we && ex_mem_reg_q.valid;
assign data_req_valid_mem  = mem_read_mem || mem_write_mem;
assign data_req_write_mem  = mem_write_mem;
assign data_req_addr_mem   = ex_mem_reg_q.alu_result;

// if data_req_valid is high and data_req_write is low, indicates read, so no need for separate data_req_read signal.

assign redirect_pc_request_mem = ex_mem_reg_q.redirect_request && ex_mem_reg_q.valid;
assign redirect_next_pc_mem = ex_mem_reg_q.redirect_request_pc;

lsu_mem lsu_mem (
    // Inputs
    .wren      (mem_write_mem),
    .rden      (mem_read_mem),
    .addr      (ex_mem_reg_q.alu_result),
    .store_data(ex_mem_reg_q.rs2_data),
    .memsize   (ex_mem_reg_q.memsize),

    // Outputs
    .wstrb                (data_req_wstrb_mem),
    .mem_wdata            (data_req_wdata_mem),
    .load_misalign_except (load_misalign_except_mem),
    .store_misalign_except(store_misalign_except_mem)
);

always_comb begin
    mem_wb_reg_d             = '0;
    mem_wb_reg_d.pcplus4     = ex_mem_reg_q.pcplus4;
    mem_wb_reg_d.alu_result  = ex_mem_reg_q.alu_result;
    mem_wb_reg_d.rs2_data    = ex_mem_reg_q.rs2_data;
    mem_wb_reg_d.rd          = ex_mem_reg_q.rd;
    mem_wb_reg_d.memsize     = ex_mem_reg_q.memsize;
    mem_wb_reg_d.memsign     = ex_mem_reg_q.memsign;
    mem_wb_reg_d.mmio_rden   = ex_mem_reg_q.mem_re;
    mem_wb_reg_d.reg_we      = ex_mem_reg_q.reg_we;
    mem_wb_reg_d.wb_sel      = ex_mem_reg_q.wb_sel;
    mem_wb_reg_d.valid       = ex_mem_reg_q.valid;
end

endmodule
