// IF stage
`timescale 1ns / 1ps
import riscv_pkg::PC_START;
import riscv_pkg::XLEN;

module pc (
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic [XLEN-1:0] next_pc,

    // Outputs
    output logic [XLEN-1:0] current_pc
);

always_ff @(posedge clk) begin
    if(!reset_n)
        current_pc <= PC_START;
    else
        current_pc <= next_pc;
end
endmodule
