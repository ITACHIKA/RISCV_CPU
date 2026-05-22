`timescale 1ns / 1ps
import riscv_pkg::*;
module dmem(
    input logic clk,
    input logic wren,
    //input logic rden, //not for single cycle cpu
    input logic [31:0] addr,
    input logic [31:0] wdata,
    input logic [3:0] wstrb,
    output logic [31:0] rdata
);

logic [31:0] data_ram [0:255]='{default:32'd0};;

always_ff @(posedge clk) begin
    if(wren) begin
        if(wstrb[0]) data_ram[addr[31:2]][7:0] <= wdata[7:0];
        if(wstrb[1]) data_ram[addr[31:2]][15:8] <= wdata[15:8];
        if(wstrb[2]) data_ram[addr[31:2]][23:16] <= wdata[23:16];
        if(wstrb[3]) data_ram[addr[31:2]][31:24] <= wdata[31:24];
    end
end

assign rdata = data_ram[addr[31:2]];

endmodule