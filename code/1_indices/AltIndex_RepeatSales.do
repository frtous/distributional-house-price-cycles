********************************************************************************
* AltIndex_RepeatSales.do
*
* Builds tiered repeat-sales house price indices (repeat sales of the same
* address, three price tiers per local authority) and their y/y growth.
* Inputs:  data/restricted/pp-complete.csv
*          data/restricted/Postcode_to_LAU.dta
* Output:  data/intermediate/RS_index_LAU_tier_quarterly.dta
********************************************************************************

clear all
set more off

local minpairs = 200    // minimum number of pairs per local authority x tier

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
* 1. SALES
*==============================================================================*

*** Price Paid Data: category A, current records, no 'other' property type, up to 2019
import delimited "$restricted/pp-complete.csv", stringcols(4 8 9 10) clear
keep v2 v3 v4 v5 v6 v8 v9 v10 v15 v16
rename (v2 v3 v4 v5 v6 v8 v9 v10 v15 v16) ///
       (price date pcds ptype oldnew paon saon street ppdcat status)

keep if ppdcat == "A" & status == "A"
drop if ptype == "O"
drop if missing(price) | price <= 0

gen double td = date(substr(date, 1, 10), "YMD")
drop if missing(td)
gen int year = year(td)
keep if year <= 2019

*** Local authority
merge m:1 pcds using "$restricted/Postcode_to_LAU.dta", keep(match) nogen keepusing(laua)
rename laua lau117cd

*** Property identifier: postcode, PAON, SAON and street
foreach v of varlist pcds paon saon street {
    replace `v' = upper(stritrim(strtrim(`v')))
}
gen straddr = pcds + "~" + paon + "~" + saon + "~" + street
egen propid = group(straddr)
drop straddr
bysort propid: gen long n_tx = _N


*==============================================================================*
* 2. PAIRS AND TIERS
*==============================================================================*

*** Consecutive sales of the same property
sort propid td, stable
by propid: gen double dlog       = log(price) - log(price[_n-1])
by propid: gen double firsttd    = td[_n-1]
by propid: gen double firstprice = price[_n-1]
by propid: gen int    firstyear  = year[_n-1]
by propid: gen byte   firstnew   = oldnew[_n-1] == "Y"
by propid: gen        firstptype = ptype[_n-1]
keep if !missing(dlog)

*** Pair filters
gen double gap_days = td - firsttd
drop if gap_days < 365                                  // less than a year apart
drop if year == firstyear                               // same calendar year
drop if firstnew == 1                                   // first sale a new build
drop if abs(dlog / (gap_days / 365.25)) > 1             // annualised log change above 1
drop if ptype != firstptype & (ptype == "F" | firstptype == "F")   // flat <-> house
drop if n_tx > 10                                       // more than 10 sales

*** At least four quarters apart
gen int first_quarter  = qofd(firsttd)
gen int resale_quarter = qofd(td)
gen int gap_quarters   = resale_quarter - first_quarter
drop if gap_quarters < 4

*** Tiers: tertiles of the first-sale price within local authority x first quarter
gen double firstlogp = log(firstprice)
bysort lau117cd first_quarter: egen double p33 = pctile(firstlogp), p(33)
bysort lau117cd first_quarter: egen double p67 = pctile(firstlogp), p(67)
gen byte tier = 1 + (firstlogp > p33) + (firstlogp > p67)

keep lau117cd tier first_quarter resale_quarter gap_quarters dlog
sort lau117cd
compress
tempfile pairs
save "`pairs'"


*==============================================================================*
* 3. ONE INDEX PER LOCAL AUTHORITY x TIER
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
        wrs3 `P' `la`i'' `k' `minpairs' `Qmin' `Qmax' 0
        restore
    }
}
postclose `P'


*==============================================================================*
* 4. GROWTH
*==============================================================================*

use "`idx'", clear
format quarter %tq
egen panel = group(lau117cd tier)
xtset panel quarter

*** y/y growth in percent, 1996q1-2019q4
gen double rs_g = 100 * (exp(beta - L4.beta) - 1)
keep if inrange(quarter, tq(1996q1), tq(2019q4))

*** Winsorise at p1/p99 within quarter x tier
bysort quarter tier: egen double p1  = pctile(rs_g), p(1)
bysort quarter tier: egen double p99 = pctile(rs_g), p(99)
gen double rs_g_w = rs_g
replace rs_g_w = p1  if rs_g_w < p1
replace rs_g_w = p99 if rs_g_w > p99 & !missing(rs_g_w)

keep lau117cd tier quarter npairs rs_g_w
label define tierlbl 1 "Bottom" 2 "Middle" 3 "Top"
label values tier tierlbl
compress
save "$inter/RS_index_LAU_tier_quarterly.dta", replace
