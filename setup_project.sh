#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Initializing Air Pollution Analytics Environment ==="

# 1. Create directory structure (mkdir -p is naturally idempotent)
mkdir -p data/raw data/processed reports
echo "✔ Project directories checked/provisioned."

# 2. Conditionally move data (Idempotent check)
if [ -f "air_pollution_data.csv" ]; then
    mv air_pollution_data.csv data/raw/
    echo "✔ Data moved to data/raw/."
else
    echo "ℹ Data file not found in root (already moved or missing), skipping."
fi

# 3. Check if R is installed
if ! command -v Rscript &> /dev/null; then
    echo "❌ Error: Rscript is not installed. Please install R before running."
    exit 1
fi

echo "✔ Environment fully synchronized and reproducible."
