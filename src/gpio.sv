`timescale 1ns / 1ps
import riscv_pkg::*;
module gpio (
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic gpio_wren,
    input logic gpio_rden,
    input logic [31:0] gpio_addr,
    input logic [31:0] gpio_wdata,
    input logic [3:0] gpio_wstrb,
    input logic gpio_btn_in,

    // Outputs
    output logic [31:0] rdata,
    output logic gpio_led_out
);

logic [31:0] led_reg;
logic [31:0] btn_reg;

assign gpio_led_out = led_reg[0];
assign btn_reg = {31'd0, gpio_btn_in};

always_ff @(posedge clk) begin
    if(!reset_n) begin
        led_reg <= 32'd0;
    end
    else
    if(gpio_wren) begin
        if(gpio_addr == 32'h4000_0000) begin
            if(gpio_wstrb[0]) led_reg[7:0] <= gpio_wdata[7:0];
            if(gpio_wstrb[1]) led_reg[15:8] <= gpio_wdata[15:8];
            if(gpio_wstrb[2]) led_reg[23:16] <= gpio_wdata[23:16];
            if(gpio_wstrb[3]) led_reg[31:24] <= gpio_wdata[31:24];
        end
    end
end

// assign rdata = data_ram[addr[31:2]];

always_ff @(posedge clk) begin
    rdata <= 32'd0;
    if(gpio_rden) begin
        if(gpio_addr == 32'h4000_0004) begin
            rdata <= btn_reg;
        end
    end
end

endmodule

