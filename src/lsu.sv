`timescale 1ns / 1ps
import riscv_pkg::*;
module lsu( //load store unit
    input logic wren,
    //input logic wren, //not for single cycle cpu
    input logic [31:0] addr,
    input logic [31:0] store_data, //from rs2
    input logic [31:0] mem_data, //from mem raw data
    input mem_size_t memsize,
    input mem_sign_t memsign,
    output logic [3:0] wstrb,
    output logic [31:0] mem_wdata, //output to mem after process
    output logic [31:0] load_data, //output to rd after process,
    output logic misalign_except
);

always_comb begin
    wstrb = 4'b0000;
    mem_wdata = 32'd0;
    unique case(memsize)
        MEM_BYTE: begin
            if(wren) begin
                case(addr[1:0])
                    2'b00: begin
                        wstrb = 4'b0001;
                        mem_wdata = {24'b0,store_data[7:0]};
                    end
                    2'b01: begin
                        wstrb = 4'b0010;
                        mem_wdata = {16'b0, store_data[7:0], 8'b0};
                    end
                    2'b10: begin
                        wstrb = 4'b0100;
                        mem_wdata = {8'b0, store_data[7:0], 16'b0};
                    end
                    2'b11: begin
                        wstrb = 4'b1000;
                        mem_wdata = {store_data[7:0],24'b0};
                    end
                    default: begin
                        wstrb = 4'b0000;
                        mem_wdata = 32'd0;
                    end
                endcase
            end
            else begin
                    case(addr[1:0])
                    2'b00: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_data[7]}},mem_data[7:0]}: {24'b0,mem_data[7:0]};
                    end
                    2'b01: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_data[15]}},mem_data[15:8]}: {24'b0,mem_data[15:8]};
                    end
                    2'b10: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_data[23]}},mem_data[23:16]}: {24'b0,mem_data[23:16]};
                    end
                    2'b11: begin
                        load_data = (memsign == MEM_SIGNED)? {{24{mem_data[31]}},mem_data[31:24]}: {24'b0,mem_data[31:24]};
                    end
                    default: begin
                        load_data = 32'd0;
                    end
                endcase                
            end
        end
        MEM_HALF: begin
            if(wren) begin
                case(addr[1])
                    1'b0: begin
                        wstrb = 4'b0011;
                        mem_wdata = {16'b0,store_data[15:0]};
                    end
                    1'b1: begin
                        wstrb = 4'b1100;
                        mem_wdata = {store_data[15:0], 16'b0};
                    end
                    default: begin
                        wstrb = 4'b0000;
                        mem_wdata = 32'd0;
                    end
                endcase
            end
            else begin
                    case(addr[1])
                    1'b0: begin
                        load_data = (memsign == MEM_SIGNED)? {{16{mem_data[15]}},mem_data[15:0]}: {16'b0,mem_data[15:0]};
                    end
                    1'b1: begin
                        load_data = (memsign == MEM_SIGNED)? {{16{mem_data[31]}},mem_data[31:16]}: {16'b0,mem_data[31:16]};
                    end
                    default: begin
                        load_data = 32'd0;
                    end
                endcase                
            end
        end
        MEM_WORD: begin
            if(wren) begin
                wstrb = 4'b1111;
                mem_wdata = store_data;
            end
            else begin
                load_data = mem_data;
            end
        end
    endcase
end

endmodule