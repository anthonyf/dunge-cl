.PHONY: run test build serve web-dev-assets clean ece ece-clean

ECE_DIR   := $(CURDIR)/vendor/ece
ECE       := $(ECE_DIR)/bin/ece
ECE_BUILD := $(ECE_DIR)/bin/ece-build
ECE_SERVE := $(ECE_DIR)/bin/ece-serve
ECE_UNIT  := $(ECE_DIR)/src/ece-unit.scm
PORT      ?= 8080

ece: $(ECE)

run: $(ECE)
	$(ECE) game/main.scm

test: $(ECE)
	ECE_UNIT_PATH=$(ECE_UNIT) $(ECE) tests/run-all.scm

build: $(ECE) $(ECE_BUILD)
	ECE_BIN=$(ECE_BUILD) scripts/build-web.sh

serve: $(ECE) $(ECE_SERVE) web-dev-assets
	cd web && $(ECE_SERVE) main.scm --port $(PORT)

web-dev-assets: web/ece-runtime.js web/runtime.wasm web/bootstrap.ecec web/ece-bootstrap.js web/app.js

web/ece-runtime.js: $(ECE)
	cp $(ECE_DIR)/share/ece/glue.js $@

web/runtime.wasm: $(ECE)
	cp $(ECE_DIR)/share/ece/runtime.wasm $@

web/bootstrap.ecec: $(ECE)
	cp $(ECE_DIR)/share/ece/bootstrap.ecec $@

web/ece-bootstrap.js:
	printf '%s\n' '// dev placeholder: ece-serve loads bootstrap.ecec directly' > $@

web/app.js:
	printf '%s\n' '// dev placeholder: ece-serve loads /__ece_dev/artifacts/app.ecec' > $@

$(ECE) $(ECE_BUILD) $(ECE_SERVE):
	@test -f $(ECE_DIR)/Makefile || { \
	  echo >&2 "ERROR: vendor/ece submodule is not initialized."; \
	  echo >&2 "Run: git submodule update --init"; \
	  exit 1; }
	$(MAKE) -C $(ECE_DIR)

ece-clean:
	@test -f $(ECE_DIR)/Makefile || { \
	  echo >&2 "ERROR: vendor/ece submodule is not initialized."; \
	  echo >&2 "Run: git submodule update --init"; \
	  exit 1; }
	$(MAKE) -C $(ECE_DIR) clean

clean:
	rm -rf dist/
