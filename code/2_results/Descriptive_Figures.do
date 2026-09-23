********************************************************************************
* Descriptive_Figures.do
*
* Time series of GDP growth, credit, monetary policy surprises and the DHPIs.
* Inputs:  data/intermediate/gdp_quarterly.dta
*          data/intermediate/lending_quarterly.dta
*          data/derived/QuarterlyMPC.dta
*          data/derived/QuarterlyFactorsMPC.dta
*          data/intermediate/SeriesQReady_WIDE.dta
* Outputs: output/figures/series_gdp_net_lending.pdf/.png
*          output/figures/series_mp_shocks.pdf/.png
*          output/figures/dhpis.pdf/.png
*          output/figures/gap_p20_p80.pdf
*          output/figures/gap_p20_p80_distribution.pdf
*          output/figures/series_credit_measures.pdf/.png
********************************************************************************

clear all
set more off

*** x-axis ticks
local xq `=tq(1996q1)' `=tq(2000q1)' `=tq(2004q1)' `=tq(2008q1)' `=tq(2012q1)' `=tq(2016q1)' `=tq(2019q4)'


*==============================================================================*
* GDP GROWTH AND NET SECURED LENDING
*==============================================================================*

use quarter gdp_growth using "$inter/gdp_quarterly.dta", clear
merge 1:1 quarter using "$inter/lending_quarterly.dta", keep(match) nogen keepusing(net_secured)
keep if inrange(quarter, tq(1996q1), tq(2019q4))

gen net_bn = net_secured / 1000

twoway (line gdp_growth quarter, lcolor("0 114 178") lwidth(medthick)) ///
    , yline(0, lcolor(gs12) lpattern(dash) lwidth(thin)) ///
      ytitle("Per cent, year-on-year", size(small)) xtitle("") ///
      ylabel(, labsize(small)) xlabel(`xq', labsize(small)) ///
      title("(A) The business cycle: real GDP growth", size(medsmall) color(black)) ///
      graphregion(color(white)) plotregion(color(white)) legend(off) ///
      name(F1A, replace) nodraw

twoway (line net_bn quarter, lcolor("213 94 0") lwidth(medthick)) ///
    , yline(0, lcolor(gs12) lpattern(dash) lwidth(thin)) ///
      ytitle("`=uchar(163)'bn per month", size(small)) xtitle("") ///
      ylabel(, labsize(small)) xlabel(`xq', labsize(small)) ///
      title("(B) The credit cycle: net secured lending", size(medsmall) color(black)) ///
      graphregion(color(white)) plotregion(color(white)) legend(off) ///
      name(F1B, replace) nodraw

graph combine F1A F1B, cols(1) iscale(0.9) xsize(9) ysize(7) graphregion(color(white))
graph export "$figures/series_gdp_net_lending.pdf", as(pdf) replace
graph export "$figures/series_gdp_net_lending.png", replace width(2000)


*==============================================================================*
* MONETARY POLICY SURPRISES AND FACTORS
*==============================================================================*

use quarter FSScm2 GB2YTRR using "$derived/QuarterlyMPC.dta", clear
merge 1:1 quarter using "$derived/QuarterlyFactorsMPC.dta", nogen keepusing(Target Path QE)
keep if quarter <= tq(2019q4)

local xq2 `=tq(1997q1)' `=tq(2000q1)' `=tq(2004q1)' `=tq(2008q1)' `=tq(2012q1)' `=tq(2016q1)' `=tq(2019q4)'

twoway (line FSScm2  quarter, lcolor(navy)   lpattern(solid) lwidth(medthick)) ///
       (line GB2YTRR quarter, lcolor(maroon) lpattern(dash)  lwidth(medthick)) ///
    , yline(0, lcolor(gs12) lpattern(dash) lwidth(thin)) ///
      ytitle("Quarterly sum (pp)", size(small)) xtitle("") ///
      ylabel(, labsize(small)) xlabel(`xq2', labsize(small)) ///
      title("(A) Surprises", size(medsmall) color(black)) ///
      legend(order(1 "6-month forward rate" 2 "2-year gilt yield") cols(2) size(small) position(6)) ///
      graphregion(color(white)) plotregion(color(white)) ///
      name(F2A, replace) nodraw

twoway (line Target quarter, lcolor(navy)         lpattern(solid)     lwidth(medthick)) ///
       (line Path   quarter, lcolor(forest_green) lpattern(longdash)  lwidth(medthick)) ///
       (line QE     quarter, lcolor(maroon)       lpattern(shortdash) lwidth(medthick)) ///
    , yline(0, lcolor(gs12) lpattern(dash) lwidth(thin)) ///
      ytitle("Quarterly sum", size(small)) xtitle("") ///
      ylabel(, labsize(small)) xlabel(`xq2', labsize(small)) ///
      title("(B) Factors", size(medsmall) color(black)) ///
      legend(order(1 "Target" 2 "Path" 3 "QE") cols(3) size(small) position(6)) ///
      graphregion(color(white)) plotregion(color(white)) ///
      name(F2B, replace) nodraw

graph combine F2A F2B, cols(1) iscale(0.9) xsize(9) ysize(7) graphregion(color(white))
graph export "$figures/series_mp_shocks.pdf", as(pdf) replace
graph export "$figures/series_mp_shocks.png", replace width(2000)


*==============================================================================*
* AVERAGE DHPI GROWTH BY PERCENTILE
*==============================================================================*

use quarter ch_p20_w ch_p25_w ch_p40_w ch_p50_w ch_p60_w ch_p75_w ch_p80_w ///
    using "$inter/SeriesQReady_WIDE.dta", clear
keep if inrange(quarter, tq(1996q1), tq(2019q4))
collapse (mean) ch_p20_w ch_p25_w ch_p40_w ch_p50_w ch_p60_w ch_p75_w ch_p80_w, by(quarter)

twoway (line ch_p25_w quarter, lcolor(navy)  lpattern(dash)  lwidth(medthick)) ///
       (line ch_p50_w quarter, lcolor(black) lpattern(solid) lwidth(medthick)) ///
       (line ch_p75_w quarter, lcolor(red)   lpattern(dash)  lwidth(medthick)) ///
    , ylabel(-15(5)30, labsize(small)) ytitle("") xtitle("") ///
      title("P25, P50, and P75", size(small) color(black)) ///
      legend(order(1 "P25" 2 "P50" 3 "P75") cols(3) size(small) position(6)) ///
      graphregion(color(white)) plotregion(color(white)) ///
      name(F3A, replace) nodraw

twoway (line ch_p20_w quarter, lcolor(navy)   lpattern(dash)  lwidth(medthick)) ///
       (line ch_p40_w quarter, lcolor(blue)   lpattern(solid) lwidth(medthick)) ///
       (line ch_p60_w quarter, lcolor(maroon) lpattern(solid) lwidth(medthick)) ///
       (line ch_p80_w quarter, lcolor(red)    lpattern(dash)  lwidth(medthick)) ///
    , ylabel(-15(5)30, labsize(small)) ytitle("") xtitle("") ///
      title("P20, P40, P60, and P80", size(small) color(black)) ///
      legend(order(1 "P20" 2 "P40" 3 "P60" 4 "P80") cols(4) size(small) position(6)) ///
      graphregion(color(white)) plotregion(color(white)) ///
      name(F3B, replace) nodraw

graph combine F3A F3B, cols(2) imargin(small) ycommon graphregion(color(white))
graph export "$figures/dhpis.pdf", as(pdf) replace
graph export "$figures/dhpis.png", replace width(2000)


*==============================================================================*
* P20 MINUS P80 GROWTH
*==============================================================================*

use lau117cd quarter ch_p20_w ch_p80_w using "$inter/SeriesQReady_WIDE.dta", clear
keep if inrange(quarter, tq(1996q1), tq(2019q4))
gen diff2080 = ch_p20_w - ch_p80_w

collapse (mean) avg = diff2080 (p25) q25 = diff2080 (p50) q50 = diff2080 ///
         (p75) q75 = diff2080, by(quarter)

*** Statistics quoted in the text
sum avg
sum avg if inrange(quarter, tq(2002q1), tq(2005q4))
sum avg
list quarter avg if avg == r(max) | avg == r(min), noobs
count if avg > 0
di "share of quarters with a positive spread: " %4.1f 100 * r(N) / _N "%"

local xq4 `=tq(1996q1)' `=tq(2000q1)' `=tq(2004q1)' `=tq(2008q1)' `=tq(2012q1)' `=tq(2016q1)'

*** (A) average
twoway (line avg quarter, lcolor(black) lwidth(medium)) ///
    , yline(0, lcolor(gs12) lpattern(dash) lwidth(thin)) ///
      ylabel(-5(5)10, labsize(small)) xlabel(`xq4', labsize(small)) ///
      ytitle("Percentage points", size(small)) xtitle("") ///
      graphregion(color(white)) plotregion(color(white)) legend(off)
graph export "$figures/gap_p20_p80.pdf", as(pdf) replace

*** (B) distribution across local areas
twoway (rarea q25 q75 quarter, color(gs13) lwidth(none)) ///
       (line q50 quarter, lcolor(black) lwidth(medium)) ///
    , yline(0, lcolor(gs10) lpattern(dash) lwidth(thin)) ///
      ylabel(, labsize(small)) xlabel(`xq4', labsize(small)) ///
      ytitle("P20 minus P80 growth rate (pp)", size(small)) xtitle("") ///
      legend(order(2 "Cross-market median" 1 "P25-P75 across markets") cols(2) size(small) position(6)) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$figures/gap_p20_p80_distribution.pdf", as(pdf) replace


*==============================================================================*
* CREDIT MEASURES
*==============================================================================*

use quarter net_secured l1_mortgage_debt mortgage_debt_g approvals_hp consumer_credit_g ///
    using "$inter/lending_quarterly.dta", clear

*** Net secured lending as a % of the mortgage stock, annualised
gen nl_stock = 100 * 12 * net_secured / l1_mortgage_debt
keep if inrange(quarter, tq(1996q1), tq(2019q4))

*** Standardised over the plotted quarters
foreach v in net_secured nl_stock mortgage_debt_g approvals_hp consumer_credit_g {
    quietly sum `v'
    gen z_`v' = (`v' - r(mean)) / r(sd)
}

twoway (line z_net_secured       quarter, lcolor("213 94 0")    lpattern(solid)    lwidth(medthick)) ///
       (line z_nl_stock          quarter, lcolor("230 159 0")   lpattern(dash)     lwidth(medthick)) ///
       (line z_mortgage_debt_g   quarter, lcolor("0 158 115")   lpattern(solid)    lwidth(medthick)) ///
       (line z_approvals_hp      quarter, lcolor("86 180 233")  lpattern(solid)    lwidth(medthick)) ///
       (line z_consumer_credit_g quarter, lcolor("204 121 167") lpattern(longdash) lwidth(medthick)) ///
    , yline(0, lcolor(gs12) lpattern(dash) lwidth(thin)) ///
      xline(`=tq(2008q2)' `=tq(2009q2)', lcolor(gs13) lwidth(medthick)) ///
      ytitle("Standard deviations from mean", size(small)) xtitle("") ///
      ylabel(, labsize(small)) xlabel(`xq', labsize(small)) ///
      legend(order(1 "Net secured lending (value)" 2 "Net secured lending (% of stock)" ///
                   3 "Mortgage debt growth (% y/y)" 4 "Approvals, house purchase (no.)" ///
                   5 "Consumer credit growth (% y/y)") ///
             rows(2) size(small) position(6) region(lstyle(none))) ///
      graphregion(color(white)) plotregion(color(white))
graph export "$figures/series_credit_measures.pdf", as(pdf) replace
graph export "$figures/series_credit_measures.png", replace width(2200)
