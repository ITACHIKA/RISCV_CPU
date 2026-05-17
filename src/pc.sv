`timescale 1ns / 1ps
import riscv_pkg::PC_START;

module pc (
    input logic clk,
    input logic reset_n,
    input logic [31:0] next_pc,
    output logic [31:0] current_pc
);

always_ff @(posedge clk) begin
    if(!reset_n)
        current_pc <= PC_START;
    else
        current_pc <= next_pc;
end
endmodule