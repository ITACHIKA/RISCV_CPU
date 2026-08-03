`timescale 1ns / 1ps
module imem_if(
    // Inputs
    input logic req_valid,
    input logic resp_ready,
    input logic [31:0] addr,

    // Outputs
    output logic [31:0] instruction,
    output logic req_ready,
    output logic resp_valid
);
logic [31:0] instr_rom [0:255];
initial begin
    $readmemh("asm.mem", instr_rom);
end

assign instruction = instr_rom[addr[31:2]];
assign req_ready = 1'b1;
assign resp_valid = req_valid && resp_ready;

endmodule
