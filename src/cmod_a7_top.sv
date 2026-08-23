// Cmod A7 board-level wrapper.
`timescale 1ns / 1ps

module cmod_a7_top (
    // Inputs
    input  logic       sysclk,
    input  logic       reset,
    input  logic [1:0] btn,

    // Outputs
    output logic [0:0] led
);

logic clk;
logic reset_n;
logic soc_led;
(* ASYNC_REG = "TRUE" *) logic [1:0] gpio_btn_sync_ff;

// assign clk     = sysclk;
assign reset_n = ~reset;
assign led[0]  = soc_led;

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
    .clk_out1(clk)
);

riscv_soc soc (
    // Inputs
    .clk        (clk),
    .reset_n    (reset_n),
    .gpio_btn_in(gpio_btn_sync_ff[1]),

    // Outputs
    .gpio_led_out(soc_led)
);

endmodule
