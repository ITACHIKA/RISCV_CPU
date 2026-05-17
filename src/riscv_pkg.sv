package riscv_pkg;
    parameter int XLEN = 32;
    parameter int PC_START = 32'h0000_0000;
    typedef enum logic [2:0] {
        IMM_NONE,
        IMM_I,
        IMM_S,
        IMM_B,
        IMM_U,
        IMM_J
    } imm_type_t;

    typedef logic [6:0] opcode_t;
    localparam opcode_t LOAD =  7'b0000011;
    localparam opcode_t STORE = 7'b0100011;
    localparam opcode_t OP =    7'b0110011;
    localparam opcode_t OP_IMM =7'b0010011;
    localparam opcode_t AUIPC  =7'b0010111;
    localparam opcode_t LUI =   7'b0110111;
    localparam opcode_t BRANCH =7'b1100011;
    localparam opcode_t JALR =  7'b1100111;
    localparam opcode_t JAL =   7'b1101111;

    typedef logic [2:0] funct3_t;
    typedef logic [6:0] funct7_t;
    // BRANCH funct3 codes
    localparam funct3_t F3_BEQ = 3'b000;
    localparam funct3_t F3_BNE = 3'b001;
    localparam funct3_t F3_BLT = 3'b100;
    localparam funct3_t F3_BGE = 3'b101;
    localparam funct3_t F3_BLTU= 3'b110;
    localparam funct3_t F3_BGEU= 3'b111;

    //LOAD funct3
    localparam funct3_t F3_LB = 3'b000;
    localparam funct3_t F3_LH = 3'b001;
    localparam funct3_t F3_LW = 3'b010;
    localparam funct3_t F3_LBU= 3'b100;
    localparam funct3_t F3_LHU= 3'b101;

    //STORE funct3
    localparam funct3_t F3_SB = 3'b000;
    localparam funct3_t F3_SH = 3'b001;
    localparam funct3_t F3_SW = 3'b010;

    //OP-IMM funct3
    localparam funct3_t F3_ADDI = 3'b000;
    localparam funct3_t F3_SLTI = 3'b010;
    localparam funct3_t F3_SLTIU= 3'b011;
    localparam funct3_t F3_XORI = 3'b100;
    localparam funct3_t F3_ORI  = 3'b110;
    localparam funct3_t F3_ANDI = 3'b111;

    localparam funct3_t F3_SLLI = 3'b001;
    localparam funct3_t F3_SRLI = 3'b101;
    localparam funct3_t F3_SRAI = 3'b101;

    //Shift Instruction funct7
    localparam funct7_t F7_SLLI = 7'b0000000;
    localparam funct7_t F7_SRLI = 7'b0000000;
    localparam funct7_t F7_SRAI = 7'b0100000;

    //OP funct3
    localparam funct3_t F3_ADD = 3'b000;
    localparam funct3_t F3_SUB = 3'b000;
    localparam funct3_t F3_SLL = 3'b001;
    localparam funct3_t F3_SLT = 3'b010;
    localparam funct3_t F3_SLTU= 3'b011;
    localparam funct3_t F3_XOR = 3'b100;
    localparam funct3_t F3_SRL = 3'b101;
    localparam funct3_t F3_SRA = 3'b101;
    localparam funct3_t F3_OR  = 3'b110;
    localparam funct3_t F3_AND = 3'b111;

    //OP funct7
    localparam funct7_t F7_ADD = 7'b0000000;
    localparam funct7_t F7_SUB = 7'b0100000;
    localparam funct7_t F7_SLL = 7'b0000000;
    localparam funct7_t F7_SLT = 7'b0000000;
    localparam funct7_t F7_SLTU= 7'b0000000;
    localparam funct7_t F7_XOR = 7'b0000000;
    localparam funct7_t F7_SRL = 7'b0000000;
    localparam funct7_t F7_SRA = 7'b0100000;
    localparam funct7_t F7_OR  = 7'b0000000;
    localparam funct7_t F7_AND = 7'b0000000;
endpackage