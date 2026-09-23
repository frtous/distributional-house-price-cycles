********************************************************************************
* mp_shocks.do
*
* Quarterly and annual sums of the monetary policy surprises and factors over
* MPC announcements, and the 2-year gilt surprise split into no-information
* and information meetings.
* Input:   data/restricted/measuring-monetary-policy-in-the-uk-the-ukmpesd.xlsx
* Outputs: data/derived/QuarterlyMPC.dta
*          data/derived/AnnualMPC.dta
*          data/derived/QuarterlyFactorsMPC.dta
*          data/derived/AnnualFactorsMPC.dta
*          data/derived/Quarterly_MPS_InfoSplit.dta
********************************************************************************

clear all
set more off

local xls "$restricted/measuring-monetary-policy-in-the-uk-the-ukmpesd.xlsx"
local surprises "FSScm2 GB2YTRR GB5YTRR GB10YTRR"


*==============================================================================*
* SURPRISES, MPC ANNOUNCEMENTS
*==============================================================================*

import excel "`xls'", sheet("surprises") firstrow clear
tostring isMPC, replace
keep if inlist(upper(isMPC), "1", "TRUE")
gen quarter = qofd(dofc(Datetime))
gen year    = yofd(dofc(Datetime))
format quarter %tq
keep quarter year `surprises' FFIc1
tempfile surp
save `surp'

*** Sums by quarter and by year; missing when a series has no observation
foreach t in quarter year {
    use `surp', clear
    local cnt ""
    foreach v of local surprises {
        local cnt "`cnt' n_`v'=`v'"
    }
    collapse (sum) `surprises' (count) `cnt', by(`t')
    foreach v of local surprises {
        replace `v' = . if n_`v' == 0
    }
    egen nobs = rowtotal(n_*)
    drop if nobs == 0
    drop n_* nobs
    if "`t'" == "quarter" save "$derived/QuarterlyMPC.dta", replace
    if "`t'" == "year"    save "$derived/AnnualMPC.dta", replace
}


*==============================================================================*
* FACTORS (TARGET, PATH, QE), MPC ANNOUNCEMENTS
*==============================================================================*

import excel "`xls'", sheet("factors") firstrow clear
tostring isMPC, replace
keep if inlist(upper(isMPC), "1", "TRUE")
gen quarter = qofd(dofc(Datetime))
gen year    = yofd(dofc(Datetime))
format quarter %tq

preserve
collapse (sum) Target Path QE, by(quarter)
save "$derived/QuarterlyFactorsMPC.dta", replace
restore

collapse (sum) Target Path QE, by(year)
save "$derived/AnnualFactorsMPC.dta", replace


*==============================================================================*
* 2-YEAR GILT SURPRISE: NO-INFORMATION VS. INFORMATION MEETINGS
*   no-information: the 2-year surprise and the FTSE 100 future (FFIc1) move in
*   opposite directions; information: same direction. A zero 2-year surprise
*   counts in both (it adds zero); a zero stock move with a non-zero surprise
*   in neither. A quarter with no meeting of a type is missing.
*==============================================================================*

use `surp', clear
drop if missing(GB2YTRR)

gen byte zero_rate  = abs(GB2YTRR) < 1e-6
gen byte zero_stock = abs(FFIc1)   < 1e-6
gen double prod     = GB2YTRR * FFIc1

gen byte noinfo = (prod < 0            & !zero_rate & !zero_stock) | zero_rate
gen byte info   = (prod > 0 & prod < . & !zero_rate & !zero_stock) | zero_rate

gen double GB2YTRR_noinfo = GB2YTRR if noinfo
gen double GB2YTRR_info   = GB2YTRR if info

collapse (sum) GB2YTRR_noinfo GB2YTRR_info ///
         (count) n_ni=GB2YTRR_noinfo n_in=GB2YTRR_info, by(quarter)
replace GB2YTRR_noinfo = . if n_ni == 0
replace GB2YTRR_info   = . if n_in == 0
drop n_ni n_in

save "$derived/Quarterly_MPS_InfoSplit.dta", replace
