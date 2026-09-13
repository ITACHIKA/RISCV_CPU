// Cmod A7 board-level wrapper.
`timescale 1ns / 1ps

module cmod_a7_top (
    // Inputs
    input  logic       sysclk,
    input  logic       reset,
    input  logic [1:0] btn,
    input  logic       pio2,

    // Outputs
    output logic [0:0] led,
    output logic pio1
);

logic clk;
logic reset_n;
logic soc_led;
(* ASYNC_REG = "TRUE" *) logic [1:0] gpio_btn_sync_ff;

// assign clk     = sysclk;
assign led[0]  = soc_led;
logic clk_locked;
logic [1:0] reset_sync_ff = 2'b00;

always_ff @(posedge clk) begin
    if (!reset_n) begin
        gpio_btn_sync_ff <= 2'b00;
    end
    else begin
        gpio_btn_sync_ff[0] <= btn[1];
        gpio_btn_sync_ff[1] <= gpio_btn_sync_ff[0];
    end
end

clk_wiz_0 clk_wiz_inst (
    // Inputs
    .clk_in1(sysclk),
    .reset(reset),

    // Outputs
    .clk_out1(clk),
    .locked(clk_locked)
);

riscv_soc soc (
    // Inputs
    .clk        (clk),
    .reset_n    (reset_n),
    .gpio_btn_in(gpio_btn_sync_ff[1]),
    .uart_rx   (pio2),

    // Outputs
    .gpio_led_out(soc_led),
    .uart_tx   (pio1)
);

always_ff @(posedge clk or negedge clk_locked) begin
    if (!clk_locked)
        reset_sync_ff <= 2'b00;
    else
        reset_sync_ff <= {reset_sync_ff[0], 1'b1};
end

assign reset_n = reset_sync_ff[1];

endmodule
