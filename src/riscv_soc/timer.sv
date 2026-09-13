`timescale 1ns / 1ps
import riscv_pkg::*;

module timer (
    // Inputs
    input logic clk,
    input logic reset_n,
    
    input logic [31:0] timer_addr,
    input logic timer_wren,
    input logic timer_rden,
    input logic [31:0] timer_wdata,
    input logic [3:0] timer_wstrb,

    // Outputs
    output logic [31:0] timer_rdata
);

// Timer MMIO registers
// 0x0000: Timer Control Register, RO
// 0x0004: Timer Control SET Register, WO
// 0x0008: Timer Control CLEAR Register, WO
// 0x000C: Timer Time Register Low, RO
// 0x0010: Timer Time Register High, RO

// Timer Control Register bits
// Bit 0: Timer Enable
// Bit 1: Timer Result Clear
// Bit 2: Timer Soft Reset
logic [31:0] timer_ctrl_reg;
logic [31:0] timer_time_low_reg;
logic [31:0] timer_time_high_reg;

logic [31:0] timer_write_mask;
always_comb begin
    timer_write_mask = {
        {8{timer_wstrb[3]}},
        {8{timer_wstrb[2]}},
        {8{timer_wstrb[1]}},
        {8{timer_wstrb[0]}}
    };
end

logic timer_soft_reset;
logic timer_result_clear;
assign timer_soft_reset = (timer_wren && timer_addr[11:0] == 12'h004 && (timer_write_mask[2] & timer_wdata[2]) == 32'd1); // soft reset
assign timer_result_clear = (timer_wren && timer_addr[11:0] == 12'h004 && (timer_write_mask[1] & timer_wdata[1]) == 32'd1); // clear bit SET

always_ff @(posedge clk) begin
    if(!reset_n || timer_soft_reset) begin
        timer_ctrl_reg <= 32'd0;
        timer_rdata <= 32'd0;
    end
    else begin
        if(timer_wren) begin
            if(timer_addr[11:0] == 12'h004) begin
                timer_ctrl_reg <= timer_ctrl_reg | (timer_write_mask & timer_wdata);
            end
            else if(timer_addr[11:0] == 12'h008) begin
                timer_ctrl_reg <= timer_ctrl_reg & ~(timer_write_mask & timer_wdata);
            end
        end
        else if(timer_rden) begin
            if(timer_addr[11:0] == 12'h000) begin
                timer_rdata <= timer_ctrl_reg;
            end
            else if(timer_addr[11:0] == 12'h00C) begin
                timer_rdata <= timer_time_low_reg;
            end
            else if(timer_addr[11:0] == 12'h010) begin
                timer_rdata <= timer_time_high_reg;
            end
        end
    end
end

always_ff @(posedge clk) begin
    if(!reset_n || timer_soft_reset || timer_result_clear) begin // reset or clear result
        timer_time_low_reg <= 32'd0;
        timer_time_high_reg <= 32'd0;
    end
    else begin
        if(timer_ctrl_reg[0]) begin// timer enabled
            {timer_time_high_reg, timer_time_low_reg} <= {timer_time_high_reg, timer_time_low_reg} + 64'd1;
        end
    end
end

endmodule
