`timescale 1ns / 1ps
module imem(
    input logic [31:0] addr,
    output logic [31:0] instruction
);
logic [31:0] instr_rom [0:255];
initial begin
    $readmemh("instr_rom.dat", instr_rom);
end

assign instruction = instr_rom[addr[31:2]];

endmodule