@echo off
if not exist "data\raw" mkdir "data\raw"
if not exist "data\processed" mkdir "data\processed"
if not exist "reports" mkdir "reports"

if exist "air_pollution_data.csv" (
    move "air_pollution_data.csv" "data\raw\"
    echo Data file moved to data\raw\
) else (
    echo Data file not found in root, skipping move.
)
