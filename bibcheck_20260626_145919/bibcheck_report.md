# Bibcheck report

Input: `references.bib`
Mode: `--by-citation` (default), with Crossref DOI/title pass plus manual adjudication for institutional references.

## Summary

- Clean/no change: 19
- Corrected in `corrected.bib`: 13
- Still needs human/source-specific review: 3

## Corrected in corrected.bib

- `ampudia2024shopping`: added doi=10.1016/j.jmoneco.2024.103618.
- `argente2021cost`: added doi=10.1093/jeea/jvaa018.
- `arregui2022targeted`: added doi=10.5089/9798400227400.001.
- `bobasu2023impact`: added url=https://www.ecb.europa.eu/press/economic-bulletin/articles/2023/html/ecb.ebart202303_02~d32f2a9b3f.en.html.
- `charalampakis2022impact`: added url=https://www.ecb.europa.eu/press/economic-bulletin/focus/2022/html/ecb.ebbox202207_04~a89ec1a6fe.en.html.
- `claeys2022inflation`: added url=https://www.bruegel.org/dataset/inflation-inequality-european-union-and-its-drivers.
- `cravino2020household`: added doi=10.1016/j.jinteco.2020.103303.
- `doepke2006inflation`: added doi=10.1086/508379.
- `hobijn2005inflation`: added doi=10.1111/j.1475-4991.2005.00184.x.
- `jaravel2024distributional`: added url=https://cepr.org/publications/dp19802.
- `kaplan2017inflation`: added doi=10.1016/j.jmoneco.2017.08.002.
- `pallotti2024bears`: added doi=10.1016/j.jmoneco.2024.103671.
- `sgaravatti2021national`: added url=https://www.bruegel.org/dataset/national-policies-shield-consumers-rising-energy-prices.

## Clean or no source-file change recommended

- `accardo2023measuring`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `bacharach1965estimating`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `bonnet2025compensating`: verified by DOI/title pass; no change made.
- `cai2020bridging`: verified by DOI/title pass; no change made.
- `cardoso2022heterogeneous`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `chen2024cheapflation`: verified by DOI/title pass; no change made.
- `corsello2026inflation`: verified by DOI/title pass; no change made.
- `coxWohlgenant1986prices`: verified by DOI/title pass; no change made.
- `dao2023unconventional`: verified by DOI/title pass; no change made.
- `drolsbach2023pass`: verified by DOI/title pass; no change made.
- `garciaMiralles2023support`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `gautier2024effects`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `jaravel2019unequal`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `jaravel2021inflation`: verified by DOI/title pass; no change made.
- `kiss2024inflation`: verified by DOI/title pass; no change made.
- `levell2026welfare`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `martin2022revisiting`: verified by DOI/title pass; no change made.
- `redding2020measuring`: Crossref suggested differences, but these appear to be online-first/working-paper metadata rather than clear BibTeX errors; no automatic change made.
- `sangani2026cheapflation`: verified by DOI/title pass; no change made.

## Human review queue

These entries were not conclusively verified by Crossref, usually because they are institutional pages, datasets, or working papers. I added URLs for the high-confidence institutional cases when the canonical page is known, but they should receive human/source-specific confirmation before submission.

- `deaton1988quality`: Crossref top hit title mismatch: Quality, quantity, and spatial variation of price: Back to the bog.
- `gautier2013vat`: Crossref top hit title mismatch: How Do Trade Disruptions Affect Inflation?.
- `levell2024distributional`: Crossref top hit title mismatch: Distributional effects of energy innovation.

## Parse test

`corrected.bib` was tested with a minimal BibTeX run using `plainnat`. The file parses successfully. BibTeX reports three non-fatal warnings (`number` without `volume`) for bulletin-style entries: `bobasu2023impact`, `charalampakis2022impact`, and `gautier2013vat`.

## Notes on conservative adjudication

- Crossref often reports the online publication year for journal articles. I did not replace print-volume years such as `argente2021cost`, `jaravel2019unequal`, or `redding2020measuring` where the existing volume/year metadata is internally consistent.
- SSRN hits were not treated as replacements for journal or central-bank working-paper entries unless the supplied entry itself is clearly a working-paper citation.
- `corrected.bib` is a proposed drop-in file. The source `references.bib` was not overwritten.

