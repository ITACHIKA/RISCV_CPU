`timescale 1ns / 1ps
import riscv_pkg::*;
module cpu_tb;

logic clk;
logic reset_n;

riscv_cpu uut (
    .clk(clk),
    .reset_n(reset_n)
);

initial clk=0;
always #5 clk = ~clk;

initial begin
    reset_n=0;
    repeat (3) @(posedge clk);
    reset_n=1;
end

initial begin
    @(posedge reset_n);

    repeat (40) @(posedge clk);

    $finish;
end

endmodule