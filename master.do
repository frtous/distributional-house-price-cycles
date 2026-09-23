********************************************************************************
* master.do
*
* Replication package for "Distributional house price cycles"
* Francesc Rodriguez Tous, Bayes Business School
*
* Runs every step, from the raw data to the tables and figures in the paper.
* Before running: save the files listed as restricted in data/README.md in
* data/restricted/, then set the path in Section 1. Nothing else needs editing.
*
* To run one step on its own: run Sections 1 to 4, then that do-file.
********************************************************************************

clear all
set more off
version 18


*==============================================================================*
* 1. THE ONLY LINE TO EDIT: where this repository is on your computer
*==============================================================================*

global root "D:/GitHub/distributional-house-price-cycles"


*==============================================================================*
* 2. FOLDERS (all relative to $root; forward slashes work on every system)
*==============================================================================*

global code       "$root/code"
global raw        "$root/data/raw"            // raw downloads (on GitHub)
global derived    "$root/data/derived"        // small derived inputs (not on GitHub)
global restricted "$root/data/restricted"     // large or licensed files (not on GitHub)
global inter      "$root/data/intermediate"   // created by the code (not on GitHub)
global figures    "$root/output/figures"
global tables     "$root/output/tables"
global logs       "$root/output/logs"

foreach d in "$inter" "$root/output" "$figures" "$tables" "$logs" {
    capture mkdir "`d'"
}


*==============================================================================*
* 3. OPTIONS
*==============================================================================*

global run_maps        1         // 1 = draw the two maps (Figures 5 and 6) with Python
global python          "python"  // command that starts Python 3 with geopandas installed
global rebuild_derived 1         // 1 = rebuild the files in data/derived/ from the
                                 //     workbooks in data/restricted/; they are not
                                 //     in the repository, so a fresh copy needs this
global build_indices   1         // 0 = skip Step 1 and reuse the indices already in
                                 //     data/intermediate/ (much faster)


*==============================================================================*
* 4. USER-WRITTEN PACKAGES (installed once, from SSC)
*==============================================================================*

foreach p in ftools reghdfe coefplot boottest {
    capture which `p'
    if _rc ssc install `p'
}


*==============================================================================*
* 5. RUN EVERYTHING
*==============================================================================*

capture log close _all
log using "$logs/master.log", replace text name(master)
global t0 "`c(current_date)' `c(current_time)'"

* Package versions, for the record
foreach p in ftools reghdfe coefplot boottest {
    which `p'
}

*--- Step 0: macro series and monetary policy surprises ------------------------

do "$code/0_inputs/rates_quarterly.do"         // interest rates
do "$code/0_inputs/lending_quarterly.do"       // lending and credit
do "$code/0_inputs/gdp_quarterly.do"           // real GDP growth

* Files in data/derived/ from the restricted workbooks (see the option above)
if $rebuild_derived {
    do "$code/0_inputs/mp_shocks.do"           // monetary policy surprises
    do "$code/0_inputs/yields_annual.do"       // change in the 2-year yield
}

*--- Step 1: indices from the Land Registry data -------------------------------

if $build_indices {
    do "$code/1_indices/DHPI_Quarterly.do"        // quarterly DHPIs; Table A.1 counts
    do "$code/1_indices/DHPI_5Y_LP.do"            // five-year constant-basket DHPIs
    do "$code/1_indices/AltIndex_RepeatUnit.do"   // tiered repeat-unit index
    do "$code/1_indices/AltIndex_RepeatSales.do"  // tiered repeat-sales index
}

*--- Step 2: tables and figures ------------------------------------------------

do "$code/2_results/Summary_Statistics.do"     // Tables 1, A.1, A.2
do "$code/2_results/Descriptive_Figures.do"    // Figures 1-4, A.4
do "$code/2_results/Maps_Figures.do"           // data for Figures 5 and 6

* Figures 5 and 6: the maps are drawn in Python
if $run_maps {
    shell $python "$code/2_results/make_map_p20p80_annual_chained.py"
    shell $python "$code/2_results/make_map_p20p80_longrun.py"
}

do "$code/2_results/Hedonic_HPI_Figures.do"    // Figures 7, A.6, A.11, A.16
do "$code/2_results/Business_Credit_Cycles.do" // Table A.3, Figures 8, A.2, A.3, A.5
do "$code/2_results/Price_of_Credit.do"        // Figures 9, A.7, A.8, Table A.5
do "$code/2_results/Monetary_Policy.do"        // Figures 10, A.9, A.10, A.12, Table A.6
do "$code/2_results/Local_Projections.do"      // Figures 11, A.13-A.15, A.17, A.18
do "$code/2_results/Alternative_Indices.do"    // Figure A.1, Tables A.4 and A.7

display as text _n "Started  $t0" _n "Finished `c(current_date)' `c(current_time)'"
log close master
