OUTPUT_DIR = output
VPATH = src:include:testbench:target:tests:$(OUTPUT_DIR)

CRT = target/crt.s
LINKERS = target/linker.lds
ASLINKERS = target/aslinker.lds

GCC = riscv32-unknown-elf-gcc
OBJDUMP = riscv32-unknown-elf-objdump
AS = riscv32-unknown-elf-as
ELF2HEX = riscv32-unknown-elf-elf2hex

CFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align -mno-div
OFLAGS ?= -O0
ASFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS = -SD -M no-aliases 
OBJDFLAGS = -SD -M numeric,no-aliases

ASM_TESTS = $(wildcard tests/*.s)
C_TESTS = $(wildcard tests/*.c)

$(OUTPUT_DIR):
	@mkdir -p $@

$(ASM_TESTS:tests/%.s=$(OUTPUT_DIR)/%.elf): $(OUTPUT_DIR)/%.elf: %.s | $(AS_LINKERS) $(OUTPUT_DIR)
	$(GCC) $(ASFLAGS) $^ -T $(ASLINKERS) $(CUSTOM_ASM_ARGS) -o $@

$(C_TESTS:tests/%.c=$(OUTPUT_DIR)/%.elf): $(OUTPUT_DIR)/%.elf: $(CRT) %.c | $(LINKERS) $(OUTPUT_DIR)
	$(GCC) $(CFLAGS) $(OFLAGS) $^ -T $(LINKERS) $(CUSTOM_C_ARGS) -o $@

$(C_TESTS:tests/%.c=$(OUTPUT_DIR)/%.debug.elf): $(OUTPUT_DIR)/%.debug.elf: $(CRT) %.c | $(LINKERS) $(OUTPUT_DIR)
	$(GCC) -g $(CFLAGS) $(OFLAGS) $^ -T $(LINKERS) $(CUSTOM_C_ARGS) -o $@

$(OUTPUT_DIR)/%.lst: $(OUTPUT_DIR)/%.elf
	$(OBJDUMP) $(OBJDFLAGS) $< > $@

$(OUTPUT_DIR)/%.hex: $(OUTPUT_DIR)/%.elf
	$(ELF2HEX) --bit-width 64 --input $< > $@

CLOCK_CYCLE ?= 10
export CLOCK_CYCLE

REF_MODE ?= 0

VERILATOR = verilator --binary --timing --trace -Wno-fatal --timescale 1ns/100ps -Mdir $(OUTPUT_DIR) -Iinclude
XVLOG = xvlog --nolog --sv --incr --define CLOCK_CYCLE=$(CLOCK_CYCLE)
XELAB = xelab --nolog --incr --define CLOCK_CYCLE=$(CLOCK_CYCLE)
XELAB_SYNTH = $(XELAB) -maxdelay -transport_int_delays -pulse_r 0 -pulse_int_r 0 -L secureip -L simprims_ver
XSIM = xsim --nolog --tempDir $(OUTPUT_DIR)

HEADERS = $(wildcard include/*.svh)
SOURCES = $(wildcard src/*.sv)
TESTBENCH = mem.sv testbench.sv pipe_print.c

$(OUTPUT_DIR)/simulate: $(HEADERS) $(SOURCES) $(TESTBENCH) | $(OUTPUT_DIR)
	$(VERILATOR) --top testbench $^ -o simulate

$(OUTPUT_DIR)/%.out: $(OUTPUT_DIR)/%.hex $(OUTPUT_DIR)/simulate
	@touch $@
	$(OUTPUT_DIR)/simulate +MEMORY=$< +WRITEBACK=$(OUTPUT_DIR)/$*.wb +PIPELINE=$(OUTPUT_DIR)/$*.ppln | tee $@

$(OUTPUT_DIR)/%.ppln: $(OUTPUT_DIR)/%.out
	@:

$(OUTPUT_DIR)/%.wb: $(OUTPUT_DIR)/%.out
	@:

REF_DIR = tests/ref
ALL_CASES = $(ASM_TESTS:tests/%.s=%) $(C_TESTS:tests/%.c=%)

$(REF_DIR):
	@mkdir -p $@

$(OUTPUT_DIR)/%.mem: $(OUTPUT_DIR)/%.out | $(OUTPUT_DIR)
	grep -E '^@@@' $< > $@

$(REF_DIR)/%.mem: $(OUTPUT_DIR)/%.mem | $(OUTPUT_DIR) $(REF_DIR)
ifeq ($(REF_MODE),1)
	cp $< $@
endif

$(REF_DIR)/%.wb: $(OUTPUT_DIR)/%.wb | $(OUTPUT_DIR) $(REF_DIR)
ifeq ($(REF_MODE),1)
	cp $< $@
endif

$(ALL_CASES:%=%.ref): %.ref: $(REF_DIR)/%.mem $(REF_DIR)/%.wb | $(REF_DIR)
	@:

ref: $(ALL_CASES:%=%.ref)
	@:

#####################
# ---- Printing ----
#####################

# this is a function with two arguments: PRINT_COLOR(color : int 0-7, msg : string)
PRINT_COLOR = if [ -t 0 ]; then tput setaf $(1) ; fi; echo $(2); if [ -t 0 ]; then tput sgr0; fi
# this decomposes to:
# first, check if in a terminal and in a compliant shell
# second, use tput setaf to set the ANSI Foreground color based on the number 0-7:
#   0:black, 1:red, 2:green, 3:yellow, 4:blue, 5:magenta, 6:cyan, 7:white
# third, echo the message
# finally, reset the terminal color (but still only if a terminal)
# make functions are called like this:
# $(call PRINT_COLOR,5,msg)
# add '@' at the start of the line so it doesn't print the command itself, only the outpu

$(ALL_CASES:%=%.test): %.test: $(OUTPUT_DIR)/%.mem $(OUTPUT_DIR)/%.wb $(REF_DIR)/%.mem $(REF_DIR)/%.wb | $(REF_DIR)
	@diff $(OUTPUT_DIR)/$*.mem $(REF_DIR)/$*.mem > /dev/null && diff $(OUTPUT_DIR)/$*.wb $(REF_DIR)/$*.wb > /dev/null
	@if [ $$? -eq 0 ]; then $(call PRINT_COLOR,2,@@@PASSED $*); else $(call PRINT_COLOR,1,@@@FAILED $*); fi

test: $(ALL_CASES:%=%.test)
	@:


clean:
	rm -f *.log *.pb *.wdb
	rm -rf xsim.dir $(OUTPUT_DIR)

.PHONY: ref clean $(ALL_CASES:%=%.ref)
