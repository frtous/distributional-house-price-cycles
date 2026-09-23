********************************************************************************
* Business_Credit_Cycles.do
*
* Regressions of DHPI growth on lagged GDP growth and credit, by percentile set:
* table of estimates and coefficient plots.
* Inputs:  data/intermediate/SeriesQReady_LONG.dta
*          data/intermediate/gdp_quarterly.dta
*          data/intermediate/lending_quarterly.dta
* Outputs: output/tables/gdp_credit_p20_p80.tex
*          output/figures/gdp_credit_p*_A/B/C.pdf/.png
*          output/figures/credit_measures_p20_p80.pdf/.png
********************************************************************************

clear all
set more off

*** Drivers: lagged four quarters, standardised by their sd over 1998q2-2019q4
use quarter gdp_growth using "$inter/gdp_quarterly.dta", clear
merge 1:1 quarter using "$inter/lending_quarterly.dta", nogen ///
    keepusing(net_secured approvals_hp l1_mortgage_debt mortgage_debt_g consumer_credit_g)
gen nl_stock = 100 * 12 * net_secured / l1_mortgage_debt
tsset quarter

local vlist gdp_growth net_secured nl_stock mortgage_debt_g approvals_hp consumer_credit_g
foreach v of local vlist {
    gen double l4_`v' = L4.`v'
}
keep if inrange(quarter, tq(1998q2), tq(2019q4))
foreach v of local vlist {
    quietly sum l4_`v'
    gen double z_`v' = l4_`v' / r(sd)
}
rename (z_gdp_growth z_net_secured) (gdp nl)
keep quarter gdp nl z_nl_stock z_mortgage_debt_g z_approvals_hp z_consumer_credit_g
tempfile drv
save `drv'

*** DHPI panel
use "$inter/SeriesQReady_LONG.dta", clear
merge m:1 quarter using `drv', keep(match) nogen

label define pct 1 "p10" 2 "p20" 3 "p25" 4 "p30" 5 "p40" 6 "p50" ///
                 7 "p60" 8 "p70" 9 "p75" 10 "p80" 11 "p90"
label values percentile pct

egen lau = group(lau117cd)
local fe "absorb(lau#quarter percentile#lau) vce(cluster quarter)"

*** panels3: plots GDP alone, net lending alone and both, from the stored
*** estimates gdp_only, nl_only and both (ref = omitted percentile,
*** pcts = percentiles shown, fname = file name stem)
capture program drop panels3
program define panels3
    args ref pcts fname

    local reflab : label pct `ref'

    local rG ""
    local rN ""
    foreach k of local pcts {
        local lab : label pct `k'
        local rG "`rG' `k'.percentile#c.gdp = `lab'"
        local rN "`rN' `k'.percentile#c.nl = `lab'"
    }

    *** Common vertical scale: all 90% intervals and zero
    local ymin 0
    local ymax 0
    foreach m in gdp_only nl_only both {
        quietly estimates restore `m'
        local t = invttail(e(df_r), .05)
        local cn : colnames e(b)
        foreach c of local cn {
            if "`c'" == "_cons" continue
            local ymin = min(`ymin', _b[`c'] - `t' * _se[`c'])
            local ymax = max(`ymax', _b[`c'] + `t' * _se[`c'])
        }
    }
    local ylo = 0.5 * ceil(`ymin' / 0.5) + 0
    local yhi = 0.5 * ceil(`ymax' / 0.5)

    local opts vertical level(90) yline(0, lcolor(gs8) lpattern(dash))       ///
        yscale(range(`ymin' `yhi')) ylabel(`ylo'(0.5)`yhi')                  ///
        xtitle("Percentile (`reflab' omitted, ref.)")                        ///
        ytitle("Coefficient per 1 SD (90% CI)")                              ///
        graphregion(color(white)) plotregion(color(white))                   ///
        xsize(3.2) ysize(3.4) scale(1.4)

    local cG "0 114 178"
    local cN "213 94 0"

    coefplot (gdp_only, keep(*.percentile#c.gdp) rename(`rG') msymbol(O) mcolor("`cG'") ciopts(lcolor("`cG'"))), ///
        `opts' legend(off) name(A, replace)

    coefplot (nl_only, keep(*.percentile#c.nl) rename(`rN') msymbol(D) mcolor("`cN'") ciopts(lcolor("`cN'"))), ///
        `opts' legend(off) name(B, replace)

    coefplot (both, keep(*.percentile#c.gdp) rename(`rG') msymbol(Oh) mcolor("`cG'") ciopts(lcolor("`cG'")) label("GDP growth")) ///
             (both, keep(*.percentile#c.nl)  rename(`rN') msymbol(Dh) mcolor("`cN'") ciopts(lcolor("`cN'")) label("Net lending")), ///
        `opts' legend(ring(0) position(1) cols(1) size(small) region(fcolor(white) lcolor(gs13))) name(C, replace)

    foreach P in A B C {
        graph export "$figures/`fname'_`P'.pdf", name(`P') as(pdf) replace
        graph export "$figures/`fname'_`P'.png", name(`P') replace width(1200)
    }
end


*==============================================================================*
* P20-P80 SET (P80 OMITTED)
*==============================================================================*

local if "if d_min1 == 1 & inlist(percentile, 2, 5, 7, 10)"

reghdfe ch ib10.percentile#c.gdp                      `if', `fe'
estimates store gdp_only
reghdfe ch ib10.percentile#c.nl                       `if', `fe'
estimates store nl_only
reghdfe ch ib10.percentile#c.gdp ib10.percentile#c.nl `if', `fe'
estimates store both

*** Table of the three regressions
file open T using "$tables/gdp_credit_p20_p80.tex", write replace text
file write T "\begin{tabular}{lccc} \hline" _n
file write T " & (1) & (2) & (3) \\" _n
file write T "VARIABLES & GDP only & Net lending & GDP + net lending \\ \hline" _n
file write T " &  &  &  \\" _n
foreach v in gdp nl {
    if "`v'" == "gdp" local vlab "GDP growth"
    if "`v'" == "nl"  local vlab "Net lending"
    foreach k in 2 5 7 {
        local lab : label pct `k'
        local P = upper("`lab'")
        local row  ""
        local srow ""
        foreach m in gdp_only nl_only both {
            quietly estimates restore `m'
            capture local b = _b[`k'.percentile#c.`v']
            if _rc {
                local row  "`row' & "
                local srow "`srow' & "
                continue
            }
            local se = _se[`k'.percentile#c.`v']
            local pv = 2 * ttail(e(df_r), abs(`b' / `se'))
            local st = cond(`pv' < 0.01, "***", cond(`pv' < 0.05, "**", cond(`pv' < 0.10, "*", "")))
            local row  = "`row' & " + string(`b', "%9.3f") + "`st'"
            local srow = "`srow' & (" + string(`se', "%9.3f") + ")"
        }
        file write T "`vlab' x `P'`row' \\" _n
        file write T "`srow' \\" _n
    }
}
local nrow ""
local rrow ""
foreach m in gdp_only nl_only both {
    quietly estimates restore `m'
    local nrow = "`nrow' & " + string(e(N), "%15.0fc")
    local rrow = "`rrow' & " + string(e(r2), "%9.3f")
}
file write T " &  &  &  \\" _n
file write T "Observations`nrow' \\" _n
file write T "R-squared`rrow' \\ \hline" _n
file write T "\end{tabular}" _n
file close T

*** Coefficient plots
panels3 10 "2 5 7" gdp_credit_p20_p80

*** Five credit measures, one at a time
gen double m = .
local k = 0
foreach v in nl z_nl_stock z_mortgage_debt_g z_approvals_hp z_consumer_credit_g {
    local ++k
    quietly replace m = `v'
    reghdfe ch ib10.percentile#c.m `if', `fe'
    estimates store cd`k'
}

coefplot ///
    (cd1, label("Net secured lending (`=uchar(163)'m)")  msymbol(D)  mcolor("213 94 0")    ciopts(lcolor("213 94 0")))   ///
    (cd2, label("Net secured lending (% of stock)") msymbol(Dh) mcolor("230 159 0")   ciopts(lcolor("230 159 0")))  ///
    (cd3, label("Mortgage debt growth (% y/y)")     msymbol(O)  mcolor("0 158 115")   ciopts(lcolor("0 158 115")))  ///
    (cd4, label("Approvals, house purchase (no.)")  msymbol(T)  mcolor("86 180 233")  ciopts(lcolor("86 180 233"))) ///
    (cd5, label("Consumer credit growth (% y/y)")   msymbol(Th) mcolor("204 121 167") ciopts(lcolor("204 121 167"))), ///
    keep(2.percentile#c.m 5.percentile#c.m 7.percentile#c.m) ///
    rename(2.percentile#c.m = P20 5.percentile#c.m = P40 7.percentile#c.m = P60) ///
    vertical level(90) yline(0, lcolor(gs8) lpattern(dash)) ///
    xtitle("Percentile (P80 omitted, ref.)") ytitle("Coefficient per 1 SD (90% CI)") ///
    graphregion(color(white)) plotregion(color(white)) ///
    legend(position(6) rows(2) size(vsmall) region(lstyle(none)))

graph export "$figures/credit_measures_p20_p80.pdf", as(pdf) replace
graph export "$figures/credit_measures_p20_p80.png", replace width(2200) height(1400)


*==============================================================================*
* P25-P75 SET (P75 OMITTED)
*==============================================================================*

local if "if d_min1 == 1 & inlist(percentile, 3, 6, 9)"

reghdfe ch ib9.percentile#c.gdp                     `if', `fe'
estimates store gdp_only
reghdfe ch ib9.percentile#c.nl                      `if', `fe'
estimates store nl_only
reghdfe ch ib9.percentile#c.gdp ib9.percentile#c.nl `if', `fe'
estimates store both

panels3 9 "3 6" gdp_credit_p25_p75


*==============================================================================*
* P10-P90 SET (P90 OMITTED), STRICTER SAMPLE
*==============================================================================*

local if "if d_min2 == 1 & inlist(percentile, 1, 2, 4, 5, 6, 7, 8, 10, 11)"

reghdfe ch ib11.percentile#c.gdp                      `if', `fe'
estimates store gdp_only
reghdfe ch ib11.percentile#c.nl                       `if', `fe'
estimates store nl_only
reghdfe ch ib11.percentile#c.gdp ib11.percentile#c.nl `if', `fe'
estimates store both

panels3 11 "1 2 4 5 6 7 8 10" gdp_credit_p10_p90
