********************************************************************************
* Summary_Statistics.do
*
* Tables of the sample at each construction step and of summary statistics of
* the DHPIs.
* Inputs:  data/intermediate/DHPI_steps.dta
*          data/intermediate/SeriesQReady_WIDE.dta
* Outputs: output/tables/dhpi_steps.tex
*          output/tables/summary_stats.tex
*          output/tables/summary_stats_deciles.tex
********************************************************************************

clear all
set more off

*==============================================================================*
* OBSERVATIONS AFTER EACH CONSTRUCTION STEP
*==============================================================================*

use "$inter/DHPI_steps.dta", clear

*** Counts, and observations dropped at each step (none for steps 1, 5 and 8)
forvalues s = 1/9 {
    local N`s' = trim(string(obs[`s'], "%15.0fc"))
}
foreach s in 2 3 4 6 7 9 {
    local C`s' = trim(string(obs[`s' - 1] - obs[`s'], "%15.0fc"))
}

file open T using "$tables/dhpi_steps.tex", write replace text
file write T "\begin{tabular}{llrr} \hline" _n
file write T "Step & Unit of observation & Observations & Change \\ \hline" _n
file write T " &  &  &  \\" _n
file write T "\multicolumn{4}{l}{\textit{A. Transactions}} \\" _n
file write T "(1) Price Paid Data, 1995--2019 & Transaction & `N1' &  \\" _n
file write T "(2) Standard price-paid transactions (category A) & Transaction & `N2' & \$-\$`C2' \\" _n
file write T "(3) Second-hand properties only & Transaction & `N3' & \$-\$`C3' \\" _n
file write T "(4) Postcode matched to a local area & Transaction & `N4' & \$-\$`C4' \\" _n
file write T " &  &  &  \\" _n
file write T "\multicolumn{4}{l}{\textit{B. Units}} \\" _n
file write T "(5) Collapse to units (postcode \$\times\$ property type \$\times\$ quarter) & Unit-quarter & `N5' &  \\" _n
file write T "(6) Drop cells above the 99th percentile of transactions & Unit-quarter & `N6' & \$-\$`C6' \\" _n
file write T "(7) Keep units also observed four quarters earlier & Unit-quarter & `N7' & \$-\$`C7' \\" _n
file write T " &  &  &  \\" _n
file write T "\multicolumn{4}{l}{\textit{C. Local markets}} \\" _n
file write T "(8) Percentiles by local area and quarter & Local area-quarter & `N8' &  \\" _n
file write T "(9) Balanced panel: local areas observed in all 96 quarters & Local area-quarter & `N9' & \$-\$`C9' \\ \hline" _n
file write T "\end{tabular}" _n
file close T


*==============================================================================*
* SUMMARY STATISTICS
*==============================================================================*

use "$inter/SeriesQReady_WIDE.dta", clear

*** Samples: all local areas and quarters; baseline (d_min1) and decile
*** (d_min2) samples over 1998q2-2019q4
gen byte s1 = 1
gen byte s2 = d_min1 == 1 & inrange(quarter, tq(1998q2), tq(2019q4))
gen byte s3 = d_min2 == 1 & inrange(quarter, tq(1998q2), tq(2019q4))

*** Panel A (num = matched repeat units per local area-quarter)
forvalues c = 1/3 {
    egen tl`c' = tag(lau117cd) if s`c'
    egen tq`c' = tag(quarter) if s`c'
    count if tl`c' == 1
    local lau`c' = r(N)
    count if tq`c' == 1
    local nq`c' = r(N)
    summarize quarter if s`c', meanonly
    local q0`c' = strupper(string(r(min), "%tq"))
    local q1`c' = strupper(string(r(max), "%tq"))
    summarize num if s`c', detail
    local obs`c'  = r(N)
    local sum`c'  = r(sum)
    local mean`c' = r(mean)
    local p10`c'  = r(p10)
    local p50`c'  = r(p50)
    local p90`c'  = r(p90)
}

*** Thresholds: median and 75th percentile of min_num across local areas
summarize min_num if tl1 == 1, detail
local thr1 = r(p50)
local thr2 = r(p75)

*** Panel B and the decile table. Growth: mean and sd over the baseline (G1)
*** and decile (G2) samples
foreach p in 10 20 25 30 40 50 60 70 75 80 90 {
    summarize ch_p`p'_w if s2
    local G1m`p'  = r(mean)
    local G1sd`p' = r(sd)
    summarize ch_p`p'_w if s3
    local G2m`p'  = r(mean)
    local G2sd`p' = r(sd)
}

*** Price levels (GBP thousand) in 1996 and 2019: mean over the quarters of
*** each year within a local area, then across local areas (L1, L2)
gen year = yofd(dofq(quarter))
forvalues d = 1/2 {
    preserve
    keep if d_min`d' == 1 & inlist(year, 1996, 2019)
    collapse (mean) p10 p20 p25 p30 p40 p50 p60 p70 p75 p80 p90, by(lau117cd year)
    collapse (mean) p10 p20 p25 p30 p40 p50 p60 p70 p75 p80 p90, by(year)
    sort year
    foreach p in 10 20 25 30 40 50 60 70 75 80 90 {
        local L`d'a`p' = p`p'[1] / 1000
        local L`d'b`p' = p`p'[2] / 1000
    }
    restore
}

*** Panels A and B, two stacked tabulars
file open T using "$tables/summary_stats.tex", write replace text
file write T "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lccc@{}} \hline" _n
file write T " & (1) & (2) & (3) \\" _n
file write T " & All local areas & Baseline sample & Decile sample \\ \hline" _n
file write T "\multicolumn{4}{l}{\textit{Panel A. The panel}} \\" _n
file write T "Local areas & `lau1' & `lau2' & `lau3' \\" _n
file write T "Quarters & `nq1' & `nq2' & `nq3' \\" _n
file write T "First quarter & `q01' & `q02' & `q03' \\" _n
file write T "Last quarter & `q11' & `q12' & `q13' \\" _n
file write T "Local area-quarter observations & " %12.0fc (`obs1') " & " %12.0fc (`obs2') " & " %12.0fc (`obs3') " \\" _n
file write T "Matched repeat units, total & " %14.0fc (`sum1') " & " %14.0fc (`sum2') " & " %14.0fc (`sum3') " \\" _n
file write T "\multicolumn{4}{l}{Matched repeat units per local area-quarter:} \\" _n
file write T "\quad Mean & " %8.1f (`mean1') " & " %8.1f (`mean2') " & " %8.1f (`mean3') " \\" _n
file write T "\quad 10th percentile & " %8.0f (`p101') " & " %8.0f (`p102') " & " %8.0f (`p103') " \\" _n
file write T "\quad Median & " %8.0f (`p501') " & " %8.0f (`p502') " & " %8.0f (`p503') " \\" _n
file write T "\quad 90th percentile & " %8.0f (`p901') " & " %8.0f (`p902') " & " %8.0f (`p903') " \\" _n
file write T "Minimum units per local area, threshold & --- & " %6.0f (`thr1') " & " %6.0f (`thr2') " \\ \hline" _n
file write T "\end{tabular*}" _n _n
file write T "\vspace{0.3cm}" _n _n
file write T "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc@{}} \hline" _n
file write T " & \multicolumn{2}{c}{Year-on-year growth (\%)} & \multicolumn{2}{c}{Price level (\pounds{} thousand)} \\" _n
file write T "\cline{2-3}\cline{4-5}" _n
file write T " & Mean & Std. dev. & 1996 & 2019 \\ \hline" _n
file write T "\multicolumn{5}{l}{\textit{Panel B. DHPI growth and price levels, by percentile}} \\" _n
foreach p in 20 25 40 50 60 75 80 {
    file write T "P`p' & " %7.2f (`G1m`p'') " & " %7.2f (`G1sd`p'') " & " %8.1f (`L1a`p'') " & " %8.1f (`L1b`p'') " \\" _n
}
file write T "\hline" _n
file write T "\end{tabular*}" _n
file close T

*** P10-P90 set, decile sample
file open T using "$tables/summary_stats_deciles.tex", write replace text
file write T "\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc@{}} \hline" _n
file write T " & \multicolumn{2}{c}{Year-on-year growth (\%)} & \multicolumn{2}{c}{Price level (\pounds{} thousand)} \\" _n
file write T "\cline{2-3}\cline{4-5}" _n
file write T " & Mean & Std. dev. & 1996 & 2019 \\ \hline" _n
foreach p in 10 20 30 40 50 60 70 80 90 {
    file write T "P`p' & " %7.2f (`G2m`p'') " & " %7.2f (`G2sd`p'') " & " %8.1f (`L2a`p'') " & " %8.1f (`L2b`p'') " \\" _n
}
file write T "\hline" _n
file write T "\end{tabular*}" _n
file close T
