// SoC integration: CPU core, local memories, address decoding, and GPIO.
`timescale 1ns / 1ps
import riscv_pkg::*;

module riscv_soc (
    // Inputs
    input  logic clk,
    input  logic reset_n,
    input  logic gpio_btn_in,

    // Outputs
    output logic gpio_led_out
);

logic        imem_req_valid_if;
logic        imem_req_ready_if;
logic [31:0] imem_req_addr_if;
logic        imem_resp_valid_if;
logic        imem_resp_ready_if;
logic [31:0] imem_resp_data_if;
logic        imem_flush_if;

logic        data_req_valid_mem;
logic        data_req_write_mem;
logic [31:0] data_req_addr_mem;
logic [31:0] data_req_wdata_mem;
logic [3:0]  data_req_wstrb_mem;
logic [31:0] data_resp_rdata_wb;

logic dmem_resolved_wren_mem;
logic dmem_resolved_rden_mem;
logic gpio_resolved_wren_mem;
logic gpio_resolved_rden_mem;

logic [31:0] dmem_rdata_wb;
logic [31:0] gpio_rdata_wb;
mmio_wb_sel_t mmio_wb_sel_wb;

riscv_cpu core (
    // Inputs
    .clk                 (clk),
    .reset_n             (reset_n),
    .imem_req_ready_if   (imem_req_ready_if),
    .imem_resp_valid_if  (imem_resp_valid_if),
    .imem_resp_data_if   (imem_resp_data_if),
    .data_resp_rdata_wb  (data_resp_rdata_wb), // data response from peripheral memory-mapped devices

    // Outputs
    .imem_req_valid_if   (imem_req_valid_if),
    .imem_req_addr_if    (imem_req_addr_if),
    .imem_resp_ready_if  (imem_resp_ready_if),
    .imem_flush_if       (imem_flush_if),
    .data_req_valid_mem  (data_req_valid_mem),
    .data_req_write_mem  (data_req_write_mem),
    .data_req_addr_mem   (data_req_addr_mem),
    .data_req_wdata_mem  (data_req_wdata_mem),
    .data_req_wstrb_mem  (data_req_wstrb_mem)
);

imem_if imem (
    // Inputs
    .clk       (clk),
    .reset_n   (reset_n),
    .addr      (imem_req_addr_if),
    .req_valid (imem_req_valid_if),
    .resp_ready(imem_resp_ready_if),
    .flush     (imem_flush_if),

    // Outputs
    .instruction(imem_resp_data_if),
    .req_ready  (imem_req_ready_if),
    .resp_valid (imem_resp_valid_if)
);

address_resolver_mem address_resolver_mem (
    // Inputs
    .clk             (clk),
    .reset_n         (reset_n),
    .addr            (data_req_addr_mem),
    .mmio_device_wren(data_req_valid_mem && data_req_write_mem),
    .mmio_device_rden(data_req_valid_mem && !data_req_write_mem),

    // Outputs
    .mmio_wb_sel       (mmio_wb_sel_wb),
    .dmem_resolved_wren(dmem_resolved_wren_mem),
    .dmem_resolved_rden(dmem_resolved_rden_mem),
    .gpio_resolved_wren(gpio_resolved_wren_mem),
    .gpio_resolved_rden(gpio_resolved_rden_mem)
);

dmem_mem dmem (
    // Inputs
    .clk  (clk),
    .wren (dmem_resolved_wren_mem),
    .rden (dmem_resolved_rden_mem),
    .addr (data_req_addr_mem),
    .wdata(data_req_wdata_mem),
    .wstrb(data_req_wstrb_mem),

    // Outputs
    .rdata(dmem_rdata_wb)
);

gpio gpio (
    // Inputs
    .clk        (clk),
    .reset_n    (reset_n),
    .gpio_wren  (gpio_resolved_wren_mem),
    .gpio_rden  (gpio_resolved_rden_mem),
    .gpio_addr  (data_req_addr_mem),
    .gpio_wdata (data_req_wdata_mem),
    .gpio_wstrb (data_req_wstrb_mem),
    .gpio_btn_in(gpio_btn_in),

    // Outputs
    .rdata       (gpio_rdata_wb),
    .gpio_led_out(gpio_led_out)
);

always_comb begin
    unique case (mmio_wb_sel_wb)
        MMIO_WB_SEL_DMEM: data_resp_rdata_wb = dmem_rdata_wb;
        MMIO_WB_SEL_GPIO: data_resp_rdata_wb = gpio_rdata_wb;
        default:          data_resp_rdata_wb = 32'd0;
    endcase
end

endmodule
