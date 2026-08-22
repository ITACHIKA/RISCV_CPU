`timescale 1ns / 1ps
module imem_if(
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic req_valid,
    input logic resp_ready,
    input logic flush, // flush signal to discard the current instruction fetch request
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

logic rden;
assign rden = req_valid && req_ready; // read enable signal, when request is valid and ready to accept new request

// handshake protocol is a little bit complicated here, will come back later

// imem can accept request, when there is no response waiting to be accepted,
// or when CPU is ready to accpet response at this cycle, so a new request can be accepted by the end of this cycle
assign req_ready = (!resp_valid || resp_ready) && !flush;

always_ff @(posedge clk) begin
    if(!reset_n || flush) begin
        resp_valid <= 1'b0;
    end
    else begin
        if(req_ready) begin
            resp_valid <= req_valid;
        end // keep resp_valid if CPU is not ready to accept new instruction
        if(rden) begin // read enable and CPU is capable of accepting new instruction
            instruction <= instr_rom[addr[31:2]];
        end
    end
end

endmodule
