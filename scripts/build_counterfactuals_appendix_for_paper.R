#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
})

paper_root <- "C:/Users/jerem/Documents/GitHub/inflation-inequality-paper"
fig_src_root <- "C:/Users/jerem/Documents/GitHub/build-figures-tables"
manifest_path <- file.path(
  fig_src_root,
  "cache",
  "ea20_energy_counterfactual_graph_manifest",
  "output",
  "energy_counterfactual_graph_manifest.csv"
)

appendix_path <- file.path(paper_root, "appendices", "counterfactuals_appendix.tex")
fig_dest_dir <- file.path(paper_root, "fig", "counterfactuals")
dir.create(fig_dest_dir, recursive = TRUE, showWarnings = FALSE)
unlink(file.path(fig_dest_dir, "*.png"))

pretty_component <- function(coicop, component) {
  component <- as.character(component)
  case_when(
    coicop == "CP0451" ~ "electricity",
    coicop == "CP0452" ~ "gas",
    coicop == "CP0455" ~ "heat energy",
    coicop == "CP0722" ~ "transport fuels",
    TRUE ~ str_to_lower(component)
  )
}

method_title <- function(method_family) {
  case_when(
    method_family == "vat_exclusive_rechained" ~ "VAT reduction",
    method_family == "regulated_price_existing_replication" ~ "regulated price cap",
    method_family == "existing_spain_replication" ~ "electricity price measures",
    method_family == "unit_fuel_rebate_existing_replication" ~ "fuel rebate",
    method_family == "unit_subsidy_rechained" ~ "unit subsidy",
    method_family == "targeted_social_bonus_aggregate_test" ~ "social bonus aggregate test",
    TRUE ~ method_family
  )
}

method_source <- function(method_family) {
  case_when(
    method_family == "vat_exclusive_rechained" ~
      "Eurostat HICP; Bruegel energy-policy dataset; authors' calculations.",
    method_family == "regulated_price_existing_replication" ~
      "Eurostat HICP; CRE regulated-tariff data; Bruegel energy-policy dataset; authors' calculations.",
    method_family == "existing_spain_replication" ~
      "Eurostat HICP; Spanish public electricity-market and policy data; Bruegel energy-policy dataset; authors' calculations.",
    method_family == "unit_fuel_rebate_existing_replication" ~
      "Eurostat HICP; EC Weekly Oil Bulletin and national fuel-price data; Bruegel energy-policy dataset; authors' calculations.",
    method_family == "unit_subsidy_rechained" ~
      "Eurostat HICP; Bruegel energy-policy dataset and statutory unit-subsidy schedules; authors' calculations.",
    method_family == "targeted_social_bonus_aggregate_test" ~
      "Eurostat HICP; Bruegel energy-policy dataset; ARERA social-bonus information; authors' calculations.",
    TRUE ~ "Eurostat HICP; Bruegel energy-policy dataset; authors' calculations."
  )
}

method_note <- function(method_family) {
  case_when(
    method_family == "vat_exclusive_rechained" ~
      "The counterfactual removes the temporary VAT cut by backing out the reduced-tax price, reapplying the normal VAT rate and rechaining the index.",
    method_family == "regulated_price_existing_replication" ~
      "The counterfactual follows the existing France regulated-tariff replication and compares the observed HICP with a no-shield tariff path.",
    method_family == "existing_spain_replication" ~
      "The counterfactual uses the existing Spain replication of electricity price measures, excluding the proscribed neighbourhood-benchmark method.",
    method_family == "unit_fuel_rebate_existing_replication" ~
      "The counterfactual adds back the statutory per-litre fuel rebate to the observed pump-price path and rechains the HICP component.",
    method_family == "unit_subsidy_rechained" ~
      "The counterfactual reconstructs a unit price from the HICP, adds the monthly EUR/kWh or EUR/MWh subsidy and rechains the index.",
    method_family == "targeted_social_bonus_aggregate_test" ~
      "This is an aggregate incidence test for a targeted bill discount; it is shown as an order-of-magnitude exercise rather than a final HICP correction.",
    TRUE ~ "Observed and counterfactual HICP component indices."
  )
}

latex_escape <- function(x) {
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([#$%&_{}])", "\\\\\\1", x, perl = TRUE)
  x <- gsub("~", "\\\\textasciitilde{}", x)
  x <- gsub("\\^", "\\\\textasciicircum{}", x)
  x
}

manifest <- read_csv(manifest_path, show_col_types = FALSE) |>
  filter(status != "excluded_by_user") |>
  filter(!country %in% c("France", "Spain")) |>
  mutate(
    component_label = pretty_component(coicop, component),
    method_label = method_title(method_family),
    title = paste0(country, " -- ", component_label, " (", coicop, "), ", method_label),
    source = method_source(method_family),
    note = method_note(method_family),
    source_file = file.path(fig_src_root, figure),
    dest_name = paste0(
      str_pad(row_number(), 2, pad = "0"),
      "_",
      str_replace_all(str_to_lower(country), "[^a-z0-9]+", "_"),
      "_",
      str_to_lower(coicop),
      "_",
      str_replace_all(str_to_lower(method_family), "[^a-z0-9]+", "_"),
      ".png"
    ),
    dest_file = file.path(fig_dest_dir, dest_name),
    latex_file = file.path("fig", "counterfactuals", dest_name) |>
      str_replace_all("\\\\", "/")
  ) |>
  arrange(country, coicop, method_family)

missing <- manifest |> filter(!file.exists(source_file))
if (nrow(missing) > 0) {
  stop("Missing source figures: ", paste(missing$source_file, collapse = "; "))
}

file.copy(manifest$source_file, manifest$dest_file, overwrite = TRUE)
write_csv(
  manifest |> select(country, coicop, component_label, method_family, status, title, source, note, latex_file),
  file.path(paper_root, "fig", "counterfactuals", "_counterfactuals_appendix_manifest.csv")
)

graph_block <- function(row) {
  paste0(
    "\\begin{minipage}{0.92\\textwidth}\n",
    "\\centering\n",
    "{\\large\\textbf{", latex_escape(row$title), "}\\par}\n",
    "\\vspace{0.2em}\n",
    "\\includegraphics[width=\\linewidth,height=0.265\\textheight,keepaspectratio]{", row$latex_file, "}\n",
    "{\\scriptsize\\RaggedRight Source: ", latex_escape(row$source), "\\\\\n",
    "Note: ", latex_escape(row$note), "\\par}\n",
    "\\end{minipage}\n"
  )
}

country_pages <- lapply(split(manifest, manifest$country), function(country_df) {
  country_df <- country_df |> arrange(coicop, method_family)
  rows <- split(country_df, seq_len(nrow(country_df)))
  pairs <- split(rows, ceiling(seq_along(rows) / 2))

  pages <- vapply(seq_along(pairs), function(i) {
    blocks <- paste(vapply(pairs[[i]], graph_block, character(1)), collapse = "\\vspace{0.6em}\n")
    paste0(
      "\\begin{center}\n",
      "\\centering\n",
      blocks,
      "\\end{center}\n",
      "\\clearpage\n"
    )
  }, character(1))

  paste0(
    "\\subsection{", latex_escape(country_df$country[1]), "}\n",
    paste(pages, collapse = "\n")
  )
})

tex <- paste0(
  "% Auto-generated by scripts/build_counterfactuals_appendix_for_paper.R.\n",
  "\\clearpage\n",
  "\\section{Counterfactuals}\n",
  "\\label{sec:app-counterfactuals}\n\n",
  "This appendix reports the observed and counterfactual energy-price component indices used to assess price-measure effects. ",
  "Figures are ordered alphabetically by country. The synthetic neighbourhood benchmark is excluded.\n\n",
  paste(unname(country_pages), collapse = "\n")
)

writeLines(tex, appendix_path, useBytes = TRUE)

cat("Wrote ", appendix_path, "\n", sep = "")
cat("Copied ", nrow(manifest), " figures to ", fig_dest_dir, "\n", sep = "")
