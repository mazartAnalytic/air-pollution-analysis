#Packages installation and verification
required_packages <- c("readr", "lme4", "lmerTest", "tidyverse", "car", "partR2", "effectsize", "ggplot2", "performance", "here")
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if (length(missing_packages) > 0) {
  install.packages(missing_packages)
}
invisible(lapply(required_packages, library, character.only = TRUE))

# ==========================================
#  Import Dataset & Define Diagnostic Core
# ==========================================
# 1. Environment Initialization
# Ensures directory structure exists regardless of how the script is started
required_dirs <- c(here("data", "raw"), here("data", "processed"), here("reports"))
for (dir in required_dirs) {
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
}

# 2. Data Provisioning
# Moves data if user skipped the setup scripts
target_file <- here("data", "raw", "air_pollution_data.csv")
source_file <- "air_pollution_data.csv"

if (!file.exists(target_file) && file.exists(source_file)) {
  file.rename(source_file, target_file)
  message("Automatic setup: Data file moved to data/raw/")
}

# 3. Final Validation
if (!file.exists(target_file)) {
  stop("Deployment Error: Missing 'air_pollution_data.csv' in project root or data/raw/")
}

air_pollution_data <- read_csv(target_file)
print("Data successfully loaded via reproducible pipeline.")

# Inspect Dataset Structure
names(air_pollution_data)

check_assumptions <- function(model_input) {
  # Automatically extracts the name of the object passed into the function
  model_name <- deparse(substitute(model_input))
  file_name <- paste0("diagnostics_", model_name, ".pdf")
  
  pdf(here("reports", file_name), width = 8, height = 6)
  print(plot(model_input, type = c("p", "smooth"), col.line = "red"))
  qqnorm(residuals(model_input), main = "Normal Q-Q Plot of Residuals")
  qqline(residuals(model_input), col = "red")
  
  cat("\n--- Variance Inflation Factors (VIF) ---\n")
  print(vif(model_input))
  cat("----------------------------------------\n\n")
  # Extracts the random intercept/slope estimates (BLUPs) specifically for the 'Hour' grouping level
  rand_effs <- ranef(model_input)$Hour[[1]]
  plot_range <- c(-2.5, 2.5)
  qqnorm(rand_effs, 
         main = "Normal Q-Q Plot of Hour Random Effects",
         xlim = plot_range, 
         ylim = plot_range)
  qqline(rand_effs, col = "red")
  dev.off()
  
  message(paste("Success! Replaced or updated 'reports/", file_name, "'."))
}

# ==========================================
# 2. Feature Engineering & Initial Model
# ==========================================
air_pollution_data <- air_pollution_data %>%
  mutate(
    DateTime_cleaned = ymd_hm(DateTime),
    Hour = hour(DateTime_cleaned),
    Weekday = factor(
      as.character(wday(DateTime_cleaned, label = TRUE, abbr = FALSE)),
      levels = c("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"),
      ordered = FALSE
    ),    
    Location_factor = as.factor(Location)
  )

# Missing Value Analysis
air_pollution_data %>%
  summarise(across(everything(), ~ sum(is.na(.)))) %>%
  pivot_longer(cols = everything(), names_to = "Variable", values_to = "Missing_Count")

# Fit Initial Linear Mixed-Effects Model 
# --- Model A: Fit Model on Original Data ---
pollution_model <- lmer(
  PM25_ug_m3 ~ Location_factor + Weekday + ET_C + RH_pct + WS_km_h + WD_deg + (1 | Hour), 
  data = air_pollution_data,
  REML = TRUE
)
summary(pollution_model)
check_assumptions(pollution_model)

# ==========================================
# 3. Outlier Elimination & Baseline Plots
# ==========================================
cleaned_data <- air_pollution_data %>% filter(PM25_ug_m3 >= 0.1, PM25_ug_m3 <= 25)
print(min(cleaned_data$PM25_ug_m3, na.rm = TRUE))

contingency_table <- table(cleaned_data$Location_factor, cleaned_data$Weekday)
print(contingency_table)
chisq.test(contingency_table)

# Pre-calculate clean baseline averages
df_avg_clean <- cleaned_data %>%
  group_by(Location_factor, Weekday) %>%
  summarize(Avg_PM25 = mean(PM25_ug_m3, na.rm = TRUE), .groups = "drop")

# Generate baseline plot PDF output
#pdf("baseline_pm25_by_weekday.pdf", width = 8, height = 5)
pdf(here("reports", "baseline_pm25_by_weekday.pdf"), width = 8, height = 6)
print(
ggplot(df_avg_clean, aes(x = Weekday, y = Avg_PM25, fill = Weekday)) +
  geom_col(color = "black", show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f", Avg_PM25)), vjust = -0.5, size = 3) +
  facet_wrap(~ Location_factor) +
  scale_y_continuous(breaks = seq(0, 8, by = 2), limits = c(0, 8)) +
  theme_bw() +
  theme(
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.ticks.length.y = unit(0.15, "cm"),
    axis.text.x = element_text(angle = 45, hjust = 1)
  ) +
  labs(x = "Weekday", y = "Average PM2.5 (µg/m³)")
)
dev.off()

# ==========================================
# 4. Sequential Model Operations
# ==========================================

# --- Model B: Fit Model on Outlier-Removed Data ---
cleaned_model <- lmer(
  PM25_ug_m3 ~ Location_factor + Weekday + ET_C + RH_pct + WS_km_h + WD_deg + (1 | Hour), 
  data = cleaned_data,
  REML = TRUE
)
summary(cleaned_model)
check_assumptions(cleaned_model)

# --- Model C: Decompose Wind Direction into Vector Components ---
cleaned_data$WD_rad <- cleaned_data$WD_deg * (pi / 180)
# Positive = East, Negative = West
cleaned_data$WD_EastWest <- sin(cleaned_data$WD_rad)
# Positive = North, Negative = South
cleaned_data$WD_NorthSouth <- cos(cleaned_data$WD_rad) 
# Fit Model with Wind Vector Components
cleaned_model_wind <- lmer(
  PM25_ug_m3 ~ Location_factor + Weekday + ET_C + RH_pct + WS_km_h + WD_EastWest + WD_NorthSouth + (1 | Hour),
  data = cleaned_data,
  REML = TRUE
)
summary(cleaned_model_wind)
check_assumptions(cleaned_model_wind)

# Multi-collinearity Check for Continuous Variables
continuous_vars <- cleaned_data[, c("ET_C", "RH_pct", "WS_km_h", "WD_EastWest", "WD_NorthSouth")]
cor_matrix <- cor(continuous_vars, use = "complete.obs")
round(cor_matrix, 2)

# --- Model D: Log-Transform Response Variable for Skewness ---
cleaned_data$log_PM25 <- log(cleaned_data$PM25_ug_m3)

cleaned_model_log <- lmer(
  log_PM25 ~ Location_factor + Weekday + ET_C + RH_pct + WS_km_h + WD_EastWest + WD_NorthSouth + (1 | Hour), 
  data = cleaned_data, 
  REML = TRUE
)
summary(cleaned_model_log)
check_assumptions(cleaned_model_log)

# --- Model E: Fit Final Optimal Mixed-Effects Model ---
# Inspect Factor Levels for Contrast Coding
length(levels(cleaned_data$Location_factor))
# Apply Sum-to-Zero Contrast Coding
contrasts(cleaned_data$Location_factor) <- contr.sum(4)
write.csv(cleaned_data, here("data", "processed", "cleaned_data.csv"), row.names = FALSE)
final_city_avg_model <- lmer(
  log_PM25 ~ Location_factor + Weekday + ET_C + RH_pct + WS_km_h + WD_EastWest + WD_NorthSouth + (1 | Hour),
  data = cleaned_data,
  REML = TRUE
)
# Model Evaluation and Summary Metrics
summary(final_city_avg_model)
performance::r2(final_city_avg_model)

# ==========================================
# 5. Exploratory Model Extensions
# ==========================================

# Univariate Iteration Loop
# Define the vector of individual predictors
predictors <- c("Location_factor", "Weekday", "ET_C", "RH_pct", "WS_km_h", "WD_EastWest", "WD_NorthSouth")

for (pred in predictors) {
  cat("\n=========================================================\n")
  cat("UNIVARIATE MODEL FOR PREDICTOR:", pred, "\n")
  cat("=========================================================\n")
  form <- as.formula(paste("log_PM25 ~", pred, "+ (1 | Hour)"))
  mod <- lmer(form, data = cleaned_data, REML = TRUE)
  print(coef(summary(mod)))
  cat("\n--- Residual Variance ---\n")
  print(sigma(mod)^2) # <--- Extracts just the residual variance numeric value
  cat("\n--- Variance Explained (R2) ---\n")
  print(performance::r2(mod))
  cat("\n")
}
# Backward elimination look for the full model
drop1(final_city_avg_model, test = "Chisq")
# Key Environmental Interaction Modeling
interaction_model <- lmer(
  log_PM25 ~ Location_factor + Weekday + 
    ET_C * RH_pct + 
    WS_km_h * WD_EastWest + WS_km_h * WD_NorthSouth + 
    (1 | Hour),
  data = cleaned_data,
  REML = TRUE
)
summary(interaction_model)
performance::r2(interaction_model)

# Standardized Parameter Estimations
standardized_effects <- effectsize::standardize_parameters(interaction_model, method = "refit")
print(standardized_effects)

# ==========================================
# 6. Coefficients Extraction & Final Forest Plot
# ==========================================
raw_coefs <- suppressMessages(summary(final_city_avg_model))$coefficients

coef_df <- data.frame(
  Predictor = rownames(raw_coefs),
  Estimate = raw_coefs[, "Estimate"],
  Std_Error = raw_coefs[, "Std. Error"],
  stringsAsFactors = FALSE
)
coef_df <- coef_df[coef_df$Predictor != "(Intercept)", ]

rename_lookup <- c(
  "Location_factor1" = "Calgary Central",
  "Location_factor2" = "Calgary Northwest",
  "Location_factor3" = "Calgary Southeast",
  "WeekdayMonday"    = "Weekday Monday",
  "WeekdayTuesday"   = "Weekday Tuesday",
  "WeekdayWednesday" = "Weekday Wednesday",
  "WeekdayThursday"  = "Weekday Thursday",
  "WeekdayFriday"    = "Weekday Friday",
  "WeekdaySaturday"  = "Weekday Saturday",
  "ET_C"             = "External Temperature (°C)",
  "RH_pct"           = "Relative Humidity (%)",
  "WS_km_h"          = "Wind Speed (km/h)",
  "WD_EastWest"      = "Wind Direction (East-West)",
  "WD_NorthSouth"    = "Wind Direction (North-South)"
)
coef_df$Predictor <- rename_lookup[coef_df$Predictor]

plot_order <- c(
  "Calgary Central",
  "Calgary Northwest",
  "Calgary Southeast",
  "Weekday Monday",
  "Weekday Tuesday",
  "Weekday Wednesday",
  "Weekday Thursday",
  "Weekday Friday",
  "Weekday Saturday",
  "External Temperature (°C)",
  "Relative Humidity (%)",
  "Wind Speed (km/h)",
  "Wind Direction (East-West)",
  "Wind Direction (North-South)"
)
coef_df$Predictor <- factor(coef_df$Predictor, levels = rev(plot_order))
pdf(here("reports", "predictor_effects.pdf"), width = 8, height = 5)
#pdf("predictor_effects.pdf", width = 8, height = 5)
print(
ggplot(coef_df, aes(x = Estimate, y = Predictor)) +
  geom_point(size = 2.5) +
  geom_errorbar(aes(xmin = Estimate - 1.96 * Std_Error, xmax = Estimate + 1.96 * Std_Error), width = 0.15) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  scale_x_continuous(
    limits = c(-0.4, 0.4), 
    breaks = seq(-0.4, 0.4, by = 0.1)
  ) +
  labs(
    title = "Fixed Effects Estimates on log-PM2.5 Concentrations",
    x = "Effect Size (Deviation from Grand Mean in log-PM2.5 Units)", 
    y = "Predictor"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 12),
    axis.text.y = element_text(face = "bold", color = "black"),
    axis.text.x = element_text(color = "black"),
    axis.line.x.bottom = element_line(color = "black", linewidth = 0.5),
    axis.line.x.top = element_line(color = "black", linewidth = 0.5),
    panel.grid.minor = element_blank()
  )
)
dev.off()
