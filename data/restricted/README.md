# data/restricted

Files in this folder stay on your computer: `.gitignore` keeps everything here, except this note, off GitHub. They are too large for GitHub or not openly licensed. Download them as described in [`../README.md`](../README.md) and save them here under these names:

| File | What it is |
|---|---|
| `pp-complete.csv` | HM Land Registry Price Paid Data, complete file (several GB) |
| `Postcode_to_LAU.dta` | Postcode-to-local-authority lookup. Built from `Data/NSPL_FEB_2019_UK.csv` in the National Statistics Postcode Lookup, February 2019 UK edition: keep `pcd`, `pcd2`, `pcds` and `laua`, and drop the 9,808 rows with a blank `laua`, leaving 2,614,777 postcodes. The December 2018 local authority geography it uses is what gives the 348 England and Wales districts in the paper; a later NSPL edition has a different set of local authorities and will not reproduce them |
| `measuring-monetary-policy-in-the-uk-the-ukmpesd.xlsx` | The UK Monetary Policy Event-Study Database (Braun, Miranda-Agrippino and Saha). Only needed to rebuild the shock files in `data/derived/`; stays here unless the Bank of England agrees to it being posted |
| `GLC Nominal month end data_1970 to 2015.xlsx` and `GLC Nominal month end data_2016 to 2024.xlsx` | Bank of England nominal government liability curve, month-end: the first two files in the zip "Monthly government liability curve (nominal): archive data" on the Bank's [Yield curves](https://www.bankofengland.co.uk/statistics/yield-curves) page. Only needed to rebuild `Yields_UK_24m.dta` in `data/derived/`; stay here unless the Bank of England agrees to them being posted |
