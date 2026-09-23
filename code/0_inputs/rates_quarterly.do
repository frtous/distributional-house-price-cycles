********************************************************************************
* rates_quarterly.do
*
* Converts the raw Bank of England interest rate files into quarterly series.
* Inputs:  data/raw/boe_bankrate_daily_2026-09-22.csv
*          data/raw/boe_gilt_yields_daily_2026-09-22.csv
*          data/raw/boe_mortgage_rate_2y75_monthly_2026-09-22.csv
* Output:  data/intermediate/rates_quarterly.dta
********************************************************************************

clear all
set more off

*** Each file: the first series after the date, averaged by quarter; dates
*** have two-digit years (topyear 2030)

*** Bank Rate, daily (IUDBEDR)
import delimited using "$raw/boe_bankrate_daily_2026-09-22.csv", ///
    varnames(nonames) rowrange(2) stringcols(_all) clear
destring v2, replace force
gen quarter = qofd(date(v1, "DMY", 2030))
drop if missing(quarter)
collapse (mean) bankrate_avg = v2, by(quarter)
tempfile bank
save `bank'

*** 10-year gilt nominal par yield, daily (IUDMNPY)
import delimited using "$raw/boe_gilt_yields_daily_2026-09-22.csv", ///
    varnames(nonames) rowrange(2) stringcols(_all) clear
destring v2, replace force
gen quarter = qofd(date(v1, "DMY", 2030))
drop if missing(quarter)
collapse (mean) gilt10_avg = v2, by(quarter)
tempfile gilt
save `gilt'

*** Quoted 2-year fixed mortgage rate, 75% LTV, monthly (IUMBV34)
import delimited using "$raw/boe_mortgage_rate_2y75_monthly_2026-09-22.csv", ///
    varnames(nonames) rowrange(2) stringcols(_all) clear
destring v2, replace force
gen quarter = qofd(date(v1, "DMY", 2030))
drop if missing(quarter)
collapse (mean) fix2y75_avg = v2, by(quarter)

*** Combine and keep 1995q1-2019q4
merge 1:1 quarter using `bank', nogen
merge 1:1 quarter using `gilt', nogen
format quarter %tq
keep if inrange(quarter, tq(1995q1), tq(2019q4))

label variable quarter         "Quarter"
label variable bankrate_avg    "Bank Rate, quarterly average (IUDBEDR), %"
label variable gilt10_avg      "10-year gilt yield, quarterly average (IUDMNPY), %"
label variable fix2y75_avg     "2-year fixed mortgage rate, 75% LTV, quarterly average (IUMBV34), %"

order quarter bankrate_avg gilt10_avg fix2y75_avg
compress
save "$inter/rates_quarterly.dta", replace
