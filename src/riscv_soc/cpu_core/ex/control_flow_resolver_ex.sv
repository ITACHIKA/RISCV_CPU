`timescale 1ns / 1ps
import riscv_pkg::*;
module control_flow_resolver_ex(
    // Inputs
    // input logic clk,
    // input logic reset_n,
    input logic [31:0] current_pc,
    input logic [31:0] predicted_pc,
    input logic predicted_taken,
    input logic branch_taken,

    input logic [31:0] alu_result,
    input logic [31:0] imm,
    input pc_sel_t pc_sel,

    input logic valid_ex,

    // Outputs
    output logic redirect_pc_request,
    output logic [31:0] redirect_next_pc,
    
    output logic [31:0] btb_target_pc,
    output logic btb_update_valid,
    output branch_predict_type_t btb_update_type,
    output logic btb_actual_taken
);

always_comb begin
    redirect_next_pc = 32'd0;
    btb_update_valid = 1'b0;
    btb_update_type = BP_NONE;
    btb_target_pc = 32'd0;
    btb_actual_taken = 1'b0;

    unique case (pc_sel)
        PC_NEXT: begin
            redirect_next_pc = current_pc + 32'd4;
        end

        PC_BRANCH: begin
            redirect_next_pc = branch_taken? current_pc + imm : current_pc + 32'd4;
            // redirect_next_pc = current_pc + imm; // since branch_taken is already checked in redirect_pc_request, we can just use the branch target address here
            btb_update_valid = 1'b1;
            btb_update_type = BP_CONDITIONAL;
            btb_target_pc = current_pc + imm;
            btb_actual_taken = branch_taken;
        end

        PC_JAL: begin
            redirect_next_pc = alu_result;
            btb_update_valid = 1'b1;
            btb_update_type = BP_JAL;
            btb_target_pc = alu_result;
            btb_actual_taken = 1'b1; // JAL is always taken
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
            redirect_pc_request = valid_ex && (branch_taken != predicted_taken); // if branch prediction is wrong, redirect to correct pc

        PC_JAL,
        PC_TRAP:
            redirect_pc_request = valid_ex && !predicted_taken; // if predicted_taken is false, but we have a jump or trap, redirect to correct pc

        PC_JALR:
            redirect_pc_request = valid_ex;
        default:
            redirect_pc_request = 1'b0;
    endcase
end

endmodule
