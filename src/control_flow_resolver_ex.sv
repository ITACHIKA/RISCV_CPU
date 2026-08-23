`timescale 1ns / 1ps
import riscv_pkg::*;
module control_flow_resolver_ex(
    // Inputs
    // input logic clk,
    // input logic reset_n,
    input logic [31:0] current_pc,
    input logic [31:0] predicted_next_pc,
    input logic branch_taken,

    input logic [31:0] alu_result,
    input logic [31:0] imm,
    input pc_sel_t pc_sel,

    input logic valid_ex,

    // Outputs
    output logic redirect_pc_request,
    output logic [31:0] redirect_next_pc
);

always_comb begin
    unique case (pc_sel)
        PC_NEXT: begin
            redirect_next_pc = current_pc + 32'd4;
        end

        PC_BRANCH: begin
            // redirect_next_pc = branch_taken? current_pc + imm : current_pc + 32'd4;
            redirect_next_pc = current_pc + imm; // since branch_taken is already checked in redirect_pc_request, we can just use the branch target address here
        end

        PC_JAL: begin
            redirect_next_pc = alu_result;
        end

        PC_JALR: begin
            redirect_next_pc = alu_result & 32'hFFFF_FFFE;
        end

        PC_TRAP: begin
            redirect_next_pc = 32'h0000_0000;
        end

        default: begin
            redirect_next_pc = current_pc + 32'd4;
        end
    endcase
end

always_comb begin
    redirect_pc_request = 1'b0;

    unique case (pc_sel)
        PC_BRANCH:
            redirect_pc_request = valid_ex && branch_taken;

        PC_JAL,
        PC_JALR,
        PC_TRAP:
            redirect_pc_request = valid_ex;

        default:
            redirect_pc_request = 1'b0;
    endcase
end

endmodule
