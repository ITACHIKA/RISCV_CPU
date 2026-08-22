`timescale 1ns / 1ps
import riscv_pkg::*;
module lsu_wb( //load store unit in WB stage
    // Inputs
    input logic [31:0] mem_raw_data, //raw data read from dmem
    input logic [31:0] mem_addr, //dmem address
    input mem_size_t memsize,
    input mem_sign_t memsign,
    input logic rden,

    // Outputs
    output logic [31:0] load_data //output to rd after process,
);

always_comb begin
    load_data = 32'd0;
    if(rden) begin
        unique case(memsize)
            MEM_BYTE: begin
                case(mem_addr[1:0])
                    2'b00: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_raw_data[7]}},mem_raw_data[7:0]}: {24'b0,mem_raw_data[7:0]};
                    end
                    2'b01: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_raw_data[15]}},mem_raw_data[15:8]}: {24'b0,mem_raw_data[15:8]};
                    end
                    2'b10: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_raw_data[23]}},mem_raw_data[23:16]}: {24'b0,mem_raw_data[23:16]};
                    end
                    2'b11: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_raw_data[31]}},mem_raw_data[31:24]}: {24'b0,mem_raw_data[31:24]};
                    end
                    default: begin
                        load_data = 32'd0;
                    end
                endcase
            end
            MEM_HALF: begin
                case(mem_addr[1])
                    1'b0: begin
                        load_data = (memsign == MEM_SIGNED)? {{16{mem_raw_data[15]}},mem_raw_data[15:0]}: {16'b0,mem_raw_data[15:0]};
                    end
                    1'b1: begin
                        load_data = (memsign == MEM_SIGNED)? {{16{mem_raw_data[31]}},mem_raw_data[31:16]}: {16'b0,mem_raw_data[31:16]};
                    end
                    default: begin
                        load_data = 32'd0;
                    end
                endcase             
            end
            MEM_WORD: begin
                load_data = mem_raw_data;
            end
        endcase
    end
end

endmodule
