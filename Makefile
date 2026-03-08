.PHONY: test run build clean fmt check-fmt setup

test:
	sbcl --non-interactive --load run-tests.lisp

run:
	qlot exec sbcl --non-interactive \
		--eval '(asdf:load-system :dunge)' \
		--eval '(dunge/ece-bootstrap:start)'

build:
	sbcl --non-interactive --load web-export.lisp

ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
LISP_FILES := $(wildcard src/*.lisp) web-export.lisp run-tests.lisp dunge.asd

fmt:
	@for f in $(LISP_FILES); do \
		echo "Formatting $$f"; \
		emacs --batch "$$f" --load "$(ROOT_DIR)/scripts/cl-indent.el" 2>/dev/null; \
	done

check-fmt: fmt
	@if git diff --quiet -- $(LISP_FILES); then \
		echo "Formatting check passed."; \
	else \
		echo "Formatting check failed. Run 'make fmt' to fix."; \
		git checkout -- $(LISP_FILES); \
		exit 1; \
	fi

setup:
	ln -sf ../../scripts/pre-commit .git/hooks/pre-commit
	@echo "Pre-commit hook installed."

clean:
	rm -rf ~/.cache/common-lisp/
	find . -name '*.fasl' -delete
	rm -rf dist/
