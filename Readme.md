
# Analysis of Spatial and Environmental Drivers of Ambient Fine Particulate Matter (PM2.5) Concentrations Across the Calgary Metropolitan Area (June 2026)

## Air Pollution Analytics Pipeline

A reproducible R pipeline for analyzing air pollution sensor data, managing environment dependencies, and exporting statistical models.

---

## Project Structure

project-root/
├── data/
│   ├── raw/             # Active directory for "air pollution data.csv"
│   └── processed/       # Storage for cleaned and filtered data exports
├── reports/             # Destination for diagnostic output PDFs
├── License.txt          # Project license
├── main.R               # Primary analysis script
├── Readme.md            # Project documentation
├── setup_project.sh     # Shell script to create directory structure
└── setup_project.bat    # Windows batch script to create directory structure

---

## Getting Started

1. Initialize Folders:
   - macOS/Linux: Run `chmod +x setup_project.sh && ./setup_project.sh`
   - Windows: Double-click `setup_project.bat` or run it via Command Prompt/PowerShell.

2. Run Analysis:
   - Execute `main.R`, which automatically manages all required library dependencies.

---

## 1. Study Purpose and Executive Objective

This repository contains the analytical framework used to investigate the primary environmental, meteorological, and spatial drivers of ambient fine particulate matter (PM2.5) levels within the Calgary metropolitan area during June 2026.

By employing linear mixed-effects models (LMMs), advanced feature engineering, and a standardized regression diagnostic pipeline, this project isolates localized air quality variations. The core objective is to identify the underlying meteorological and temporal dynamics that influence urban pollutant behavior during early summer conditions, providing a reproducible methodology for high-resolution spatial air quality assessment.

---

## 2. Technical Data Dictionary

The analytical pipeline processes a composite dataset consisting of fifteen core tracking metrics and engineered feature vectors:

* DateTime (Character): The raw, unparsed temporal stamp recorded at the moment of atmospheric data collection.

* DateTime_cleaned (Datetime / POSIXct): Standardized temporal observation vector parsed from character strings via ISO-compliant date-time structures.

* Hour (Integer): The localized 24-hour diurnal interval (bounded between 0 and 23) extracted to serve as the random effect grouping factor.

* Weekday (Factor): Chronologically ordered categorical tracking factor spanning from Sunday to Saturday.

* Location (Character): The raw string nomenclature identifying the specific physical air monitoring station asset.

* Location_factor (Factor): Nominal monitoring site metric configured using a sum-to-zero contrast matrix (orthogonal deviation from the grand mean).

* PM25_ug_m3 (Numeric): Ambient concentration of fine particulate matter measured uniformly in micrograms per cubic meter (ug/m3).

* log_PM25 (Numeric): Natural log-transformed PM2.5 mass concentration used as the primary modeled response to stabilize residual variance and skewness.

* ET_C (Numeric): External ambient air temperature recorded in degrees Celsius (deg C).

* RH_pct (Numeric): Relative atmospheric environmental humidity tracked as an absolute percentage (%).

* WS_km_h (Numeric): Observed scalar wind velocity quantified in kilometers per hour (km/h).

* WD_deg (Numeric): Original polar wind direction logged in compass arc degrees spanning from 0 to 360 degrees.

* WD_rad (Numeric): Angular wind direction converted into absolute mathematical radians for geometric transformation.

* WD_EastWest (Numeric): Engineered horizontal wind vector tracking East-West drift, calculated via the sine transformation of the angular wind vector.

* WD_NorthSouth (Numeric): Engineered vertical wind vector tracking North-South drift, calculated via the cosine transformation of the angular wind vector.

---

## 3. Core Operations and Analytical Workflow

The script executes a systematic data science pipeline divided into four distinct phases:

### Phase I: Automated Environment Initialization
System configuration and dependency provisioning are managed entirely by an integrated shell script (`setup_project.sh`). This routine validates the local R runtime environment, deploys a reproducible directory layout, and executes a silent, non-interactive library restoration via `main.R` to guarantee package version alignment across all modeling dependencies.

### Phase II: Feature Engineering and Data Pre-Processing
The pipeline maps polar wind tracking angles into decoupled orthogonal vectors (Sine and Cosine transformations). This step eliminates the geometric boundary multicollinearity that occurs when treating circular 0 and 360 degree metrics as standard linear values. Concurrently, a strict data-cleaning filter restricts the analysis to valid ambient values (0.1 <= PM2.5 <= 25.0 ug/m3), purging instrumentation faults and measurement anomalies.

### Phase III: Iterative Regression Modeling
Statistical modeling progresses through five distinct iterations:

* Model A (Baseline LMM): Evaluates raw environmental and spatial metrics utilizing random intercepts grouped by diurnal interval (`Hour`).

* Model B (Outlier-Purged LMM): Evaluates structural changes in parameter weights using the cleaned data subset.

* Model C (Spatial Wind Vector LMM): Swaps raw polar degrees for the engineered linear directional vectors to resolve predictor instability.

* Models D & E (Optimal Fixed-Effects LMM): Stabilizes residual distribution through the log-transformation of the response variable and applies sum-to-zero contrast coding across localized station nodes.

* Interaction Assessment: Assesses complex meteorological couplings, including interactive thermal-humidity gradients and wind speed-vector intersections.

### Phase IV: Production of Deliverables
The end-to-end execution script automatically compiles three reporting assets:

1. Model Diagnostics (`reports/diagnostics_[Model].pdf`): Multi-panel validation plots mapping residual normality, fitted versus observed spreads, and random effect Q-Q paths.

2. Temporal Baselines (`baseline_pm25_by_weekday.pdf`): A faceted ggplot visualization charting raw spatial-temporal average pollutant behaviors.

3. Predictor Forest Plot (`predictor_effects.pdf`): A publication-ready effect-size chart showing fixed coefficient points and standard error parameters against the urban system mean.


---

## Contact
For commercial licensing inquiries, please reach out to: mazart.analytic@proton.me
