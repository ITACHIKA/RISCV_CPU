import re

REG = {f"x{i}": i for i in range(32)}

OPCODES = {
    "OP":      0b0110011,
    "OPIMM":   0b0010011,
    "LUI":     0b0110111,
    "AUIPC":   0b0010111,
    "JAL":     0b1101111,
    "JALR":    0b1100111,
    "BRANCH":  0b1100011,
}

FUNCT3 = {
    "ADD_SUB": 0b000,
    "SLL":     0b001,
    "SLT":     0b010,
    "SLTU":    0b011,
    "XOR":     0b100,
    "SR":      0b101,
    "OR":      0b110,
    "AND":     0b111,
    "JALR":    0b000,
    "BEQ":     0b000,
    "BNE":     0b001,
    "BLT":     0b100,
    "BGE":     0b101,
    "BLTU":    0b110,
    "BGEU":    0b111,
}

FUNCT7 = {
    "ADD": 0b0000000,
    "SUB": 0b0100000,
    "SLL": 0b0000000,
    "SRL": 0b0000000,
    "SRA": 0b0100000,
    "OP":  0b0000000,
}

def enc_r(f7, rs2, rs1, f3, rd, opc):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc

def enc_i(imm, rs1, f3, rd, opc):
    imm &= 0xfff
    return (imm << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opc

def enc_u(imm, rd, opc):
    return ((imm & 0xfffff)<<12) | (rd << 7) | opc

def enc_b(imm, rs2, rs1, f3, opc):
    # B-type immediate encoding:
    # imm[12|10:5] -> bits[31:25], imm[4:1] -> bits[11:8], imm[11] -> bits[7]
    imm &= 0x1fff  # 13-bit signed immediate
    bit12 = (imm >> 12) & 0x1
    bit11 = (imm >> 11) & 0x1
    bit10_5 = (imm >> 5) & 0x3f
    bit4_1 = (imm >> 1) & 0xf
    return (bit12 << 31) | (bit10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (bit4_1 << 8) | (bit11 << 7) | opc

def enc_j(imm, rd, opc):
    # J-type immediate encoding:
    # imm[20|10:1|11|19:12] -> bits[31|30:21|20|19:12]
    imm &= 0x1fffff  # 21-bit signed immediate
    bit20 = (imm >> 20) & 0x1
    bit10_1 = (imm >> 1) & 0x3ff
    bit11 = (imm >> 11) & 0x1
    bit19_12 = (imm >> 12) & 0xff
    return (bit20 << 31) | (bit10_1 << 21) | (bit11 << 20) | (bit19_12 << 12) | (rd << 7) | opc

def enc_jalr(imm, rs1, rd, opc):
    # I-type for JALR: imm[11:0] -> bits[31:20]
    imm &= 0xfff
    return (imm << 20) | (rs1 << 15) | (0b000 << 12) | (rd << 7) | opc

def parse_reg(s):
    s = s.strip()
    return REG[s]

def parse_imm(s):
    return int(s, 0)

def encode_line(line):
    line = line.split("#")[0].strip()
    if not line:
        return None

    line = re.sub(r"[,\s]+", " ", line)
    toks = line.split()
    op = toks[0].lower()

    if op == "add":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["ADD"], rs2, rs1, FUNCT3["ADD_SUB"], rd, OPCODES["OP"])

    if op == "sub":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["SUB"], rs2, rs1, FUNCT3["ADD_SUB"], rd, OPCODES["OP"])

    if op == "sll":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["SLL"], rs2, rs1, FUNCT3["SLL"], rd, OPCODES["OP"])

    if op == "srl":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["SRL"], rs2, rs1, FUNCT3["SR"], rd, OPCODES["OP"])

    if op == "sra":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["SRA"], rs2, rs1, FUNCT3["SR"], rd, OPCODES["OP"])

    if op == "and":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["OP"], rs2, rs1, FUNCT3["AND"], rd, OPCODES["OP"])

    if op == "or":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["OP"], rs2, rs1, FUNCT3["OR"], rd, OPCODES["OP"])

    if op == "xor":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["OP"], rs2, rs1, FUNCT3["XOR"], rd, OPCODES["OP"])

    if op == "slt":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["OP"], rs2, rs1, FUNCT3["SLT"], rd, OPCODES["OP"])

    if op == "sltu":
        rd, rs1, rs2 = map(parse_reg, toks[1:4])
        return enc_r(FUNCT7["OP"], rs2, rs1, FUNCT3["SLTU"], rd, OPCODES["OP"])

    if op == "addi":
        rd, rs1 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_i(imm, rs1, FUNCT3["ADD_SUB"], rd, OPCODES["OPIMM"])

    if op == "andi":
        rd, rs1 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_i(imm, rs1, FUNCT3["AND"], rd, OPCODES["OPIMM"])

    if op == "ori":
        rd, rs1 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_i(imm, rs1, FUNCT3["OR"], rd, OPCODES["OPIMM"])

    if op == "xori":
        rd, rs1 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_i(imm, rs1, FUNCT3["XOR"], rd, OPCODES["OPIMM"])

    if op == "slli":
        rd, rs1 = map(parse_reg, toks[1:3])
        shamt = parse_imm(toks[3])
        imm = (FUNCT7["SLL"] << 5) | (shamt & 0x1f)
        return enc_i(imm, rs1, FUNCT3["SLL"], rd, OPCODES["OPIMM"])

    if op == "srli":
        rd, rs1 = map(parse_reg, toks[1:3])
        shamt = parse_imm(toks[3])
        imm = (FUNCT7["SRL"] << 5) | (shamt & 0x1f)
        return enc_i(imm, rs1, FUNCT3["SR"], rd, OPCODES["OPIMM"])

    if op == "srai":
        rd, rs1 = map(parse_reg, toks[1:3])
        shamt = parse_imm(toks[3])
        imm = (FUNCT7["SRA"] << 5) | (shamt & 0x1f)
        return enc_i(imm, rs1, FUNCT3["SR"], rd, OPCODES["OPIMM"])

    if op == "slti":
        rd, rs1 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_i(imm, rs1, FUNCT3["SLT"], rd, OPCODES["OPIMM"])

    if op == "sltiu":
        rd, rs1 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_i(imm, rs1, FUNCT3["SLTU"], rd, OPCODES["OPIMM"])

    if op == "lui":
        rd = parse_reg(toks[1])
        imm = parse_imm(toks[2])
        return enc_u(imm, rd, OPCODES["LUI"])

    if op == "auipc":
        rd = parse_reg(toks[1])
        imm = parse_imm(toks[2])
        return enc_u(imm, rd, OPCODES["AUIPC"])

    if op == "beq":
        rs1, rs2 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_b(imm, rs2, rs1, FUNCT3["BEQ"], OPCODES["BRANCH"])

    if op == "bne":
        rs1, rs2 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_b(imm, rs2, rs1, FUNCT3["BNE"], OPCODES["BRANCH"])

    if op == "blt":
        rs1, rs2 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_b(imm, rs2, rs1, FUNCT3["BLT"], OPCODES["BRANCH"])

    if op == "bge":
        rs1, rs2 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_b(imm, rs2, rs1, FUNCT3["BGE"], OPCODES["BRANCH"])

    if op == "bltu":
        rs1, rs2 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_b(imm, rs2, rs1, FUNCT3["BLTU"], OPCODES["BRANCH"])

    if op == "bgeu":
        rs1, rs2 = map(parse_reg, toks[1:3])
        imm = parse_imm(toks[3])
        return enc_b(imm, rs2, rs1, FUNCT3["BGEU"], OPCODES["BRANCH"])

    if op == "jal":
        rd = parse_reg(toks[1])
        imm = parse_imm(toks[2])
        return enc_j(imm, rd, OPCODES["JAL"])

    if op == "jalr":
        rd = parse_reg(toks[1])
        rs1 = parse_reg(toks[2])
        imm = parse_imm(toks[3])
        return enc_jalr(imm, rs1, rd, OPCODES["JALR"])

    raise ValueError(f"Unsupported instruction: {line}")

# ===== main =====
asm = [
    "addi x1, x0, 5",
    "addi x2, x0, -1",
    "bgeu x1, x2, 8",
    "addi x3, x0, 2",
    "add x4, x1, x2",
    "auipc x5, 0x12345",
    "jal x6, 8",
    "addi x7, x7, 1",
    "jalr x0, x6, 0",
]

with open("instr_rom.mem", "w") as f:
    for line in asm:
        word = encode_line(line)
        if word is not None:
            f.write(f"{word:08x}\n")

print("Wrote instr_rom.mem")