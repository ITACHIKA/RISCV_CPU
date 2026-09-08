`timescale 1ns / 1ps
import riscv_pkg::*;

module system_control (
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic sysctrl_wren,
    input logic sysctrl_rden,
    input logic [31:0] sysctrl_addr,
    input logic [31:0] sysctrl_wdata,
    input logic [3:0] sysctrl_wstrb,

    // Outputs
    output logic [31:0] rdata,
    output bootmode_t bootmode
);

bootmode_t bootmode_reg = BOOTMODE_DOWNLOAD;
assign bootmode = bootmode_reg;

always_ff @(posedge clk) begin
    begin
        if(sysctrl_wren && sysctrl_addr == 32'h1000_F000) begin
            bootmode_reg <= bootmode_t'(sysctrl_wdata[0]);
        end
    end
end

endmodule
