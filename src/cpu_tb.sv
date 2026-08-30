`timescale 1ns / 1ps
import riscv_pkg::*;
module cpu_tb;

logic clk;
logic reset;
logic [1:0] btn;
logic [0:0] led;

logic reset_n;
assign reset_n = ~reset;

riscv_soc uut (
    .clk         (clk),
    .reset_n     (reset_n),
    .gpio_btn_in (btn),
    .gpio_led_out(led)
);

initial clk=0;
always #5 clk = ~clk;

initial begin
    reset=1;
    btn=2'b00;
    repeat (2) @(posedge clk);
    @(negedge clk);
    reset = 0;
end

initial begin
    @(posedge reset);

    repeat (50000) @(posedge clk);

    $finish;
end

endmodule
