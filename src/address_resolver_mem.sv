`timescale 1ns / 1ps
import riscv_pkg::*;
module address_resolver_mem (
    // Inputs
    input logic [31:0] addr,
    input logic mmio_device_wren, // indicate write to all mmio devices including memory
    input logic mmio_device_rden, // indicate read from all mmio devices including memory

    // Outputs
    output logic dmem_resolved_wren,
    output logic dmem_resolved_rden

);

/*
MMIO mapping:
0x0000_0000 - 0x0FFF_FFFF: IMEM
0x1000_0000 - 0x1FFF_FFFF: DMEM

0x4000_0000 - temporary address for a GPIO

*/

localparam LED_ADDR = 32'h4000_0000;

always_comb begin
    dmem_resolved_wren = 1'b0;
    dmem_resolved_rden = 1'b0;

    if(mmio_device_wren) begin
        if(addr >= 32'h1000_0000 && addr <= 32'h1FFF_FFFF) begin
            dmem_resolved_wren = 1'b1;
        end
        else begin
            dmem_resolved_wren = 1'b0;
        end
    end
    else if(mmio_device_rden) begin
        if(addr >= 32'h1000_0000 && addr <= 32'h1FFF_FFFF) begin
            dmem_resolved_rden = 1'b1;
        end
        else begin
            dmem_resolved_rden = 1'b0;
        end
    end
    else begin
        // if no mmio device is accessing, then dmem can access
        dmem_resolved_wren = 1'b0;
        dmem_resolved_rden = 1'b0;
    end
end

endmodule
