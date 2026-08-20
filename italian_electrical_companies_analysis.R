# ============================================================
# Italian Electrical Equipment Companies - Statistical Analysis
# ============================================================
#
# Purpose:
#   Clean, reproducible version of the original academic R analysis.
#
# Expected input:
#   facts.xlsx
#   Sheet: "Results"
#
# Main analyses:
#   1. Data quality and descriptive checks
#   2. Multiple linear regression
#   3. Regression diagnostics
#   4. K-means clustering
#   5. Silhouette-based cluster selection
#
# ------------------------------------------------------------


# ------------------------------------------------------------
# 1. Packages
# ------------------------------------------------------------

library(readxl)
library(dplyr)
library(tidyr)
library(ggplot2)
library(factoextra)
library(broom)


# ------------------------------------------------------------
# 2. Reproducibility and output folders
# ------------------------------------------------------------

set.seed(123)

dir.create("plots", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)


# ------------------------------------------------------------
# 3. Import data
# ------------------------------------------------------------

facts <- read_excel(
  "facts.xlsx",
  sheet = "Results"
)

# Inspect the dataset
glimpse(facts)
dim(facts)
summary(facts)


# ------------------------------------------------------------
# 4. Variable check
# ------------------------------------------------------------
#
# Original project notation used in the academic dataset:
#   S  = Sales
#   E  = Employees
#   EX = Financial Expenses
#   A  = Assets
#   B  = Branches
#   TX = Taxation
#   CS = Cash Flow
#   P  = Profit Margin
#
# If the Excel file uses different column names, update this
# dictionary and the model formulas below before running.

required_columns <- c("S", "E", "EX", "A", "B", "TX", "CS", "P")

missing_columns <- setdiff(required_columns, names(facts))

if (length(missing_columns) > 0) {
  stop(
    paste(
      "Missing required columns:",
      paste(missing_columns, collapse = ", ")
    )
  )
}


# ------------------------------------------------------------
# 5. Missing-value analysis
# ------------------------------------------------------------

missing_summary <- data.frame(
  variable = names(facts),
  missing_count = colSums(is.na(facts)),
  missing_percent = round(colMeans(is.na(facts)) * 100, 2)
)

print(missing_summary)

write.csv(
  missing_summary,
  "outputs/missing_values_summary.csv",
  row.names = FALSE
)

missing_plot <- ggplot(
  missing_summary,
  aes(
    x = reorder(variable, missing_count),
    y = missing_count
  )
) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Missing Values by Variable",
    x = NULL,
    y = "Missing observations"
  ) +
  theme_minimal()

ggsave(
  "plots/missing_values.png",
  missing_plot,
  width = 8,
  height = 5,
  dpi = 300
)


# ------------------------------------------------------------
# 6. Multiple linear regression
# ------------------------------------------------------------
#
# Research model:
# Sales ~ Employees + Financial Expenses + Assets +
#         Branches + Taxation + Cash Flow

regression_data <- facts %>%
  select(S, E, EX, A, B, TX, CS) %>%
  drop_na()

sales_model <- lm(
  S ~ E + EX + A + B + TX + CS,
  data = regression_data
)

# Full R regression output
summary(sales_model)

capture.output(
  summary(sales_model),
  file = "outputs/regression_summary.txt"
)

# Clean coefficient table for GitHub / reporting
regression_coefficients <- tidy(
  sales_model,
  conf.int = TRUE
)

print(regression_coefficients)

write.csv(
  regression_coefficients,
  "outputs/regression_coefficients.csv",
  row.names = FALSE
)

# Model-level statistics
regression_model_stats <- glance(sales_model)

print(regression_model_stats)

write.csv(
  regression_model_stats,
  "outputs/regression_model_statistics.csv",
  row.names = FALSE
)


# ------------------------------------------------------------
# 7. Regression diagnostics
# ------------------------------------------------------------

png(
  "plots/regression_diagnostics.png",
  width = 1800,
  height = 1800,
  res = 220
)

par(mfrow = c(2, 2))
plot(sales_model)
par(mfrow = c(1, 1))

dev.off()


# Residuals vs fitted values - presentation-friendly version
diagnostic_data <- data.frame(
  fitted = fitted(sales_model),
  residuals = residuals(sales_model)
)

residual_plot <- ggplot(
  diagnostic_data,
  aes(x = fitted, y = residuals)
) +
  geom_point(alpha = 0.65) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed"
  ) +
  labs(
    title = "Residuals vs Fitted Values",
    x = "Fitted values",
    y = "Residuals"
  ) +
  theme_minimal()

ggsave(
  "plots/residuals_vs_fitted.png",
  residual_plot,
  width = 8,
  height = 5,
  dpi = 300
)


# ------------------------------------------------------------
# 8. K-means clustering data
# ------------------------------------------------------------
#
# Final clustering specification:
# Profit Margin (P) and Branches (B)

cluster_data <- facts %>%
  select(P, B) %>%
  drop_na()

# K-means is distance-based, so variables are standardized
cluster_scaled <- scale(cluster_data)


# ------------------------------------------------------------
# 9. Select the number of clusters
# ------------------------------------------------------------

silhouette_plot <- fviz_nbclust(
  cluster_scaled,
  kmeans,
  method = "silhouette",
  k.max = 16
) +
  labs(
    title = "Silhouette Analysis for K-Means",
    x = "Number of clusters (k)",
    y = "Average silhouette width"
  ) +
  theme_minimal()

ggsave(
  "plots/silhouette_analysis.png",
  silhouette_plot,
  width = 8,
  height = 5,
  dpi = 300
)


# ------------------------------------------------------------
# 10. Final K-means model
# ------------------------------------------------------------

set.seed(123)

kmeans_model <- kmeans(
  cluster_scaled,
  centers = 5,
  nstart = 25
)

print(kmeans_model)

# Number of firms in each cluster
cluster_frequency <- as.data.frame(
  table(kmeans_model$cluster)
)

names(cluster_frequency) <- c(
  "cluster",
  "number_of_firms"
)

print(cluster_frequency)

write.csv(
  cluster_frequency,
  "outputs/cluster_frequency.csv",
  row.names = FALSE
)


# ------------------------------------------------------------
# 11. Cluster profiles
# ------------------------------------------------------------

cluster_results <- cluster_data %>%
  mutate(
    cluster = factor(kmeans_model$cluster)
  )

cluster_profiles <- cluster_results %>%
  group_by(cluster) %>%
  summarise(
    number_of_firms = n(),
    mean_profit_margin = mean(P, na.rm = TRUE),
    median_profit_margin = median(P, na.rm = TRUE),
    mean_branches = mean(B, na.rm = TRUE),
    median_branches = median(B, na.rm = TRUE),
    .groups = "drop"
  )

print(cluster_profiles)

write.csv(
  cluster_profiles,
  "outputs/cluster_profiles.csv",
  row.names = FALSE
)


# ------------------------------------------------------------
# 12. Visualize the final clusters
# ------------------------------------------------------------

cluster_plot <- fviz_cluster(
  kmeans_model,
  data = cluster_scaled,
  geom = "point",
  ellipse.type = "convex",
  ggtheme = theme_minimal()
) +
  labs(
    title = "K-Means Clustering of Italian Electrical Companies",
    subtitle = "Based on standardized Profit Margin and Number of Branches"
  )

ggsave(
  "plots/kmeans_clusters.png",
  cluster_plot,
  width = 8,
  height = 6,
  dpi = 300
)


# ------------------------------------------------------------
# 13. Save dataset with cluster assignments
# ------------------------------------------------------------

cluster_export <- cluster_results

write.csv(
  cluster_export,
  "outputs/company_cluster_assignments.csv",
  row.names = FALSE
)


# ------------------------------------------------------------
# 14. Final console summary
# ------------------------------------------------------------

cat("\n============================================\n")
cat("ANALYSIS COMPLETE\n")
cat("============================================\n")

cat(
  "\nRegression observations:",
  nobs(sales_model),
  "\n"
)

cat(
  "Regression R-squared:",
  round(summary(sales_model)$r.squared, 4),
  "\n"
)

cat(
  "Adjusted R-squared:",
  round(summary(sales_model)$adj.r.squared, 4),
  "\n"
)

cat(
  "Number of observations used in clustering:",
  nrow(cluster_data),
  "\n"
)

cat(
  "Final number of clusters:",
  kmeans_model$centers |> nrow(),
  "\n"
)

cat("\nFiles saved to /plots and /outputs.\n")
