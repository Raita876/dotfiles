set -euo pipefail

mkdir -p fixture/nix fixture/templates/node
printf '{ value = 1; }\n' > fixture/flake.nix
printf '{ value = 1; }\n' > fixture/nix/module.nix
printf '{ value = 1; }\n' > fixture/templates/node/flake.nix
"$NIX_LINT" fixture

for file in flake.nix nix/module.nix templates/node/flake.nix; do
  for defect in 'let unused = 1; in { value = 1; }' '{ a.x = 1; a.y = 2; a.z = 3; }'; do
    printf '%s\n' "$defect" > "fixture/$file"
    cp -R fixture before
    if "$NIX_LINT" fixture > diagnostics.log 2>&1; then
      echo "Lint unexpectedly accepted $file: $defect" >&2
      exit 1
    fi
    cat diagnostics.log
    diff -r before fixture
    rm -r before
    printf '{ value = 1; }\n' > "fixture/$file"
  done
done

"$NIX_LINT" fixture
