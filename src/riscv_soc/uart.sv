`timescale 1ns / 1ps
import riscv_pkg::*;

module uart (
    // Inputs
    input logic clk,
    input logic reset_n,
    
    input logic uart_addr,
    input logic uart_wren,
    input logic uart_rden,
    input logic [31:0] uart_wdata,
    input logic uart_rx,

    // Outputs
    output logic [31:0] uart_rdata,
    output logic uart_tx
);
    
endmodule
