// Cmod A7 board-level wrapper.
`timescale 1ns / 1ps

module z7_lite_top (
    // Inputs
    input  logic       PL_CLK_50M,
    input  logic       PL_KEY2,
    input  logic       PL_KEY1,

    // Outputs
    output logic       PL_LED2
);

logic clk;
logic reset_n;
logic soc_led;
(* ASYNC_REG = "TRUE" *) logic [1:0] gpio_btn_sync_ff;

// assign clk     = sysclk;
assign reset_n = PL_KEY2; // Active low reset on Z7-Lite
assign PL_LED2  = ~soc_led;

always_ff @(posedge clk) begin
    if (!reset_n) begin
        gpio_btn_sync_ff <= 2'b00;
    end
    else begin
        gpio_btn_sync_ff[0] <= ~PL_KEY1;
        gpio_btn_sync_ff[1] <= gpio_btn_sync_ff[0];
    end
end

clk_wiz_0 clk_wiz_inst (
    // Inputs
    .clk_in1(PL_CLK_50M),
    .reset(~reset_n),

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
