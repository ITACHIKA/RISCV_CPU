// WB-stage load formatting and register-file writeback selection.
`timescale 1ns / 1ps
import riscv_pkg::*;

module writeback_stage_wb (
    // Inputs
    input  mem_wb_reg_t mem_wb_reg_q,
    input  logic [31:0] data_resp_rdata_wb,

    // Outputs
    output logic [4:0]  rd_addr_wb,
    output logic [31:0] wb_data_wb,
    output logic [31:0] wb_forward_data_wb,
    // output logic        wb_forward_valid_wb,
    output logic        rd_we_wb
);

logic [31:0] load_data_wb;

lsu_wb lsu_wb (
    // Inputs
    .mem_raw_data(data_resp_rdata_wb),
    .mem_addr    (mem_wb_reg_q.alu_result),
    .memsize     (mem_wb_reg_q.memsize),
    .memsign     (mem_wb_reg_q.memsign),
    .rden        (mem_wb_reg_q.mmio_rden && mem_wb_reg_q.valid),

    // Outputs
    .load_data(load_data_wb)
);

// assign wb_forward_valid_wb = mem_wb_reg_q.valid && mem_wb_reg_q.reg_we && (mem_wb_reg_q.wb_sel != WB_MEM); // only forward ALU and PC results, not MEM results

always_comb begin
    unique case (mem_wb_reg_q.wb_sel)
        WB_ALU:  wb_data_wb = mem_wb_reg_q.alu_result;
        WB_MEM:  wb_data_wb = load_data_wb;
        WB_PC:   wb_data_wb = mem_wb_reg_q.pcplus4;
        default: wb_data_wb = 32'd0;
    endcase
end

// special mux for forwarding only
// removed the case for WB_MEM forwarding since in this design load-use stalls pipeline for 2 cycles and there is no need to forward MEM from WB to EX
always_comb begin
    unique case (mem_wb_reg_q.wb_sel)
        WB_ALU:  wb_forward_data_wb = mem_wb_reg_q.alu_result;
        WB_PC:   wb_forward_data_wb = mem_wb_reg_q.pcplus4;
        default: wb_forward_data_wb = 32'd0;
    endcase
end

assign rd_addr_wb = mem_wb_reg_q.rd;
assign rd_we_wb   = mem_wb_reg_q.reg_we && mem_wb_reg_q.valid;

endmodule
