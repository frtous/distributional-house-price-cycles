********************************************************************************
* lending_quarterly.do
*
* Converts the raw Bank of England lending file into quarterly series.
* Input:  data/raw/boe_lending_monthly_2026-09-22.csv
* Output: data/intermediate/lending_quarterly.dta
********************************************************************************

clear all
set more off

*** Monthly series
import delimited using "$raw/boe_lending_monthly_2026-09-22.csv", ///
    varnames(1) case(preserve) clear
rename (LPMVTVJ LPMVTXK LPMVTVX LPMBI2O) ///
       (net_secured mortgage_debt approvals_hp consumer_credit)
recast double net_secured mortgage_debt approvals_hp consumer_credit
gen m = mofd(date(DATE, "DMY"))
gen quarter = qofd(dofm(m))
format quarter %tq

*** Flows: average of the three months in the quarter
preserve
collapse (mean) net_secured approvals_hp, by(quarter)
tempfile flows
save `flows'
restore

*** Stocks: value at the end of the quarter
keep if inlist(month(dofm(m)), 3, 6, 9, 12)
keep quarter mortgage_debt consumer_credit
merge 1:1 quarter using `flows', nogen

*** Lagged stock and 4-quarter growth rates; keep 1995q1-2019q4
tsset quarter
gen double l1_mortgage_debt  = L.mortgage_debt
gen double mortgage_debt_g   = 100 * (mortgage_debt / L4.mortgage_debt - 1)
gen double consumer_credit_g = 100 * (consumer_credit / L4.consumer_credit - 1)

keep if inrange(quarter, tq(1995q1), tq(2019q4))
keep quarter net_secured approvals_hp l1_mortgage_debt mortgage_debt_g consumer_credit_g

label variable quarter           "Quarter"
label variable net_secured       "Net secured lending, quarterly average (LPMVTVJ), GBP m per month"
label variable approvals_hp      "Approvals for house purchase, quarterly average (LPMVTVX), number"
label variable l1_mortgage_debt  "Secured lending outstanding, end of previous quarter (LPMVTXK), GBP m"
label variable mortgage_debt_g   "Secured lending outstanding, growth over 4 quarters (LPMVTXK), %"
label variable consumer_credit_g "Consumer credit outstanding, growth over 4 quarters (LPMBI2O), %"

order quarter net_secured approvals_hp l1_mortgage_debt mortgage_debt_g consumer_credit_g
compress
save "$inter/lending_quarterly.dta", replace
