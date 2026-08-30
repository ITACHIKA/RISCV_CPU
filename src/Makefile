ifneq ($(MAKECMDGOALS),clean)
	ifeq ($(strip $(PRGM)),)
		$(error Usage: make asm PRGM=<asmname> or make c PRGM=<cname>)
	endif
endif
# ========= Config =========

ASM_DIR := asm
C_DIR   := c
STARTUP := $(C_DIR)/startup.S
BUILD_DIR := build

BASENAME := asm

CC       := riscv64-unknown-elf-gcc
OBJCOPY  := riscv64-unknown-elf-objcopy
OBJDUMP  := riscv64-unknown-elf-objdump

ARCH     := rv32i
ABI      := ilp32

ENTRY    := _start
LINKER_SCRIPT := linker.ld

# make c selects C; make asm and legacy make select assembly.
BUILD_MODE := $(if $(filter c,$(MAKECMDGOALS)),c,asm)

COMMON_FLAGS := -march=$(ARCH) -mabi=$(ABI)
C_ONLY_FLAGS := -O2 -ffreestanding -fno-builtin -fno-pic -fno-pie \
	-ffunction-sections -fdata-sections -fno-unwind-tables \
	-fno-asynchronous-unwind-tables -msmall-data-limit=0
LDFLAGS := -nostdlib -static -Wl,-T,$(LINKER_SCRIPT) \
	-Wl,-e,$(ENTRY) -Wl,--gc-sections

# Override SRCS to build multiple application files.
ifeq ($(BUILD_MODE),c)
	APP_SRCS    := $(if $(strip $(SRCS)),$(SRCS),$(C_DIR)/$(PRGM).c)
	SOURCES     := $(STARTUP) $(APP_SRCS)
	BUILD_FLAGS := $(COMMON_FLAGS) $(C_ONLY_FLAGS)
	LDLIBS      := -lgcc
else
	SOURCES     := $(if $(strip $(SRCS)),$(SRCS),$(ASM_DIR)/$(PRGM).s)
	BUILD_FLAGS := $(COMMON_FLAGS)
	LDLIBS      :=
endif

# ========= Output Files =========

OBJ  := $(BUILD_DIR)/$(BASENAME).o
ELF  := $(BUILD_DIR)/$(BASENAME).elf
BIN  := $(BUILD_DIR)/$(BASENAME).bin
HEX  := $(BUILD_DIR)/$(BASENAME).mem
DUMP := $(BUILD_DIR)/$(BASENAME).dump

# ========= Rules =========

all: asm

asm: $(HEX) $(DUMP)

c: $(HEX) $(DUMP)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile all selected sources and link them with the shared memory map.
# FORCE prevents reuse of an ELF produced for a different PRGM or mode.
$(ELF): FORCE $(SOURCES) $(LINKER_SCRIPT) | $(BUILD_DIR)
	$(CC) \
	$(BUILD_FLAGS) \
	$(SOURCES) \
	$(LDFLAGS) \
	-o $(ELF) \
	$(LDLIBS)

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

FORCE:

.PHONY: all asm c clean FORCE
