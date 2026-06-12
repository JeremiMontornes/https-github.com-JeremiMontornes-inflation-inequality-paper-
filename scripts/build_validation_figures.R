library(data.table)
library(ggplot2)

pkg_repo <- "C:/Users/jerem/Documents/GitHub/inflationinequality"
paper_repo <- "C:/Users/jerem/Documents/GitHub/inflation-inequality-paper"
pkgload::load_all(pkg_repo, quiet = TRUE)

paper_naked_plot <- function(plot) {
  plot +
    labs(title = NULL, subtitle = NULL, x = NULL, y = NULL, caption = NULL) +
    theme(
      plot.title = element_blank(),
      plot.subtitle = element_blank(),
      axis.title.x = element_blank(),
      axis.title.y = element_blank(),
      plot.caption = element_blank()
    )
}

category_shares <- function(dt, categories, country = "FR") {
  out <- copy(dt)[category != "Total"]
  out[, share_year := year]
  shares <- inflationinequality:::ras_income_category_shares(
    country = country,
    categories = categories,
    weight_years = sort(unique(out$year))
  )
  shares[out, on = .(category, weight_year = share_year)]
}

save_paper_plot <- function(plot, filename, width = 8.5, height = 4.8) {
  ggsave(
    file.path(paper_repo, "fig", filename),
    plot,
    width = width,
    height = height,
    dpi = 160,
    bg = "white"
  )
}

inflation <- calculate_inflation(
  "FR",
  "income",
  level = 2,
  start_year = 2019,
  end_year = 2026,
  end_month = 4,
  weighting_method = "ras"
)

d1 <- paper_naked_plot(compare_to_official_hicp(inflation, measure = "rate")$plot)
save_paper_plot(
  d1,
  "fig_FR_2010_2026_hicp_inflation_validation_level2_recode_mean_vs_published.png"
)

weighted_dt <- category_shares(inflation$dt, inflation$categories)
comparison_dt <- weighted_dt[
  ,
  .(
    total_inflation = mean(inflation),
    weighted_quintile_inflation = weighted.mean(inflation, category_share)
  ),
  by = .(year, month)
]
comparison_dt[, date := as.Date(sprintf("%04d-%02d-01", year, month))]
comparison_dt[, difference := weighted_quintile_inflation - total_inflation]

line_dt <- melt(
  comparison_dt,
  id.vars = c("year", "month", "date", "difference"),
  measure.vars = c("total_inflation", "weighted_quintile_inflation"),
  variable.name = "series",
  value.name = "value"
)
line_dt[
  ,
  series := fcase(
    series == "total_inflation", "Total",
    series == "weighted_quintile_inflation", "Weighted average of quintiles"
  )
]

d2 <- ggplot(comparison_dt, aes(x = date)) +
  geom_col(aes(y = difference), fill = "grey75", color = "grey75", width = 25) +
  geom_hline(yintercept = 0, color = "grey40", linewidth = 0.3) +
  geom_line(data = line_dt, aes(y = value, color = series), linewidth = 0.8) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  scale_color_manual(
    values = c(
      "Total" = "black",
      "Weighted average of quintiles" = "#2f6fbb"
    )
  ) +
  labs(x = NULL, y = NULL, color = NULL, title = NULL, subtitle = NULL, caption = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank(),
    plot.title = element_blank(),
    plot.subtitle = element_blank(),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    plot.caption = element_blank()
  )

save_paper_plot(
  d2,
  "fig_FR_2010_2026_hicp_validation_level_mean_vs_published.png"
)

print(comparison_dt[
  ,
  .(
    n = .N,
    mean_difference = mean(difference, na.rm = TRUE),
    mean_abs_difference = mean(abs(difference), na.rm = TRUE),
    max_abs_difference = max(abs(difference), na.rm = TRUE)
  )
])
