// IF stage
`timescale 1ns / 1ps
import riscv_pkg::PC_START;
import riscv_pkg::XLEN;

module pc_if (
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic [XLEN-1:0] next_pc,
    input logic pc_update_enable,

    // Outputs
    output logic [XLEN-1:0] current_pc
);

logic [XLEN-1:0] current_pc_next;

always_comb begin
    current_pc_next = next_pc;
    if(!pc_update_enable)
        current_pc_next = current_pc; // hold the current pc if not updating
end

always_ff @(posedge clk) begin
    if(!reset_n)
        current_pc <= PC_START;
    else
        current_pc <= current_pc_next;
end
endmodule
