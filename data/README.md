# Data

Where every input comes from, whether it is in this repository, and under which licence.

| Folder | Contents | On GitHub? |
|---|---|---|
| `raw/` | Raw files exactly as downloaded, with the download date in the file name (for the ONS file, its release date) | Yes |
| `derived/` | Small files built from the workbooks in `restricted/`; `master.do` rebuilds them (option `rebuild_derived`) | No |
| `restricted/` | Large or licensed files: download them yourself (see below) | No |
| `intermediate/` | Files the code creates; `master.do` rebuilds them | No |

## Sources

| Input | Source | Licence | Where | Downloaded |
|---|---|---|---|---|
| Price Paid Data, complete file (`pp-complete.csv`) | HM Land Registry, [Price Paid Data](https://www.gov.uk/government/statistical-data-sets/price-paid-data-downloads) | Open Government Licence v3.0; the address fields are Royal Mail and Ordnance Survey data and are not covered | `restricted/` | 25 Nov 2024 (file date) |
| Postcode-to-local-authority lookup (`Postcode_to_LAU.dta`) | ONS, National Statistics Postcode Lookup (NSPL), February 2019 UK edition, [Open Geography Portal](https://geoportal.statistics.gov.uk/) | Open Government Licence v3.0, with Ordnance Survey and Royal Mail attribution | `restricted/` | February 2019 edition |
| UK House Price Index, full file, December 2023 edition | HM Land Registry and ONS, [UK HPI data downloads, December 2023](https://www.gov.uk/government/statistical-data-sets/uk-house-price-index-data-downloads-december-2023) | Open Government Licence v3.0 | `raw/UK-HPI-full-file-2023-12.csv` | 15 Dec 2024 (file date) |
| Bank Rate, daily (`IUDBEDR`), with the Bank's quarterly average (`IUQABEDR`) and end-quarter value (`IUQLBEDR`) | [Bank of England Database](https://www.bankofengland.co.uk/boeapps/database/) | Open Government Licence v3.0 | `raw/boe_bankrate_daily_2026-09-22.csv` | 22 Sep 2026 |
| Gilt yields, daily: 10-year (`IUDMNPY`) and 5-year (`IUDSNPY`) nominal par yields, with quarterly averages (`IUQAMNPY`, `IUQASNPY`) and end-quarter values (`IUQMNPY`, `IUQSNPY`) | Bank of England Database | Open Government Licence v3.0 | `raw/boe_gilt_yields_daily_2026-09-22.csv` | 22 Sep 2026 |
| Quoted 2-year fixed-rate mortgage rate, 75% LTV, monthly (`IUMBV34`) | Bank of England Database | Open Government Licence v3.0 | `raw/boe_mortgage_rate_2y75_monthly_2026-09-22.csv` | 22 Sep 2026 |
| Lending, monthly, seasonally adjusted: net secured lending (`LPMVTVJ`), secured lending outstanding (`LPMVTXK`), approvals for house purchase (`LPMVTVX`), consumer credit outstanding (`LPMBI2O`) | Bank of England Database | Open Government Licence v3.0 | `raw/boe_lending_monthly_2026-09-22.csv` | 22 Sep 2026 |
| Real GDP growth, quarter on the same quarter a year earlier, chained volume measure, seasonally adjusted, % (`IHYR`, dataset QNA) | ONS, [IHYR time series](https://www.ons.gov.uk/economy/grossdomesticproductgdp/timeseries/ihyr/qna) | Open Government Licence v3.0 | `raw/ons_gdp_growth_quarterly_2026-06-30.csv` | ONS release of 30 June 2026 |
| Monetary policy surprises and Target, Path and QE factors | Braun, Miranda-Agrippino and Saha, [UK Monetary Policy Event-Study Database](https://www.bankofengland.co.uk/working-paper/2023/measuring-monetary-policy-in-the-uk-ukmpd), Bank of England Staff Working Paper No. 1,050. Direct download: [measuring-monetary-policy-in-the-uk-the-ukmpesd.xlsx](https://www.bankofengland.co.uk/-/media/boe/files/working-paper/2023/measuring-monetary-policy-in-the-uk-the-ukmpesd.xlsx) | Bank of England terms; posting the workbook, or series built from it, needs the Bank's permission | Workbook in `restricted/`; quarterly and annual sums built into `derived/` by `code/0_inputs/mp_shocks.do`, neither posted | 22 Sep 2026 (April 2026 revision of the database) |
| 2-year nominal spot yield, month-end (its December-to-December change is `Yields_UK_24m.dta`) | Bank of England, [Yield curves](https://www.bankofengland.co.uk/statistics/yield-curves): UK nominal government liability curve, sheet "3. spot, short end" of the first two files in "Monthly government liability curve (nominal): archive data" | Bank of England terms (the Open Government Licence covers only the Bank of England Database); posting the workbooks, or series built from them, needs the Bank's permission | Workbooks in `restricted/`; the annual change built into `derived/` by `code/0_inputs/yields_annual.do`, neither posted | The two files are identical to those in the Bank's archive on 22 Sep 2026 |
| Local authority boundaries, December 2017 (`lad17.geojson`) | ONS Open Geography Portal | Open Government Licence v3.0, with Ordnance Survey attribution | `raw/lad17.geojson` | 10 Aug 2026 (file date) |

## Attribution statements

Work that reuses these data should include:

- **HM Land Registry** (Price Paid Data, UK HPI): "Contains HM Land Registry data © Crown copyright and database right 2026. This data is licensed under the Open Government Licence v3.0."
- **ONS**: "Source: Office for National Statistics licensed under the Open Government Licence v.3.0." For the boundaries and the postcode lookup, add "Contains OS data © Crown copyright and database right 2026". For the postcode lookup, also add "Contains Royal Mail data © Royal Mail copyright and database right 2026".
- **Bank of England Database**: "Contains public sector information licensed under the Open Government Licence v3.0."
- **Bank of England yield curves**: "Source: Bank of England." The data are copyright of the Governor and Company of the Bank of England.
- **Monetary policy surprises**: cite Braun, R., S. Miranda-Agrippino and T. Saha (2025), "Measuring monetary policy in the UK: The UK monetary policy event-study database", *Journal of Monetary Economics* 149.

## Why `derived/` is not in the repository

`data/derived/` holds quarterly and annual sums of the monetary policy surprises, the Target, Path and QE factors, and the December-to-December change in the 2-year spot yield. All of them are built from Bank of England workbooks that are not openly licensed.

Aggregating does not make them free to post. Over the estimation window the MPC announced three times in most quarters, but in 20 of the 91 quarters only one announcement carried a non-zero six-month surprise, so for those quarters the quarterly figure is the original announcement-level number rather than a summary of several. Until the Bank agrees otherwise, the workbooks and everything built from them stay off GitHub.

This costs a replicator very little, because both sources are free downloads from the Bank's own website (links in the table above). Save them in `data/restricted/` under the names listed in [`restricted/README.md`](restricted/README.md) and run `master.do` with `rebuild_derived` set to 1, which is the default.

## Versions

These sources change over time. The Land Registry updates past records every month, ONS revises GDP, the Bank revises its seasonally adjusted lending series, and the monetary policy factors are re-estimated as the event-study database grows. The files in this repository are the versions used in the paper, so `master.do` reproduces its numbers exactly. A fresh download may give slightly different numbers. This applies with particular force to the two Bank of England workbooks, which are not in the repository: the paper uses the April 2026 revision of the event-study database, downloaded on 22 September 2026, and the Bank re-estimates the factors as the database grows, so a later revision will not reproduce the monetary policy results exactly. The Price Paid Data cannot be posted, so the observation counts in Table A.1 may differ slightly for a file downloaded at a later date.
