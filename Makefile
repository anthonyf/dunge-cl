.PHONY: test test-web test-all run build clean fmt check-fmt setup

test:
	qlot exec sbcl --eval '(asdf:test-system :dunge)' --quit

run:
	qlot exec sbcl --non-interactive \
		--eval '(asdf:load-system :dunge)' \
		--eval '(dunge:game-repl (dunge:room (quote dunge::start)))'

test-all: test test-web

test-web:
	qlot exec sbcl --non-interactive --eval '(push :web-test *features*)' --load web-export.lisp
	npx playwright test

build:
	qlot exec sbcl --non-interactive --load web-export.lisp

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

fmt:
	@for f in src/*.lisp; do \
		echo "Formatting $$f"; \
		emacs --batch "$$f" --load "$(ROOT_DIR)/scripts/cl-indent.el" 2>/dev/null; \
	done

check-fmt: fmt
	@if git diff --quiet src/; then \
		echo "Formatting check passed."; \
	else \
		echo "Formatting check failed. Run 'make fmt' to fix."; \
		git checkout src/; \
		exit 1; \
	fi

setup:
	ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
	@echo "Pre-commit hook installed."

clean:
	rm -rf ~/.cache/common-lisp/
	find . -name '*.fasl' -delete
	rm -rf dist/
	rm -rf test-results/
