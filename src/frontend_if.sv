// Instruction-fetch stage and instruction-memory handshake control.
`timescale 1ns / 1ps
import riscv_pkg::*;

module frontend_if (
    // Inputs
    input  logic        clk,
    input  logic        reset_n,
    input  logic        stall_if,
    input  logic        redirect_request_ex,
    input  logic [31:0] redirect_pc_ex,
    input  logic        imem_req_ready_if,
    input  logic        imem_resp_valid_if,
    input  logic [31:0] imem_resp_data_if,

    // Outputs
    output logic        imem_req_valid_if,
    output logic [31:0] imem_req_addr_if,
    output logic        imem_resp_ready_if,
    output logic        imem_flush_if,
    output if_id_reg_t  if_id_reg_d
);

logic [31:0] current_pc_if;
logic [31:0] current_pc_imem_if;
logic [31:0] next_pc_if;
logic        imem_req_fire_if;
logic        imem_resp_fire_if;
logic        pc_update_enable_if;

pc_predict_result_t pc_predict_result_if;
pc_predict_result_t pc_predict_result_imem_if;

assign imem_req_valid_if  = !stall_if;
assign imem_resp_ready_if = !stall_if;
assign imem_flush_if      = redirect_request_ex;
assign imem_req_addr_if   = current_pc_if;
assign imem_req_fire_if   = imem_req_valid_if && imem_req_ready_if;
assign imem_resp_fire_if  = imem_resp_valid_if && imem_resp_ready_if;

branch_predict_if branch_predict (
    // Inputs
    .clk       (clk),
    .reset_n   (reset_n),
    .current_pc(current_pc_if),

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

always_comb begin
    next_pc_if = pc_predict_result_if.predicted_pc;
    if (redirect_request_ex) begin
        next_pc_if = redirect_pc_ex;
    end
end

assign pc_update_enable_if = imem_req_fire_if || redirect_request_ex;

always_ff @(posedge clk) begin
    if (!reset_n) begin
        current_pc_imem_if          <= 32'd0;
        pc_predict_result_imem_if   <= '0;
    end
    else if(imem_req_fire_if) begin
        current_pc_imem_if        <= current_pc_if;
        pc_predict_result_imem_if <= pc_predict_result_if;
    end
end

always_comb begin
    if_id_reg_d               = '0;
    if_id_reg_d.pc            = current_pc_imem_if;
    if_id_reg_d.pcplus4       = current_pc_imem_if + 32'd4;
    if_id_reg_d.instruction   = imem_resp_data_if;
    if_id_reg_d.predicted_pc  = pc_predict_result_imem_if.predicted_pc;
    if_id_reg_d.valid         = imem_resp_fire_if;
end

endmodule
