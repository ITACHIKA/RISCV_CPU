`timescale 1ns / 1ps
import riscv_pkg::*;

module uart (
    // Inputs
    input logic clk,
    input logic reset_n,
    
    input logic [31:0] uart_addr,
    input logic uart_wren,
    input logic uart_rden,
    input logic [31:0] uart_wdata,
    input logic [3:0] uart_wstrb,
    input logic uart_rx,

    // Outputs
    output logic [31:0] uart_rdata,
    output logic uart_tx
);

// UART registers
// MMIO address
// 0x0000: Control register read (readonly)
// 0x0004: Control register SET (write only)
// 0x0008: Control register CLEAR (write only)
// 0x000C: Baud rate register
// 0x0010: Status register read (readonly)
// 0x0014: TX data register (write only)
// 0x0018: RX data register read (readonly)

// control reg definitions
// Bit 0: UART enable
// Bit 1: TX enable
// Bit 2: RX enable
// Other: reserved
logic [31:0] uart_control_reg;

// baud reg definitions
// Bit 0-15: Baud rate clock divider
// Bit 16-31: reserved
logic [31:0] uart_baud_reg;
logic [31:0] uart_baud_counter;
logic uart_baud_tick;

// UART status reg definitions
logic [31:0] uart_status_reg;

// For both register, only lower 8 bits are valid
logic [31:0] uart_tx_reg;
logic [31:0] uart_rx_reg;

logic uart_tx_busy;

logic [7:0] uart_tx_fifo [0:15]; // 16 bytes FIFO
logic [4:0] uart_tx_fifo_wp; // n+1 bit FIFO
logic [4:0] uart_tx_fifo_rp;
logic [4:0] uart_tx_fifo_count;
logic uart_tx_fifo_push;
logic uart_tx_fifo_pop;
logic uart_tx_fifo_full;
logic uart_tx_fifo_empty;
assign uart_tx_fifo_full= (uart_tx_fifo_wp[3:0] == uart_tx_fifo_rp[3:0]) && (uart_tx_fifo_wp[4] != uart_tx_fifo_rp[4]);
assign uart_tx_fifo_empty= (uart_tx_fifo_wp[3:0] == uart_tx_fifo_rp[3:0]) && (uart_tx_fifo_wp[4] == uart_tx_fifo_rp[4]);
assign uart_tx_fifo_push = !uart_tx_fifo_full && uart_wren && (uart_addr[11:0] == 12'h014) && uart_wstrb[0];
assign uart_tx_fifo_pop = !uart_tx_fifo_empty && !uart_tx_busy && uart_baud_reg !=0 && uart_control_reg[0] && uart_control_reg[1];
// send a byte for TX when UART TX enabled, fifo not empty, tx not busy and baud rate divider is not 0

always_ff @(posedge clk) begin
    if(!reset_n) begin
        uart_tx_fifo_count <= 5'd0;
    end
    else begin
        if(uart_tx_fifo_push && !uart_tx_fifo_pop) begin
            uart_tx_fifo_count <= uart_tx_fifo_count + 1;
        end
        else if(!uart_tx_fifo_push && uart_tx_fifo_pop) begin
            uart_tx_fifo_count <= uart_tx_fifo_count - 1;
        end
        // otherwise no change
    end
end

logic [31:0] uart_write_mask;
always_comb begin
    uart_write_mask = {
        {8{uart_wstrb[3]}},
        {8{uart_wstrb[2]}},
        {8{uart_wstrb[1]}},
        {8{uart_wstrb[0]}}
    };
end

// UART address decoding
always_ff @(posedge clk) begin
    if(!reset_n) begin
        uart_control_reg <= 32'd0;
        uart_baud_reg <= 32'd0;
        uart_status_reg <= 32'd0;
        uart_tx_reg <= 32'd0;
        uart_rx_reg <= 32'd0;
        uart_tx_fifo_wp <= 5'd0;
    end
    else begin
        uart_rdata <= 32'd0;
        if(uart_wren) begin
            if(uart_addr[11:0] == 12'h004) begin
                uart_control_reg <= uart_control_reg | (uart_wdata & uart_write_mask);
            end
            else if(uart_addr[11:0] == 12'h008) begin
                uart_control_reg <= uart_control_reg & ~(uart_wdata & uart_write_mask);
            end
            else if(uart_addr[11:0] == 12'h00C) begin
                uart_baud_reg <= (uart_wdata & uart_write_mask);
            end
            else if(uart_addr[11:0] == 12'h014) begin
                if(uart_tx_fifo_push) begin // all conditions meet, so can add to FIFO
                    uart_tx_fifo[uart_tx_fifo_wp[3:0]] <= (uart_wdata[7:0] & uart_write_mask[7:0]);
                    uart_tx_fifo_wp <= uart_tx_fifo_wp + 1;
                end
            end
        end
        else if(uart_rden) begin
            if(uart_addr[11:0] == 12'h000) begin
                uart_rdata <= uart_control_reg;
            end
            else if(uart_addr[11:0] == 12'h00C) begin
                uart_rdata <= uart_baud_reg;
            end
            else if(uart_addr[11:0] == 12'h010) begin
                uart_rdata <= uart_status_reg;
            end
            else if(uart_addr[11:0] == 12'h018) begin
                uart_rdata <= uart_rx_reg;
            end
        end
    end
end

// UART clock divider
always_ff @(posedge clk) begin
    if(!reset_n) begin
        uart_baud_counter <= 32'd0;
        uart_baud_tick <= 1'b0;
    end
    else begin
        if(uart_control_reg[0] && uart_baud_reg != 32'd0) // UART enabled and valid baud rate divider
        begin
            if(uart_baud_counter==uart_baud_reg-1) begin
                uart_baud_tick <= 1'b1;
                uart_baud_counter <= 32'd0;
            end
            else begin
                uart_baud_tick <= 1'b0;
                uart_baud_counter <= uart_baud_counter + 1;
            end
        end
        else begin
            uart_baud_tick <= 1'b0;
            uart_baud_counter <= 32'd0;
        end
    end
end

// UART TX module
logic [9:0] uart_tx_shift_reg; // Assume 8N1
logic [3:0] uart_tx_bit_count;
always_ff @(posedge clk) begin
    if(!reset_n) begin
        uart_tx_fifo_rp <= 5'd0;
        uart_tx_shift_reg <= 10'h3FF;
        uart_tx_bit_count <= 4'd0;
        uart_tx <= 1'b1; // idle state is high
        uart_tx_busy <= 1'b0;
    end
    else begin
        if(!uart_control_reg[0] || !uart_control_reg[1]) begin // UART disabled
            uart_tx <= 1'b1; // idle state is high
            uart_tx_busy <= 1'b0;
            uart_tx_bit_count <= 4'd0;
            uart_tx_shift_reg <= 10'h3FF;
        end
        else begin
            if(uart_tx_fifo_pop) begin// the fifo pop condition met
                uart_tx_shift_reg <= {1'b1, uart_tx_fifo[uart_tx_fifo_rp[3:0]], 1'b0}; // start bit, data bits, stop bit
                uart_tx_fifo_rp <= uart_tx_fifo_rp + 1;
                uart_tx_bit_count <= 0;
                uart_tx_busy <= 1'b1;
            end // since CPU clock is much faster UART, after tx_busy=0, the fifo can pop immediately without waiting for tick
            else if(uart_baud_tick && uart_tx_busy)begin
                uart_tx <= uart_tx_shift_reg[0];
                uart_tx_shift_reg <= {1'b1, uart_tx_shift_reg[9:1]}; // shift right, fill with 1 for stop bit
                uart_tx_bit_count <= uart_tx_bit_count + 1;
                if(uart_tx_bit_count == 4'd9) begin // sending last bit (stop bit)
                    uart_tx_busy <= 1'b0;
                    uart_tx <= 1'b1;
                    uart_tx_bit_count <= 4'd0;
                    uart_tx_shift_reg <= 10'h3FF;
                end
            end
        end
    end
end

endmodule
