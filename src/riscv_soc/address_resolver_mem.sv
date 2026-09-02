`timescale 1ns / 1ps
import riscv_pkg::*;
module address_resolver_mem (
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic [31:0] addr,
    input logic mmio_device_wren, // indicate write to all mmio devices including memory
    input logic mmio_device_rden, // indicate read from all mmio devices including memory

    // Outputs
    output mmio_wb_sel_t mmio_wb_sel,
    output logic dmem_resolved_wren,
    output logic dmem_resolved_rden,
    output logic imem_resolved_rden, // imem is read only
    output logic gpio_resolved_wren,
    output logic gpio_resolved_rden,
    output logic uart_resolved_wren,
    output logic uart_resolved_rden

);

logic illegal_addr_except;

/*
MMIO mapping:
0x0000_0000 - 0x0FFF_FFFF: IMEM
0x8000_0000 - 0x8FFF_FFFF: DMEM

0x1000_0000 - 0x1000_1000: GPIO
0x1000_1000 - 0x1000_2000: UART

0x1000_0000 - temporary address for a GPIO
0x1000_0004 - temporary address for a GPIO

*/

// in general, every MMIO peripheral is assigned a 4K address range, so 1000 in hex

always_comb begin
    dmem_resolved_wren = 1'b0;
    dmem_resolved_rden = 1'b0;
    imem_resolved_rden = 1'b0;
    gpio_resolved_rden = 1'b0;
    gpio_resolved_wren = 1'b0;
    uart_resolved_rden = 1'b0;
    uart_resolved_wren = 1'b0;

    if(mmio_device_wren) begin
        if(addr >= 32'h8000_0000 && addr < 32'h8FFF_FFFF) begin
            dmem_resolved_wren = 1'b1;
        end
        else if(addr >= 32'h1000_0000 && addr < 32'h1000_1000) begin
            gpio_resolved_wren = 1'b1;
        end
        else if(addr >= 32'h1000_1000 && addr < 32'h1000_2000) begin
            uart_resolved_wren = 1'b1;
        end
    end
    else if(mmio_device_rden) begin
        if(addr >= 32'h0000_0000 && addr < 32'h0FFF_FFFF) begin
            imem_resolved_rden = 1'b1;
        end
        else if(addr >= 32'h8000_0000 && addr < 32'h8FFF_FFFF) begin
            dmem_resolved_rden = 1'b1;
        end
        else if(addr >= 32'h1000_0000 && addr < 32'h1000_1000) begin
            gpio_resolved_rden = 1'b1;
        end
        else if(addr >= 32'h1000_1000 && addr < 32'h1000_2000) begin
            uart_resolved_rden = 1'b1;
        end
    end
    else begin // no read or write to MMIO devices
        imem_resolved_rden = 1'b0;
        dmem_resolved_wren = 1'b0;
        dmem_resolved_rden = 1'b0;
        gpio_resolved_wren = 1'b0;
        gpio_resolved_rden = 1'b0;
        uart_resolved_wren = 1'b0;
        uart_resolved_rden = 1'b0;
    end
end

always_ff @(posedge clk) begin
    if(!reset_n) begin
        mmio_wb_sel <= MMIO_WB_SEL_NONE;
    end
    else begin
        if(imem_resolved_rden) begin
            mmio_wb_sel <= MMIO_WB_SEL_IMEM;
        end
        else if(dmem_resolved_rden) begin
            mmio_wb_sel <= MMIO_WB_SEL_DMEM;
        end
        else if(gpio_resolved_rden) begin
            mmio_wb_sel <= MMIO_WB_SEL_GPIO;
        end
        else if(uart_resolved_rden) begin
            mmio_wb_sel <= MMIO_WB_SEL_UART;
        end
        else begin
            mmio_wb_sel <= MMIO_WB_SEL_NONE;
        end
    end
end

endmodule
