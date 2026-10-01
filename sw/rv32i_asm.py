#!/usr/bin/env python3
# =============================================================================
# File: rv32i_asm.py
# Project: ISO 26262 ASIL-D Dual-Core Lockstep (DCLS) Safety SoC
# Description: Self-contained pure Python RV32I assembler.
#              Assembles standard RISC-V assembly into Verilog $readmemh hex
#              format without external GCC toolchain dependencies.
# =============================================================================

import sys
import re

REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15,
    'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21,
    's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}

for i in range(32):
    REG_MAP[f'x{i}'] = i

def parse_reg(r):
    r = r.strip().lower()
    if r in REG_MAP:
        return REG_MAP[r]
    raise ValueError(f"Unknown register '{r}'")

def parse_imm(imm_str):
    imm_str = imm_str.strip()
    return int(imm_str, 0)

def assemble_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def assemble_i(imm, rs1, funct3, rd, opcode):
    imm = imm & 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def assemble_s(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0xFFF
    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0  = imm & 0x1F
    return (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm_4_0 << 7) | opcode

def assemble_b(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0x1FFF
    b12   = (imm >> 12) & 0x1
    b11   = (imm >> 11) & 0x1
    b10_5 = (imm >> 5)  & 0x3F
    b4_1  = (imm >> 1)  & 0xF
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode

def assemble_u(imm, rd, opcode):
    imm_20 = (imm & 0xFFFFF)
    return (imm_20 << 12) | (rd << 7) | opcode

def assemble_j(imm, rd, opcode):
    imm = imm & 0x1FFFFF
    j20   = (imm >> 20) & 0x1
    j19_12= (imm >> 12) & 0xFF
    j11   = (imm >> 11) & 0x1
    j10_1 = (imm >> 1)  & 0x3FF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | (rd << 7) | opcode

def assemble_line(instr, args, pc, labels):
    instr = instr.lower()

    # Pseudo-instructions
    if instr == 'nop':
        return assemble_i(0, 0, 0, 0, 0x13) # addi x0, x0, 0
    elif instr == 'j':
        target = labels[args[0]]
        offset = target - pc
        return assemble_j(offset, 0, 0x6F) # jal x0, offset
    elif instr == 'ret':
        return assemble_i(0, 1, 0, 0, 0x67) # jalr x0, 0(ra)
    elif instr == 'mv':
        rd = parse_reg(args[0])
        rs = parse_reg(args[1])
        return assemble_i(0, rs, 0, rd, 0x13) # addi rd, rs, 0
    elif instr == 'li':
        rd = parse_reg(args[0])
        val = parse_imm(args[1])
        return assemble_i(val, 0, 0, rd, 0x13) # addi rd, x0, val

    # R-Type
    elif instr in ['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and']:
        rd  = parse_reg(args[0])
        rs1 = parse_reg(args[1])
        rs2 = parse_reg(args[2])
        r_table = {
            'add':  (0x00, 0x0), 'sub':  (0x20, 0x0),
            'sll':  (0x00, 0x1), 'slt':  (0x00, 0x2),
            'sltu': (0x00, 0x3), 'xor':  (0x00, 0x4),
            'srl':  (0x00, 0x5), 'sra':  (0x20, 0x5),
            'or':   (0x00, 0x6), 'and':  (0x00, 0x7)
        }
        f7, f3 = r_table[instr]
        return assemble_r(f7, rs2, rs1, f3, rd, 0x33)

    # I-Type ALU
    elif instr in ['addi', 'slti', 'sltiu', 'xori', 'ori', 'andi', 'slli', 'srli', 'srai']:
        rd  = parse_reg(args[0])
        rs1 = parse_reg(args[1])
        imm = parse_imm(args[2])
        i_table = {
            'addi': 0x0, 'slti': 0x2, 'sltiu': 0x3,
            'xori': 0x4, 'ori':  0x6, 'andi':  0x7,
            'slli': 0x1, 'srli': 0x5, 'srai':  0x5
        }
        f3 = i_table[instr]
        if instr == 'srai':
            imm = (0x20 << 5) | (imm & 0x1F)
        return assemble_i(imm, rs1, f3, rd, 0x13)

    # Loads: lw rd, offset(rs1)
    elif instr in ['lb', 'lh', 'lw', 'lbu', 'lhu']:
        rd = parse_reg(args[0])
        match = re.match(r'(-?\w+)\s*\((.+)\)', args[1].strip())
        if not match:
            raise ValueError(f"Malformed load operand '{args[1]}'")
        imm = parse_imm(match.group(1))
        rs1 = parse_reg(match.group(2))
        l_table = {'lb': 0x0, 'lh': 0x1, 'lw': 0x2, 'lbu': 0x4, 'lhu': 0x5}
        return assemble_i(imm, rs1, l_table[instr], rd, 0x03)

    # Stores: sw rs2, offset(rs1)
    elif instr in ['sb', 'sh', 'sw']:
        rs2 = parse_reg(args[0])
        match = re.match(r'(-?\w+)\s*\((.+)\)', args[1].strip())
        if not match:
            raise ValueError(f"Malformed store operand '{args[1]}'")
        imm = parse_imm(match.group(1))
        rs1 = parse_reg(match.group(2))
        s_table = {'sb': 0x0, 'sh': 0x1, 'sw': 0x2}
        return assemble_s(imm, rs2, rs1, s_table[instr], 0x23)

    # Branches: beq rs1, rs2, label
    elif instr in ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu']:
        rs1 = parse_reg(args[0])
        rs2 = parse_reg(args[1])
        target_str = args[2].strip()
        if target_str in labels:
            offset = labels[target_str] - pc
        else:
            offset = parse_imm(target_str)
        b_table = {'beq': 0x0, 'bne': 0x1, 'blt': 0x4, 'bge': 0x5, 'bltu': 0x6, 'bgeu': 0x7}
        return assemble_b(offset, rs2, rs1, b_table[instr], 0x63)

    # U-Type: lui rd, imm
    elif instr == 'lui':
        rd  = parse_reg(args[0])
        imm = parse_imm(args[1])
        return assemble_u(imm, rd, 0x37)

    elif instr == 'auipc':
        rd  = parse_reg(args[0])
        imm = parse_imm(args[1])
        return assemble_u(imm, rd, 0x17)

    # J-Type: jal rd, label
    elif instr == 'jal':
        rd = parse_reg(args[0])
        target_str = args[1].strip()
        if target_str in labels:
            offset = labels[target_str] - pc
        else:
            offset = parse_imm(target_str)
        return assemble_j(offset, rd, 0x6F)

    # JALR: jalr rd, rs1, offset
    elif instr == 'jalr':
        rd  = parse_reg(args[0])
        rs1 = parse_reg(args[1])
        imm = parse_imm(args[2]) if len(args) > 2 else 0
        return assemble_i(imm, rs1, 0x0, rd, 0x67)

    raise ValueError(f"Unsupported instruction '{instr}'")

def assemble_file(src_path, out_hex_path):
    with open(src_path, 'r') as f:
        lines = f.readlines()

    clean_lines = []
    labels = {}
    pc = 0

    # Pass 1: Collect Labels & Strip Comments
    for line in lines:
        line = re.sub(r'#.*$', '', line)
        line = re.sub(r'//.*$', '', line).strip()
        if not line or line.startswith('.'):
            continue

        if ':' in line:
            parts = line.split(':', 1)
            lbl = parts[0].strip()
            labels[lbl] = pc
            rem = parts[1].strip()
            if rem:
                clean_lines.append((pc, rem))
                pc += 4
        else:
            clean_lines.append((pc, line))
            pc += 4

    # Pass 2: Assemble to Machine Code
    hex_words = []
    for cur_pc, text in clean_lines:
        tokens = re.split(r'[\s,]+', text.strip())
        instr = tokens[0]
        args = [t for t in tokens[1:] if t]
        code = assemble_line(instr, args, cur_pc, labels)
        hex_words.append(f"{code:08X}")

    with open(out_hex_path, 'w') as out:
        for w in hex_words:
            out.write(w + '\n')

    print(f"[ASSEMBLER] Successfully assembled {len(hex_words)} instructions -> {out_hex_path}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python rv32i_asm.py <input.S> <output.hex>")
        sys.exit(1)
    assemble_file(sys.argv[1], sys.argv[2])
