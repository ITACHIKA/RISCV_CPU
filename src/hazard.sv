`timescale 1ns / 1ps
import riscv_pkg::*;
module hazard(
    // Inputs
    // input logic clk,
    // input logic reset_n,
    // input logic [31:0] pc,

    input logic [4:0] rs1_ex,
    input logic [4:0] rs2_ex,
    input logic [4:0] rd_mem,
    input logic [4:0] rd_wb,
    input logic reg_we_mem,
    input logic reg_we_wb,

    input logic valid_ex,

    // Outputs
    output rs_forward_mux_sel_t rs1_forward_mux_sel,
    output rs_forward_mux_sel_t rs2_forward_mux_sel
);

always_comb begin
    rs1_forward_mux_sel = RS_FORWARD_NONE;
    rs2_forward_mux_sel = RS_FORWARD_NONE;

    // do not forward if rd is x0 since its constant 0
    // prioritize MEM stage forwarding over WB stage since MEM stage is closer to EX stage
    if(valid_ex) begin
        if(rs1_ex == rd_mem && reg_we_mem && rd_mem != 5'd0) begin
            rs1_forward_mux_sel = RS_FORWARD_MEM;
        end
        else if(rs1_ex == rd_wb && reg_we_wb && rd_wb != 5'd0) begin
            rs1_forward_mux_sel = RS_FORWARD_WB;
        end
    end
    else begin
        rs1_forward_mux_sel = RS_FORWARD_NONE;
    end

    if(valid_ex) begin
        if(rs2_ex == rd_mem && reg_we_mem && rd_mem != 5'd0) begin
            rs2_forward_mux_sel = RS_FORWARD_MEM;
        end
        else if(rs2_ex == rd_wb && reg_we_wb && rd_wb != 5'd0) begin
            rs2_forward_mux_sel = RS_FORWARD_WB;
        end
    end
    else begin
        rs2_forward_mux_sel = RS_FORWARD_NONE;
    end
end

endmodule
