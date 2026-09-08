ifeq ($(filter clean bootloader,$(MAKECMDGOALS)),)
	ifeq ($(strip $(PRGM)),)
		$(error Usage: make bootloader, make asm PRGM=<asmname>, or make c PRGM=<cname>)
	endif
endif
# ========= Config =========

ASM_DIR := asm
C_DIR   := c
STARTUP := $(C_DIR)/startup.S
BUILD_DIR := build
DRIVER_SRCS := $(C_DIR)/riscv/uart.c

CC       := riscv64-unknown-elf-gcc
OBJCOPY  := riscv64-unknown-elf-objcopy
OBJDUMP  := riscv64-unknown-elf-objdump

ARCH     := rv32i
ABI      := ilp32

ENTRY    := _start
BOOT_BUILD := $(filter bootloader,$(MAKECMDGOALS))
LINKER_SCRIPT := $(if $(BOOT_BUILD),linker_bootloader.ld,linker.ld)
BASENAME := $(if $(BOOT_BUILD),bootloader,$(PRGM))


# make c and make bootloader select C; make asm and legacy make select assembly.
BUILD_MODE := $(if $(filter c bootloader,$(MAKECMDGOALS)),c,asm)

COMMON_FLAGS := -march=$(ARCH) -mabi=$(ABI)
C_ONLY_FLAGS := -O2 -ffreestanding -fno-builtin -fno-pic -fno-pie \
	-ffunction-sections -fdata-sections -fno-unwind-tables \
	-fno-asynchronous-unwind-tables -msmall-data-limit=0
LDFLAGS := -nostdlib -static -Wl,-T,$(LINKER_SCRIPT) \
	-Wl,-e,$(ENTRY) -Wl,--gc-sections

# Override SRCS to build multiple application files.
ifeq ($(BUILD_MODE),c)
	ifneq ($(BOOT_BUILD),)
		APP_SRCS := $(C_DIR)/bootloader.c
	else
		APP_SRCS := $(if $(strip $(SRCS)),$(SRCS),$(C_DIR)/$(PRGM).c)
	endif
	SOURCES     := $(STARTUP) $(APP_SRCS) $(DRIVER_SRCS)
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

asm: $(BIN) $(HEX) $(DUMP)

c: $(BIN) $(HEX) $(DUMP)

bootloader: $(BIN) $(HEX) $(DUMP)

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

.PHONY: all asm c bootloader clean FORCE
