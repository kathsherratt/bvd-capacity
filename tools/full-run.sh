#!/bin/sh
set -u
cd "$(dirname "$0")/.."
export GEMINI_LEDGER="$HOME/Documents/Github/bvd-sitreps/outputs/gemini-ledger.csv"
export GEMINI_BACKEND=agy
date "+%F %H:%M:%S start, 116 reports on agy:gemini-3.1-pro-low"
Rscript R/01_facilities.R
echo "exit $? at $(date +%H:%M:%S)"
