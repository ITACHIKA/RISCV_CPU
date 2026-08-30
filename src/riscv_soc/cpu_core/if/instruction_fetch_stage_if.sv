// Instruction-fetch stage and instruction-memory handshake control.
`timescale 1ns / 1ps
import riscv_pkg::*;

module instruction_fetch_stage_if (
    // Inputs
    input  logic        clk,
    input  logic        reset_n,
    input  logic        stall_if,
    input  logic        redirect_request_mem,
    input  logic [31:0] redirect_pc_mem,
    input  logic        imem_req_ready_if,
    input  logic        imem_resp_valid_if,
    input  logic [31:0] imem_resp_data_if,

    input logic [31:0] btb_feedback_pc_mem,
    input logic [31:0] btb_feedback_actual_target_mem,
    input logic        btb_feedback_taken_mem,
    input logic        btb_feedback_valid_mem,
    input branch_predict_type_t btb_feedback_predict_type_mem,

    // Outputs
    output logic        imem_req_valid_if,
    output logic [31:0] imem_req_addr_if,
    output logic        imem_resp_ready_if,
    output logic        imem_flush_if,
    output if_id_reg_t  if_id_reg_d
);

// BTB feedback signals from MEM stage are used to train BTB and BHT predictor

logic [31:0] current_pc_if;
logic [31:0] current_pc_imem_if; // the PC used to fetch instruction from IMEM in this cycle
logic [31:0] next_pc_if;
logic        imem_req_fire_if;
logic        imem_resp_fire_if;
logic        pc_update_enable_if;

pc_predict_result_t pc_predict_result_if;
pc_predict_result_t pc_predict_result_imem_if;

// We don't always use current pc for fetch now. If redirect, use redirect PC to fetch directly.
logic [31:0] fetch_pc_if;
assign fetch_pc_if = redirect_request_mem? redirect_pc_mem: current_pc_if; // actual PC used to fetch instr in this cycle

assign imem_req_valid_if  = !stall_if || redirect_request_mem; // while redirecting, send redirected PC to IMEM to fetch
assign imem_resp_ready_if = !stall_if;
assign imem_flush_if      = redirect_request_mem;
assign imem_req_addr_if   = fetch_pc_if;
assign imem_req_fire_if   = imem_req_valid_if && imem_req_ready_if;
assign imem_resp_fire_if  = imem_resp_valid_if && imem_resp_ready_if;

branch_predict_if branch_predict (
    // Inputs
    .clk       (clk),
    .reset_n   (reset_n),
    .current_pc(fetch_pc_if),

    .btb_feedback_pc(btb_feedback_pc_mem),
    .btb_feedback_actual_target(btb_feedback_actual_target_mem),
    .btb_feedback_taken(btb_feedback_taken_mem),
    .btb_feedback_valid(btb_feedback_valid_mem),
    .btb_feedback_predict_type(btb_feedback_predict_type_mem),

    // Outputs
    .branch_predict_result(pc_predict_result_if)
);

pc_if pc (
    // Inputs
    .clk             (clk),
    .reset_n         (reset_n),
    .next_pc         (next_pc_if),
    .pc_update_enable(pc_update_enable_if),

    // Outputs
    .current_pc(current_pc_if)
);

// always_comb begin
//     next_pc_if = pc_predict_result_if.predicted_pc;
//     if (redirect_request_mem) begin
//         next_pc_if = redirect_pc_mem;
//     end
// end

// since we request the redirected PC to IMEM in same cycle, no need to wait for 1 cycle
// directly use the PC predicted using redirect PC for instr fetch as well as next PC
assign next_pc_if = pc_predict_result_if.predicted_pc;
assign pc_update_enable_if = imem_req_fire_if; //|| redirect_request_mem;

always_ff @(posedge clk) begin
    if (!reset_n) begin
        current_pc_imem_if          <= 32'd0;
        pc_predict_result_imem_if   <= '0;
    end
    else if(imem_req_fire_if) begin
        current_pc_imem_if        <= fetch_pc_if;
        pc_predict_result_imem_if <= pc_predict_result_if;
    end
end

always_comb begin
    if_id_reg_d               = '0;
    if_id_reg_d.pc            = current_pc_imem_if;
    if_id_reg_d.pcplus4       = current_pc_imem_if + 32'd4;
    if_id_reg_d.instruction   = imem_resp_data_if;
    if_id_reg_d.predicted_pc  = pc_predict_result_imem_if.predicted_pc;
    if_id_reg_d.predicted_taken = pc_predict_result_imem_if.predict_taken;
    if_id_reg_d.valid         = imem_resp_fire_if;
end

endmodule
