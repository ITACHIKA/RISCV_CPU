`timescale 1ns / 1ps
import riscv_pkg::*;
module hazard(
    // Inputs
    // input logic clk,
    // input logic reset_n,
    // input logic [31:0] pc,

    input logic [4:0] rs1_id,
    input logic [4:0] rs2_id,
    input logic [4:0] rs1_ex,
    input logic [4:0] rs2_ex,
    input logic [4:0] rd_ex, // for load-use hazard detection, need rd in EX stage
    input logic [4:0] rd_mem,
    input logic [4:0] rd_wb,
    input logic reg_we_mem,
    input logic reg_we_wb,

    input logic uses_rs1_id, // for load-use hazard detection
    input logic uses_rs2_id, // for load-use hazard detection
    input logic uses_rs1_ex,
    input logic uses_rs2_ex,
    input logic mem_rden_ex, // for load-use hazard detection
    input logic mem_rden_mem,

    input logic valid_id, // for load-use hazard detection
    input logic valid_ex,
    input logic valid_mem,
    input logic valid_wb,

    // Outputs
    output rs_forward_mux_sel_t rs1_forward_mux_sel,
    output rs_forward_mux_sel_t rs2_forward_mux_sel,

    output logic load_use_stall_if
);

always_comb begin
    rs1_forward_mux_sel = RS_FORWARD_NONE;
    rs2_forward_mux_sel = RS_FORWARD_NONE;

    // do not forward if rd is x0 since its constant 0
    // prioritize MEM stage forwarding over WB stage since MEM stage is closer to EX stage
    
    load_use_stall_if = 
    valid_id && // valid instruction in id
    valid_ex && // valid instruction in ex
    mem_rden_ex && // load instruction in ex stage
    (rd_ex != 5'd0) &&
    ((uses_rs1_id && (rs1_id == rd_ex)) || (uses_rs2_id && (rs2_id == rd_ex)));

    if(valid_ex && uses_rs1_ex) begin
        if(rs1_ex == rd_mem && reg_we_mem && rd_mem != 5'd0 && valid_mem) begin
            // do not forward if there is a load instruction in MEM stage, since the data is not ready yet
            if(mem_rden_mem) begin
                rs1_forward_mux_sel = RS_FORWARD_NONE;
            end
            else begin
                rs1_forward_mux_sel = RS_FORWARD_MEM;
            end
        end
        else if(rs1_ex == rd_wb && reg_we_wb && rd_wb != 5'd0 && valid_wb) begin
            rs1_forward_mux_sel = RS_FORWARD_WB;
        end
        else begin
            rs1_forward_mux_sel = RS_FORWARD_NONE;
        end
    end
    else begin
        rs1_forward_mux_sel = RS_FORWARD_NONE;
    end

    if(valid_ex && uses_rs2_ex) begin
        if(rs2_ex == rd_mem && reg_we_mem && rd_mem != 5'd0 && valid_mem) begin
            if(mem_rden_mem) begin
                rs2_forward_mux_sel = RS_FORWARD_NONE;
            end
            else begin
                rs2_forward_mux_sel = RS_FORWARD_MEM;
            end
        end
        else if(rs2_ex == rd_wb && reg_we_wb && rd_wb != 5'd0 && valid_wb) begin
            rs2_forward_mux_sel = RS_FORWARD_WB;
        end
        else begin
            rs2_forward_mux_sel = RS_FORWARD_NONE;
        end
    end
    else begin
        rs2_forward_mux_sel = RS_FORWARD_NONE;
    end
end

endmodule
