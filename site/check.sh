#!/bin/sh
# Build the GitHub Pages site into OUT-DIR (default: public) and check it.
# Run from the repository root.
#
# The site is built twice: once normally, and once after recompiling Dunge
# with Parenscript's gensym counter moved away from zero. The two builds must
# be identical; any difference means the output depends on compiler state
# rather than on the sources. Each game page is then booted under Node with
# the parity harness to make sure it starts without errors.
set -eu

out="${1:-public}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

rm -rf "$out"
sbcl --non-interactive \
  --eval '(asdf:load-system "dunge/pages")' \
  --eval "(dunge-pages:build-site \"$out/\")"

sbcl --non-interactive \
  --eval '(asdf:load-system "parenscript")' \
  --eval '(setf ps:*ps-gensym-counter* 4242)' \
  --eval '(asdf:load-system "dunge" :force t)' \
  --eval '(asdf:load-system "dunge/pages")' \
  --eval "(dunge-pages:build-site \"$scratch/perturbed/\")"

if ! diff -r "$out" "$scratch/perturbed" > "$scratch/site.diff"; then
  echo "Site build is not reproducible:" >&2
  head -c 2000 "$scratch/site.diff" >&2
  exit 1
fi
echo "Site build is reproducible."

find "$out" -mindepth 2 -name index.html | sort | while read -r page; do
  frames="$(node tests/parity/harness.js "$page")"
  case "$frames" in
    *"(:error"*|*"(:missing-choice"*)
      echo "Page failed to boot: $page" >&2
      echo "$frames" >&2
      exit 1
      ;;
    *"(:title"*)
      echo "Page boots: $page"
      ;;
    *)
      echo "Page rendered no scene: $page" >&2
      echo "$frames" >&2
      exit 1
      ;;
  esac
done
