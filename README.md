# Distributional House Price Cycles

Replication code for:

> Rodriguez Tous, Francesc (2026). "Distributional house price cycles." Working paper, Bayes Business School, City St George's, University of London. SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7510918

## Abstract

I study how house price cycles differ across the distribution of house prices within local markets. Using transaction-level housing data, I create a set of distributional house price indices (DHPIs) that track how different percentiles of the house price distribution evolve over time. Controlling for local market conditions, I show that house prices at the lower end of the distribution are substantially more procyclical, particularly in response to the credit cycle, and exhibit significantly stronger responses to monetary policy shocks; the differences are sizeable and accumulate over time. The pattern is consistent with borrowing constraints binding more tightly for the marginal buyers of lower-priced homes and reveals a distributional channel through which monetary policy and macroeconomic fluctuations propagate within housing markets.

## How to reproduce the results

1. Download the files marked `restricted/` in [`data/README.md`](data/README.md) and save them in `data/restricted/`. Everything else is already in the repository. Both Bank of England workbooks (monetary policy surprises and yield curves) are free downloads from the Bank's website; `master.do` rebuilds `data/derived/` from them on every run (option `rebuild_derived`, set to 1 by default).
2. Open `master.do` and set `global root` to the folder where this repository sits on your computer.
3. Run `master.do`. It installs the Stata packages it needs, builds the indices, and writes every table and figure to `output/`.

To run a single step, run Sections 1 to 4 of `master.do` first, then the do-file you want. Once the indices exist, set `build_indices` to 0 in `master.do` to rerun everything except the indices.

## Requirements

- **Stata** 18 or later (the paper's results were produced with Stata 18 SE). User-written packages, installed by `master.do` from SSC: `ftools`, `reghdfe`, `coefplot`, `boottest`.
- **Python 3**, only for the two maps (Figures 5 and 6), with `pandas`, `numpy`, `geopandas`, `matplotlib` and `shapely`.
- **Memory and time.** The Land Registry file has tens of millions of transactions, so building the indices needs plenty of memory. The local projections run 252 wild cluster bootstraps of 9,999 draws each. A full run takes about 45 minutes on a laptop, of which about 15 are the tables and figures.

## What is where

```
master.do          runs everything, in order
code/
  0_inputs/        raw macro data and monetary policy surprises -> quarterly and annual series
  1_indices/       Land Registry data -> the DHPIs and the two alternative indices
  2_results/       tables and figures
data/
  raw/             raw downloads, unchanged, with the download date in the file name
  derived/         small files the code builds from the workbooks in restricted/ (not on GitHub)
  restricted/      large or licensed files you download yourself (not on GitHub)
  intermediate/    files created by the code (not on GitHub)
output/            tables, figures and logs created by the code (not on GitHub)
```

## Data

All data are public. The raw Bank of England Database and ONS files are in `data/raw/`. The Land Registry Price Paid file is too large for GitHub, and its address fields are not openly licensed, so it has to be downloaded. The Bank of England's monetary policy and yield curve workbooks are not openly licensed either, so neither they nor the series built from them are posted; the code rebuilds those series from workbooks you download yourself. [`data/README.md`](data/README.md) lists every source, its licence, the version used and the attribution statements.

## Which file produces each table and figure

Numbering as in the September 2026 version of the paper. All do-files are in `code/2_results/` unless stated otherwise.

| Exhibit | Code | Output file |
|---|---|---|
| Table 1 | `Summary_Statistics.do` | `summary_stats.tex` |
| Figure 1 | `Descriptive_Figures.do` | `series_gdp_net_lending.pdf` |
| Figure 2 | `Descriptive_Figures.do` | `series_mp_shocks.pdf` |
| Figure 3 | `Descriptive_Figures.do` | `dhpis.pdf` |
| Figure 4 | `Descriptive_Figures.do` | `gap_p20_p80.pdf`, `gap_p20_p80_distribution.pdf` |
| Figure 5 | `Maps_Figures.do`, then `make_map_p20p80_annual_chained.py` | `map_boom_bust.pdf` |
| Figure 6 | `Maps_Figures.do`, then `make_map_p20p80_longrun.py` | `map_long_run.pdf` |
| Figure 7 | `Hedonic_HPI_Figures.do` | `dhpi_vs_hedonic.pdf` |
| Figure 8 | `Business_Credit_Cycles.do` | `gdp_credit_p20_p80_A/B/C.pdf` |
| Figure 9 | `Price_of_Credit.do` | `rates_p20_p80.pdf` |
| Figure 10 | `Monetary_Policy.do` | `mp_p20_p80.pdf` |
| Figure 11 | `Local_Projections.do` | `lp_p20_p80.pdf` |
| Table A.1 | `Summary_Statistics.do`, from the counts saved by `code/1_indices/DHPI_Quarterly.do` | `dhpi_steps.tex` |
| Table A.2 | `Summary_Statistics.do` | `summary_stats_deciles.tex` |
| Figure A.1 | `Alternative_Indices.do` | `alt_indices.pdf` |
| Table A.3 | `Business_Credit_Cycles.do` | `gdp_credit_p20_p80.tex` |
| Figure A.2 | `Business_Credit_Cycles.do` | `gdp_credit_p25_p75_A/B/C.pdf` |
| Figure A.3 | `Business_Credit_Cycles.do` | `gdp_credit_p10_p90_A/B/C.pdf` |
| Figure A.4 | `Descriptive_Figures.do` | `series_credit_measures.pdf` |
| Figure A.5 | `Business_Credit_Cycles.do` | `credit_measures_p20_p80.pdf` |
| Figure A.6 | `Hedonic_HPI_Figures.do` | `gdp_credit_by_type.pdf` |
| Table A.4 | `Alternative_Indices.do` | `alt_indices_gdp_credit.tex` |
| Table A.5 | `Price_of_Credit.do` | `rates_p20_p80.tex` |
| Figure A.7 | `Price_of_Credit.do` | `rates_p25_p75.pdf` |
| Figure A.8 | `Price_of_Credit.do` | `rates_p10_p90.pdf` |
| Table A.6 | `Monetary_Policy.do` | `mp_p20_p80.tex` |
| Figure A.9 | `Monetary_Policy.do` | `mp_p25_p75.pdf` |
| Figure A.10 | `Monetary_Policy.do` | `mp_p10_p90.pdf` |
| Figure A.11 | `Hedonic_HPI_Figures.do` | `mp_by_type.pdf` |
| Table A.7 | `Alternative_Indices.do` | `alt_indices_mp.tex` |
| Figure A.12 | `Monetary_Policy.do` | `mp_info_split.pdf` |
| Figure A.13 | `Local_Projections.do` | `lp_other_shocks.pdf` |
| Figure A.14 | `Local_Projections.do` | `lp_p25_p75.pdf` |
| Figure A.15 | `Local_Projections.do` | `lp_p10_p90.pdf` |
| Figure A.16 | `Hedonic_HPI_Figures.do` | `lp_by_type.pdf` |
| Figure A.17 | `Local_Projections.do` | `lp_actual_yield.pdf` |
| Figure A.18 | `Local_Projections.do` | `lp_p20_p80_lead.pdf` |

## How to cite

If you use this code or the DHPIs, please cite the paper:

```bibtex
@unpublished{RodriguezTous2026,
  author = {Rodriguez Tous, Francesc},
  title  = {Distributional House Price Cycles},
  year   = {2026},
  note   = {Working paper, Bayes Business School},
  url    = {https://papers.ssrn.com/sol3/papers.cfm?abstract_id=7510918}
}
```

## Licence

The code is released under the MIT licence (see [`LICENSE`](LICENSE)). The data keep their own licences, listed in [`data/README.md`](data/README.md).

## Contact

Francesc Rodriguez Tous, Bayes Business School, City St George's, University of London. Francesc.Rodriguez-Tous@citystgeorges.ac.uk
