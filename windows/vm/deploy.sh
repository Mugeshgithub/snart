#!/bin/bash
# Based on Cicada (https://github.com/wquguru/cicada), Apache License 2.0.
# Modified by CognivexAI, 2026.
# Quits Snart in the test VM and copies in fresh builds (run scripts/build.sh first).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
"$here/vmctl.sh" ssh 'Get-Process Snart -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 1; Remove-Item C:\cicada-test\Snart-win-arm64, C:\cicada-test\Snart-win-x64 -Recurse -Force -ErrorAction SilentlyContinue; exit 0'
for rid in win-arm64 win-x64; do "$here/vmctl.sh" put "$here/../build/Snart-$rid" C:/cicada-test/; done
"$here/vmctl.sh" put "$here/guest.ps1" C:/cicada-test/
echo deployed
