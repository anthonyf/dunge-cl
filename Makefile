.PHONY: test run build clean

run:
	ece game/main.scm

test:
	ece tests/run-all.scm

build:
	scripts/build-web.sh

clean:
	rm -rf dist/
