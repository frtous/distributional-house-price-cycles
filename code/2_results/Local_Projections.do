********************************************************************************
* Local_Projections.do
*
* Local projections of cumulative DHPI growth over one to four years on annual
* monetary policy shocks, with wild cluster bootstrap bands: one section per
* figure.
* Inputs:  data/intermediate/DHPI_5Y_LP.dta
*          data/derived/AnnualMPC.dta
*          data/derived/AnnualFactorsMPC.dta
*          data/derived/Yields_UK_24m.dta
* Outputs: output/figures/lp_*.pdf/.png
*          data/intermediate/lp_*_results.dta
********************************************************************************

clear all
set more off


*==============================================================================*
* DATA
*==============================================================================*

use "$inter/DHPI_5Y_LP.dta", clear

*** Shocks: annual sums of the surprises over MPC announcements
merge m:1 year using "$derived/AnnualMPC.dta", keep(master match) nogen ///
	keepusing(FSScm2 GB2YTRR GB5YTRR GB10YTRR)
merge m:1 year using "$derived/AnnualFactorsMPC.dta", keep(master match) nogen ///
	keepusing(Target Path QE)

*** Base years 1998-2015
keep if inrange(year, 1998, 2015)

*** Standardise each shock by its standard deviation across the base years
egen ytag = tag(year)
foreach v in FSScm2 GB2YTRR GB5YTRR GB10YTRR Target Path QE {
	quietly sum `v' if ytag
	di "sd of `v' = " %6.4f r(sd)
	gen z_`v' = `v' / r(sd)
}

*** Fixed-effect key and sample: P20, P40, P60 and the reference P80
*** (percentile = 2, 5, 7, 10), better-populated local areas
egen lau = group(lau117cd)
gen byte insamp = d_min1 == 1 & inlist(percentile, 2, 5, 7, 10)

*** Keep the prepared data; each figure section starts from here
tempfile lpdata
save `lpdata'


********************************************************************************
* MAIN FIGURE -- P20-P80: 6-month surprise, 2-year surprise, Target factor
********************************************************************************

use `lpdata', clear

*==============================================================================*
* Local projections
*------------------------------------------------------------------------------
* For each shock and horizon:
*  1. reghdfe gives the point estimates (and fixes the estimation sample);
*  2. both sets of fixed effects are partialled out and boottest (wild
*     cluster bootstrap, clusters = years) runs on the regression of
*     residuals on residuals. Same seed in every call.
*==============================================================================*

local fe "absorb(lau#year percentile#lau)"

tempfile res
postfile R str8 shock int perc int h double b lo hi using `res', replace

foreach s in FSScm2 GB2YTRR Target {

	*** shock x percentile dummies (p80 omitted)
	foreach k in 2 5 7 {
		gen double x`k' = z_`s' * (percentile == `k')
	}

	forvalues h = 1/4 {

		*** 1. point estimates, clustered by year
		quietly reghdfe ch`h'p x2 x5 x7 if insamp, `fe' vce(cluster year)
		gen byte es = e(sample)
		foreach k in 2 5 7 {
			local b`k' = _b[x`k']
		}

		*** 2. partial out the fixed effects, then bootstrap each coefficient
		quietly reghdfe ch`h'p if es, `fe' residuals(ry) keepsingletons
		foreach k in 2 5 7 {
			quietly reghdfe x`k' if es, `fe' residuals(rx`k') keepsingletons
		}
		quietly regress ry rx2 rx5 rx7 if es, vce(cluster year)

		foreach k in 2 5 7 {
			quietly boottest rx`k', level(68) weighttype(webb) reps(9999) seed(8675309) nograph
			local lo = .
			local hi = .
			capture matrix CI = r(CI)
			if !_rc {
				local lo = CI[1,1]
				local hi = CI[rowsof(CI),2]
			}
			post R ("`s'") (`k') (`h') (`b`k'') (`lo') (`hi')
		}
		drop es ry rx2 rx5 rx7
		di "`s'  h = `h'  done"
	}
	drop x2 x5 x7
}
postclose R

*==============================================================================*
* Results
*==============================================================================*

use `res', clear
recode perc (2 = 20) (5 = 40) (7 = 60)
sort shock perc h
save "$inter/lp_p20_p80_results.dta", replace

list shock perc h b lo hi, sepby(shock perc) noobs

*==============================================================================*
* Figure -- 3 x 3 small multiples on one common y-axis
*==============================================================================*

*** common y-axis: from the lowest to the highest band (always including zero);
*** labels only at round values inside that range
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
	foreach pp in 20 40 60 {
		twoway ///
			(rarea hi lo h if shock == "`s'" & perc == `pp', color(blue%15) lwidth(none)) ///
			(line  b     h if shock == "`s'" & perc == `pp', lcolor(navy) lwidth(medthick)) ///
			, yline(0, lcolor(gs8) lpattern(dash)) ///
			  xlabel(1(1)4, labsize(small)) ///
			  yscale(range(`ymin' `ymax')) ylabel(`ylo'(`yst')`yhi', labsize(small) format(%9.2g)) ///
			  xtitle("Horizon (years)", size(small)) ytitle("pp", size(small)) ///
			  title("P`pp'", size(medsmall) color(black)) ///
			  graphregion(color(white)) plotregion(color(white)) legend(off) ///
			  name(g`s'`pp', replace) nodraw
		local names "`names' g`s'`pp'"
	}
	graph combine `names', cols(3) imargin(small) ///
		title("`rtit'", size(medsmall) color(black) position(11) ring(1)) ///
		graphregion(color(white)) name(row`s', replace) nodraw
	local rows "`rows' row`s'"
}

graph combine `rows', cols(1) imargin(small) graphregion(color(white)) xsize(11) ysize(12)

graph export "$figures/lp_p20_p80.pdf", as(pdf) replace
graph export "$figures/lp_p20_p80.png", replace width(2200)
graph drop _all


********************************************************************************
* APPENDIX FIGURE -- P20-P80: 5-year surprise, 10-year surprise, Path, QE
********************************************************************************

use `lpdata', clear

*==============================================================================*
* Local projections -- as in the main figure, for the other four shocks
*==============================================================================*

local fe "absorb(lau#year percentile#lau)"

tempfile res
postfile R str8 shock int perc int h double b lo hi using `res', replace

foreach s in GB5YTRR GB10YTRR Path QE {

	*** shock x percentile dummies (p80 omitted)
	foreach k in 2 5 7 {
		gen double x`k' = z_`s' * (percentile == `k')
	}

	forvalues h = 1/4 {

		*** 1. point estimates, clustered by year
		quietly reghdfe ch`h'p x2 x5 x7 if insamp, `fe' vce(cluster year)
		gen byte es = e(sample)
		foreach k in 2 5 7 {
			local b`k' = _b[x`k']
		}

		*** 2. partial out the fixed effects, then bootstrap each coefficient
		quietly reghdfe ch`h'p if es, `fe' residuals(ry) keepsingletons
		foreach k in 2 5 7 {
			quietly reghdfe x`k' if es, `fe' residuals(rx`k') keepsingletons
		}
		quietly regress ry rx2 rx5 rx7 if es, vce(cluster year)

		foreach k in 2 5 7 {
			quietly boottest rx`k', level(68) weighttype(webb) reps(9999) seed(8675309) nograph
			local lo = .
			local hi = .
			capture matrix CI = r(CI)
			if !_rc {
				local lo = CI[1,1]
				local hi = CI[rowsof(CI),2]
			}
			post R ("`s'") (`k') (`h') (`b`k'') (`lo') (`hi')
		}
		drop es ry rx2 rx5 rx7
		di "`s'  h = `h'  done"
	}
	drop x2 x5 x7
}
postclose R

*==============================================================================*
* Results
*==============================================================================*

use `res', clear
recode perc (2 = 20) (5 = 40) (7 = 60)
sort shock perc h
save "$inter/lp_other_shocks_results.dta", replace

list shock perc h b lo hi, sepby(shock perc) noobs

*==============================================================================*
* Figure -- 4 x 3 small multiples on one common y-axis
*==============================================================================*

qui sum lo
local ymin = min(r(min), 0)
qui sum hi
local ymax = max(r(max), 0)
_natscale `ymin' `ymax' 5
local yst = r(delta)
local ylo = `yst' * ceil(`ymin' / `yst') + 0
local yhi = `yst' * floor(`ymax' / `yst') + 0

local rows ""
foreach s in GB5YTRR GB10YTRR Path QE {
	if "`s'" == "GB5YTRR"  local rtit "A. 5-year gilt surprise"
	if "`s'" == "GB10YTRR" local rtit "B. 10-year gilt surprise"
	if "`s'" == "Path"     local rtit "C. Path factor"
	if "`s'" == "QE"       local rtit "D. QE factor"

	local names ""
	foreach pp in 20 40 60 {
		twoway ///
			(rarea hi lo h if shock == "`s'" & perc == `pp', color(blue%15) lwidth(none)) ///
			(line  b     h if shock == "`s'" & perc == `pp', lcolor(navy) lwidth(medthick)) ///
			, yline(0, lcolor(gs8) lpattern(dash)) ///
			  xlabel(1(1)4, labsize(small)) ///
			  yscale(range(`ymin' `ymax')) ylabel(`ylo'(`yst')`yhi', labsize(small) format(%9.2g)) ///
			  xtitle("Horizon (years)", size(small)) ytitle("pp", size(small)) ///
			  title("P`pp'", size(medsmall) color(black)) ///
			  graphregion(color(white)) plotregion(color(white)) legend(off) ///
			  name(g`s'`pp', replace) nodraw
		local names "`names' g`s'`pp'"
	}
	graph combine `names', cols(3) imargin(small) ///
		title("`rtit'", size(medsmall) color(black) position(11) ring(1)) ///
		graphregion(color(white)) name(row`s', replace) nodraw
	local rows "`rows' row`s'"
}

graph combine `rows', cols(1) imargin(small) graphregion(color(white)) xsize(11) ysize(16)

graph export "$figures/lp_other_shocks.pdf", as(pdf) replace
graph export "$figures/lp_other_shocks.png", replace width(2200)
graph drop _all


********************************************************************************
* MAIN FIGURE, P25-P75 SET -- 6-month surprise, 2-year surprise, Target factor
*   P25 and P50 against the reference P75 (percentile = 3, 6, 9)
********************************************************************************

use `lpdata', clear

*** Sample for this set: P25, P50 and the reference P75, better-populated areas
gen byte insamp_t = d_min1 == 1 & inlist(percentile, 3, 6, 9)

*==============================================================================*
* Local projections -- as in the main figure, with two percentiles
*==============================================================================*

local fe "absorb(lau#year percentile#lau)"

tempfile res
postfile R str8 shock int perc int h double b lo hi using `res', replace

foreach s in FSScm2 GB2YTRR Target {

	*** shock x percentile dummies (p75 omitted)
	foreach k in 3 6 {
		gen double x`k' = z_`s' * (percentile == `k')
	}

	forvalues h = 1/4 {

		*** 1. point estimates, clustered by year
		quietly reghdfe ch`h'p x3 x6 if insamp_t, `fe' vce(cluster year)
		gen byte es = e(sample)
		foreach k in 3 6 {
			local b`k' = _b[x`k']
		}

		*** 2. partial out the fixed effects, then bootstrap each coefficient
		quietly reghdfe ch`h'p if es, `fe' residuals(ry) keepsingletons
		foreach k in 3 6 {
			quietly reghdfe x`k' if es, `fe' residuals(rx`k') keepsingletons
		}
		quietly regress ry rx3 rx6 if es, vce(cluster year)

		foreach k in 3 6 {
			quietly boottest rx`k', level(68) weighttype(webb) reps(9999) seed(8675309) nograph
			local lo = .
			local hi = .
			capture matrix CI = r(CI)
			if !_rc {
				local lo = CI[1,1]
				local hi = CI[rowsof(CI),2]
			}
			post R ("`s'") (`k') (`h') (`b`k'') (`lo') (`hi')
		}
		drop es ry rx3 rx6
		di "`s'  h = `h'  done"
	}
	drop x3 x6
}
postclose R

*==============================================================================*
* Results
*==============================================================================*

use `res', clear
recode perc (3 = 25) (6 = 50)
sort shock perc h
save "$inter/lp_p25_p75_results.dta", replace

list shock perc h b lo hi, sepby(shock perc) noobs

*==============================================================================*
* Figure -- 3 x 2 small multiples on one common y-axis
*==============================================================================*

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
	foreach pp in 25 50 {
		twoway ///
			(rarea hi lo h if shock == "`s'" & perc == `pp', color(blue%15) lwidth(none)) ///
			(line  b     h if shock == "`s'" & perc == `pp', lcolor(navy) lwidth(medthick)) ///
			, yline(0, lcolor(gs8) lpattern(dash)) ///
			  xlabel(1(1)4, labsize(small)) ///
			  yscale(range(`ymin' `ymax')) ylabel(`ylo'(`yst')`yhi', labsize(small) format(%9.2g)) ///
			  xtitle("Horizon (years)", size(small)) ytitle("pp", size(small)) ///
			  title("P`pp'", size(medsmall) color(black)) ///
			  graphregion(color(white)) plotregion(color(white)) legend(off) ///
			  name(g`s'`pp', replace) nodraw
		local names "`names' g`s'`pp'"
	}
	graph combine `names', cols(2) imargin(small) ///
		title("`rtit'", size(medium) color(black) position(11) ring(1)) ///
		graphregion(color(white)) name(row`s', replace) nodraw
	local rows "`rows' row`s'"
}

graph combine `rows', cols(1) imargin(small) graphregion(color(white)) xsize(8) ysize(12)

graph export "$figures/lp_p25_p75.pdf", as(pdf) replace
graph export "$figures/lp_p25_p75.png", replace width(1800)
graph drop _all


********************************************************************************
* MAIN FIGURE, P10-P90 SET -- 6-month surprise, 2-year surprise, Target factor
*   P10, P20, P30, ..., P80 against the reference P90
*   (percentile = 1, 2, 4, 5, 6, 7, 8, 10 vs 11); local areas with d_min1 == 1
********************************************************************************

use `lpdata', clear

*** Sample for this set
gen byte insamp_d = d_min1 == 1 & inlist(percentile, 1, 2, 4, 5, 6, 7, 8, 10, 11)

*** Percentile codes interacted with the shock (P90 omitted)
local codes "1 2 4 5 6 7 8 10"

*==============================================================================*
* Local projections -- as in the main figure, with eight percentiles
*==============================================================================*

local fe "absorb(lau#year percentile#lau)"

tempfile res
postfile R str8 shock int perc int h double b lo hi using `res', replace

foreach s in FSScm2 GB2YTRR Target {

	*** shock x percentile dummies (p90 omitted)
	local xlist ""
	local rxlist ""
	foreach k of local codes {
		gen double x`k' = z_`s' * (percentile == `k')
		local xlist "`xlist' x`k'"
		local rxlist "`rxlist' rx`k'"
	}

	forvalues h = 1/4 {

		*** 1. point estimates, clustered by year
		quietly reghdfe ch`h'p `xlist' if insamp_d, `fe' vce(cluster year)
		gen byte es = e(sample)
		foreach k of local codes {
			local b`k' = _b[x`k']
		}

		*** 2. partial out the fixed effects, then bootstrap each coefficient
		quietly reghdfe ch`h'p if es, `fe' residuals(ry) keepsingletons
		foreach k of local codes {
			quietly reghdfe x`k' if es, `fe' residuals(rx`k') keepsingletons
		}
		quietly regress ry `rxlist' if es, vce(cluster year)

		foreach k of local codes {
			quietly boottest rx`k', level(68) weighttype(webb) reps(9999) seed(8675309) nograph
			local lo = .
			local hi = .
			capture matrix CI = r(CI)
			if !_rc {
				local lo = CI[1,1]
				local hi = CI[rowsof(CI),2]
			}
			post R ("`s'") (`k') (`h') (`b`k'') (`lo') (`hi')
		}
		drop es ry `rxlist'
		di "`s'  h = `h'  done"
	}
	drop `xlist'
}
postclose R

*==============================================================================*
* Results
*==============================================================================*

use `res', clear
recode perc (1 = 10) (2 = 20) (4 = 30) (5 = 40) (6 = 50) (7 = 60) (8 = 70) (10 = 80)
sort shock perc h
save "$inter/lp_p10_p90_results.dta", replace

list shock perc h b lo hi if h == 4, sepby(shock) noobs

*==============================================================================*
* Figure -- landscape: one row per shock (P10 ... P80 across, eight panels),
* three rows stacked, all 24 panels on one common y-axis. Only the P10 panel
* of each row shows y-axis labels; the axis titles ("pp", "Horizon (years)")
* are written once per row / once for the figure.
*==============================================================================*

local tscale 1          // text and marker scale inside each row (iscale)

qui sum lo
local ymin = min(r(min), 0)
qui sum hi
local ymax = max(r(max), 0)
_natscale `ymin' `ymax' 5
local yst = r(delta)
local ylo = `yst' * ceil(`ymin' / `yst') + 0
local yhi = `yst' * floor(`ymax' / `yst') + 0

local blocks ""
foreach s in FSScm2 GB2YTRR Target {
	if "`s'" == "FSScm2"  local rtit "A. 6-month surprise"
	if "`s'" == "GB2YTRR" local rtit "B. 2-year gilt surprise"
	if "`s'" == "Target"  local rtit "C. Target factor"

	local names ""
	foreach pp in 10 20 30 40 50 60 70 80 {
		*** y-axis labels on the first panel of the row only
		local ylabopt "labsize(small) format(%9.2g)"
		if `pp' != 10 local ylabopt "nolabels"
		twoway ///
			(rarea hi lo h if shock == "`s'" & perc == `pp', color(blue%15) lwidth(none)) ///
			(line  b     h if shock == "`s'" & perc == `pp', lcolor(navy) lwidth(medthick)) ///
			, yline(0, lcolor(gs8) lpattern(dash)) ///
			  xlabel(1(1)4, labsize(small)) ///
			  yscale(range(`ymin' `ymax')) ylabel(`ylo'(`yst')`yhi', `ylabopt') ///
			  xtitle("") ytitle("") ///
			  title("P`pp'", size(medsmall) color(black)) ///
			  graphregion(color(white)) plotregion(color(white)) legend(off) ///
			  name(g`s'`pp', replace) nodraw
		local names "`names' g`s'`pp'"
	}
	graph combine `names', cols(8) imargin(tiny) iscale(`tscale') ///
		title("`rtit'", size(medium) color(black) position(11) ring(1)) ///
		l1title("pp", size(small)) ///
		graphregion(color(white)) name(blk`s', replace) nodraw
	local blocks "`blocks' blk`s'"
}

graph combine `blocks', cols(1) imargin(small) graphregion(color(white)) ///
	b1title("Horizon (years)", size(small)) xsize(16) ysize(8.5)

graph export "$figures/lp_p10_p90.pdf", as(pdf) replace
graph export "$figures/lp_p10_p90.png", replace width(3200)
graph drop _all


********************************************************************************
* MAIN FIGURE WITH THE SHOCK AT t+1 -- P20-P80: 6-month, 2-year, Target
*
*   The regressor is the shock sum of the year after the base year; base years
*   1997-2015; each led shock standardised by its sd over these base years.
*   This section rebuilds its own data.
********************************************************************************

*** Shock files shifted back one year: row `year' holds the sum of year + 1
use "$derived/AnnualMPC.dta", clear
keep year FSScm2 GB2YTRR
replace year = year - 1
tempfile leadmpc
save `leadmpc'

use "$derived/AnnualFactorsMPC.dta", clear
keep year Target
replace year = year - 1
tempfile leadfac
save `leadfac'

use "$inter/DHPI_5Y_LP.dta", clear
merge m:1 year using `leadmpc', keep(match) nogen
merge m:1 year using `leadfac', keep(match) nogen

*** Base years
keep if inrange(year, 1997, 2015)

*** Standardise each led shock by its standard deviation across base years
egen ytag = tag(year)
foreach v in FSScm2 GB2YTRR Target {
	quietly sum `v' if ytag
	di "sd of `v' (t+1) = " %6.4f r(sd)
	gen z_`v' = `v' / r(sd)
}

*** Fixed-effect key and sample: P20, P40, P60 and the reference P80
egen lau = group(lau117cd)
gen byte insamp = d_min1 == 1 & inlist(percentile, 2, 5, 7, 10)

*==============================================================================*
* Local projections -- as in the main figure
*==============================================================================*

local fe "absorb(lau#year percentile#lau)"

tempfile res
postfile R str8 shock int perc int h double b lo hi using `res', replace

foreach s in FSScm2 GB2YTRR Target {

	*** shock x percentile dummies (p80 omitted)
	foreach k in 2 5 7 {
		gen double x`k' = z_`s' * (percentile == `k')
	}

	forvalues h = 1/4 {

		*** 1. point estimates, clustered by year
		quietly reghdfe ch`h'p x2 x5 x7 if insamp, `fe' vce(cluster year)
		gen byte es = e(sample)
		foreach k in 2 5 7 {
			local b`k' = _b[x`k']
		}

		*** 2. partial out the fixed effects, then bootstrap each coefficient
		quietly reghdfe ch`h'p if es, `fe' residuals(ry) keepsingletons
		foreach k in 2 5 7 {
			quietly reghdfe x`k' if es, `fe' residuals(rx`k') keepsingletons
		}
		quietly regress ry rx2 rx5 rx7 if es, vce(cluster year)

		foreach k in 2 5 7 {
			quietly boottest rx`k', level(68) weighttype(webb) reps(9999) seed(8675309) nograph
			local lo = .
			local hi = .
			capture matrix CI = r(CI)
			if !_rc {
				local lo = CI[1,1]
				local hi = CI[rowsof(CI),2]
			}
			post R ("`s'") (`k') (`h') (`b`k'') (`lo') (`hi')
		}
		drop es ry rx2 rx5 rx7
		di "`s' (t+1)  h = `h'  done"
	}
	drop x2 x5 x7
}
postclose R

*==============================================================================*
* Results
*==============================================================================*

use `res', clear
recode perc (2 = 20) (5 = 40) (7 = 60)
sort shock perc h
save "$inter/lp_p20_p80_lead_results.dta", replace

list shock perc h b lo hi, sepby(shock perc) noobs

*==============================================================================*
* Figure -- 3 x 3 small multiples on one common y-axis
*==============================================================================*

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
	if "`s'" == "FSScm2"  local rtit "A. 6-month surprise (t+1)"
	if "`s'" == "GB2YTRR" local rtit "B. 2-year gilt surprise (t+1)"
	if "`s'" == "Target"  local rtit "C. Target factor (t+1)"

	local names ""
	foreach pp in 20 40 60 {
		twoway ///
			(rarea hi lo h if shock == "`s'" & perc == `pp', color(blue%15) lwidth(none)) ///
			(line  b     h if shock == "`s'" & perc == `pp', lcolor(navy) lwidth(medthick)) ///
			, yline(0, lcolor(gs8) lpattern(dash)) ///
			  xlabel(1(1)4, labsize(small)) ///
			  yscale(range(`ymin' `ymax')) ylabel(`ylo'(`yst')`yhi', labsize(small) format(%9.2g)) ///
			  xtitle("Horizon (years)", size(small)) ytitle("pp", size(small)) ///
			  title("P`pp'", size(medsmall) color(black)) ///
			  graphregion(color(white)) plotregion(color(white)) legend(off) ///
			  name(g`s'`pp', replace) nodraw
		local names "`names' g`s'`pp'"
	}
	graph combine `names', cols(3) imargin(small) ///
		title("`rtit'", size(medsmall) color(black) position(11) ring(1)) ///
		graphregion(color(white)) name(row`s', replace) nodraw
	local rows "`rows' row`s'"
}

graph combine `rows', cols(1) imargin(small) graphregion(color(white)) xsize(11) ysize(12)

graph export "$figures/lp_p20_p80_lead.pdf", as(pdf) replace
graph export "$figures/lp_p20_p80_lead.png", replace width(2200)
graph drop _all


********************************************************************************
* ACTUAL CHANGE IN THE 2-YEAR YIELD -- P20-P80
*
*   The actual annual change in the 2-year UK yield (Ch_yield_24m) in place of
*   the MPC surprises; same base years as the main figure.
********************************************************************************

use `lpdata', clear

*** Actual annual change in the 2-year yield
merge m:1 year using "$derived/Yields_UK_24m.dta", keep(match) nogen keepusing(Ch_yield_24m)

*** Standardise by its standard deviation across the base years; correlation
*** with the 2-year surprise
quietly sum Ch_yield_24m if ytag
di "sd of Ch_yield_24m = " %6.4f r(sd)
gen z_chy = Ch_yield_24m / r(sd)
corr Ch_yield_24m GB2YTRR if ytag

*==============================================================================*
* Local projections -- as in the main figure, one regressor
*==============================================================================*

local fe "absorb(lau#year percentile#lau)"

tempfile res
postfile R str8 shock int perc int h double b lo hi using `res', replace

*** yield change x percentile dummies (p80 omitted)
foreach k in 2 5 7 {
	gen double x`k' = z_chy * (percentile == `k')
}

forvalues h = 1/4 {

	*** 1. point estimates, clustered by year
	quietly reghdfe ch`h'p x2 x5 x7 if insamp, `fe' vce(cluster year)
	gen byte es = e(sample)
	foreach k in 2 5 7 {
		local b`k' = _b[x`k']
	}

	*** 2. partial out the fixed effects, then bootstrap each coefficient
	quietly reghdfe ch`h'p if es, `fe' residuals(ry) keepsingletons
	foreach k in 2 5 7 {
		quietly reghdfe x`k' if es, `fe' residuals(rx`k') keepsingletons
	}
	quietly regress ry rx2 rx5 rx7 if es, vce(cluster year)

	foreach k in 2 5 7 {
		quietly boottest rx`k', level(68) weighttype(webb) reps(9999) seed(8675309) nograph
		local lo = .
		local hi = .
		capture matrix CI = r(CI)
		if !_rc {
			local lo = CI[1,1]
			local hi = CI[rowsof(CI),2]
		}
		post R ("chy") (`k') (`h') (`b`k'') (`lo') (`hi')
	}
	drop es ry rx2 rx5 rx7
	di "yield change  h = `h'  done"
}
postclose R

*==============================================================================*
* Results
*==============================================================================*

use `res', clear
recode perc (2 = 20) (5 = 40) (7 = 60)
sort perc h
save "$inter/lp_actual_yield_results.dta", replace

list perc h b lo hi, sepby(perc) noobs

*==============================================================================*
* Figure -- one row, P20 / P40 / P60, common y-axis
*==============================================================================*

qui sum lo
local ymin = min(r(min), 0)
qui sum hi
local ymax = max(r(max), 0)
_natscale `ymin' `ymax' 5
local yst = r(delta)
local ylo = `yst' * ceil(`ymin' / `yst') + 0
local yhi = `yst' * floor(`ymax' / `yst') + 0

local names ""
foreach pp in 20 40 60 {
	twoway ///
		(rarea hi lo h if perc == `pp', color(blue%15) lwidth(none)) ///
		(line  b     h if perc == `pp', lcolor(navy) lwidth(medthick)) ///
		, yline(0, lcolor(gs8) lpattern(dash)) ///
		  xlabel(1(1)4, labsize(medium)) ///
		  yscale(range(`ymin' `ymax')) ylabel(`ylo'(`yst')`yhi', labsize(medium) format(%9.2g)) ///
		  xtitle("Horizon (years)", size(medium)) ytitle("pp", size(medium)) ///
		  title("P`pp'", size(medlarge) color(black)) ///
		  graphregion(color(white)) plotregion(color(white)) legend(off) ///
		  name(gchy`pp', replace) nodraw
	local names "`names' gchy`pp'"
}

graph combine `names', cols(3) imargin(small) graphregion(color(white)) xsize(11) ysize(4)

graph export "$figures/lp_actual_yield.pdf", as(pdf) replace
graph export "$figures/lp_actual_yield.png", replace width(2200)
graph drop _all
