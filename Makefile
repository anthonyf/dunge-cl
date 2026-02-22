.PHONY: test run build clean

test: build
	qlot exec sbcl --eval '(asdf:test-system :dunge)' --quit

run: build
	qlot exec sbcl --non-interactive \
                       --eval '(asdf:load-system :dunge)' \
	               --eval '(dunge:game-repl (dunge:room (quote dunge::start)))'

build:
	qlot exec sbcl --non-interactive --load web-export.lisp

clean:
	rm -rf ~/.cache/common-lisp/
	find . -name '*.fasl' -delete
	rm -rf dist/
	rm -rf test-results/
