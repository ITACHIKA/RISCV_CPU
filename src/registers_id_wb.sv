`timescale 1ns / 1ps
module registers_id_wb(
    // Inputs
    input logic clk,
    input logic reset_n,

    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [4:0] rd_addr,
    input logic [31:0] rd_data,
    input logic rd_we,

    // Outputs
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
// assign rs1_data = (rs1_addr == 0) ? 32'd0 : registers[rs1_addr];
// assign rs2_data = (rs2_addr == 0) ? 32'd0 : registers[rs2_addr];

// we need a forwarding machanism to forward data from WB stage to ID decode
// without forwarding, WB updates register at rising edge, but ID also captures reg at rising edge
// So ID will capture old value of register
always_comb begin
    if(rs1_addr == 5'd0) begin
        rs1_data = 32'd0;
    end
    else begin
        if(rs1_addr == rd_addr && rd_we && rd_addr != 5'd0) begin
            rs1_data = rd_data;
        end
        else begin
            rs1_data = registers[rs1_addr];
        end
    end

    if(rs2_addr == 5'd0) begin
        rs2_data = 32'd0;
    end
    else begin
        if(rs2_addr == rd_addr && rd_we && rd_addr != 5'd0) begin
            rs2_data = rd_data;
        end
        else begin
            rs2_data = registers[rs2_addr];
        end
    end
end

endmodule
