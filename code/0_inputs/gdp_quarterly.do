********************************************************************************
* gdp_quarterly.do
*
* Converts the raw ONS GDP growth file into a quarterly series.
* Input:  data/raw/ons_gdp_growth_quarterly_2026-06-30.csv
* Output: data/intermediate/gdp_quarterly.dta
********************************************************************************

clear all
set more off

*** Quarterly rows ("1956 Q1", ...)
import delimited using "$raw/ons_gdp_growth_quarterly_2026-06-30.csv", ///
    varnames(nonames) stringcols(_all) clear
keep if regexm(v1, "^[0-9][0-9][0-9][0-9] Q[1-4]$")
gen quarter = yq(real(substr(v1, 1, 4)), real(substr(v1, -1, 1)))
format quarter %tq
destring v2, gen(gdp_growth)

keep if inrange(quarter, tq(1995q1), tq(2019q4))
keep quarter gdp_growth

label variable quarter    "Quarter"
label variable gdp_growth "Real GDP, growth over 4 quarters (IHYR), %"

compress
save "$inter/gdp_quarterly.dta", replace
