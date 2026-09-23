********************************************************************************
* DHPI_Quarterly.do
*
* Builds the quarterly distributional house price indices (DHPIs) by local
* authority from the HM Land Registry Price Paid Data.
* Inputs:  data/restricted/pp-complete.csv
*          data/restricted/Postcode_to_LAU.dta
* Outputs: data/intermediate/SeriesQReady_WIDE.dta
*          data/intermediate/SeriesQReady_LONG.dta
*          data/intermediate/DHPI_steps.dta
********************************************************************************

clear

*** Price Paid Data: up to 2019, category A, no new builds
import delimited "$restricted/pp-complete.csv"
keep v2 v3 v4 v5 v6 v15
rename (v2 v3 v4 v5 v6 v15) (price date pcds property_type new_prop category)

split date, p(" ")
gen date_n = date(date1, "YMD")
gen year = yofd(date_n)
gen quarter = qofd(date_n)
format quarter %tq

keep if year <= 2019
local n1 = _N
keep if category == "A"
local n2 = _N
keep if new_prop == "N"
local n3 = _N

*** Local authority
merge m:1 pcds using "$restricted/Postcode_to_LAU.dta", keep(match) nogen keepusing(laua)
rename laua lau117cd
local n4 = _N

*** Mean price and number of transactions by postcode x property type x quarter
collapse (mean) price (count) num=price, by(lau117cd pcds new_prop property_type year quarter)
local n5 = _N

*** Drop cells above the 99th percentile of transactions
sum num, d
keep if num <= `r(p99)'
drop num
local n6 = _N

*** Keep units also observed four quarters earlier
egen id = group(pcds property_type)
xtset id quarter
gen l_price = l4.price
keep if !missing(price, l_price)
local n7 = _N

*** Percentiles by local authority and quarter, and their y/y growth (%)
local pcts 10 20 25 30 40 50 60 70 75 80 90

local cstats ""
foreach q of local pcts {
    local cstats `cstats' (p`q') p`q'=price l_p`q'=l_price
}
collapse `cstats' (count) num=price, by(lau117cd quarter)
local n8 = _N

foreach q of local pcts {
    gen ch_p`q' = 100 * (p`q' - l_p`q') / l_p`q'
}

*** Keep local authorities observed in all 96 quarters
bysort lau117cd: gen e = _N
keep if e == 96
drop e
local n9 = _N

*** Flags: smallest number of units at or above the median (d_min1) or the
*** 75th percentile (d_min2) across local authorities
bysort lau117cd: egen min_num = min(num)
bysort lau117cd: gen e = _n
sum min_num if e == 1, d
gen d_min1 = 1 if min_num >= `r(p50)'
gen d_min2 = 1 if min_num >= `r(p75)'
drop e

*** Winsorise growth at p1/p99 within quarter
foreach var of varlist ch_p10 ch_p20 ch_p25 ch_p30 ch_p40 ch_p50 ch_p60 ch_p70 ch_p75 ch_p80 ch_p90 {
    gen `var'_w = `var'
    forvalues x = 144 / 239 {
        sum `var' if quarter == `x', d
        replace `var'_w = `r(p1)' if `var' < `r(p1)' & `var' != . & quarter == `x'
        replace `var'_w = `r(p99)' if `var' > `r(p99)' & `var' != . & quarter == `x'
    }
}

save "$inter/SeriesQReady_WIDE.dta", replace

*** Long version: one row per local authority x quarter x percentile
rename ch_p10_w ch1
rename ch_p20_w ch2
rename ch_p25_w ch3
rename ch_p30_w ch4
rename ch_p40_w ch5
rename ch_p50_w ch6
rename ch_p60_w ch7
rename ch_p70_w ch8
rename ch_p75_w ch9
rename ch_p80_w ch10
rename ch_p90_w ch11

egen id = group(lau117cd quarter)

drop ch_p* p* l_p*
reshape long ch, i(id) j(percentile)
drop id

*** Percentile dummies
gen p10 = percentile == 1
gen p20 = percentile == 2
gen p25 = percentile == 3
gen p30 = percentile == 4
gen p40 = percentile == 5
gen p50 = percentile == 6
gen p60 = percentile == 7
gen p70 = percentile == 8
gen p75 = percentile == 9
gen p80 = percentile == 10
gen p90 = percentile == 11

save "$inter/SeriesQReady_LONG.dta", replace

*** Observations after each step
clear
set obs 9
gen byte step = _n
gen double obs = .
forvalues s = 1/9 {
    replace obs = `n`s'' in `s'
}
save "$inter/DHPI_steps.dta", replace
