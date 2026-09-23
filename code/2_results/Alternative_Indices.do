********************************************************************************
* Alternative_Indices.do
*
* Tiered repeat-unit and repeat-sales indices by price tertile: cross-market
* average growth, and regressions on lagged GDP growth, net lending and
* monetary policy surprises.
* Inputs:  data/intermediate/UnitRS_index_LAU_tier_quarterly.dta
*          data/intermediate/RS_index_LAU_tier_quarterly.dta
*          data/intermediate/SeriesQReady_LONG.dta
*          data/intermediate/gdp_quarterly.dta
*          data/intermediate/lending_quarterly.dta
*          data/derived/QuarterlyMPC.dta
* Outputs: output/figures/alt_indices.pdf/.png
*          output/tables/alt_indices_gdp_credit.tex
*          output/tables/alt_indices_mp.tex
********************************************************************************

clear all
set more off


*==============================================================================*
* DATA -- the two tiered panels, stacked
*==============================================================================*

*** Repeat-unit (design 1)
use "$inter/UnitRS_index_LAU_tier_quarterly.dta", clear
keep lau117cd quarter tier ur_g_w
rename ur_g_w g
gen byte design = 1
tempfile ur
save `ur'

*** Repeat-sales (design 2)
use "$inter/RS_index_LAU_tier_quarterly.dta", clear
keep lau117cd quarter tier rs_g_w
rename rs_g_w g
gen byte design = 2

append using `ur'
drop if missing(g)
keep if quarter <= tq(2019q4)

tempfile tiers
save `tiers'


********************************************************************************
* AVERAGE GROWTH BY TERTILE, 1996q1-2019q4
*   Simple averages over all local areas with the index
********************************************************************************

keep if quarter >= tq(1996q1)
collapse (mean) g, by(design tier quarter)
reshape wide g, i(design quarter) j(tier)
format quarter %tq

foreach d in 1 2 {
    if `d' == 1 local tit "Repeat-unit (postcode-type cells)"
    if `d' == 2 local tit "Repeat-sales (same address)"
    twoway ///
        (line g1 quarter if design == `d', lcolor(navy)  lpattern(dash)  lwidth(medthick)) ///
        (line g2 quarter if design == `d', lcolor(black) lpattern(solid) lwidth(medthick)) ///
        (line g3 quarter if design == `d', lcolor(red)   lpattern(dash)  lwidth(medthick)) ///
        , ylabel(-15(5)30, labsize(small)) yline(0, lcolor(gs12)) ///
          ytitle("") xtitle("") title("`tit'", size(small) color(black)) ///
          graphregion(color(white)) plotregion(color(white)) ///
          legend(order(1 "Bottom tertile" 2 "Middle" 3 "Top tertile") cols(3) size(small) position(6)) ///
          name(d`d', replace) nodraw
}

graph combine d1 d2, cols(2) imargin(small) ycommon graphregion(color(white))
graph export "$figures/alt_indices.pdf", as(pdf) replace
graph export "$figures/alt_indices.png", replace width(2000)


*==============================================================================*
* REGRESSION SAMPLE AND DRIVERS
*==============================================================================*

*** Drivers: lagged four quarters, 1998q2-2019q4
use "$derived/QuarterlyMPC.dta", clear
merge 1:1 quarter using "$inter/lending_quarterly.dta", keep(match) nogen keepusing(net_secured)
merge 1:1 quarter using "$inter/gdp_quarterly.dta",     keep(match) nogen keepusing(gdp_growth)
tsset quarter
gen double l_gdp    = L4.gdp_growth
gen double l_nl     = L4.net_secured
gen double l_FSScm2 = L4.FSScm2
gen double l_GB2Y   = L4.GB2YTRR
keep if inrange(quarter, tq(1998q2), tq(2019q4))
keep quarter l_gdp l_nl l_FSScm2 l_GB2Y
tempfile drivers
save `drivers'

*** Local areas in the DHPI baseline sample (d_min1)
use lau117cd d_min1 using "$inter/SeriesQReady_LONG.dta", clear
keep if d_min1 == 1
duplicates drop lau117cd, force
tempfile dmin
save `dmin'

use `tiers', clear
merge m:1 lau117cd using `dmin', keep(master match) nogen
merge m:1 quarter using `drivers', keep(match) nogen

egen lau = group(lau117cd)

*** Standardise each driver by its standard deviation across quarters
egen qtag = tag(quarter)
foreach v in l_gdp l_nl l_FSScm2 l_GB2Y {
    quietly sum `v' if qtag
    gen double z_`v' = `v' / r(sd)
}
rename (z_l_gdp z_l_nl z_l_FSScm2 z_l_GB2Y) (gdp nl FSScm2 GB2YTRR)

*** One common sample per table
gen byte insamp  = d_min1 == 1 & !missing(gdp, nl)
gen byte insampM = d_min1 == 1 & !missing(FSScm2, GB2YTRR)

*** ib3.tier#c.gdp = GDP growth interacted with the Bottom and Middle dummies,
*** Top (3) omitted
local fe "absorb(lau#quarter tier#lau) vce(cluster quarter)"

*** cell: coefficient (with stars, t test on e(df_r)) and standard error of one
*** term of a stored model, formatted for the table; blank if not in the model
capture program drop cell
program define cell, rclass
    args model term
    quietly estimates restore `model'
    capture local b = _b[`term']
    if _rc {
        return local c ""
        return local s ""
        exit
    }
    local se = _se[`term']
    local pv = 2 * ttail(e(df_r), abs(`b' / `se'))
    local st = cond(`pv' < 0.01, "***", cond(`pv' < 0.05, "**", cond(`pv' < 0.10, "*", "")))
    return local c = string(`b', "%9.3f") + "`st'"
    return local s = "(" + string(`se', "%9.3f") + ")"
end


********************************************************************************
* GDP GROWTH VS. NET LENDING -- three columns per design
*   (1)-(3) repeat-unit: GDP only | net lending only | both
*   (4)-(6) repeat-sales: the same
********************************************************************************

foreach d in 1 2 {
    local if "if design == `d' & insamp"
    reghdfe g ib3.tier#c.gdp                   `if', `fe'
    estimates store g`d'
    reghdfe g ib3.tier#c.nl                    `if', `fe'
    estimates store n`d'
    reghdfe g ib3.tier#c.gdp ib3.tier#c.nl     `if', `fe'
    estimates store b`d'
}
estimates table g1 n1 b1 g2 n2 b2, b(%9.3f) se(%9.3f) stats(N r2) drop(_cons)

local models "g1 n1 b1 g2 n2 b2"

file open T using "$tables/alt_indices_gdp_credit.tex", write replace text
file write T "\begin{tabular}{lcccccc} \hline" _n
file write T " & (1) & (2) & (3) & (4) & (5) & (6) \\" _n
file write T "VARIABLES & GDP only & Net lending & GDP + net lending & GDP only & Net lending & GDP + net lending \\ \hline" _n
file write T " &  &  &  &  &  &  \\" _n
foreach v in gdp nl {
    if "`v'" == "gdp" local vlab "GDP growth"
    if "`v'" == "nl"  local vlab "Net lending"
    foreach t in 1 2 {
        local tlab : label tierlbl `t'
        local row  ""
        local srow ""
        foreach m of local models {
            cell `m' `t'.tier#c.`v'
            local row  "`row' & `r(c)'"
            local srow "`srow' & `r(s)'"
        }
        file write T "`vlab' x `tlab'`row' \\" _n
        file write T "`srow' \\" _n
    }
}
local nrow ""
local rrow ""
foreach m of local models {
    quietly estimates restore `m'
    local nrow = "`nrow' & " + string(e(N), "%15.0fc")
    local rrow = "`rrow' & " + string(e(r2), "%9.3f")
}
file write T " &  &  &  &  &  &  \\" _n
file write T "Observations`nrow' \\" _n
file write T "R-squared`rrow' \\" _n
file write T " Index & Repeat-unit & Repeat-unit & Repeat-unit & Repeat-sales & Repeat-sales & Repeat-sales \\ \hline" _n
file write T "\end{tabular}" _n
file close T


********************************************************************************
* MONETARY POLICY SURPRISES -- two columns per design
*   (1)-(2) repeat-unit: six-month | 2-year gilt
*   (3)-(4) repeat-sales: the same
*   Each shock is copied into m, so all four share coefficient names.
********************************************************************************

gen double m = .
foreach d in 1 2 {
    foreach s in FSScm2 GB2YTRR {
        quietly replace m = `s'
        reghdfe g ib3.tier#c.m if design == `d' & insampM, `fe'
        estimates store `s'`d'
    }
}
estimates table FSScm21 GB2YTRR1 FSScm22 GB2YTRR2, b(%9.3f) se(%9.3f) stats(N r2) drop(_cons)

local models "FSScm21 GB2YTRR1 FSScm22 GB2YTRR2"

file open T using "$tables/alt_indices_mp.tex", write replace text
file write T "\begin{tabular}{lcccc} \hline" _n
file write T " & (1) & (2) & (3) & (4) \\" _n
file write T "VARIABLES & Six-month & 2-year gilt & Six-month & 2-year gilt \\ \hline" _n
file write T " &  &  &  &  \\" _n
foreach t in 1 2 {
    local tlab : label tierlbl `t'
    local row  ""
    local srow ""
    foreach m of local models {
        cell `m' `t'.tier#c.m
        local row  "`row' & `r(c)'"
        local srow "`srow' & `r(s)'"
    }
    file write T "MPS x `tlab'`row' \\" _n
    file write T "`srow' \\" _n
}
local nrow ""
local rrow ""
foreach m of local models {
    quietly estimates restore `m'
    local nrow = "`nrow' & " + string(e(N), "%15.0fc")
    local rrow = "`rrow' & " + string(e(r2), "%9.3f")
}
file write T " &  &  &  &  \\" _n
file write T "Observations`nrow' \\" _n
file write T "R-squared`rrow' \\" _n
file write T " Index & Repeat-unit & Repeat-unit & Repeat-sales & Repeat-sales \\ \hline" _n
file write T "\end{tabular}" _n
file close T
