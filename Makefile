SRC_DIR := days
LIB_DIR := lib
OUT_DIR := build
SOLUTION_NAME := solution

AS := as

LIB_SRCS := $(wildcard $(LIB_DIR)/*.s)
LIB_OBJS := $(patsubst $(LIB_DIR)/%.s,$(OUT_DIR)/%.o,$(LIB_SRCS))

.PHONY: clean run-% %
.PRECIOUS: $(OUT_DIR)/% $(OUT_DIR)/%.o $(LIB_OBJS)

# assemble lib files
$(OUT_DIR)/%.o: $(LIB_DIR)/%.s
	@echo "Assembling library file $<"
	@mkdir -p $(OUT_DIR)
	@$(AS) -g $< -o $@

# assemble actual challenge files
$(OUT_DIR)/%.o: $(SRC_DIR)/%/$(SOLUTION_NAME).s
	@echo "Assembling $<"
	@mkdir -p $(OUT_DIR)
	@$(AS) -g $< -o $@

# link all object files to build binary
$(OUT_DIR)/%: $(OUT_DIR)/%.o $(LIB_OBJS)
	@echo "Linking $<"
	@ld \
		$^ \
		-o $@ \
		-e _start \
		-lSystem \
		-syslibroot $(shell xcrun --show-sdk-path)
	@echo "Built binary '$@' successfully"

%: $(OUT_DIR)/%
	@: # this no-op needs to be here for the target to work for some reason

run-%: $(OUT_DIR)/%
	@echo "Running $<"
	@echo "===================="
	@./$<

clean:
	rm -rf $(OUT_DIR)
