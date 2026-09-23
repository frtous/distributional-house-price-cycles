********************************************************************************
* Price_of_Credit.do
*
* Regressions of DHPI growth on lagged changes in interest rates, alone and with
* net secured lending, by percentile set: coefficient plots and a table.
* Inputs:  data/intermediate/SeriesQReady_LONG.dta
*          data/intermediate/rates_quarterly.dta
*          data/intermediate/lending_quarterly.dta
* Outputs: output/figures/rates_p*.pdf/.png
*          output/tables/rates_p20_p80.tex
********************************************************************************

clear all
set more off

*** Drivers: four-quarter changes in the rates, and net secured lending, lagged
*** four quarters, standardised by their sd over 1998q2-2019q4
use quarter bankrate_avg gilt10_avg fix2y75_avg using "$inter/rates_quarterly.dta", clear
merge 1:1 quarter using "$inter/lending_quarterly.dta", nogen keepusing(net_secured)
tsset quarter
gen double d4_bank = bankrate_avg - L4.bankrate_avg
gen double d4_gilt = gilt10_avg   - L4.gilt10_avg
gen double d4_mort = fix2y75_avg  - L4.fix2y75_avg

local vlist net_secured d4_bank d4_gilt d4_mort
foreach v of local vlist {
    gen double l4_`v' = L4.`v'
}
keep if inrange(quarter, tq(1998q2), tq(2019q4))
foreach v of local vlist {
    quietly sum l4_`v'
    gen double z_`v' = l4_`v' / r(sd)
}
rename (z_net_secured z_d4_bank z_d4_gilt z_d4_mort) (nl bank gilt mort)
keep quarter nl bank gilt mort
tempfile drv
save `drv'

*** DHPI panel
use "$inter/SeriesQReady_LONG.dta", clear
merge m:1 quarter using `drv', keep(match) nogen

label define pct 1 "p10" 2 "p20" 3 "p25" 4 "p30" 5 "p40" 6 "p50" ///
                 7 "p60" 8 "p70" 9 "p75" 10 "p80" 11 "p90"
label values percentile pct

egen lau = group(lau117cd)

*** rates3: for one set, each rate alone and with net lending, and the
*** three-panel figure (ref = omitted percentile, pcts = percentiles shown,
*** smp = sample flag, fname = file name, cols xs ys = panel layout and size,
*** lrows = legend rows, default 2). Stores bank_alone, bank_nl, ...
capture program drop rates3
program define rates3
    args ref pcts smp fname cols xs ys lrows
    if "`lrows'" == "" local lrows 2

    local inl : subinstr local pcts " " ", ", all
    local if "if `smp' == 1 & inlist(percentile, `inl', `ref')"
    local fe "absorb(lau#quarter percentile#lau) vce(cluster quarter)"
    local reflab : label pct `ref'

    foreach r in bank gilt mort {
        quietly reghdfe ch ib`ref'.percentile#c.`r'                          `if', `fe'
        estimates store `r'_alone
        quietly reghdfe ch ib`ref'.percentile#c.`r' ib`ref'.percentile#c.nl `if', `fe'
        estimates store `r'_nl

        *** coefficients to plot, renamed to their percentile (p20, p40, ...)
        local k_`r'  ""
        local rn_`r' ""
        foreach k of local pcts {
            local lab : label pct `k'
            local k_`r'  "`k_`r'' `k'.percentile#c.`r'"
            local rn_`r' "`rn_`r'' `k'.percentile#c.`r' = `lab'"
        }
    }
    estimates table bank_alone bank_nl gilt_alone gilt_nl mort_alone mort_nl, ///
        b(%9.3f) se(%9.3f) stats(N r2) drop(_cons)

    local opts vertical level(90) yline(0, lcolor(gs8) lpattern(dash))       ///
        xtitle("Percentile (`reflab' omitted, ref.)", size(small))           ///
        ytitle("Coefficient per 1 SD of the rate (90% CI)", size(small))     ///
        graphregion(color(white)) plotregion(color(white))                   ///
        legend(position(6) rows(`lrows') size(vsmall)) nodraw

    *** Colours
    local cB "0 158 115"
    local cG "86 180 233"
    local cM "230 159 0"

    *** A -- Bank Rate
    coefplot ///
        (bank_alone, keep(`k_bank') rename(`rn_bank') label("Bank Rate change (alone)")                          msymbol(O)  mcolor("`cB'") ciopts(lcolor("`cB'"))) ///
        (bank_nl,    keep(`k_bank') rename(`rn_bank') label("Bank Rate change (controlling for net lending)")     msymbol(Oh) mcolor("`cB'") ciopts(lcolor("`cB'"))), ///
        `opts' title("A. Bank Rate", size(medium) color(black)) name(PANB, replace)

    *** B -- 10-year gilt
    coefplot ///
        (gilt_alone, keep(`k_gilt') rename(`rn_gilt') label("10y gilt change (alone)")                           msymbol(T)  mcolor("`cG'") ciopts(lcolor("`cG'"))) ///
        (gilt_nl,    keep(`k_gilt') rename(`rn_gilt') label("10y gilt change (controlling for net lending)")      msymbol(Th) mcolor("`cG'") ciopts(lcolor("`cG'"))), ///
        `opts' title("B. 10-year gilt", size(medium) color(black)) name(PANT, replace)

    *** C -- quoted mortgage rate
    coefplot ///
        (mort_alone, keep(`k_mort') rename(`rn_mort') label("Mortgage rate change (alone)")                      msymbol(S)  mcolor("`cM'") ciopts(lcolor("`cM'"))) ///
        (mort_nl,    keep(`k_mort') rename(`rn_mort') label("Mortgage rate change (controlling for net lending)") msymbol(Sh) mcolor("`cM'") ciopts(lcolor("`cM'"))), ///
        `opts' title("C. Quoted mortgage rate", size(medium) color(black)) name(PANM, replace)

    graph combine PANB PANT PANM, cols(`cols') ycommon ///
        graphregion(color(white)) plotregion(color(white)) ///
        xsize(`xs') ysize(`ys') name(COMB, replace)

    graph export "$figures/`fname'.pdf", name(COMB) as(pdf) replace
    graph export "$figures/`fname'.png", name(COMB) replace width(2400)
    graph drop PANB PANT PANM COMB
end


*==============================================================================*
* P20-P80 SET (P80 OMITTED)
*==============================================================================*

rates3 10 "2 5 7" d_min1 rates_p20_p80 3 12 4.8

*** Table of the six regressions
local cols "bank_alone bank_nl gilt_alone gilt_nl mort_alone mort_nl"

*** p-values of the joint test that a driver's percentile interactions are zero
local i = 0
foreach m of local cols {
    local ++i
    quietly estimates restore `m'
    foreach v in bank gilt mort nl {
        local p_`v'_`i' ""
        capture test 2.percentile#c.`v' 5.percentile#c.`v' 7.percentile#c.`v'
        if !_rc local p_`v'_`i' = string(r(p), "%6.4f")
    }
}

file open T using "$tables/rates_p20_p80.tex", write replace text
file write T "\begin{tabular}{lcccccc} \hline" _n
file write T " & \multicolumn{2}{c}{Bank Rate} & \multicolumn{2}{c}{10y gilt} & \multicolumn{2}{c}{Mortgage rate} \\" _n
file write T "\cline{2-3} \cline{4-5} \cline{6-7}" _n
file write T " & (1) & (2) & (3) & (4) & (5) & (6) \\ \hline" _n
file write T " &  &  &  &  &  &  \\" _n

foreach v in bank gilt mort nl {
    if "`v'" == "bank" local vlab "Bank Rate change"
    if "`v'" == "gilt" local vlab "10y gilt change"
    if "`v'" == "mort" local vlab "Quoted mortgage rate"
    if "`v'" == "nl"   local vlab "Net secured lending"
    foreach k in 2 5 7 {
        local lab : label pct `k'
        local P = upper("`lab'")
        local row  ""
        local srow ""
        foreach m of local cols {
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

*** Observations, R-squared and the p-values
local nrow ""
local rrow ""
local pR ""
local pN ""
local i = 0
foreach m of local cols {
    local ++i
    quietly estimates restore `m'
    local nrow = "`nrow' & " + string(e(N), "%15.0fc")
    local rrow = "`rrow' & " + string(e(r2), "%9.3f")
    local pR "`pR' & `p_bank_`i''`p_gilt_`i''`p_mort_`i''"
    local pN "`pN' & `p_nl_`i''"
}

file write T " &  &  &  &  &  &  \\" _n
file write T "Observations`nrow' \\" _n
file write T "R-squared`rrow' \\" _n
file write T "p: rate gradient`pR' \\" _n
file write T "p: net lending gradient`pN' \\ \hline" _n
file write T "\end{tabular}" _n
file close T


*==============================================================================*
* P25-P75 SET (P75 OMITTED)
*==============================================================================*

rates3 9 "3 6" d_min1 rates_p25_p75 3 12 4.8


*==============================================================================*
* P10-P90 SET (P90 OMITTED), STRICTER SAMPLE
*==============================================================================*

*** Panels stacked, one-row legends
rates3 11 "1 2 4 5 6 7 8 10" d_min2 rates_p10_p90 1 7 11 1
