#!/usr/bin/env bash
# Compile-check every Lua file in the mod, to catch truncation / syntax errors
# before they reach the game. Project Zomboid silently disables a file that
# fails to load, so a chopped or malformed file can quietly break a system.
#
# Usage:  ./tools/check_lua.sh
# Exit:   0 = all good, 1 = at least one file failed, 2 = no checker available.
#
# Prefers luac5.1 / luac (Lua 5.1 ~ PZ's Kahlua). Falls back to python3 + lupa.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOD_DIR="$ROOT/KierpocalypticHomestead"

checker=""
if command -v luac5.1 >/dev/null 2>&1; then checker="luac5.1 -p"
elif command -v luac    >/dev/null 2>&1; then checker="luac -p"
fi

if [ -n "$checker" ]; then
  fail=0; count=0
  while IFS= read -r -d '' f; do
    count=$((count + 1))
    if ! $checker "$f" 2> /tmp/khluaerr; then
      echo "FAIL: ${f#"$ROOT"/}"
      sed 's/^/    /' /tmp/khluaerr
      fail=1
    fi
  done < <(find "$MOD_DIR" -name '*.lua' -print0)
  echo "Checked $count Lua files with '$checker'."
  if [ "$fail" -ne 0 ]; then echo "Lua check FAILED."; exit 1; fi
  echo "All Lua files compile cleanly."
  exit 0
fi

echo "No luac found; trying python3 + lupa..."
python3 - "$MOD_DIR" <<'PY'
import sys, glob
try:
    from lupa import LuaRuntime
except Exception:
    print("ERROR: no luac and no python 'lupa' module; cannot syntax-check.")
    print("Install one of:  apt-get install lua5.1   |   pip install lupa")
    sys.exit(2)
lua = LuaRuntime(); bad = 0; n = 0
for f in glob.glob(sys.argv[1] + "/**/*.lua", recursive=True):
    n += 1
    try:
        lua.compile(open(f, encoding="utf-8", errors="replace").read())
    except Exception as e:
        bad += 1
        print("FAIL:", f, "->", str(e).splitlines()[0])
print(f"Checked {n} Lua files with lupa; {bad} failed.")
sys.exit(1 if bad else 0)
PY
