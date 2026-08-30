`timescale 1ns / 1ps
import riscv_pkg::*;
module hw_perf_counter(
    // Inputs
    input logic clk,
    input logic reset_n,

    input logic branch,
    input logic branch_miss,
    input logic retired_instr,
    input logic cpu_stall,


    // Outputs

    output logic [63:0] cycle_count,
    output logic [31:0] branch_count,
    output logic [31:0] branch_miss_count,
    output logic [31:0] retired_instr_count,
    output logic [31:0] cpu_stall_count
);

logic [63:0] cycle_counter;
logic [31:0] retired_instr_counter;
logic [31:0] branch_miss_counter;
logic [31:0] branch_counter;
logic [31:0] cpu_stall_counter;

assign cycle_count = cycle_counter;
assign retired_instr_count = retired_instr_counter;
assign branch_miss_count = branch_miss_counter;
assign branch_count = branch_counter;
assign cpu_stall_count = cpu_stall_counter;

always_ff @(posedge clk) begin
    if(!reset_n) begin
        cycle_counter <= 64'd0;
        retired_instr_counter <= 32'd0;
        branch_miss_counter <= 32'd0;
        branch_counter <= 32'd0;
        cpu_stall_counter <= 32'd0;
    end else begin
        cycle_counter <= cycle_counter + 1;
        if (retired_instr) begin
            retired_instr_counter <= retired_instr_counter + 1;
        end
        if (branch) begin
            branch_counter <= branch_counter + 1;
        end
        if (branch_miss) begin
            branch_miss_counter <= branch_miss_counter + 1;
        end
        if (cpu_stall) begin
            cpu_stall_counter <= cpu_stall_counter + 1;
        end
    end
end

endmodule
