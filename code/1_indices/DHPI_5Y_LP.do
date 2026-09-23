********************************************************************************
* DHPI_5Y_LP.do
*
* Builds the annual distributional house price indices (DHPIs) on five-year
* constant baskets, by local authority, from the HM Land Registry Price Paid Data.
* Inputs:  data/restricted/pp-complete.csv
*          data/restricted/Postcode_to_LAU.dta
* Output:  data/intermediate/DHPI_5Y_LP.dta
********************************************************************************

clear

*** Price Paid Data: category A, no new builds, up to 2019
import delimited "$restricted/pp-complete.csv"

keep v2 v3 v4 v5 v6 v15
rename (v2 v3 v4 v5 v6 v15) (price date postcode property_type new_prop category)

keep if new_prop == "N" & category == "A"
drop new_prop category

split date, p(" ")
gen year = yofd(date(date1, "YMD"))
drop date date1 date2

keep if year <= 2019

*** Local authority
rename postcode pcds
merge m:1 pcds using "$restricted/Postcode_to_LAU.dta", gen(merge_local_auth)
keep if merge_local_auth == 3
drop merge_local_auth

rename laua lau117cd

*** Mean price and number of transactions by postcode x property type x year
collapse (mean) price (count) num=price, by(lau117cd pcds property_type year)

egen id = group(pcds property_type)
xtset id year

*** Drop cells above the 99th percentile of transactions
sum num, d
drop if num > `r(p99)'
drop num

*** Keep units observed in the base year and in each of the next four years
local pctiles "10 20 25 30 40 50 60 70 75 80 90"

forvalues y = 1/4 {
    gen f`y'_price = F`y'.price
}

keep if !missing(price, f1_price, f2_price, f3_price, f4_price)

*** Percentiles by local authority and base year, at the base year and at each horizon
local cstats ""
foreach p of local pctiles {
    local cstats `cstats' (p`p') p`p'=price f1_p`p'=f1_price f2_p`p'=f2_price f3_p`p'=f3_price f4_p`p'=f4_price
}

collapse `cstats' (count) num=price, by(lau117cd year)

*** Cumulative growth of each percentile at horizons 1-4 (%)
local j = 0
foreach p of local pctiles {
    local j = `j' + 1
    forvalues x = 1 / 4 {
        gen ch`x'p`j' = 100 * (f`x'_p`p' - p`p') / p`p'
    }
}

*** Winsorise at p1/p99 within base year
forvalues x = 1995 / 2015 {
    forvalues y = 1 / 4 {
        forvalues j = 1 / 11 {
            sum ch`y'p`j' if year == `x', d
            replace ch`y'p`j' = `r(p1)'  if ch`y'p`j' < `r(p1)' & year == `x'
            replace ch`y'p`j' = `r(p99)' if ch`y'p`j' > `r(p99)' & ch`y'p`j' != . & year == `x'
        }
    }
}

*** Flag: smallest basket at or above the median across local authorities (d_min1)
bysort lau117cd: egen min_num = min(num)
bysort lau117cd: gen e_lau = _n
sum min_num if e_lau == 1, d
gen d_min1 = (min_num >= `r(p50)')
drop e_lau

*** Long version: percentile 1=p10 2=p20 3=p25 4=p30 5=p40 6=p50 7=p60 8=p70 9=p75 10=p80 11=p90
egen id = group(lau117cd year)

keep year lau117cd id num min_num d_min1 ch*
reshape long ch1p ch2p ch3p ch4p, i(id) j(percentile)
drop id

save "$inter/DHPI_5Y_LP.dta", replace
