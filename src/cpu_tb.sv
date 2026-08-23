`timescale 1ns / 1ps
import riscv_pkg::*;
module cpu_tb;

logic clk;
logic reset;
logic [1:0] btn;
logic [0:0] led;

cmod_a7_top uut (
    // Inputs
    .sysclk(clk),
    .reset(reset),
    .btn(btn),

    // Outputs
    .led(led)
);

initial clk=0;
always #5 clk = ~clk;

initial begin
    reset=1;
    btn=2'b00;
    repeat (1) @(posedge clk);
    reset=0;
end

initial begin
    @(posedge reset);

    repeat (300) @(posedge clk);

    $finish;
end

endmodule
