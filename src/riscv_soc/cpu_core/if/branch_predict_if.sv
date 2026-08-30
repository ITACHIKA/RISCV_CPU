`timescale 1ns / 1ps
import riscv_pkg::*;
module branch_predict_if(
    // Inputs
    input logic clk,
    input logic reset_n,
    input logic [31:0] current_pc,

    input logic [31:0] btb_feedback_pc, // the addr of the instr that was used for prediction in previous IF stage
    input logic [31:0] btb_feedback_actual_target, // the actual target PC
    input logic        btb_feedback_taken,
    input logic        btb_feedback_valid,
    input branch_predict_type_t btb_feedback_predict_type, // need to distinguish between JAL and conditional branches

    // Outputs
    output pc_predict_result_t branch_predict_result
);

btb_entry_t [BTB_ENTRIES-1:0] btb_table;

logic [BTB_BITS-1:0] branch_update_index;
logic [7:0] btb_query_tag;
logic [BTB_BITS-1:0] btb_query_index;
logic [XLEN-1:0] btb_result_target;
logic btb_tag_match;
logic btb_result_hit;

logic [1:0] bht_table [BHT_ENTRIES-1:0] = '{default: 2'b01}; // initialize all entries to weakly not taken
logic [BHT_BITS-1:0] bht_query_index; // index into the BHT
logic [BHT_BITS-1:0] bht_update_index; // index into the BHT for updates

assign branch_update_index = btb_feedback_pc[4:2];
assign bht_query_index = current_pc[6:2]; // use bits [6:2] of the current PC to index into the BHT
assign bht_update_index = btb_feedback_pc[6:2]; // use the same index as BTB for BHT update

// 00: strongly not taken
// 01: weakly not taken
// 10: weakly taken
// 11: strongly taken
// only taken when the state is 10 or 11, otherwise not taken
logic bht_predict_taken;
assign bht_predict_taken = bht_table[bht_query_index][1];

// BTB query logic
always_comb begin
    btb_query_index = current_pc[4:2];
    btb_query_tag = current_pc[12:5];
    btb_result_target = btb_table[btb_query_index].target_pc;
    btb_tag_match = (btb_table[btb_query_index].tag == btb_query_tag);
    btb_result_hit = btb_tag_match
    && btb_table[btb_query_index].valid; // entry is valid and tag matches
end

// BTB update logic
always_ff @(posedge clk) begin
    if(!reset_n) begin
        for (int i = 0; i < BTB_ENTRIES; i++) begin
            btb_table[i].valid <= 1'b0;
            btb_table[i].tag <= 8'd0;
            btb_table[i].target_pc <= 32'd0;
            btb_table[i].predict_type <= BP_NONE;
        end
    end
    else begin
        if(btb_feedback_valid && (btb_feedback_predict_type == BP_JAL || (btb_feedback_taken && btb_feedback_predict_type == BP_CONDITIONAL))) begin
            btb_table[branch_update_index].valid <= 1'b1;
            btb_table[branch_update_index].tag <= btb_feedback_pc[12:5];
            btb_table[branch_update_index].target_pc <= btb_feedback_actual_target;
            btb_table[branch_update_index].predict_type <= btb_feedback_predict_type;
        end
    end
end

// BTB predict logic
always_comb begin
    branch_predict_result.predicted_pc = current_pc + 4;
    branch_predict_result.predict_taken = 1'b0;
    if(btb_result_hit) begin
        if(btb_table[btb_query_index].predict_type == BP_JAL) begin
            branch_predict_result.predicted_pc = btb_result_target;
            branch_predict_result.predict_taken = 1'b1; // JAL is always taken
        end
        else if(btb_table[btb_query_index].predict_type == BP_CONDITIONAL) begin
            if(bht_predict_taken) begin
                branch_predict_result.predicted_pc = btb_result_target;
                branch_predict_result.predict_taken = 1'b1;
            end
        end
    end
end

always_ff @(posedge clk) begin
    if(!reset_n) begin
        for (int i = 0; i < BHT_ENTRIES; i++)
            bht_table[i] <= 2'b01;
    end
    else begin
        if(btb_feedback_valid && btb_feedback_predict_type == BP_CONDITIONAL) begin
            if(btb_feedback_taken) begin
                if (bht_table[bht_update_index] != 2'b11)
                    bht_table[bht_update_index] <= bht_table[bht_update_index] + 2'b01;
            end
            else begin
                if(bht_table[bht_update_index] != 2'b00)
                    bht_table[bht_update_index] <= bht_table[bht_update_index] - 2'b01;
            end
        end
    end
end

endmodule
