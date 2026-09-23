# data/derived

Files in this folder stay on your computer: `.gitignore` keeps everything here, except this note, off GitHub. They are built from Bank of England workbooks that are not openly licensed, so they are not posted either (see [`../README.md`](../README.md)).

`master.do` writes them when `rebuild_derived` is set to 1, which is the default. It needs the two workbooks in [`../restricted/`](../restricted/README.md).

| File | Built by | What it is |
|---|---|---|
| `QuarterlyMPC.dta` | `code/0_inputs/mp_shocks.do` | Quarterly sums of the six-month and 2-, 5- and 10-year surprises over MPC announcements |
| `AnnualMPC.dta` | `code/0_inputs/mp_shocks.do` | The same sums by year |
| `QuarterlyFactorsMPC.dta` | `code/0_inputs/mp_shocks.do` | Quarterly sums of the Target, Path and QE factors |
| `AnnualFactorsMPC.dta` | `code/0_inputs/mp_shocks.do` | The same sums by year |
| `Quarterly_MPS_InfoSplit.dta` | `code/0_inputs/mp_shocks.do` | The 2-year surprise split into no-information and information meetings |
| `Yields_UK_24m.dta` | `code/0_inputs/yields_annual.do` | December-to-December change in the 2-year nominal spot yield |
