`timescale 1ns / 1ps
import riscv_pkg::*;
module cpu_tb;

logic clk;
logic reset;

riscv_cpu uut (
    .sysclk(clk),
    .reset(reset)
);

initial clk=0;
always #5 clk = ~clk;

initial begin
    reset=1;
    repeat (1) @(posedge clk);
    reset=0;
end

initial begin
    @(posedge reset);

    repeat (40) @(posedge clk);

    $finish;
end

endmodule