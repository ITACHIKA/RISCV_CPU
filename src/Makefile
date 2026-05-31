ifneq ($(MAKECMDGOALS),clean)
	ifeq ($(strip $(PRGM)),)
		$(error Usage: make PRGM=<asmname>)
	endif
endif
# ========= Config =========

ASM_DIR := asm

SRC = $(ASM_DIR)/$(PRGM).s

BUILD_DIR := build

BASENAME := $(basename $(notdir $(SRC)))

CC       := riscv64-unknown-elf-gcc
OBJCOPY  := riscv64-unknown-elf-objcopy
OBJDUMP  := riscv64-unknown-elf-objdump

ARCH     := rv32i
ABI      := ilp32

ENTRY    := _start
TEXTADDR := 0x00000000

# ========= Output Files =========

OBJ  := $(BUILD_DIR)/$(BASENAME).o
ELF  := $(BUILD_DIR)/$(BASENAME).elf
BIN  := $(BUILD_DIR)/$(BASENAME).bin
HEX  := $(BUILD_DIR)/$(BASENAME).hex
DUMP := $(BUILD_DIR)/$(BASENAME).dump

# ========= Rules =========

all: clean $(HEX) $(DUMP)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Assemble + Link
$(ELF): $(SRC) | $(BUILD_DIR)
	$(CC) \
	-march=$(ARCH) \
	-mabi=$(ABI) \
	-nostdlib \
	-Wl,-Ttext=$(TEXTADDR) \
	-Wl,-e,$(ENTRY) \
	$(SRC) \
	-o $(ELF)

# Optional object dump
$(OBJ): $(SRC) | $(BUILD_DIR)
	$(CC) \
	-march=$(ARCH) \
	-mabi=$(ABI) \
	-c $(SRC) \
	-o $(OBJ)

# Binary
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $(ELF) $(BIN)

# Verilog HEX
$(HEX): $(ELF)
	$(OBJCOPY) \
	-O verilog \
	--verilog-data-width=4 \
	$(ELF) \
	$(HEX)

# Disassembly
$(DUMP): $(ELF)
	$(OBJDUMP) -d $(ELF) > $(DUMP)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean