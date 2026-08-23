// Centralized pipeline boundary registers and flush/stall priority.
`timescale 1ns / 1ps
import riscv_pkg::*;

module pipeline_registers (
    // Inputs
    input  logic        clk,
    input  logic        reset_n,
    input  logic        redirect_request_ex,
    input  logic        load_use_stall_if,
    input  if_id_reg_t  if_id_reg_d,
    input  id_ex_reg_t  id_ex_reg_d,
    input  ex_mem_reg_t ex_mem_reg_d,
    input  mem_wb_reg_t mem_wb_reg_d,

    // Outputs
    output if_id_reg_t  if_id_reg_q,
    output id_ex_reg_t  id_ex_reg_q,
    output ex_mem_reg_t ex_mem_reg_q,
    output mem_wb_reg_t mem_wb_reg_q
);

if_id_reg_t  if_id_reg_next;
id_ex_reg_t  id_ex_reg_next;
ex_mem_reg_t ex_mem_reg_next;
mem_wb_reg_t mem_wb_reg_next;

always_comb begin
    if_id_reg_next = if_id_reg_d;
    id_ex_reg_next = id_ex_reg_d;
    ex_mem_reg_next = ex_mem_reg_d;
    mem_wb_reg_next = mem_wb_reg_d;
    if(redirect_request_ex) begin
        if_id_reg_next.valid = 1'b0; // Flush the IF/ID register on redirect
        id_ex_reg_next.valid = 1'b0;
    end
    else if(load_use_stall_if) begin
        if_id_reg_next = if_id_reg_q; // Stall the IF/ID register on load-use hazard
        id_ex_reg_next.valid = 1'b0;
    end
end

always_ff @(posedge clk) begin
    if (!reset_n) begin
        if_id_reg_q  <= '0;
        id_ex_reg_q  <= '0;
        ex_mem_reg_q <= '0;
        mem_wb_reg_q <= '0;
    end
    else begin
        if_id_reg_q  <= if_id_reg_next;
        id_ex_reg_q  <= id_ex_reg_next;
        ex_mem_reg_q <= ex_mem_reg_next;
        mem_wb_reg_q <= mem_wb_reg_next;
    end
end

endmodule
