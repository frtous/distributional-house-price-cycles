********************************************************************************
* Monetary_Policy.do
*
* Regressions of DHPI growth on lagged monetary policy surprises and factors,
* by percentile set, and on the 2-year surprise split by meeting type:
* coefficient plots and a table.
* Inputs:  data/intermediate/SeriesQReady_LONG.dta
*          data/derived/QuarterlyMPC.dta
*          data/derived/QuarterlyFactorsMPC.dta
*          data/derived/Quarterly_MPS_InfoSplit.dta
* Outputs: output/figures/mp_p*.pdf/.png
*          output/figures/mp_info_split.pdf/.png
*          output/tables/mp_p20_p80.tex
********************************************************************************

clear all
set more off

*** Shocks: quarterly sums over MPC announcements, lagged four quarters and
*** standardised by their sd over 1998q2-2019q4
use quarter FSScm2 GB2YTRR GB5YTRR GB10YTRR using "$derived/QuarterlyMPC.dta", clear
merge 1:1 quarter using "$derived/QuarterlyFactorsMPC.dta", keep(match) nogen ///
    keepusing(Target Path QE)
merge 1:1 quarter using "$derived/Quarterly_MPS_InfoSplit.dta", keep(master match) nogen ///
    keepusing(GB2YTRR_noinfo GB2YTRR_info)
tsset quarter

foreach v in FSScm2 GB2YTRR GB5YTRR GB10YTRR Target Path QE GB2YTRR_noinfo GB2YTRR_info {
    gen double l4_`v' = L4.`v'
}
keep if inrange(quarter, tq(1998q2), tq(2019q4))
foreach v in FSScm2 GB2YTRR GB5YTRR GB10YTRR Target Path QE {
    quietly sum l4_`v'
    gen double z_`v' = l4_`v' / r(sd)
}

*** Split series divided by the sd of the full 2-year surprise
quietly sum l4_GB2YTRR
gen double z_noinfo = l4_GB2YTRR_noinfo / r(sd)
gen double z_info   = l4_GB2YTRR_info   / r(sd)

keep quarter z_*
tempfile drv
save `drv'

*** DHPI panel
use "$inter/SeriesQReady_LONG.dta", clear
merge m:1 quarter using `drv', keep(match) nogen

label define pct 1 "p10" 2 "p20" 3 "p25" 4 "p30" 5 "p40" 6 "p50" ///
                 7 "p60" 8 "p70" 9 "p75" 10 "p80" 11 "p90"
label values percentile pct

egen lau = group(lau117cd)
gen double m = .

*** mpsgrad: the seven regressions for one set, each shock copied in turn into
*** m, and the two-panel figure (ref = omitted percentile, pcts = percentiles
*** shown, smp = sample flag, fname = file name, xs ys = figure size).
*** Stores m_FSScm2, m_GB2YTRR, ...
capture program drop mpsgrad
program define mpsgrad
    args ref pcts smp fname xs ys

    local inl : subinstr local pcts " " ", ", all
    local ren ""
    foreach k of local pcts {
        local lab : label pct `k'
        local P = upper("`lab'")
        local ren "`ren' `k'.percentile#c.m = `P'"
    }
    local reflab : label pct `ref'
    local reflab = upper("`reflab'")

    foreach s in FSScm2 GB2YTRR GB5YTRR GB10YTRR Target Path QE {
        quietly replace m = z_`s'
        quietly reghdfe ch ib`ref'.percentile#c.m if `smp' == 1 & inlist(percentile, `inl', `ref'), ///
            absorb(lau#quarter percentile#lau) vce(cluster quarter)
        estimates store m_`s'
    }
    estimates table m_FSScm2 m_GB2YTRR m_GB5YTRR m_GB10YTRR m_Target m_Path m_QE, ///
        b(%9.3f) se(%9.3f) stats(N N_clust) drop(_cons)

    *** Colours (Okabe-Ito)
    local opts keep(*.percentile#c.m) rename(`ren') vertical level(90)   ///
        yline(0, lcolor(gs8) lpattern(dash))                              ///
        xtitle("Percentile (`reflab' omitted, ref.)", size(small))        ///
        ytitle("Coefficient per 1 SD (90% CI)", size(small))              ///
        graphregion(color(white)) plotregion(color(white))                ///
        legend(position(6) rows(1) size(small)) nodraw

    *** A -- surprises along the yield curve
    coefplot ///
        (m_FSScm2,   label("6-month")      msymbol(O) mcolor("0 114 178")  ciopts(lcolor("0 114 178")))  ///
        (m_GB2YTRR,  label("2-year gilt")  msymbol(D) mcolor("213 94 0")   ciopts(lcolor("213 94 0")))   ///
        (m_GB5YTRR,  label("5-year gilt")  msymbol(T) mcolor("230 159 0")  ciopts(lcolor("230 159 0")))  ///
        (m_GB10YTRR, label("10-year gilt") msymbol(S) mcolor("86 180 233") ciopts(lcolor("86 180 233"))), ///
        `opts' title("A. Monetary policy surprises", size(medium) color(black)) name(PANA, replace)

    *** B -- factors
    coefplot ///
        (m_Target, label("Target factor") msymbol(T) mcolor("0 158 115")   ciopts(lcolor("0 158 115")))   ///
        (m_Path,   label("Path factor")   msymbol(S) mcolor("204 121 167") ciopts(lcolor("204 121 167"))) ///
        (m_QE,     label("QE factor")     msymbol(X) mcolor(gs6)           ciopts(lcolor(gs6))),          ///
        `opts' title("B. Monetary policy factors", size(medium) color(black)) name(PANB, replace)

    *** Stacked, on one vertical scale
    graph combine PANA PANB, cols(1) ycommon ///
        graphregion(color(white)) plotregion(color(white)) ///
        xsize(`xs') ysize(`ys') name(COMB, replace)

    graph export "$figures/`fname'.pdf", name(COMB) as(pdf) replace
    graph export "$figures/`fname'.png", name(COMB) replace width(2000)
    graph drop PANA PANB COMB
end


*==============================================================================*
* P20-P80 SET (P80 OMITTED)
*==============================================================================*

mpsgrad 10 "2 5 7" d_min1 mp_p20_p80 6.5 8

*** Table of the seven regressions
local shocks "FSScm2 GB2YTRR GB5YTRR GB10YTRR Target Path QE"

file open T using "$tables/mp_p20_p80.tex", write replace text
file write T "\begin{tabular}{lccccccc} \hline" _n
file write T "VARIABLES & (1) & (2) & (3) & (4) & (5) & (6) & (7) \\" _n
file write T "Shock measure & 6-month & 2-year & 5-year & 10-year & Target & Path & QE \\ \hline" _n
file write T " &  &  &  &  &  &  &  \\" _n

foreach k in 2 5 7 {
    local lab : label pct `k'
    local P = upper("`lab'")
    local row  ""
    local srow ""
    foreach s of local shocks {
        quietly estimates restore m_`s'
        local b  = _b[`k'.percentile#c.m]
        local se = _se[`k'.percentile#c.m]
        local pv = 2 * ttail(e(df_r), abs(`b' / `se'))
        local st = cond(`pv' < 0.01, "***", cond(`pv' < 0.05, "**", cond(`pv' < 0.10, "*", "")))
        local row  = "`row' & " + string(`b', "%9.3f") + "`st'"
        local srow = "`srow' & (" + string(`se', "%9.3f") + ")"
    }
    file write T "MPS\$_{t-4}\times\$`P'\$_j\$`row' \\" _n
    file write T "`srow' \\" _n
}

local nrow ""
local rrow ""
foreach s of local shocks {
    quietly estimates restore m_`s'
    local nrow = "`nrow' & " + string(e(N), "%15.0fc")
    local rrow = "`rrow' & " + string(e(r2), "%9.3f")
}
file write T " &  &  &  &  &  &  &  \\" _n
file write T "Observations`nrow' \\" _n
file write T "R-squared`rrow' \\" _n
file write T "Reference group & P80 & P80 & P80 & P80 & P80 & P80 & P80 \\" _n
file write T "Local area-time FE & Y & Y & Y & Y & Y & Y & Y \\" _n
file write T "Percentile-Local area FE & Y & Y & Y & Y & Y & Y & Y \\ \hline" _n
file write T "\end{tabular}" _n
file close T


*==============================================================================*
* P25-P75 SET (P75 OMITTED)
*==============================================================================*

mpsgrad 9 "3 6" d_min1 mp_p25_p75 6.5 8


*==============================================================================*
* P10-P90 SET (P90 OMITTED), STRICTER SAMPLE
*==============================================================================*

mpsgrad 11 "1 2 4 5 6 7 8 10" d_min2 mp_p10_p90 7.5 9


*==============================================================================*
* 2-YEAR SURPRISE BY MEETING TYPE, P20-P80 SET
*==============================================================================*

*** No-information and information series in one regression
local if "if d_min1 == 1 & inlist(percentile, 2, 5, 7, 10)"

reghdfe ch ib10.percentile#c.z_noinfo ib10.percentile#c.z_info `if', ///
    absorb(lau#quarter percentile#lau) vce(cluster quarter)
estimates store joint

*** Tests of equal coefficients, by percentile and jointly
foreach k in 2 5 7 {
    test `k'.percentile#c.z_noinfo = `k'.percentile#c.z_info
}
test (2.percentile#c.z_noinfo = 2.percentile#c.z_info) ///
     (5.percentile#c.z_noinfo = 5.percentile#c.z_info) ///
     (7.percentile#c.z_noinfo = 7.percentile#c.z_info)

*** Coefficients renamed to P20, P40, P60 so the two series share the x-axis
local rNI ""
local rIN ""
foreach k in 2 5 7 {
    local lab : label pct `k'
    local P = upper("`lab'")
    local rNI "`rNI' `k'.percentile#c.z_noinfo = `P'"
    local rIN "`rIN' `k'.percentile#c.z_info = `P'"
}

coefplot ///
    (joint, keep(*.percentile#c.z_noinfo) rename(`rNI') label("No-information (pure MP)") ///
        msymbol(D) mcolor("213 94 0")  ciopts(lcolor("213 94 0"))) ///
    (joint, keep(*.percentile#c.z_info)   rename(`rIN') label("Information") ///
        msymbol(O) mcolor("0 114 178") ciopts(lcolor("0 114 178"))), ///
    vertical level(90) yline(0, lcolor(gs8) lpattern(dash)) ///
    xtitle("Percentile (P80 omitted, ref.)") ///
    ytitle("Coefficient per 1 SD of the 2-year surprise (90% CI)") ///
    graphregion(color(white)) plotregion(color(white)) ///
    legend(position(6) rows(1) size(small)) name(A12, replace)

graph export "$figures/mp_info_split.pdf", name(A12) as(pdf) replace
graph export "$figures/mp_info_split.png", name(A12) replace width(2000) height(1200)
