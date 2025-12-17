SRC_DIR := days
LIB_DIR := lib
OUT_DIR := build

AS := as

LIB_SRCS := $(wildcard $(LIB_DIR)/*.s)
LIB_OBJS := $(patsubst $(LIB_DIR)/%.s,$(OUT_DIR)/%.o,$(LIB_SRCS))

CHAL_BIN := $(OUT_DIR)/day$(day)-part$(part)
CHAL_OBJ := $(CHAL_BIN).o

.PHONY: clean build run
.PRECIOUS: $(OUT_DIR)/% $(OUT_DIR)/%.o $(LIB_OBJS)

build: $(CHAL_BIN)

# assemble lib files
$(OUT_DIR)/%.o: $(LIB_DIR)/%.s
	@echo "Assembling library file $<"
	@mkdir -p $(OUT_DIR)
	@$(AS) -g $< -o $@

# assemble actual challenge file
$(CHAL_OBJ): $(SRC_DIR)/day$(day)/part$(part).s
	@echo "Assembling $<"
	@mkdir -p $(OUT_DIR)
	@$(AS) -g $< -o $@

# link all object files to build binary
$(CHAL_BIN): $(CHAL_OBJ) $(LIB_OBJS)
	@echo "Linking $<"
	@ld \
		$^ \
		-o $@ \
		-e _start \
		-lSystem \
		-syslibroot $(shell xcrun --show-sdk-path)
	@echo "Built binary '$@' successfully"

run: $(CHAL_BIN) days/day$(day)/$(input)
	@echo "Running $<"
	@echo "===================="
	@./$< $(word 2,$^)

clean:
	rm -rf $(OUT_DIR)
