`timescale 1ns / 1ps
module imem_if(
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic req_valid,
    input logic resp_ready,
    input logic flush, // flush signal to discard the current instruction fetch request
    input logic [31:0] porta_addr,

    // Outputs
    output logic [31:0] porta_rdata,
    output logic req_ready,
    output logic resp_valid,

    input logic [31:0] portb_addr, // PORTB Addr
    input logic [31:0] portb_wdata, // PORTB Write Data
    input logic [3:0] portb_wstrb, // PORTB Write Strobe
    input logic portb_rden, // read enable signal for data read from instruction memory, PORT B
    input logic portb_wren, // write enable for PORT B
    output logic [31:0] portb_rdata // the data read from instruction memory, used for load instruction, PORT B
);

(* ram_style = "block" *)
logic [31:0] instr_rom [0:8191]; // 32KB instruction memory, 8192 instructions
initial begin
    $readmemh("bootloader.mem", instr_rom);
end

logic rden;
assign rden = req_valid && req_ready; // read enable signal, when request is valid and ready to accept new request

// handshake protocol is a little bit complicated here, will come back later

// imem can accept request, when there is no response waiting to be accepted,
// or when CPU is ready to accpet response at this cycle, so a new request can be accepted by the end of this cycle
// Since we request the redirect PC directly during redirect from IF, so even during flush we accept new request and fetch instr
assign req_ready = (!resp_valid || resp_ready || flush);

always @(posedge clk) begin
    if(rden) begin // read enable and CPU is capable of accepting new instruction
        porta_rdata <= instr_rom[porta_addr[14:2]];
    end
end

always @(posedge clk) begin // use always to avoid conflict with initial block
    if(portb_rden) begin
        portb_rdata <= instr_rom[portb_addr[14:2]];
    end
    else if(portb_wren) begin
        if(portb_wstrb[0]) instr_rom[portb_addr[14:2]][7:0] <= portb_wdata[7:0];
        if(portb_wstrb[1]) instr_rom[portb_addr[14:2]][15:8] <= portb_wdata[15:8];
        if(portb_wstrb[2]) instr_rom[portb_addr[14:2]][23:16] <= portb_wdata[23:16];
        if(portb_wstrb[3]) instr_rom[portb_addr[14:2]][31:24] <= portb_wdata[31:24];
    end
end


always_ff @(posedge clk) begin
    if(!reset_n) begin
        resp_valid <= 1'b0;
    end
    else begin
        if(flush) begin
            resp_valid <= rden;
        end
        else if(req_ready) begin
            resp_valid <= req_valid;
        end // keep resp_valid if CPU is not ready to accept new instruction
    end
end

endmodule
