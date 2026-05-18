import re

REG = {f"x{i}": i for i in range(32)}

OPCODES = {
    "OP":      0b0110011,
    "OPIMM":   0b0010011,
    "LUI":     0b0110111,
    "AUIPC":   0b0010111,
    "JALR":    0b1100111,
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
    return (imm & 0xfffff000) | (rd << 7) | opc

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

    if op == "lui":
        rd = parse_reg(toks[1])
        imm = parse_imm(toks[2])
        return enc_u(imm, rd, OPCODES["LUI"])

    if op == "auipc":
        rd = parse_reg(toks[1])
        imm = parse_imm(toks[2])
        return enc_u(imm, rd, OPCODES["AUIPC"])

    raise ValueError(f"Unsupported instruction: {line}")

# ===== main =====
asm = [
    "addi x1, x0, 5",
    "addi x2, x1, 3",
    "add  x3, x1, x2",
    "sub  x4, x3, x1",
    "ori  x5, x4, 0x0FF"
]

with open("instr_rom.mem", "w") as f:
    for line in asm:
        word = encode_line(line)
        if word is not None:
            f.write(f"{word:08x}\n")

print("Wrote instr_rom.mem")