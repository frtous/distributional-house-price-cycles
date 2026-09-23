********************************************************************************
* AltIndex_RepeatUnit.do
*
* Builds tiered repeat-unit house price indices (repeat observations of the same
* postcode x property-type unit, three price tiers per local authority) and
* their y/y growth.
* Inputs:  data/restricted/pp-complete.csv
*          data/restricted/Postcode_to_LAU.dta
* Output:  data/intermediate/UnitRS_index_LAU_tier_quarterly.dta
********************************************************************************

clear all
set more off

local minpairs = 500    // minimum number of pairs per local authority x tier

*** wrs3: three-stage weighted repeat-sales index for one local authority x tier
*** (base quarter = 0). Arguments: postfile handle, local authority, tier, minimum
*** pairs, first and last quarter posted, fallback (1 = Stage 1 if Stage 3 fails).
capture program drop wrs3
program define wrs3
    args post lau k minpairs Qmin Qmax fallback

    local np = _N
    local ok = 0
    if `np' >= `minpairs' {
        summarize first_quarter, meanonly
        local lmin = r(min)
        summarize resale_quarter, meanonly
        local lmax = r(max)
        local dv ""
        forvalues t = `=`lmin' + 1'/`lmax' {
            gen byte D`t' = (resale_quarter == `t') - (first_quarter == `t')
            local dv "`dv' D`t'"
        }
        gen double gap2 = gap_quarters^2

        *** Stage 1: OLS on the time dummies
        capture regress dlog `dv', noconstant
        if !_rc {
            local ok = 1
            predict double e2, residuals
            replace e2 = e2^2

            *** Stage 2: squared residuals on the gap and its square
            local w ""
            capture regress e2 gap_quarters gap2
            if !_rc {
                predict double varhat, xb
                summarize varhat if varhat > 0, meanonly
                if r(N) > 0 {
                    replace varhat = r(min) if varhat <= 0 | missing(varhat)
                    local w "[aweight = 1/varhat]"
                }
            }

            *** Stage 3: Stage 1 weighted by the inverse fitted variance
            capture regress dlog `dv' `w', noconstant
            if _rc {
                local ok = 0
                if `fallback' == 1 {
                    capture regress dlog `dv', noconstant
                    if !_rc local ok = 1
                }
            }
        }
    }

    forvalues t = `Qmin'/`Qmax' {
        local b = .
        if `ok' == 1 {
            if `t' == `lmin' {
                local b = 0
            }
            else if inrange(`t', `lmin', `lmax') {
                if _se[D`t'] != 0 & !missing(_se[D`t']) local b = _b[D`t']
            }
        }
        post `post' ("`lau'") (`k') (`t') (`b') (`np')
    }
end


*==============================================================================*
* 0. UNIT x QUARTER PRICES (as for the quarterly DHPIs)
*==============================================================================*

import delimited "$restricted/pp-complete.csv", clear
keep v2 v3 v4 v5 v6 v15
rename (v2 v3 v4 v5 v6 v15) (price date pcds property_type new_prop category)

split date, p(" ")
gen date_n = date(date1, "YMD")
gen year = yofd(date_n)
gen quarter = qofd(date_n)
format quarter %tq

keep if year <= 2019
keep if category == "A"
keep if new_prop == "N"

merge m:1 pcds using "$restricted/Postcode_to_LAU.dta", keep(match) nogen keepusing(laua)
rename laua lau117cd

collapse (mean) price (count) num=price, by(lau117cd pcds new_prop property_type year quarter)
sum num, d
keep if num <= `r(p99)'
drop num

egen id = group(pcds property_type)


*==============================================================================*
* 1. PAIRS AND TIERS
*==============================================================================*

keep id lau117cd quarter price
drop if missing(price) | price <= 0

*** Consecutive observations of the same unit
sort id quarter
by id: gen double firstlogp     = log(price[_n-1])
by id: gen double dlog          = log(price) - firstlogp
by id: gen int    first_quarter = quarter[_n-1]
gen int resale_quarter = quarter
gen int gap_quarters   = resale_quarter - first_quarter
keep if !missing(dlog)

*** Tiers: tertiles of the first-leg price within local authority x first quarter
bysort lau117cd first_quarter: egen double p33 = pctile(firstlogp), p(33)
bysort lau117cd first_quarter: egen double p67 = pctile(firstlogp), p(67)
gen byte tier = 1 + (firstlogp > p33) + (firstlogp > p67)

keep lau117cd tier first_quarter resale_quarter gap_quarters dlog
sort lau117cd
compress
tempfile pairs
save "`pairs'"


*==============================================================================*
* 2. ONE INDEX PER LOCAL AUTHORITY x TIER
*==============================================================================*

*** Row range of each local authority in the pairs file
summarize first_quarter, meanonly
local Qmin = r(min)
summarize resale_quarter, meanonly
local Qmax = r(max)

keep lau117cd
gen long row = _n
collapse (min) lo = row (max) hi = row, by(lau117cd)
local nlau = _N
forvalues i = 1/`nlau' {
    local la`i' = lau117cd[`i']
    local lo`i' = lo[`i']
    local hi`i' = hi[`i']
}

tempname P
tempfile idx
postfile `P' str9 lau117cd byte tier int quarter double beta long npairs ///
    using "`idx'", replace

quietly forvalues i = 1/`nlau' {
    if mod(`i', 25) == 0 noisily di "  local area `i' of `nlau'"
    use in `lo`i''/`hi`i'' using "`pairs'", clear
    forvalues k = 1/3 {
        preserve
        keep if tier == `k'
        wrs3 `P' `la`i'' `k' `minpairs' `Qmin' `Qmax' 1
        restore
    }
}
postclose `P'


*==============================================================================*
* 3. GROWTH
*==============================================================================*

use "`idx'", clear
format quarter %tq
egen panel = group(lau117cd tier)
xtset panel quarter

*** y/y growth in percent, 1996q1-2019q4
gen double ur_g = 100 * (exp(beta - L4.beta) - 1)
keep if inrange(quarter, tq(1996q1), tq(2019q4))

*** Winsorise at p1/p99 within quarter x tier
bysort quarter tier: egen double p1  = pctile(ur_g), p(1)
bysort quarter tier: egen double p99 = pctile(ur_g), p(99)
gen double ur_g_w = ur_g
replace ur_g_w = p1  if ur_g_w < p1
replace ur_g_w = p99 if ur_g_w > p99 & !missing(ur_g_w)

keep lau117cd tier quarter npairs ur_g_w
label define tierlbl 1 "Bottom" 2 "Middle" 3 "Top"
label values tier tierlbl
compress
save "$inter/UnitRS_index_LAU_tier_quarterly.dta", replace
