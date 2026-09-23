********************************************************************************
* Hedonic_HPI_Figures.do
*
* The ONS / HM Land Registry UK House Price Index (hedonic) by local authority,
* overall and by property type: comparison with the DHPIs, and regressions and
* local projections by property type (detached omitted).
* Inputs:  data/raw/UK-HPI-full-file-2023-12.csv
*          data/intermediate/SeriesQReady_WIDE.dta
*          data/intermediate/gdp_quarterly.dta
*          data/intermediate/lending_quarterly.dta
*          data/derived/QuarterlyMPC.dta
*          data/derived/QuarterlyFactorsMPC.dta
* Outputs: output/figures/dhpi_vs_hedonic.pdf
*          output/figures/gdp_credit_by_type.pdf/.png
*          output/figures/mp_by_type.pdf/.png
*          output/figures/lp_by_type.pdf/.png
********************************************************************************

clear all
set more off

*** All England & Wales local authorities with the hedonic index


*==============================================================================*
* DATA 1 -- quarterly UK HPI by local authority, England and Wales, 1995-2019
*==============================================================================*

import delimited "$raw/UK-HPI-full-file-2023-12.csv", varnames(1) clear

*** England & Wales local authority districts only
keep if inlist(substr(areacode, 1, 3), "E06", "E07", "E08", "E09", "W06")
keep date areacode index flatindex terracedindex semidetachedindex detachedindex

*** Force the index columns to numeric
foreach v in index flatindex terracedindex semidetachedindex detachedindex {
	capture confirm numeric variable `v'
	if _rc destring `v', replace force
}

gen int quarter = qofd(date(date, "DMY"))
format quarter %tq
keep if inrange(quarter, tq(1995q1), tq(2019q4))

*** Monthly -> quarterly mean of each index
collapse (mean) index flatindex terracedindex semidetachedindex detachedindex, ///
	by(areacode quarter)

tempfile hpi
save `hpi'


*==============================================================================*
* DATA 2 -- LAU x property type x quarter panel, y/y growth of the type index
*==============================================================================*

use `hpi', clear
drop index
rename areacode lau117cd

rename (flatindex terracedindex semidetachedindex detachedindex) (idx1 idx2 idx3 idx4)
reshape long idx, i(lau117cd quarter) j(type)
label define typel 1 "Flats" 2 "Terraced" 3 "Semi-detached" 4 "Detached"
label values type typel

egen panel = group(lau117cd type)
xtset panel quarter

*** Percentage change t-4 -> t
gen double g = 100 * (idx - L4.idx) / L4.idx

*** Winsorise at p1/p99 within type x quarter
gen double g_w = g
levelsof quarter, local(qs)
forvalues t = 1/4 {
	foreach q of local qs {
		quietly sum g if type == `t' & quarter == `q', d
		quietly replace g_w = r(p1)  if type == `t' & quarter == `q' & g_w < r(p1)
		quietly replace g_w = r(p99) if type == `t' & quarter == `q' & g_w > r(p99) & !missing(g_w)
	}
}

tempfile types
save `types'


********************************************************************************
* DHPI (P50) VS. THE ONS HEDONIC INDEX: CROSS-LAU AVERAGES OF Y/Y GROWTH,
* 1996q1-2019q4
********************************************************************************

*** Local hedonic index: y/y growth per LAU, then the average across LAUs
use `hpi', clear
egen lau = group(areacode)
xtset lau quarter
gen double g_hed = 100 * (index / L4.index - 1)
keep if quarter >= tq(1996q1)
collapse (mean) hed_avg = g_hed, by(quarter)
tempfile hedavg
save `hedavg'

*** P50 DHPI: average across LAUs
use "$inter/SeriesQReady_WIDE.dta", clear
keep if inrange(quarter, tq(1996q1), tq(2019q4))
collapse (mean) dhpi_p50 = ch_p50_w, by(quarter)
merge 1:1 quarter using `hedavg', nogen

correlate dhpi_p50 hed_avg

twoway ///
	(line dhpi_p50 quarter, lcolor(navy)  lpattern(solid) lwidth(medthick)) ///
	(line hed_avg  quarter, lcolor(black) lpattern(dash)  lwidth(medthick)) ///
	, yline(0, lcolor(gs12) lpattern(dash) lwidth(thin)) ///
	graphregion(color(white)) plotregion(color(white)) ///
	ytitle("YoY growth (%)", size(small)) xtitle("") ///
	ylabel(, labsize(small)) ///
	xlabel(`=tq(1996q1)' `=tq(2000q1)' `=tq(2004q1)' `=tq(2008q1)' ///
	       `=tq(2012q1)' `=tq(2016q1)' `=tq(2019q4)', labsize(small)) ///
	legend(order(1 "P50 (DHPI, cross-LAU avg)" 2 "UK HPI (cross-LAU avg)") ///
	       cols(2) size(small) position(6))

graph export "$figures/dhpi_vs_hedonic.pdf", as(pdf) replace


********************************************************************************
* GDP, CREDIT AND HOUSE PRICE GROWTH BY PROPERTY TYPE
*   Three regressions (GDP alone, net lending alone, both), drivers x type
*   dummies, detached omitted
********************************************************************************

use `types', clear

egen lau = group(lau117cd)

*** Drivers, lagged four quarters (the MPC merge only sets the quarters)
merge m:1 quarter using "$inter/gdp_quarterly.dta", keep(match) nogen keepusing(gdp_growth)
merge m:1 quarter using "$derived/QuarterlyMPC.dta", keep(match) nogen keepusing(quarter)
merge m:1 quarter using "$inter/lending_quarterly.dta", keep(match) nogen keepusing(net_secured)

xtset panel quarter
gen double l_gdp_growth  = L4.gdp_growth
gen double l_net_secured = L4.net_secured

*** Standardise both drivers by their standard deviation across quarters
egen qtag = tag(quarter)
quietly sum l_gdp_growth if qtag
gen double gdp = l_gdp_growth / r(sd)
quietly sum l_net_secured if qtag
gen double nl = l_net_secured / r(sd)

gen byte insamp = !missing(gdp, nl)

*** The three regressions (ib4.type#c.gdp = GDP x type dummies, detached omitted)
local fe "absorb(lau#quarter type#lau) vce(cluster quarter)"

reghdfe g_w ib4.type#c.gdp                       if insamp, `fe'
estimates store gdp_only
reghdfe g_w ib4.type#c.nl                        if insamp, `fe'
estimates store nl_only
reghdfe g_w ib4.type#c.gdp ib4.type#c.nl         if insamp, `fe'
estimates store both

estimates table gdp_only nl_only both, b(%9.3f) se(%9.3f) stats(N r2) drop(_cons)

local rG `"1.type#c.gdp = "Flats" 2.type#c.gdp = "Terraced" 3.type#c.gdp = "Semi-detached""'
local rN `"1.type#c.nl  = "Flats" 2.type#c.nl  = "Terraced" 3.type#c.nl  = "Semi-detached""'

coefplot ///
	(gdp_only, keep(1.type#c.gdp 2.type#c.gdp 3.type#c.gdp) rename(`rG') ///
		label("GDP growth (alone)")         msymbol(O)  mcolor("0 114 178") ciopts(lcolor("0 114 178"))) ///
	(both,     keep(1.type#c.gdp 2.type#c.gdp 3.type#c.gdp) rename(`rG') ///
		label("GDP growth (+ net lending)") msymbol(Oh) mcolor("0 114 178") ciopts(lcolor("0 114 178"))) ///
	(nl_only,  keep(1.type#c.nl 2.type#c.nl 3.type#c.nl) rename(`rN') ///
		label("Net lending (alone)")        msymbol(D)  mcolor("213 94 0")  ciopts(lcolor("213 94 0"))) ///
	(both,     keep(1.type#c.nl 2.type#c.nl 3.type#c.nl) rename(`rN') ///
		label("Net lending (+ GDP)")        msymbol(Dh) mcolor("213 94 0")  ciopts(lcolor("213 94 0"))), ///
	vertical level(90) yline(0, lcolor(gs8) lpattern(dash)) ///
	xtitle("Property type (detached omitted, ref.)") ///
	ytitle("Coefficient per 1 SD (90% CI)") ///
	graphregion(color(white)) plotregion(color(white)) ///
	legend(position(6) rows(2) size(small)) name(A6, replace)

graph export "$figures/gdp_credit_by_type.pdf", name(A6) as(pdf) replace
graph export "$figures/gdp_credit_by_type.png", name(A6) replace width(2000) height(1200)


********************************************************************************
* MONETARY POLICY AND HOUSE PRICE GROWTH BY PROPERTY TYPE
*   Seven shocks, two panels: A surprises along the yield curve, B factors.
*   One regression each, shock x type dummies, detached omitted.
********************************************************************************

use `types', clear

egen lau = group(lau117cd)

*** Shocks: quarterly sums over MPC announcements
merge m:1 quarter using "$derived/QuarterlyMPC.dta", keep(match) nogen keepusing(FSScm2 GB2YTRR GB5YTRR GB10YTRR)
merge m:1 quarter using "$derived/QuarterlyFactorsMPC.dta", keep(match) nogen keepusing(Target Path QE)

*** Each shock lagged four quarters and standardised by its sd across quarters
xtset panel quarter
egen qtag = tag(quarter)
foreach v in FSScm2 GB2YTRR GB5YTRR GB10YTRR Target Path QE {
	gen double l_`v' = L4.`v'
	quietly sum l_`v' if qtag
	gen double z_`v' = l_`v' / r(sd)
}

*** One regression per shock, each copied into the same variable m
local fe "absorb(lau#quarter type#lau) vce(cluster quarter)"
gen double m = .
foreach s in FSScm2 GB2YTRR GB5YTRR GB10YTRR Target Path QE {
	replace m = z_`s'
	reghdfe g_w ib4.type#c.m, `fe'
	estimates store m_`s'
}

estimates table m_FSScm2 m_GB2YTRR m_GB5YTRR m_GB10YTRR m_Target m_Path m_QE, ///
	b(%9.3f) se(%9.3f) stats(N) drop(_cons)

local opts keep(1.type#c.m 2.type#c.m 3.type#c.m) ///
	rename(1.type#c.m = "Flats" 2.type#c.m = "Terraced" 3.type#c.m = "Semi-detached") ///
	vertical level(90) yline(0, lcolor(gs8) lpattern(dash)) ///
	xtitle("Property type (detached omitted, ref.)", size(small)) ///
	ytitle("Coefficient per 1 SD (90% CI)", size(small)) ///
	graphregion(color(white)) plotregion(color(white)) ///
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

graph combine PANA PANB, cols(1) ycommon ///
	graphregion(color(white)) plotregion(color(white)) ///
	xsize(6.5) ysize(8) name(A11, replace)

graph export "$figures/mp_by_type.pdf", name(A11) as(pdf) replace
graph export "$figures/mp_by_type.png", name(A11) replace width(2000)
graph drop PANA PANB


********************************************************************************
* LOCAL PROJECTIONS BY PROPERTY TYPE
*   Three rows, one per shock: 6-month surprise, 2-year surprise, Target factor;
*   in each row flats, terraced and semi-detached vs. detached; one y-axis.
*   100*(ln I_{t+h} - ln I_{t-1}) on shock x type dummies, h = 0..16 quarters;
*   FE LAU x quarter and type x LAU; bands +-1 SE (clustered by quarter).
*   All England & Wales local authorities (no DHPI-universe restriction).
********************************************************************************

use `types', clear
egen lau = group(lau117cd)

*** Shocks (quarterly sums over MPC announcements), each standardised by its sd
*** across quarters; the first merge sets the quarters
merge m:1 quarter using "$derived/QuarterlyMPC.dta", keep(match) nogen keepusing(FSScm2 GB2YTRR)
merge m:1 quarter using "$derived/QuarterlyFactorsMPC.dta", keep(master match) nogen keepusing(Target)
egen qtag = tag(quarter)
foreach v in FSScm2 GB2YTRR Target {
	quietly sum `v' if qtag
	gen double z_`v' = `v' / r(sd)
}

*** Cumulative log-index change from t-1 to t+h (pp)
xtset panel quarter
gen double ln_idx = ln(idx)
forvalues h = 0/16 {
	gen cum`h' = 100 * (F`h'.ln_idx - L.ln_idx)
}

tempfile res
postfile R str8 shock int type int h double b se using `res', replace
foreach s in FSScm2 GB2YTRR Target {
	forvalues h = 0/16 {
		quietly reghdfe cum`h' ib4.type#c.z_`s', absorb(lau#quarter type#lau) vce(cluster quarter)
		forvalues c = 1/3 {
			post R ("`s'") (`c') (`h') (_b[`c'.type#c.z_`s']) (_se[`c'.type#c.z_`s'])
		}
	}
	di "`s' done"
}
postclose R

use `res', clear
gen lo = b - se
gen hi = b + se

list shock type h b se if inlist(h, 4, 8, 16), sepby(shock type) noobs

*** Common y-axis over all nine panels, including zero
qui sum lo
local ymin = min(r(min), 0)
qui sum hi
local ymax = max(r(max), 0)
_natscale `ymin' `ymax' 5
local yst = r(delta)
local ylo = `yst' * ceil(`ymin' / `yst') + 0
local yhi = `yst' * floor(`ymax' / `yst') + 0

local rows ""
foreach s in FSScm2 GB2YTRR Target {
	if "`s'" == "FSScm2"  local rtit "A. 6-month surprise"
	if "`s'" == "GB2YTRR" local rtit "B. 2-year gilt surprise"
	if "`s'" == "Target"  local rtit "C. Target factor"

	local names ""
	forvalues c = 1/3 {
		if `c' == 1 local clab "Flat"
		if `c' == 2 local clab "Terraced"
		if `c' == 3 local clab "Semi-detached"
		twoway ///
			(rarea hi lo h if shock == "`s'" & type == `c', color(blue%15) lwidth(none)) ///
			(line  b     h if shock == "`s'" & type == `c', lcolor(navy) lwidth(medthick)) ///
			, yline(0, lcolor(gs8) lpattern(dash)) ///
			  xlabel(0(4)16, labsize(small)) ///
			  yscale(range(`ymin' `ymax')) ylabel(`ylo'(`yst')`yhi', labsize(small) format(%9.2g)) ///
			  xtitle("Horizon (quarters)", size(small)) ytitle("pp", size(small)) ///
			  title("`clab'", size(medsmall) color(black)) ///
			  graphregion(color(white)) plotregion(color(white)) legend(off) ///
			  name(tp`s'`c', replace) nodraw
		local names "`names' tp`s'`c'"
	}
	graph combine `names', cols(3) imargin(small) ///
		title("`rtit'", size(medsmall) color(black) position(11) ring(1)) ///
		graphregion(color(white)) name(row`s', replace) nodraw
	local rows "`rows' row`s'"
}

graph combine `rows', cols(1) imargin(small) graphregion(color(white)) xsize(11) ysize(12)

graph export "$figures/lp_by_type.pdf", as(pdf) replace
graph export "$figures/lp_by_type.png", replace width(2200)
graph drop _all
