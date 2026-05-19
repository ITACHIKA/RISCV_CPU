`timescale 1ns / 1ps
import riscv_pkg::*;
module comparator(
    input logic [31:0] a,
    input logic [31:0] b,
    output logic eq,
    output logic less_signed,
    output logic less_unsigned
);

always_comb begin
    eq = (a==b);
    less_signed = ($signed(a) < $signed(b));
    less_unsigned = (a < b);
end

endmodule