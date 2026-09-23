********************************************************************************
* Maps_Figures.do
*
* Local authority values behind the maps of P20 vs. P80 house price growth:
* chained annual growth over the boom and the bust, and long-run growth on a
* basket matched across the two ends of the sample.
* Inputs:  data/restricted/pp-complete.csv
*          data/restricted/Postcode_to_LAU.dta
* Outputs: data/intermediate/Map_P20P80_A_data_0211_CH.csv
*          data/intermediate/Map_P20P80_LongRun_Matched.csv
********************************************************************************

clear all
set more off


*==============================================================================*
* DATA -- raw transactions to unit x year prices: second-hand, category A,
* 1995-2019, matched to a local authority; mean price and number of
* transactions by postcode x property type x year
*==============================================================================*

import delimited "$restricted/pp-complete.csv", clear
keep v2 v3 v4 v5 v6 v15
rename (v2 v3 v4 v5 v6 v15) (price date postcode property_type new_prop category)

keep if new_prop == "N" & category == "A"
drop new_prop category

split date, p(" ")
gen year = yofd(date(date1, "YMD"))
drop date date1 date2
keep if year <= 2019

rename postcode pcds
merge m:1 pcds using "$restricted/Postcode_to_LAU.dta", keep(match) nogen keepusing(laua)
rename laua lau117cd

collapse (mean) price (count) num = price, by(lau117cd pcds property_type year)

*** Cells with more transactions in a year than the 99th percentile across
*** unit-years are dropped in both figures
summarize num, detail
local maxtx = r(p99)

tempfile units
save `units'


********************************************************************************
* BOOM AND BUST, CHAINED ANNUAL DHPIs
*   For each local authority: 100 x [ sum_t ln(1 + g20_t/100)
*                                    - sum_t ln(1 + g80_t/100) ]
*   over the annual links t = y0+1 ... y1 (winsorised growth, each link on a
*   basket matched between t-1 and t). Missing if any link is missing.
*   The annual DHPIs are built here from the unit x year prices.
*   Boom: 2002-2006 (links 2003-2006); bust: 2007-2011 (links 2008-2011).
********************************************************************************

*** Annual DHPIs for P20 and P80: units observed in consecutive years;
*** percentiles of their prices in t and t-1 by local authority and year;
*** growth winsorised at p1/p99 within year
use `units', clear
drop if num > `maxtx'
egen long id = group(pcds property_type)
xtset id year
gen double l_price = L.price
keep if !missing(price, l_price)

collapse (p20) p20 = price l_p20 = l_price (p80) p80 = price l_p80 = l_price, by(lau117cd year)
foreach p in 20 80 {
    gen double ch_p`p' = 100 * (p`p' - l_p`p') / l_p`p'
    bysort year: egen double lo = pctile(ch_p`p'), p(1)
    bysort year: egen double hi = pctile(ch_p`p'), p(99)
    gen double ch_p`p'_w = min(max(ch_p`p', lo), hi) if !missing(ch_p`p')
    drop lo hi
}

*** Chained growth over each window

foreach w in boom bust {
    if "`w'" == "boom" local y0 = 2002
    if "`w'" == "boom" local y1 = 2006
    if "`w'" == "bust" local y0 = 2007
    if "`w'" == "bust" local y1 = 2011
    foreach p in 20 80 {
        gen double l`p'_`w' = 100 * ln(1 + ch_p`p'_w / 100) if inrange(year, `y0' + 1, `y1')
    }
    local links_`w' = `y1' - `y0'
}

collapse (sum) l20_boom l80_boom l20_bust l80_bust ///
         (count) n20_boom = l20_boom n80_boom = l80_boom ///
                 n20_bust = l20_bust n80_bust = l80_bust, by(lau117cd)

gen double div_boom = l20_boom - l80_boom if n20_boom == `links_boom' & n80_boom == `links_boom'
gen double div_bust = l20_bust - l80_bust if n20_bust == `links_bust' & n80_bust == `links_bust'

summarize div_boom div_bust

keep lau117cd div_boom div_bust
export delimited using "$inter/Map_P20P80_A_data_0211_CH.csv", replace


********************************************************************************
* LONG RUN, BASKET MATCHED ACROSS THE TWO ENDS OF THE SAMPLE
*   Units (postcode x property type) observed in 1995-1997 AND in 2017-2019.
*   Prices net of the national price trend within each window; the P20 and P80
*   of the matched units' prices in each window; divergence in log points:
*   100 x [ ln(P20_post / P20_pre) - ln(P80_post / P80_pre) ]
********************************************************************************

use `units', clear
keep if inrange(year, 1995, 1997) | inrange(year, 2017, 2019)
drop if num > `maxtx'

gen byte post = year >= 2017
egen long id = group(pcds property_type)

*** Remove the national year effect within each window
gen double lp = ln(price)
bysort year: egen double yfe    = mean(lp)
bysort post: egen double yfebar = mean(yfe)
gen double padj = exp(lp - (yfe - yfebar))

*** One price per unit and window: the mean over all its transactions
gen double pn = padj * num
collapse (sum) pn num, by(lau117cd id post)
gen double price = pn / num

*** The matched basket: units observed in both windows
bysort id: gen byte nwin = _N
keep if nwin == 2

*** P20 and P80 of the matched units, by local authority and window
collapse (p20) p20 = price (p80) p80 = price (count) n = price, by(lau117cd post)
reshape wide p20 p80 n, i(lau117cd) j(post)
gen double div_matched = 100 * (ln(p201 / p200) - ln(p801 / p800))
rename n0 n_matched

*** Summary without the Isles of Scilly and the City of London
summarize div_matched if !inlist(lau117cd, "E06000053", "E09000001")

keep lau117cd n_matched div_matched
export delimited using "$inter/Map_P20P80_LongRun_Matched.csv", replace
