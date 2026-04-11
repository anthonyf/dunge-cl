.PHONY: run test build clean ece ece-clean

ECE_DIR   := $(CURDIR)/vendor/ece
ECE       := $(ECE_DIR)/bin/ece
ECE_BUILD := $(ECE_DIR)/bin/ece-build
ECE_UNIT  := $(ECE_DIR)/src/ece-unit.scm

ece: $(ECE)

run: $(ECE)
	$(ECE) game/main.scm

test: $(ECE)
	ECE_UNIT_PATH=$(ECE_UNIT) $(ECE) tests/run-all.scm

build: $(ECE) $(ECE_BUILD)
	ECE_BIN=$(ECE_BUILD) scripts/build-web.sh

$(ECE) $(ECE_BUILD):
	@test -f $(ECE_DIR)/Makefile || { \
	  echo >&2 "ERROR: vendor/ece submodule is not initialized."; \
	  echo >&2 "Run: git submodule update --init"; \
	  exit 1; }
	cd $(ECE_DIR) && qlot install
	$(MAKE) -C $(ECE_DIR)

ece-clean:
	@test -f $(ECE_DIR)/Makefile || { \
	  echo >&2 "ERROR: vendor/ece submodule is not initialized."; \
	  echo >&2 "Run: git submodule update --init"; \
	  exit 1; }
	$(MAKE) -C $(ECE_DIR) clean

clean:
	rm -rf dist/
