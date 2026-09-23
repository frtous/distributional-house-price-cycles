********************************************************************************
* yields_annual.do
*
* Annual change in the 2-year UK nominal spot yield, December to December.
* Inputs:  data/restricted/GLC Nominal month end data_1970 to 2015.xlsx
*          data/restricted/GLC Nominal month end data_2016 to 2024.xlsx
*          (Bank of England, UK nominal government liability curve, month-end
*           data; sheet "3. spot, short end", 24-month maturity in column Y)
* Output:  data/derived/Yields_UK_24m.dta
********************************************************************************

clear all
set more off

*** Month-end date (column A) and 24-month spot yield (column Y), both files
import excel using "$restricted/GLC Nominal month end data_1970 to 2015.xlsx", ///
    sheet("3. spot, short end") cellrange(A6) clear
keep A Y
tempfile early
save `early'

import excel using "$restricted/GLC Nominal month end data_2016 to 2024.xlsx", ///
    sheet("3. spot, short end") cellrange(A6) clear
keep A Y
append using `early'

destring Y, replace force
drop if missing(A)

*** December values and their year-on-year change
keep if month(A) == 12
gen year = year(A)
rename Y Yield_24m

tsset year
gen Ch_yield_24m = D.Yield_24m

keep year Ch_yield_24m
label var Ch_yield_24m "Change in the 2-year nominal spot yield, Dec to Dec, pp"

save "$derived/Yields_UK_24m.dta", replace
