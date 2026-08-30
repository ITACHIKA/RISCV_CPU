// Execute stage including forwarding, ALU, comparison, and redirect resolution.
`timescale 1ns / 1ps
import riscv_pkg::*;

module execute_stage_ex (
    // Inputs
    input  id_ex_reg_t            id_ex_reg_q,
    input  ex_mem_reg_t           ex_mem_reg_q,
    input  logic [31:0]           wb_data_wb,
    // input  rs_forward_mux_sel_t   rs1_forward_mux_sel_ex,
    // input  rs_forward_mux_sel_t   rs2_forward_mux_sel_ex,

    // Outputs
    output ex_mem_reg_t           ex_mem_reg_d
    // output logic                  redirect_pc_request_ex,
    // output logic [31:0]           redirect_next_pc_ex
);

logic [31:0] mem_forward_result_ex;
logic [31:0] rs1_forward_result_ex;
logic [31:0] rs2_forward_result_ex;
logic [31:0] alu_a_ex;
logic [31:0] alu_b_ex;
logic [31:0] alu_result_ex;
logic eq_ex;
logic less_signed_ex;
logic less_unsigned_ex;
logic branch_taken_ex;

logic redirect_pc_request_ex;
logic [31:0] redirect_next_pc_ex;

logic [31:0] btb_target_pc_ex;
branch_predict_type_t btb_update_type_ex;
logic btb_update_valid_ex;
logic btb_actual_taken_ex;

always_comb begin
    // unique case (ex_mem_reg_q.wb_sel)
    //     WB_ALU:  mem_forward_result_ex = ex_mem_reg_q.alu_result;
    //     WB_MEM:  mem_forward_result_ex = 32'd0;
    //     WB_PC:   mem_forward_result_ex = ex_mem_reg_q.pcplus4;
    //     default: mem_forward_result_ex = 32'd0;
    // endcase
    mem_forward_result_ex = ex_mem_reg_q.forward_data;
    // use the forwarded data from MEM stage to EX stage, which can be either ALU result or PC+4, but not MEM result
    // for better timing
end

always_comb begin
    unique case (id_ex_reg_q.rs1_forward_mux_sel)
        RS_FORWARD_NONE: rs1_forward_result_ex = id_ex_reg_q.rs1_data;
        RS_FORWARD_MEM:  rs1_forward_result_ex = mem_forward_result_ex;
        RS_FORWARD_WB:   rs1_forward_result_ex = wb_data_wb;
        default:         rs1_forward_result_ex = 32'd0;
    endcase
end

always_comb begin
    unique case (id_ex_reg_q.rs2_forward_mux_sel)
        RS_FORWARD_NONE: rs2_forward_result_ex = id_ex_reg_q.rs2_data;
        RS_FORWARD_MEM:  rs2_forward_result_ex = mem_forward_result_ex;
        RS_FORWARD_WB:   rs2_forward_result_ex = wb_data_wb;
        default:         rs2_forward_result_ex = 32'd0;
    endcase
end

always_comb begin
    unique case (id_ex_reg_q.alu_src_a_sel)
        ALU_SRC_A_RS1: alu_a_ex = rs1_forward_result_ex;
        ALU_SRC_A_PC:  alu_a_ex = id_ex_reg_q.pc;
        default:       alu_a_ex = 32'd0;
    endcase
end

always_comb begin
    unique case (id_ex_reg_q.alu_src_b_sel)
        ALU_SRC_B_RS2: alu_b_ex = rs2_forward_result_ex;
        ALU_SRC_B_IMM: alu_b_ex = id_ex_reg_q.imm;
        default:       alu_b_ex = 32'd0;
    endcase
end

comparator_ex comparator (
    // Inputs
    .a(alu_a_ex),
    .b(alu_b_ex),

    // Outputs
    .eq           (eq_ex),
    .less_signed  (less_signed_ex),
    .less_unsigned(less_unsigned_ex)
);

branch_ex branch (
    // Inputs
    .funct3      (id_ex_reg_q.funct3),
    .eq           (eq_ex),
    .less_signed  (less_signed_ex),
    .less_unsigned(less_unsigned_ex),

    // Outputs
    .take(branch_taken_ex)
);

alu_ex alu (
    // Inputs
    .a            (alu_a_ex),
    .b            (alu_b_ex),
    .alu_op       (id_ex_reg_q.alu_op),
    .less_signed  (less_signed_ex),
    .less_unsigned(less_unsigned_ex),

    // Outputs
    .result(alu_result_ex)
);

control_flow_resolver_ex control_flow_resolver (
    // Inputs
    .current_pc        (id_ex_reg_q.pc),
    .predicted_pc      (id_ex_reg_q.predicted_pc),
    .predicted_taken   (id_ex_reg_q.predicted_taken),
    .branch_taken      (branch_taken_ex),
    .alu_result        (alu_result_ex),
    .imm               (id_ex_reg_q.imm),
    .pc_sel            (id_ex_reg_q.pc_sel),
    .valid_ex          (id_ex_reg_q.valid),

    // Outputs
    .redirect_pc_request(redirect_pc_request_ex),
    .redirect_next_pc   (redirect_next_pc_ex),
    .btb_target_pc      (btb_target_pc_ex),
    .btb_update_valid   (btb_update_valid_ex),
    .btb_update_type    (btb_update_type_ex),
    .btb_actual_taken   (btb_actual_taken_ex)
);

always_comb begin
    ex_mem_reg_d            = '0;
    ex_mem_reg_d.pc         = id_ex_reg_q.pc; // for BTB update in MEM stage
    ex_mem_reg_d.pcplus4    = id_ex_reg_q.pcplus4;
    ex_mem_reg_d.alu_result = alu_result_ex;
    ex_mem_reg_d.rs2_data   = rs2_forward_result_ex;
    ex_mem_reg_d.rd         = id_ex_reg_q.rd;
    ex_mem_reg_d.rs1        = id_ex_reg_q.rs1;
    ex_mem_reg_d.rs2        = id_ex_reg_q.rs2;
    ex_mem_reg_d.reg_we     = id_ex_reg_q.reg_we;
    ex_mem_reg_d.mem_re     = id_ex_reg_q.mem_re;
    ex_mem_reg_d.mem_we     = id_ex_reg_q.mem_we;
    ex_mem_reg_d.memsize    = id_ex_reg_q.memsize;
    ex_mem_reg_d.memsign    = id_ex_reg_q.memsign;
    ex_mem_reg_d.wb_sel     = id_ex_reg_q.wb_sel;
    // determine MEM->EX forward data WHEN data to be forwarded is still in EX stage
    // saves comparison timing in MEM stage. The case of forwarding dmem data is handled by stall so not covered here.
    ex_mem_reg_d.forward_data = (id_ex_reg_q.wb_sel == WB_PC) ? id_ex_reg_q.pcplus4 : alu_result_ex;
    ex_mem_reg_d.predicted_taken = id_ex_reg_q.predicted_taken;
    ex_mem_reg_d.actual_taken = btb_actual_taken_ex;
    ex_mem_reg_d.predicted_pc = id_ex_reg_q.predicted_pc;
    ex_mem_reg_d.redirect_request = redirect_pc_request_ex;
    ex_mem_reg_d.redirect_request_pc = redirect_next_pc_ex; // redirect to the correct pc in MEM stage to cut critical path WNS
    ex_mem_reg_d.btb_target_pc = btb_target_pc_ex;
    ex_mem_reg_d.btb_update_valid = btb_update_valid_ex;
    ex_mem_reg_d.btb_update_type = btb_update_type_ex;
    ex_mem_reg_d.valid      = id_ex_reg_q.valid;
end

endmodule
