`timescale 1ns / 1ps
import riscv_pkg::*;
module hazard(
    // Inputs
    // input logic clk,
    // input logic reset_n,
    // input logic [31:0] pc,

    input logic [4:0] rs1_id,
    input logic [4:0] rs2_id,
    input logic [4:0] rs1_ex,
    input logic [4:0] rs2_ex,
    input logic [4:0] rs1_mem,
    input logic [4:0] rs2_mem,
    input logic [4:0] rd_ex, // for load-use hazard detection, need rd in EX stage
    input logic [4:0] rd_mem,
    input logic [4:0] rd_wb,
    input logic reg_we_ex,
    input logic reg_we_wb,
    // input logic wb_forward_valid_wb, // for forwarding logic, only forward ALU and PC results, not MEM results
    input logic wb_forward_valid_mem, // same as above, but determine if forward needed in MEM stage

    input logic uses_rs1_id, // for load-use hazard detection
    input logic uses_rs2_id, // for load-use hazard detection
    input logic uses_rs1_ex,
    input logic uses_rs2_ex,
    input logic mem_rden_ex, // for load-use hazard detection
    input logic mem_rden_mem,

    input logic valid_id, // for load-use hazard detection
    input logic valid_ex,
    input logic valid_mem,
    input logic valid_wb,

    // Outputs
    output rs_forward_mux_sel_t rs1_forward_mux_sel,
    output rs_forward_mux_sel_t rs2_forward_mux_sel,

    output logic load_use_stall_if
);

logic mem_forward_valid;
logic rs1_mem_match;
logic rs2_mem_match;
logic rs1_wb_match;
logic rs2_wb_match;

// comapres forwarding in ID with EX and MEM
// result will be piplined into EX stage for actual forwarding
// Cut WNS path for comparing and selecting in EX stage
always_comb begin
    mem_forward_valid =
        valid_ex &&
        reg_we_ex &&
        !mem_rden_ex &&
        (rd_ex != 5'd0);

    rs1_mem_match =
        mem_forward_valid &&
        (rs1_id == rd_ex);

    rs2_mem_match =
        mem_forward_valid &&
        (rs2_id == rd_ex);

    rs1_wb_match =
        wb_forward_valid_mem &&
        (rd_mem != 5'd0) &&
        (rs1_id == rd_mem);

    rs2_wb_match =
        wb_forward_valid_mem &&
        (rd_mem != 5'd0) &&
        (rs2_id == rd_mem);
end

always_comb begin
    rs1_forward_mux_sel = RS_FORWARD_NONE;
    rs2_forward_mux_sel = RS_FORWARD_NONE;

    // do not forward if rd is x0 since its constant 0
    // prioritize MEM stage forwarding over WB stage since MEM stage is closer to EX stage
    
    load_use_stall_if = 
    valid_id && // valid instruction in id
    valid_ex && // valid instruction in ex
    mem_rden_ex && // load instruction in ex stage
    (rd_ex != 5'd0) &&
    ((uses_rs1_id && (rs1_id == rd_ex)) || (uses_rs2_id && (rs2_id == rd_ex)))
    ||
    valid_id && // valid instruction in id
    valid_mem && // valid instruction in mem
    mem_rden_mem && // load instruction in mem stage
    (rd_mem != 5'd0) &&
    ((uses_rs1_id && (rs1_id == rd_mem)) || (uses_rs2_id && (rs2_id == rd_mem)));
/* to solve the WNS issue of critical path:
DMEM BRAM -> WB LSU & Forward MUX-> EX Comparator & Branch Resolver -> PC MUX -> IF stage pc update
We stall load-use for 2 cycles rather than 1, so DMEM data can be written into register
this will cut the critical path from WB DMEM to EX
*/

    rs1_forward_mux_sel = RS_FORWARD_NONE;
    rs2_forward_mux_sel = RS_FORWARD_NONE;

    if (rs1_mem_match)
        rs1_forward_mux_sel = RS_FORWARD_MEM;
    else if (rs1_wb_match)
        rs1_forward_mux_sel = RS_FORWARD_WB;
    if (rs2_mem_match)
        rs2_forward_mux_sel = RS_FORWARD_MEM;
    else if (rs2_wb_match)
        rs2_forward_mux_sel = RS_FORWARD_WB;
end

endmodule
