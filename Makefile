.PHONY: test test-web test-all run build clean

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

clean:
	rm -rf ~/.cache/common-lisp/
	find . -name '*.fasl' -delete
	rm -rf dist/
	rm -rf test-results/
