# RV32I Five-Stage Pipelined FPGA SoC

This project implements a 32-bit, single-issue, in-order RISC-V CPU and a small FPGA SoC in SystemVerilog. It began as a single-cycle processor and now includes a five-stage pipeline, data forwarding, load-use interlocks, a BTB+BHT branch predictor, synchronous local memories, GPIO, a polled UART, a 64-bit timer, persistent boot-mode control, performance counters, and a UART software-download path.

The primary FPGA target is the Digilent Cmod A7. A Clocking Wizard converts the 12 MHz board clock to a 100 MHz CPU clock. The core has run GPIO/UART programs and a validated CoreMark workload on hardware.

## Current Configuration

| Item | Current implementation |
| --- | --- |
| ISA | RV32I subset listed below |
| Datapath | 32-bit, little-endian |
| Execution | Single issue, in order |
| Pipeline | IF, ID, EX, MEM, WB |
| Register file | 32 x 32-bit registers; `x0` is hard-wired to zero |
| Instruction memory | 32 KiB synchronous dual-port BRAM model |
| IMEM layout | 4 KiB bootloader + 28 KiB downloadable application |
| Data memory | 32 KiB synchronous local RAM |
| Branch predictor | 8-entry direct-mapped BTB + 32-entry 2-bit BHT |
| Initial reset vector | `0x0000_0000` in download mode |
| User reset vector | `0x0000_1000` in normal mode |
| CPU clock | 100 MHz on Cmod A7 |
| UART | 8N1, programmable divider, 16-byte TX and RX FIFOs |
| Timer | Software-controlled 64-bit CPU-cycle counter |

## System Hierarchy

```text
cmod_a7_top
`-- riscv_soc
    |-- riscv_cpu
    |   |-- instruction_fetch_stage_if
    |   |-- decode_stage_id
    |   |-- execute_stage_ex
    |   |-- memory_stage_mem
    |   |-- writeback_stage_wb
    |   |-- hazard
    |   |-- pipeline_registers
    |   `-- hw_perf_counter
    |-- imem_if
    |-- address_resolver_mem
    |-- dmem_mem
    |-- gpio
    |-- uart
    |-- timer
    `-- system_control
```

The CPU core exposes instruction and data interfaces. Memory storage, address decoding, and peripherals are SoC-level components rather than pipeline internals. The board wrapper provides clock generation, reset release, pin mapping, and asynchronous-input synchronization.

## CPU Pipeline

### IF: Instruction Fetch

The fetch stage:

- Holds the current PC.
- Selects the reset vector, predicted next PC, or a MEM-stage recovery PC.
- Queries the BTB and BHT.
- Drives the IMEM request/response handshake.
- Keeps the request PC and prediction metadata aligned with the one-cycle synchronous response.
- Flushes an outstanding wrong-path response on redirect.
- Issues the redirected fetch during the flush cycle instead of losing another cycle.

### ID: Decode and Register Read

The decode stage:

- Extracts `opcode`, `funct3`, `funct7`, `rs1`, `rs2`, and `rd`.
- Reconstructs I, S, B, U, and J immediates.
- Generates ALU, memory, write-back, and control-flow signals.
- Reads the two register-file operands.
- Marks whether the instruction actually uses `rs1` and `rs2`.
- Applies WB-to-ID bypass so a value written in WB is visible to an ID-stage read in the same cycle.
- Receives forwarding selections from the hazard unit and carries them through ID/EX.

### EX: Execute and Resolve Control Flow

The execute stage:

- Selects register or forwarded operands.
- Performs integer arithmetic, logical operations, shifts, comparisons, and address generation.
- Evaluates conditional branches.
- Computes JAL, JALR, and branch targets.
- Compares predicted and actual direction.
- Produces recovery information and predictor-training metadata.
- Preselects the MEM-forwarded result between an ALU value and `PC + 4`.

### MEM: Data Request and Redirect

The memory stage:

- Issues a load or store request to the SoC data/MMIO interconnect.
- Generates byte write strobes and lane-aligned store data.
- Reports load/store misalignment.
- Applies the redirect registered in EX/MEM.
- Returns resolved branch/JAL feedback to the fetch-stage predictor.
- Builds the MEM/WB payload.

A redirect is generated in EX and registered before being applied in MEM. Therefore, a misprediction flushes younger instructions in IF, ID, and EX.

### WB: Load Formatting and Register Write-Back

The write-back stage:

- Receives the one-cycle synchronous response selected by the SoC.
- Selects a byte, halfword, or word using the saved address.
- Performs signed or unsigned load extension.
- Selects the final result from ALU, load data, or `PC + 4`.
- Writes `rd` only when the MEM/WB entry is valid.

## Hazards and Pipeline Control

Every pipeline boundary contains a `valid` bit. A boundary with `valid = 0` is a bubble, regardless of the other payload bits.

`pipeline_registers` centrally owns IF/ID, ID/EX, EX/MEM, and MEM/WB. Its important behaviors are:

- Reset clears all four pipeline boundaries.
- A load-use stall holds IF/ID and inserts a bubble into ID/EX.
- A MEM-stage redirect invalidates younger IF/ID, ID/EX, and next EX/MEM entries.
- Redirect handling overrides a simultaneous stall.

### Forwarding

Forwarding dependencies are detected using the ID-stage source registers, then the selected path is carried to EX with the instruction. This removes register comparisons from the EX critical path.

| Path | Forwardable result |
| --- | --- |
| MEM to EX | ALU result or `PC + 4` |
| WB to EX | Delayed ALU result or `PC + 4` |
| WB to ID | Final register write-back result, including loads |

The newer result has priority. Loads are deliberately not forwarded directly from synchronous memory into EX.

### Load-Use Interlock

A dependent instruction stalls while its load is in EX and again while the load is in MEM. After these two stall cycles, the load reaches WB and WB-to-ID bypass supplies the value before the consumer enters EX.

This two-cycle policy trades one extra bubble for a shorter FPGA timing path: synchronous BRAM output does not pass through load formatting, forwarding selection, branch comparison, and redirect generation in one cycle.

## Branch Prediction

### BTB

The Branch Target Buffer has eight direct-mapped entries:

- Index: `PC[4:2]`
- Tag: `PC[14:5]`
- Stored fields: valid, 10-bit tag, 32-bit target, and predictor type
- Types: conditional branch or JAL
- Conditional branches allocate when taken.
- JAL allocates whenever resolved.
- JALR is not predicted.

The 10-bit tag covers the implemented 32 KiB IMEM address range without aliasing between different in-range instruction addresses. A JAL hit is always predicted taken. A conditional hit consults the BHT. A miss falls through to `PC + 4`.

### BHT

The Branch History Table contains 32 two-bit saturating counters indexed by `PC[6:2]`. Entries reset to weakly not-taken.

```text
00  strongly not-taken
01  weakly not-taken
10  weakly taken
11  strongly taken
```

Every resolved conditional branch trains its counter. The most significant counter bit supplies the prediction.

### Recovery Policy

For conditional branches, the fast misprediction test compares predicted direction with actual direction. A correctly tagged direct branch or JAL entry is assumed to retain its correct target, avoiding a 32-bit target comparator in the critical path. JALR is unpredicted and redirects to `(rs1 + imm) & ~1`.

## CPU Memory Interfaces

### Instruction Interface

| Signal | Direction | Meaning |
| --- | --- | --- |
| `imem_req_valid_if` | CPU to IMEM | Fetch request is valid |
| `imem_req_ready_if` | IMEM to CPU | Fetch request is accepted |
| `imem_req_addr_if` | CPU to IMEM | Byte address of requested instruction |
| `imem_resp_valid_if` | IMEM to CPU | Instruction response is valid |
| `imem_resp_ready_if` | CPU to IMEM | CPU accepts the response |
| `imem_resp_data_if` | IMEM to CPU | Returned instruction |
| `imem_flush_if` | CPU to IMEM | Discard the wrong-path response |

The IMEM response remains valid under backpressure. The interface can accept a replacement request when there is no pending response, when the existing response is accepted, or during redirect flushing.

### Data/MMIO Interface

| Signal | Direction | Meaning |
| --- | --- | --- |
| `data_req_valid_mem` | CPU to SoC | Load/store transaction is valid |
| `data_req_write_mem` | CPU to SoC | Write when 1; read when 0 |
| `data_req_addr_mem` | CPU to SoC | Byte address |
| `data_req_wdata_mem` | CPU to SoC | Lane-aligned store data |
| `data_req_wstrb_mem` | CPU to SoC | One strobe per byte lane |
| `data_resp_rdata_wb` | SoC to CPU | Read result returned in WB |

The data side currently assumes a fixed one-cycle read response. It has no request-ready or response-valid backpressure.

## Local Memories

### Instruction Memory

`imem_if` models 8192 words, or exactly **32 KiB**.

- Port A is the synchronous instruction-fetch port with ready/valid flow control.
- Port B is a synchronous CPU data-read/write port.
- Port B allows `LB/LH/LW`-style reads from IMEM.
- Port B byte strobes allow the bootloader to write an application one byte at a time.
- Writes below `0x0000_1000` are blocked by the address decoder, protecting the first-stage bootloader region.
- `bootloader.mem` initializes the array during simulation and FPGA configuration.
- The array carries `ram_style = "block"` to request block-RAM inference.

The SystemVerilog array is still named `instr_rom`, but it is no longer functionally read-only.

### Data Memory

`dmem_mem` models 8192 32-bit words, or exactly **32 KiB**, at `0x8000_0000`.

- Reads are synchronous.
- Writes are clocked and use four byte enables.
- The current declaration initializes simulation contents to zero.

Both physical memories index address bits `[14:2]`. The address resolver currently decodes regions much larger than the physical arrays, so out-of-range addresses alias into the 32 KiB memories rather than raising an access fault. Software should remain within the ranges listed below.

## Memory Map

| Address range | Size | Function |
| --- | ---: | --- |
| `0x0000_0000-0x0000_0FFF` | 4 KiB | First-stage bootloader in IMEM; data-side read-only |
| `0x0000_1000-0x0000_7FFF` | 28 KiB | Downloadable user application in IMEM; data-side read/write |
| `0x1000_0000-0x1000_0FFF` | 4 KiB | GPIO window |
| `0x1000_1000-0x1000_1FFF` | 4 KiB | UART window |
| `0x1000_2000-0x1000_2FFF` | 4 KiB | Timer window |
| `0x1000_F000-0x1000_FFFF` | 4 KiB | System-control window |
| `0x8000_0000-0x8000_7FFF` | 32 KiB | Physical DMEM |

### GPIO Registers

Base address: `0x1000_0000`

| Offset | Access | Register |
| --- | --- | --- |
| `0x000` | R/W | LED register; bit 0 drives the current board LED |
| `0x004` | R | Button input; bit 0 contains the synchronized button state |

The board wrapper uses a two-flip-flop synchronizer for the button. It reduces metastability risk but does not debounce mechanical transitions.

### UART Registers

Base address: `0x1000_1000`

| Offset | Access | Register |
| --- | --- | --- |
| `0x000` | R | Configuration value |
| `0x004` | W | Configuration SET |
| `0x008` | W | Configuration CLEAR |
| `0x00C` | R/W | Baud-rate clock divider |
| `0x010` | R | Status |
| `0x014` | W | TX data, low byte |
| `0x018` | R | RX data, low byte; read pops the FIFO |

Configuration bits:

| Bit | Meaning |
| ---: | --- |
| 0 | UART master enable |
| 1 | TX enable |
| 2 | RX enable |
| 3 | Soft-reset request when written through Configuration SET |

Status bits:

| Bit | Meaning |
| ---: | --- |
| 0 | TX FIFO full |
| 1 | TX FIFO empty |
| 2 | RX FIFO full |
| 3 | RX FIFO empty |
| 4 | TX completely idle: FIFO empty and serializer inactive |

The UART implements 8 data bits, no parity, and one stop bit. TX and RX each have a 16-byte FIFO. RX includes an internal two-flip-flop input synchronizer. Communication is polling-based; interrupts and hardware flow control are not implemented.

At 100 MHz, divider 868 is used for approximately 115200 baud.

### Timer Registers

Base address: `0x1000_2000`

| Offset | Access | Register |
| --- | --- | --- |
| `0x000` | R | Timer control |
| `0x004` | W | Control SET / command |
| `0x008` | W | Control CLEAR |
| `0x00C` | R | Counter low 32 bits |
| `0x010` | R | Counter high 32 bits |

Control and command bits:

| Bit | Meaning |
| ---: | --- |
| 0 | Enable counting |
| 1 | Clear the 64-bit count when written to SET |
| 2 | Soft-reset timer state when written to SET |

The timer increments once per CPU clock while enabled. The two halves are read separately and are not currently latched into an atomic snapshot.

### System-Control Register

Base address: `0x1000_F000`

| Offset | Access | Register |
| --- | --- | --- |
| `0x000` | W | Boot mode: 0 = downloader, 1 = user application |

The boot-mode register is intentionally not cleared by the external CPU reset. It initializes to download mode when the FPGA is configured, and software can set it to normal mode after a successful download. A later external reset therefore starts the application at `0x0000_1000`. Reconfiguring or power-cycling the FPGA restores download mode.

The module has a read-data port, but boot-mode readback is not implemented yet.

## First-Stage Bootloader and UART Download

The first 4 KiB of IMEM contains the software first-stage bootloader. The remaining 28 KiB is reserved for the user image.

### Boot Sequence

1. FPGA configuration initializes IMEM from `bootloader.mem` and initializes boot mode to download.
2. Reset starts the CPU at `0x0000_0000`.
3. The bootloader configures UART for 115200 baud at a 100 MHz CPU clock.
4. It waits for a host download request.
5. Incoming payload bytes are written through the CPU data port into IMEM beginning at `0x0000_1000`.
6. The bootloader computes IEEE CRC-32 while receiving the image.
7. On a matching CRC, it selects normal boot mode, reports success, waits for TX idle, soft-resets the UART, and jumps to `0x0000_1000`.
8. The application's startup code initializes `sp`, copies `.data` from IMEM to DMEM, clears `.bss`, sets `a0/a1` to zero, and calls `main`.

IMEM is BRAM, not nonvolatile flash. The downloaded application survives an external CPU reset because that reset does not clear IMEM, but it is lost when the FPGA is reconfigured or powered down.

### Serial Protocol

All multi-byte fields are little-endian.

```text
Host -> target: 0xFF
Target -> host: 0xFE
Host -> target: uint32 image_size
Host -> target: uint32 IEEE_CRC32
Host -> target: image_size raw bytes
Target -> host: 0xFD success
             or 0xFC CRC error
             or 0xFB invalid size
```

The accepted image size is 1 through 28672 bytes. The downloader sends a raw `.bin`; a Verilog `.mem` file is not a raw byte stream and must not be used for this protocol.

## Software Build

Required tools:

- GNU Make
- A RISC-V GNU toolchain using the `riscv64-unknown-elf-` prefix
- Vivado or another SystemVerilog tool for hardware builds
- MinGW-w64 or MSVC to build the Windows downloader

### Build the Bootloader

```sh
make bootloader
```

This uses `linker_bootloader.ld`, links the bootloader into `0x0000_0000-0x0000_0FFF`, and produces:

```text
build/bootloader.elf
build/bootloader.bin
build/bootloader.mem
build/bootloader.dump
```

Add `build/bootloader.mem` to the Vivado project as the initialization file expected by `$readmemh("bootloader.mem", ...)`. The simulator working directory must also make that basename visible.

### Build an Assembly Application

```sh
make asm PRGM=branch_test
```

This selects `asm/branch_test.s`, links it from `0x0000_1000`, and produces files named `build/branch_test.*`.

### Build a C Application

```sh
make c PRGM=gpio
```

This compiles `c/startup.S`, `c/gpio.c`, and the UART driver, then links the application with `linker.ld` at `0x0000_1000`.

Multiple application sources can be selected with `SRCS`:

```sh
make c PRGM=my_app SRCS='c/my_app.c c/helper.c'
```

C builds use `-march=rv32i -mabi=ilp32 -ffreestanding -nostdlib` and link `libgcc` for compiler-generated RV32I helper routines.

### Build and Run the Windows Downloader

With MinGW-w64:

```powershell
g++ -std=c++17 -O2 -Wall -Wextra util/downloader.cpp -o util/downloader.exe -lcomdlg32
```

Choose a program through the file dialog:

```powershell
util\downloader.exe -p COM5 -b 115200
```

Or provide the binary directly:

```powershell
util\downloader.exe --port COM5 --baud 115200 --file build\gpio.bin
```

See `util/README.md` for the downloader-specific notes.

## Supported Instructions

| Category | Instructions |
| --- | --- |
| Register arithmetic/logic | `ADD SUB SLL SLT SLTU XOR SRL SRA OR AND` |
| Immediate arithmetic/logic | `ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI` |
| Upper immediate | `LUI AUIPC` |
| Conditional branch | `BEQ BNE BLT BGE BLTU BGEU` |
| Jump | `JAL JALR` |
| Load | `LB LH LW LBU LHU` |
| Store | `SB SH SW` |

`FENCE`, CSR/system instructions, privilege modes, interrupts, exceptions/traps, and the M/A/F/D/C extensions are not implemented.

## Performance Monitoring and CoreMark

`hw_perf_counter` maintains internal counts for cycles, retired instructions, predictor/branch events, redirect misses, and stall cycles. The instance carries a Vivado `DONT_TOUCH` attribute because its outputs are not yet exposed through MMIO.

A hardware CoreMark run completed with the expected CRC and reported correct operation:

| Metric | Result |
| --- | ---: |
| CPU/timer frequency | 100 MHz |
| Iterations | 1100 |
| Total timer ticks | 1,104,933,608 |
| Calculated CoreMark | approximately 99.55 |
| CoreMark/MHz | approximately 0.996 |

With integer-only output enabled, CoreMark displays the rounded/truncated `Iterations/Sec` value as 100; the values above are calculated from the raw timer ticks.

## Simulation and Test Programs

`cpu_tb.sv` generates a 100 MHz clock, applies reset, and runs for 50,000 cycles, or approximately 500 microseconds. It is primarily intended for waveform inspection rather than full architectural checking.

| Program | Main coverage |
| --- | --- |
| `asm/asm.s` | Basic memory access |
| `asm/branch_test.s` | Branch conditions, prediction, redirects, and flushes |
| `asm/branch_perf_test.s` | Longer predictor/performance-counter workload |
| `asm/dmem_test.s` | Synchronous DMEM, sizes, signs, strobes, and address resolution |
| `asm/fib.s` | Fibonacci loop and realistic branch behavior |
| `asm/forward_test.s` | Basic forwarding |
| `asm/forward_test2.s` | Forwarding priority, bypass, load-use stalls, branch dependencies, JAL/JALR |
| `asm/imem_load_test.s` | Data-side reads from IMEM |
| `asm/gpio_test.s` | Button-controlled LED toggle |
| `asm/findmax.s` | Branch direction changes with memory traffic |
| `asm/memcpy.s` | Function call, memory copy, and result checks |
| `asm/sum.s` | Function call, loop, and return |
| `c/gpio.c` | GPIO from C |
| `c/uart.c` | UART TX/RX behavior |
| `c/timer.c` | Timer readout over UART |
| `c/bootloader.c` | First-stage UART loader and CRC verification |

Several self-checking assembly tests use `x31 = 1` for pass and `x31 = 0xFFFF_FFFF` for failure.

## Hardware Module Reference

### Board and SoC Modules

| File | Module | Responsibility |
| --- | --- | --- |
| `cmod_a7_top.sv` | `cmod_a7_top` | Cmod A7 clock/reset, button synchronizer, LED, and UART pins |
| `z7_top.sv` | `z7_lite_top` | Alternate Z7 Lite board wrapper |
| `riscv_soc/riscv_pkg.sv` | `riscv_pkg` | ISA constants, enums, pipeline payloads, predictor entries, MMIO selection, and boot-mode types |
| `riscv_soc/riscv_soc.sv` | `riscv_soc` | Integrates CPU, memories, decoder, peripherals, read-data mux, and reset-vector selection |
| `riscv_soc/address_resolver_mem.sv` | `address_resolver_mem` | Decodes data transactions and registers the returning read-source selection |
| `riscv_soc/imem_if.sv` | `imem_if` | 32 KiB dual-port instruction memory, fetch handshake, data reads, and bootloader writes |
| `riscv_soc/dmem_mem.sv` | `dmem_mem` | 32 KiB synchronous data RAM with byte strobes |
| `riscv_soc/gpio.sv` | `gpio` | LED output register and synchronized button readback |
| `riscv_soc/uart.sv` | `uart` | Polled 8N1 UART, baud divider, 16-byte TX/RX FIFOs, and soft reset |
| `riscv_soc/timer.sv` | `timer` | Controlled 64-bit cycle counter |
| `riscv_soc/system_control.sv` | `system_control` | Persistent boot-mode state used to choose the reset vector |

### CPU Integration and Control

Paths below are relative to `riscv_soc/cpu_core/`.

| File | Module | Responsibility |
| --- | --- | --- |
| `cpu_core.sv` | `riscv_cpu` | Integrates the five stages and exposes instruction/data interfaces |
| `pipeline_registers.sv` | `pipeline_registers` | Owns all four pipeline boundaries and reset/stall/redirect priority |
| `hazard.sv` | `hazard` | Precomputes forwarding selections and detects two-cycle load-use stalls |
| `hw_perf_counter.sv` | `hw_perf_counter` | Counts cycles, retirement, prediction/redirect, and stall events |

### IF Modules

| File | Module | Responsibility |
| --- | --- | --- |
| `if/instruction_fetch_stage_if.sv` | `instruction_fetch_stage_if` | PC selection, redirect handling, predictor integration, IMEM handshake, and IF/ID payload |
| `if/pc_if.sv` | `pc_if` | Program-counter register with programmable reset vector |
| `if/branch_predict_if.sv` | `branch_predict_if` | BTB/BHT lookup, prediction, allocation, and training |

### ID Modules

| File | Module | Responsibility |
| --- | --- | --- |
| `id/decode_stage_id.sv` | `decode_stage_id` | Integrates field decode, control, immediate generation, register reads, and bypass |
| `id/decoder_id.sv` | `decoder_id` | Extracts instruction fields and selects immediate format |
| `id/control_id.sv` | `control_id` | Generates datapath/control signals and illegal-instruction indication |
| `id/registers_id.sv` | `registers_id_wb` | Register file with `x0` protection and WB-to-ID bypass |
| `id/imm_gen_id.sv` | `imm_gen_id` | Reconstructs and sign-extends RV32I immediates |

### EX Modules

| File | Module | Responsibility |
| --- | --- | --- |
| `ex/execute_stage_ex.sv` | `execute_stage_ex` | Forwarding muxes, ALU, comparison, branch decision, control-flow resolution, and EX/MEM payload |
| `ex/alu_ex.sv` | `alu_ex` | Integer arithmetic, logic, shifts, and set-less-than operations |
| `ex/comparator_ex.sv` | `comparator_ex` | Equality and signed/unsigned magnitude comparisons |
| `ex/branch_ex.sv` | `branch_ex` | Converts comparison flags and `funct3` into a branch-taken result |
| `ex/control_flow_resolver_ex.sv` | `control_flow_resolver_ex` | Builds redirect PC and BTB/BHT feedback for branch, JAL, and JALR |

### MEM and WB Modules

| File | Module | Responsibility |
| --- | --- | --- |
| `mem/memory_stage_mem.sv` | `memory_stage_mem` | Generates SoC transactions, redirect outputs, MEM/WB payload, and forwarding-valid state |
| `mem/lsu_mem.sv` | `lsu_mem` | Store-byte placement, write strobes, and access-alignment checks |
| `wb/writeback_stage_wb.sv` | `writeback_stage_wb` | Formats load data and selects architectural/forwarded write-back values |
| `wb/lsu_wb.sv` | `lsu_wb` | Selects and extends loaded bytes, halfwords, and words |

## Current Limitations

- No trap/CSR subsystem, privilege modes, interrupts, or exception handler.
- Illegal and misaligned access indications are not connected to architectural traps.
- Misaligned stores do not yet guarantee suppression of all side effects.
- The data/MMIO interface cannot wait for variable-latency devices.
- Physical IMEM/DMEM bounds are not enforced; decoded out-of-range addresses alias.
- IMEM boot protection is address-decoder based, not a security boundary.
- JALR has no prediction or return-address stack.
- Direct-branch recovery assumes a matching BTB entry contains the correct target.
- UART is polling-only and does not report framing/overrun errors to software.
- Timer low/high reads are not atomic.
- Boot-mode readback is not implemented.
- Performance counters are not MMIO-visible.
- The GPIO button is synchronized but not debounced.
- The simulation environment is not yet a complete instruction-level self-checking testbench.

## Directory Structure

```text
src/
|-- cmod_a7_top.sv
|-- z7_top.sv
|-- cpu_tb.sv
|-- cmod_a7.xdc
|-- Z7_LITE.xdc
|-- Makefile
|-- linker.ld
|-- linker_bootloader.ld
|-- readme.md
|-- asm/
|-- c/
|   |-- startup.S
|   |-- bootloader.c
|   `-- riscv/
|       |-- io_cmoda7.h
|       |-- uart.h
|       `-- uart.c
|-- util/
|   |-- downloader.cpp
|   `-- README.md
`-- riscv_soc/
    |-- riscv_pkg.sv
    |-- riscv_soc.sv
    |-- address_resolver_mem.sv
    |-- imem_if.sv
    |-- dmem_mem.sv
    |-- gpio.sv
    |-- uart.sv
    |-- timer.sv
    |-- system_control.sv
    `-- cpu_core/
        |-- cpu_core.sv
        |-- pipeline_registers.sv
        |-- hazard.sv
        |-- hw_perf_counter.sv
        |-- if/
        |-- id/
        |-- ex/
        |-- mem/
        `-- wb/
```

After moving RTL files, update the Vivado project's explicit source paths and reset synthesis/implementation runs. Vivado does not automatically follow filesystem moves.

