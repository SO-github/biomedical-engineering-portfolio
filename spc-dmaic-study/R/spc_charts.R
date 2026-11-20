# ============================================================
# Statistical Process Control Study (DMAIC)
# p-Chart, np-Chart, Pareto, EWMA and Binomial model
# Author: Sohan Sai Jampala | Purdue University, IE530 Statistical Quality Control | April 2026
#
# Data: data/IE530_Project_data.csv
#   Columns: Week, Day, <7 hour sleep, Missed Target, >1 hour social media,
#            Skipped workout, Priority task incomplete, Daily defect (1/0)
#   56 rows: 8 weeks x 7 days
#
# Run from the project folder:  Rscript R/spc_charts.R
# Charts are written to figures/ as SVG files.
# ============================================================

# -- 0. Load data --------------------------------------------
df <- read.csv("data/IE530_Project_data.csv", header = TRUE, check.names = FALSE)
colnames(df) <- c("week", "day", "sleep", "missed", "social", "workout", "priority", "defect")
cols <- c("week", "sleep", "missed", "social", "workout", "priority", "defect")
df[, cols] <- lapply(df[, cols], as.integer)

n_total <- nrow(df)   # 56 days
k       <- 8          # subgroups (weeks)
n_sub   <- 7          # days per week
dir.create("figures", showWarnings = FALSE)
# svglite gives small, text-based SVGs; base svg() is the fallback
open_svg <- if (requireNamespace("svglite", quietly = TRUE)) svglite::svglite else grDevices::svg
cat(sprintf("Loaded %d rows | %d weeks x %d days\n", n_total, k, n_sub))

# -- 1. Weekly aggregates ------------------------------------
weekly <- aggregate(defect ~ week, data = df, FUN = sum)
colnames(weekly) <- c("week", "np_i")
weekly$p_i <- weekly$np_i / n_sub
pbar <- sum(weekly$np_i) / (k * n_sub)   # 19/56 = 0.3393
cat(sprintf("Total defects: %d | p-bar: %.4f\n", sum(df$defect), pbar))

# ============================================================
# CHART 1: p-CHART
# ============================================================
sigma_p <- sqrt(pbar * (1 - pbar) / n_sub)
UCL_p <- min(1, pbar + 3 * sigma_p)
LCL_p <- max(0, pbar - 3 * sigma_p)
cat(sprintf("\np-Chart | p-bar=%.4f sigma=%.4f UCL=%.4f LCL=%.4f\n", pbar, sigma_p, UCL_p, LCL_p))
ooc_p <- which(weekly$p_i > UCL_p | weekly$p_i < LCL_p)

open_svg("figures/p_chart.svg", width = 8, height = 5)
par(mar = c(5, 5, 4, 2))
plot(weekly$week, weekly$p_i, type = "b",
     pch = ifelse(seq_len(k) %in% ooc_p, 17, 19),
     col = ifelse(seq_len(k) %in% ooc_p, "red", "steelblue"),
     cex = 1.6, xaxt = "n",
     ylim = c(0, max(UCL_p * 1.25, max(weekly$p_i) * 1.15)),
     xlab = "Week", ylab = "Proportion defective (p)",
     main = sprintf("p-Chart: Weekly Defect Proportion\n(k=%d, n=%d days/week, p-bar=%.4f)", k, n_sub, pbar),
     las = 1)
axis(1, at = 1:k, labels = paste0("W", 1:k))
abline(h = pbar, lwd = 2, col = "black")
abline(h = UCL_p, lwd = 2, lty = 2, col = "red")
abline(h = LCL_p, lwd = 2, lty = 2, col = "red")
text(weekly$week, weekly$p_i, labels = round(weekly$p_i, 3), pos = 3, cex = 0.75, col = "steelblue")
legend("topright",
       legend = c(sprintf("p-bar = %.4f", pbar), sprintf("UCL = %.4f", UCL_p), sprintf("LCL = %.4f", LCL_p)),
       lty = c(1, 2, 2), col = c("black", "red", "red"), lwd = 2, bty = "n", cex = 0.85)
invisible(dev.off())

# ============================================================
# CHART 2: np-CHART
# ============================================================
npbar    <- n_sub * pbar
sigma_np <- sqrt(n_sub * pbar * (1 - pbar))
UCL_np   <- min(n_sub, npbar + 3 * sigma_np)
LCL_np   <- max(0, npbar - 3 * sigma_np)
cat(sprintf("\nnp-Chart | np-bar=%.4f UCL=%.4f LCL=%.4f\n", npbar, UCL_np, LCL_np))
ooc_np <- which(weekly$np_i > UCL_np | weekly$np_i < LCL_np)

open_svg("figures/np_chart.svg", width = 8, height = 5)
par(mar = c(5, 5, 4, 2))
plot(weekly$week, weekly$np_i, type = "b",
     pch = ifelse(seq_len(k) %in% ooc_np, 17, 19),
     col = ifelse(seq_len(k) %in% ooc_np, "red", "steelblue"),
     cex = 1.6, xaxt = "n",
     ylim = c(0, max(UCL_np * 1.25, max(weekly$np_i) * 1.2)),
     xlab = "Week", ylab = "Number of defective days (np)",
     main = sprintf("np-Chart: Weekly Defect Count\n(k=%d, n=%d days/week, np-bar=%.2f)", k, n_sub, npbar),
     las = 1)
axis(1, at = 1:k, labels = paste0("W", 1:k))
abline(h = npbar, lwd = 2, col = "black")
abline(h = UCL_np, lwd = 2, lty = 2, col = "red")
abline(h = LCL_np, lwd = 2, lty = 2, col = "red")
text(weekly$week, weekly$np_i, labels = weekly$np_i, pos = 3, cex = 0.85, col = "steelblue")
legend("topright",
       legend = c(sprintf("np-bar = %.2f", npbar), sprintf("UCL = %.2f", UCL_np), sprintf("LCL = %.2f", LCL_np)),
       lty = c(1, 2, 2), col = c("black", "red", "red"), lwd = 2, bty = "n", cex = 0.85)
invisible(dev.off())

# ============================================================
# CHART 3: PARETO CHART (by defect dimension)
# ============================================================
dim_counts <- c(">1h Social Media"      = sum(df$social),
                "<7h Sleep"             = sum(df$sleep),
                "Missed Target"         = sum(df$missed),
                "Skipped Workout"       = sum(df$workout),
                "Priority Task Incomp." = sum(df$priority))
o          <- order(dim_counts, decreasing = TRUE)
cnt_sorted <- dim_counts[o]
cum_pct    <- cumsum(cnt_sorted) / sum(cnt_sorted) * 100
cat("\nPareto counts (sorted):\n")
for (i in seq_along(cnt_sorted))
  cat(sprintf("  %-25s %d (cum %.1f%%)\n", names(cnt_sorted)[i], cnt_sorted[i], cum_pct[i]))

open_svg("figures/pareto_chart.svg", width = 8, height = 5.5)
par(mar = c(9, 5, 4, 5))
ymax <- max(cnt_sorted) * 1.45
bp <- barplot(cnt_sorted, names.arg = names(cnt_sorted), las = 2, cex.names = 0.85,
              col = "steelblue", border = "white", ylim = c(0, ymax),
              ylab = "Total occurrences (56 days)",
              main = sprintf("Pareto Chart: Defect Dimension Frequency\n(56 days, total = %d)", sum(cnt_sorted)))
# Cumulative % drawn on the same x positions as the bars, scaled to a right-hand axis
scale_pct <- function(x) x / 100 * ymax * 0.9
lines(bp, scale_pct(cum_pct), type = "b", pch = 19, col = "darkorange", lwd = 2)
text(bp, scale_pct(cum_pct), labels = sprintf("%.1f%%", cum_pct), pos = 3, cex = 0.7, col = "darkorange")
axis(side = 4, at = scale_pct(seq(0, 100, 20)), labels = seq(0, 100, 20), las = 1)
mtext("Cumulative %", side = 4, line = 3.5, cex = 0.9)
abline(h = scale_pct(80), lty = 2, col = "red", lwd = 1.5)
legend("left", legend = c("Occurrence count", "Cumulative %", "80% threshold"),
       fill = c("steelblue", NA, NA), border = c("white", NA, NA), lty = c(NA, 1, 2), pch = c(NA, 19, NA),
       col = c("steelblue", "darkorange", "red"), lwd = 2, bty = "n", cex = 0.8, inset = c(0.45, -0.25), xpd = TRUE)
invisible(dev.off())

# ============================================================
# CHART 4: EWMA CHART (daily defect indicator, Bernoulli n=1)
# ============================================================
lambda <- 0.2
L      <- 3.0
p0     <- pbar
sigma0 <- sqrt(p0 * (1 - p0))
t_seq  <- seq_len(n_total)

ewma <- numeric(n_total)
ewma[1] <- lambda * df$defect[1] + (1 - lambda) * p0
for (t in 2:n_total) ewma[t] <- lambda * df$defect[t] + (1 - lambda) * ewma[t - 1]

sigma_ewma <- sigma0 * sqrt(lambda * (1 - (1 - lambda)^(2 * t_seq)) / (2 - lambda))
UCL_ewma <- pmin(1, p0 + L * sigma_ewma)
LCL_ewma <- pmax(0, p0 - L * sigma_ewma)
cat(sprintf("\nEWMA | lambda=%.2f L=%.1f p0=%.4f sigma0=%.4f\n", lambda, L, p0, sigma0))
cat(sprintf("Steady-state UCL (t=56): %.4f  LCL: %.4f\n", UCL_ewma[n_total], LCL_ewma[n_total]))
ooc_ewma <- which(ewma > UCL_ewma | ewma < LCL_ewma)
cat("Out-of-control days:", if (length(ooc_ewma) > 0) ooc_ewma else "None", "\n")

week_ends <- seq(7, n_total, by = n_sub)
open_svg("figures/ewma_chart.svg", width = 9, height = 5)
par(mar = c(5, 5, 4, 2))
plot(t_seq, ewma, type = "l", lwd = 2, col = "steelblue",
     ylim = c(0, max(UCL_ewma) * 1.3),
     xlab = "Day (1 to 56)", ylab = "EWMA statistic (z_t)",
     main = sprintf("EWMA Chart: Daily Defect Indicator\n(lambda=%.2f, L=%.1f, p-bar=%.4f)", lambda, L, p0),
     las = 1)
points(t_seq[df$defect == 1], ewma[df$defect == 1], pch = 19, col = "steelblue", cex = 1.0)
points(t_seq[df$defect == 0], ewma[df$defect == 0], pch = 1,  col = "steelblue", cex = 0.7)
lines(t_seq, UCL_ewma, lwd = 2, lty = 2, col = "red")
lines(t_seq, LCL_ewma, lwd = 2, lty = 2, col = "red")
abline(h = p0, lwd = 2, col = "black")
abline(v = week_ends[-length(week_ends)], lty = 3, col = "grey70", lwd = 1)
text(week_ends[-length(week_ends)] - 3, max(UCL_ewma) * 0.97, labels = paste0("W", 1:7), cex = 0.7, col = "grey50")
if (length(ooc_ewma) > 0) points(ooc_ewma, ewma[ooc_ewma], pch = 17, col = "red", cex = 1.5)
legend("topright",
       legend = c(sprintf("EWMA (lambda=%.2f)", lambda), sprintf("p-bar = %.4f", p0),
                  "UCL / LCL (time-varying)", "Defect day", "Non-defect day"),
       lty = c(1, 1, 2, NA, NA), pch = c(NA, NA, NA, 19, 1),
       col = c("steelblue", "black", "red", "steelblue", "steelblue"),
       lwd = c(2, 2, 2, NA, NA), bty = "n", cex = 0.85)
invisible(dev.off())

# ============================================================
# Binomial model: X ~ Binomial(7, p-bar)
# ============================================================
cat("\n===== Binomial Model: X ~ Binomial(7, p-bar) =====\n")
cat(sprintf("p-bar             : %.4f\n", pbar))
cat(sprintf("E[X] = 7 * p-bar  : %.4f defective days/week\n", 7 * pbar))
cat(sprintf("Var[X]            : %.4f\n", 7 * pbar * (1 - pbar)))
cat(sprintf("P(X=0)            : %.4f (%.1f%%)\n", dbinom(0, 7, pbar), dbinom(0, 7, pbar) * 100))
cat(sprintf("P(X>=4)           : %.4f (%.1f%%)\n", 1 - pbinom(3, 7, pbar), (1 - pbinom(3, 7, pbar)) * 100))
# Improvement target check: what happens if p drops to 0.20?
cat(sprintf("At p = 0.20       : P(X=0) = %.3f, P(X>=4) = %.3f\n", dbinom(0, 7, 0.20), 1 - pbinom(3, 7, 0.20)))
