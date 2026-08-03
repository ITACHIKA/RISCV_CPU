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

    typedef enum logic [2:0] {
        WB_ALU,
        WB_MEM,
        WB_PC
    } wb_sel_t;

    typedef enum logic [2:0] {
        PC_NEXT,
        PC_BRANCH,
        PC_JAL,
        PC_JALR,
        PC_TRAP
    } pc_sel_t;

    typedef enum logic [2:0] {
        MEM_BYTE,
        MEM_HALF,
        MEM_WORD
    } mem_size_t;

    typedef enum logic {
        MEM_UNSIGNED,
        MEM_SIGNED
    } mem_sign_t;

    typedef enum logic [3:0] {
        ALU_ADD,
        ALU_SUB,
        ALU_XOR,
        ALU_OR,
        ALU_AND,
        ALU_SLL,
        ALU_SRL,
        ALU_SRA,
        ALU_SLT,
        ALU_SLTU,
        ALU_COPY_B,
        ALU_INVALID
    } alu_op_t;

    typedef enum logic [1:0] {
        ALU_SRC_A_RS1,
        ALU_SRC_A_PC
    } alu_src_a_sel_t;

    typedef enum logic [1:0] {
        ALU_SRC_B_RS2,
        ALU_SRC_B_IMM
    } alu_src_b_sel_t;

    typedef logic [6:0] opcode_t;
    localparam opcode_t OPCODE_LOAD =  7'b0000011;
    localparam opcode_t OPCODE_STORE = 7'b0100011;
    localparam opcode_t OPCODE_OP =    7'b0110011;
    localparam opcode_t OPCODE_OP_IMM =7'b0010011;
    localparam opcode_t OPCODE_AUIPC  =7'b0010111;
    localparam opcode_t OPCODE_LUI =   7'b0110111;
    localparam opcode_t OPCODE_BRANCH =7'b1100011;
    localparam opcode_t OPCODE_JALR =  7'b1100111;
    localparam opcode_t OPCODE_JAL =   7'b1101111;

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

// define pipeline stage register packs

typedef struct packed {
    logic valid; // indicate if there is valid instruction to pass to next stage
    // datapath signals
    logic [31:0] pc;
    logic [31:0] pcplus4;
    logic [31:0] instruction;

    logic [31:0] predicted_pc; // predicted pc from branch predictor
} if_id_reg_t;

typedef struct packed {
    logic valid;
    // datapath signals
    logic [31:0] pc;
    logic [31:0] pcplus4;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [4:0] rd;
    logic [31:0] imm;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic uses_rs1;
    logic uses_rs2;

    funct3_t funct3;

    // control signals
    alu_src_a_sel_t alu_src_a_sel;
    alu_src_b_sel_t alu_src_b_sel;
    alu_op_t alu_op;

    logic reg_we;
    logic mem_re;
    logic mem_we;
    mem_size_t memsize;
    mem_sign_t memsign;
    wb_sel_t wb_sel;
    pc_sel_t pc_sel;

    // predicted pc from branch predictor
    // have to be passed to EX stage
    logic [31:0] predicted_pc;

} id_ex_reg_t;

typedef struct packed {
    logic valid;
    // datapath signals
    logic [31:0] pcplus4;
    logic [31:0] alu_result;
    logic [31:0] rs2_data; // for store instruction
    logic [4:0] rd;

    // control signals
    logic reg_we;
    logic mem_re;
    logic mem_we;
    mem_size_t memsize;
    mem_sign_t memsign;
    wb_sel_t wb_sel;
} ex_mem_reg_t;

typedef struct packed {
    logic valid;
    // datapath signals
    logic [31:0] pcplus4;
    logic [31:0] alu_result;
    logic [31:0] mem_data; // data read from memory
    
    logic [31:0] rs2_data; // for store instruction
    logic [4:0] rd;

    // control signals
    logic reg_we;
    wb_sel_t wb_sel;
} mem_wb_reg_t;

typedef struct packed{
    logic predict_taken;
    logic [31:0] predicted_pc;
} pc_predict_result_t;

typedef enum logic [1:0] {
    RS_FORWARD_NONE,
    RS_FORWARD_MEM,
    RS_FORWARD_WB
} rs_forward_mux_sel_t;

endpackage
