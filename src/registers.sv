`timescale 1ns / 1ps
module registers(
    input logic clk,
    input logic reset_n,

    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [4:0] rd_addr,
    input logic [31:0] rd_data,
    input logic rd_we,

    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

logic [31:0] registers[32]='{default:32'd0};

always_ff @(posedge clk) begin
    if(!reset_n) begin
        for(integer i=0;i<32;i=i+1) begin
            registers[i]<=32'd0;
        end
    end
    else begin
        if(rd_addr!=0 && rd_we) begin
            registers[rd_addr] <= rd_data;
        end
    end
end

// always read 0 from x0
assign rs1_data = (rs1_addr == 0) ? 32'd0 : registers[rs1_addr];
assign rs2_data = (rs2_addr == 0) ? 32'd0 : registers[rs2_addr];

endmodule