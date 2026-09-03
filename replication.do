/*******************************************************************************
Project:    Fuel Demand, Spatial Competition, and Local Market Structure
Author:     David Ricardo Gonzales Pena
Purpose:    Reproduce the empirical tables reported in the paper
Software:   Stata 17 or later recommended
Input:      data/fuel_demand_lima_callao.dta
Outputs:    output/tables, output/data, and output/logs

Run this file from the repository root:
    do "code/replication.do"

The script also detects execution from the code/ directory and moves to the
repository root. It never modifies the source dataset.
*******************************************************************************/

version 17.0
clear all
set more off
set linesize 255
set varabbrev off

* -----------------------------------------------------------------------------
* 0. Portable project setup
* -----------------------------------------------------------------------------

local data_file "data/fuel_demand_lima_callao.dta"

capture confirm file "`data_file'"
if _rc {
    capture confirm file "../`data_file'"
    if !_rc cd ".."
}

capture confirm file "`data_file'"
if _rc {
    display as error "Data file not found: `data_file'"
    display as error "Set Stata's working directory to the repository root and run:"
    display as error `"do "code/replication.do""'
    exit 601
}

global PROJECT "`c(pwd)'"
global DATA    "$PROJECT/data/fuel_demand_lima_callao.dta"
global TABLES  "$PROJECT/output/tables"
global OUTDATA "$PROJECT/output/data"
global LOGS    "$PROJECT/output/logs"

capture mkdir "$PROJECT/output"
capture mkdir "$TABLES"
capture mkdir "$OUTDATA"
capture mkdir "$LOGS"

capture log close _all
log using "$LOGS/replication.log", replace text name(replication)

display as text "Repository root: $PROJECT"
display as text "Input data:     $DATA"

* -----------------------------------------------------------------------------
* 0.1 Install required community-contributed packages only when missing
* -----------------------------------------------------------------------------

capture which ftools
if _rc ssc install ftools

capture which reghdfe
if _rc ssc install reghdfe

capture which esttab
if _rc ssc install estout

capture which ivreg2
if _rc ssc install ivreg2

capture which ranktest
if _rc ssc install ranktest

capture which ivreghdfe
if _rc ssc install ivreghdfe

which reghdfe
which esttab
which ivreg2
which ivreghdfe

* -----------------------------------------------------------------------------
* 0.2 Load and validate the analysis data
* -----------------------------------------------------------------------------

use "$DATA", clear

local required_variables ///
    distrito_id distrito fecha_m year month quarter semester ///
    producto_id producto demanda_galones_dia ln_q precio_real ln_p ///
    sample_main nivel_ingreso_proxy income_group ///
    competencia_promedio_455m competencia_promedio_800m ///
    competencia_promedio_1000m pbi_yoy_m ln_flow_lima_total ///
    stringency_m usdpen_m prc_g90_ref_usdbl_m prc_g95_ref_usdbl_m ///
    z_bartik_dprc_l8_1000

local missing_variables ""
foreach variable of local required_variables {
    capture confirm variable `variable'
    if _rc local missing_variables "`missing_variables' `variable'"
}

if "`missing_variables'" != "" {
    display as error "Required variables are missing:`missing_variables'"
    log close replication
    exit 111
}

isid distrito_id fecha_m producto_id
assert inlist(producto_id, 1, 2)
assert inrange(year, 2020, 2022)

format fecha_m %tm
format quarter %tq
format semester %th

capture drop replication_sample replication_g90 replication_g95
capture drop replication_2021 replication_g90_2021 replication_g95_2021

generate byte replication_sample = sample_main == 1 ///
    & !missing(distrito_id, fecha_m, producto_id, ln_q, ln_p)
generate byte replication_g90 = replication_sample == 1 & producto_id == 1
generate byte replication_g95 = replication_sample == 1 & producto_id == 2
generate byte replication_2021 = replication_sample == 1 & year >= 2021
generate byte replication_g90_2021 = replication_2021 == 1 & producto_id == 1
generate byte replication_g95_2021 = replication_2021 == 1 & producto_id == 2

label variable replication_sample "Main complete-case analysis sample"
label variable replication_g90 "G90 complete-case analysis sample"
label variable replication_g95 "G95 complete-case analysis sample"
label variable replication_2021 "2021-2022 complete-case analysis sample"

count if replication_sample
display as result "Main complete-case sample: " r(N)
count if replication_g90
display as result "G90 complete-case sample:  " r(N)
count if replication_g95
display as result "G95 complete-case sample:  " r(N)

* The source file should contain 3,330 rows and 3,272 complete observations.
assert _N == 3330
count if replication_sample
assert r(N) == 3272

* Preserve a compact record of the exact sample definitions used here.
save "$OUTDATA/analysis_dataset_with_replication_flags.dta", replace

* -----------------------------------------------------------------------------
* 1. Descriptive statistics (paper Table 1)
* -----------------------------------------------------------------------------

eststo clear

quietly estpost summarize ///
    precio_real demanda_galones_dia ///
    competencia_promedio_455m competencia_promedio_800m ///
    competencia_promedio_1000m nivel_ingreso_proxy ///
    prc_g90_ref_usdbl_m prc_g95_ref_usdbl_m ///
    pbi_yoy_m ln_flow_lima_total stringency_m usdpen_m ///
    if replication_g90
eststo T1_G90

quietly estpost summarize ///
    precio_real demanda_galones_dia ///
    competencia_promedio_455m competencia_promedio_800m ///
    competencia_promedio_1000m nivel_ingreso_proxy ///
    prc_g90_ref_usdbl_m prc_g95_ref_usdbl_m ///
    pbi_yoy_m ln_flow_lima_total stringency_m usdpen_m ///
    if replication_g95
eststo T1_G95

quietly estpost summarize ///
    precio_real demanda_galones_dia ///
    competencia_promedio_455m competencia_promedio_800m ///
    competencia_promedio_1000m nivel_ingreso_proxy ///
    prc_g90_ref_usdbl_m prc_g95_ref_usdbl_m ///
    pbi_yoy_m ln_flow_lima_total stringency_m usdpen_m ///
    if replication_sample
eststo T1_All

esttab T1_G90 T1_G95 T1_All using "$TABLES/table_1_descriptive_statistics.rtf", ///
    cells("mean(fmt(2)) sd(fmt(2)) count(fmt(0))") ///
    mtitles("G90" "G95" "All") label nonumber replace ///
    title("Table 1. Descriptive statistics")

esttab T1_G90 T1_G95 T1_All using "$TABLES/table_1_descriptive_statistics.csv", ///
    cells("mean(fmt(4)) sd(fmt(4)) count(fmt(0))") ///
    mtitles("G90" "G95" "All") label nonumber replace

* -----------------------------------------------------------------------------
* 2. Main fixed-effects estimates (paper Table 2)
* reghdfe's default singleton handling reproduces the main-table convention.
* -----------------------------------------------------------------------------

eststo clear

quietly reghdfe ln_q ln_p if replication_g90, ///
    absorb(distrito_id fecha_m) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
estadd local Period "Full sample"
eststo T2_G90_Full

quietly reghdfe ln_q ln_p if replication_g95, ///
    absorb(distrito_id fecha_m) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
estadd local Period "Full sample"
eststo T2_G95_Full

quietly reghdfe ln_q ln_p if replication_g90_2021, ///
    absorb(distrito_id fecha_m) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
estadd local Period "2021-2022"
eststo T2_G90_2021

quietly reghdfe ln_q ln_p if replication_g95_2021, ///
    absorb(distrito_id fecha_m) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
estadd local Period "2021-2022"
eststo T2_G95_2021

esttab T2_G90_Full T2_G95_Full T2_G90_2021 T2_G95_2021 ///
    using "$TABLES/table_2_main_fixed_effects.rtf", ///
    keep(ln_p) se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("G90 Full" "G95 Full" "G90 2021-2022" "G95 2021-2022") ///
    stats(DistrictFE MonthFE N, labels("District fixed effects" ///
    "Month fixed effects" "Observations")) label replace ///
    title("Table 2. Main results: price elasticity of gasohol demand")

esttab T2_G90_Full T2_G95_Full T2_G90_2021 T2_G95_2021 ///
    using "$TABLES/table_2_main_fixed_effects.csv", ///
    keep(ln_p) se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("G90 Full" "G95 Full" "G90 2021-2022" "G95 2021-2022") ///
    stats(N, labels("Observations")) label replace

* -----------------------------------------------------------------------------
* 3. Complementary specifications with aggregate controls (paper Table 3)
* Month fixed effects are omitted because the controls vary only by month.
* -----------------------------------------------------------------------------

eststo clear

quietly reghdfe ln_q ln_p pbi_yoy_m ln_flow_lima_total stringency_m usdpen_m ///
    if replication_sample, absorb(distrito_id producto_id) ///
    vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local ProductFE "Yes"
estadd local MonthFE "No"
eststo T3_Pooled

quietly reghdfe ln_q ln_p pbi_yoy_m ln_flow_lima_total stringency_m usdpen_m ///
    if replication_g90, absorb(distrito_id) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local ProductFE "No"
estadd local MonthFE "No"
eststo T3_G90

quietly reghdfe ln_q ln_p pbi_yoy_m ln_flow_lima_total stringency_m usdpen_m ///
    if replication_g95, absorb(distrito_id) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local ProductFE "No"
estadd local MonthFE "No"
eststo T3_G95

esttab T3_Pooled T3_G90 T3_G95 ///
    using "$TABLES/table_3_aggregate_controls.rtf", ///
    keep(ln_p pbi_yoy_m ln_flow_lima_total stringency_m) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Pooled" "G90" "G95") ///
    stats(DistrictFE ProductFE MonthFE N, labels("District fixed effects" ///
    "Product fixed effects" "Month fixed effects" "Observations")) ///
    label replace title("Table 3. Complementary specifications with aggregate controls")

esttab T3_Pooled T3_G90 T3_G95 ///
    using "$TABLES/table_3_aggregate_controls.csv", ///
    keep(ln_p pbi_yoy_m ln_flow_lima_total stringency_m) ///
    se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("Pooled" "G90" "G95") stats(N) label replace

* -----------------------------------------------------------------------------
* 4. Income-by-time robustness (paper Table 4)
* -----------------------------------------------------------------------------

eststo clear

foreach product in 1 2 {
    if `product' == 1 local product_name "G90"
    if `product' == 2 local product_name "G95"

    quietly reghdfe ln_q ln_p if replication_sample & producto_id == `product', ///
        absorb(distrito_id fecha_m income_group#quarter) ///
        vce(cluster distrito_id)
    estadd local DistrictFE "Yes"
    estadd local MonthFE "Yes"
    estadd local Interaction "Income x quarter"
    eststo T4_`product_name'_Q_Full

    quietly reghdfe ln_q ln_p if replication_2021 & producto_id == `product', ///
        absorb(distrito_id fecha_m income_group#quarter) ///
        vce(cluster distrito_id)
    estadd local DistrictFE "Yes"
    estadd local MonthFE "Yes"
    estadd local Interaction "Income x quarter"
    eststo T4_`product_name'_Q_2021

    quietly reghdfe ln_q ln_p if replication_sample & producto_id == `product', ///
        absorb(distrito_id fecha_m income_group#semester) ///
        vce(cluster distrito_id)
    estadd local DistrictFE "Yes"
    estadd local MonthFE "Yes"
    estadd local Interaction "Income x semester"
    eststo T4_`product_name'_S_Full

    quietly reghdfe ln_q ln_p if replication_2021 & producto_id == `product', ///
        absorb(distrito_id fecha_m income_group#semester) ///
        vce(cluster distrito_id)
    estadd local DistrictFE "Yes"
    estadd local MonthFE "Yes"
    estadd local Interaction "Income x semester"
    eststo T4_`product_name'_S_2021
}

esttab T4_G90_Q_Full T4_G95_Q_Full T4_G90_Q_2021 T4_G95_Q_2021 ///
    using "$TABLES/table_4_panel_a_income_quarter.rtf", ///
    keep(ln_p) se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("G90 Full" "G95 Full" "G90 2021-2022" "G95 2021-2022") ///
    stats(DistrictFE MonthFE Interaction N, labels("District fixed effects" ///
    "Month fixed effects" "Income-time interaction" "Observations")) ///
    label replace title("Table 4, Panel A. District income by quarter")

esttab T4_G90_S_Full T4_G95_S_Full T4_G90_S_2021 T4_G95_S_2021 ///
    using "$TABLES/table_4_panel_b_income_semester.rtf", ///
    keep(ln_p) se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("G90 Full" "G95 Full" "G90 2021-2022" "G95 2021-2022") ///
    stats(DistrictFE MonthFE Interaction N, labels("District fixed effects" ///
    "Month fixed effects" "Income-time interaction" "Observations")) ///
    label replace title("Table 4, Panel B. District income by semester")

esttab T4_G90_Q_Full T4_G95_Q_Full T4_G90_Q_2021 T4_G95_Q_2021 ///
    T4_G90_S_Full T4_G95_S_Full T4_G90_S_2021 T4_G95_S_2021 ///
    using "$TABLES/table_4_income_time_robustness.csv", ///
    keep(ln_p) se star(* 0.10 ** 0.05 *** 0.01) stats(N) label replace

* -----------------------------------------------------------------------------
* 5. Instrumental-variable diagnostic (paper Table 5)
* The paper treats this exercise as a diagnostic, not as the preferred model.
* -----------------------------------------------------------------------------

local instrument z_bartik_dprc_l8_1000
eststo clear

quietly reghdfe ln_q ln_p if replication_g90_2021, ///
    absorb(distrito_id fecha_m) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
eststo T5_OLS

quietly reghdfe ln_p `instrument' if replication_g90_2021, ///
    absorb(distrito_id fecha_m) vce(cluster distrito_id)
quietly test `instrument'
scalar first_stage_F = r(F)
scalar first_stage_p = r(p)
estadd scalar FirstStageF = first_stage_F
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
eststo T5_FirstStage

quietly reghdfe ln_q `instrument' if replication_g90_2021, ///
    absorb(distrito_id fecha_m) vce(cluster distrito_id)
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
eststo T5_ReducedForm

quietly ivreghdfe ln_q (ln_p = `instrument') if replication_g90_2021, ///
    absorb(distrito_id fecha_m) cluster(distrito_id) first
estadd scalar FirstStageF = first_stage_F
estadd local DistrictFE "Yes"
estadd local MonthFE "Yes"
eststo T5_IV

esttab T5_OLS T5_FirstStage T5_ReducedForm T5_IV ///
    using "$TABLES/table_5_iv_diagnostic.rtf", ///
    keep(ln_p `instrument') se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("OLS" "First stage" "Reduced form" "IV") ///
    stats(FirstStageF DistrictFE MonthFE N, labels("First-stage F" ///
    "District fixed effects" "Month fixed effects" "Observations")) ///
    label replace title("Table 5. IV diagnostic: PRC shift-share, G90 2021-2022")

esttab T5_OLS T5_FirstStage T5_ReducedForm T5_IV ///
    using "$TABLES/table_5_iv_diagnostic.csv", ///
    keep(ln_p `instrument') se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("OLS" "First stage" "Reduced form" "IV") ///
    stats(FirstStageF N) label replace

display as result "Table 5 first-stage F statistic: " %9.3f first_stage_F
display as result "Table 5 first-stage p-value:     " %9.4f first_stage_p

* -----------------------------------------------------------------------------
* 6. Appendix Tables 7-8: systematic PRC-instrument diagnostics
* -----------------------------------------------------------------------------

tempname diagnostic_results
postfile `diagnostic_results' ///
    str10 family str4 product str6 form int radius int lag ///
    str32 instrument double fs_coef fs_se fs_F fs_p rf_coef rf_se rf_p N ///
    using "$OUTDATA/prc_instrument_diagnostics.dta", replace

foreach family in simple bartik {
    foreach product in 1 2 {
        if `product' == 1 {
            local product_name "G90"
            local sample_flag "replication_g90_2021"
        }
        else {
            local product_name "G95"
            local sample_flag "replication_g95_2021"
        }

        foreach radius in 455 800 1000 {
            foreach lag of numlist 1/12 {
                foreach form in level log dlog {
                    if "`family'" == "simple" & "`form'" == "level" ///
                        local candidate z_prcprod_l`lag'_`radius'
                    if "`family'" == "simple" & "`form'" == "log" ///
                        local candidate zln_prcprod_l`lag'_`radius'
                    if "`family'" == "simple" & "`form'" == "dlog" ///
                        local candidate zdln_prcprod_l`lag'_`radius'
                    if "`family'" == "bartik" & "`form'" == "log" ///
                        local candidate z_bartik_lnprc_l`lag'_`radius'
                    if "`family'" == "bartik" & "`form'" == "dlog" ///
                        local candidate z_bartik_dprc_l`lag'_`radius'

                    * No level shift-share series is defined in the source data.
                    if "`family'" == "bartik" & "`form'" == "level" continue

                    capture confirm variable `candidate'
                    if _rc continue

                    capture quietly reghdfe ln_p `candidate' ///
                        if `sample_flag', absorb(distrito_id fecha_m) ///
                        vce(cluster distrito_id)
                    if _rc continue

                    local fs_coef = _b[`candidate']
                    local fs_se = _se[`candidate']
                    local observations = e(N)
                    quietly test `candidate'
                    local fs_F = r(F)
                    local fs_p = r(p)

                    capture quietly reghdfe ln_q `candidate' ///
                        if `sample_flag', absorb(distrito_id fecha_m) ///
                        vce(cluster distrito_id)
                    if _rc continue

                    local rf_coef = _b[`candidate']
                    local rf_se = _se[`candidate']
                    quietly test `candidate'
                    local rf_p = r(p)

                    post `diagnostic_results' ("`family'") ("`product_name'") ///
                        ("`form'") (`radius') (`lag') ("`candidate'") ///
                        (`fs_coef') (`fs_se') (`fs_F') (`fs_p') ///
                        (`rf_coef') (`rf_se') (`rf_p') (`observations')
                }
            }
        }
    }
}

postclose `diagnostic_results'

preserve
use "$OUTDATA/prc_instrument_diagnostics.dta", clear
sort family product fs_p
export delimited using "$TABLES/appendix_tables_7_8_prc_diagnostics.csv", replace
restore

* -----------------------------------------------------------------------------
* 7. Appendix Table 9: temporal robustness
* The appendix retains singleton groups to match its reported sample convention.
* -----------------------------------------------------------------------------

eststo clear

foreach product in 1 2 {
    if `product' == 1 local product_name "G90"
    if `product' == 2 local product_name "G95"

    quietly reghdfe ln_q ln_p if replication_sample & producto_id == `product', ///
        absorb(distrito_id fecha_m) vce(cluster distrito_id) keepsingletons
    eststo T9_`product_name'_Full

    quietly reghdfe ln_q ln_p if replication_sample & producto_id == `product' ///
        & !inrange(fecha_m, tm(2020m3), tm(2020m6)), ///
        absorb(distrito_id fecha_m) vce(cluster distrito_id) keepsingletons
    eststo T9_`product_name'_NoEarlyCovid

    quietly reghdfe ln_q ln_p if replication_sample & producto_id == `product' ///
        & year >= 2021, absorb(distrito_id fecha_m) ///
        vce(cluster distrito_id) keepsingletons
    eststo T9_`product_name'_2021

    quietly reghdfe ln_q ln_p if replication_sample & producto_id == `product' ///
        & year == 2022, absorb(distrito_id fecha_m) ///
        vce(cluster distrito_id) keepsingletons
    eststo T9_`product_name'_2022
}

esttab T9_G90_Full T9_G90_NoEarlyCovid T9_G90_2021 T9_G90_2022 ///
    T9_G95_Full T9_G95_NoEarlyCovid T9_G95_2021 T9_G95_2022 ///
    using "$TABLES/appendix_table_9_temporal_robustness.rtf", ///
    keep(ln_p) se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("G90 Full" "G90 excl. 2020m3-m6" "G90 2021-2022" "G90 2022" ///
    "G95 Full" "G95 excl. 2020m3-m6" "G95 2021-2022" "G95 2022") ///
    stats(N, labels("Observations")) label replace ///
    title("Appendix Table 9. Temporal robustness")

esttab T9_G90_Full T9_G90_NoEarlyCovid T9_G90_2021 T9_G90_2022 ///
    T9_G95_Full T9_G95_NoEarlyCovid T9_G95_2021 T9_G95_2022 ///
    using "$TABLES/appendix_table_9_temporal_robustness.csv", ///
    keep(ln_p) se star(* 0.10 ** 0.05 *** 0.01) stats(N) label replace

* -----------------------------------------------------------------------------
* 8. Appendix Table 10: alternative functional forms, 2021-2022
* -----------------------------------------------------------------------------

capture drop asinh_q
generate double asinh_q = asinh(demanda_galones_dia)
label variable asinh_q "Inverse hyperbolic sine of quantity"

eststo clear

foreach product in 1 2 {
    if `product' == 1 local product_name "G90"
    if `product' == 2 local product_name "G95"

    quietly reghdfe ln_q ln_p if replication_2021 & producto_id == `product', ///
        absorb(distrito_id fecha_m) vce(cluster distrito_id) keepsingletons
    eststo T10_`product_name'_LogLog

    quietly reghdfe demanda_galones_dia ln_p ///
        if replication_2021 & producto_id == `product', ///
        absorb(distrito_id fecha_m) vce(cluster distrito_id) keepsingletons
    eststo T10_`product_name'_LevelLog

    quietly reghdfe ln_q precio_real ///
        if replication_2021 & producto_id == `product', ///
        absorb(distrito_id fecha_m) vce(cluster distrito_id) keepsingletons
    eststo T10_`product_name'_LogLevel

    quietly reghdfe asinh_q ln_p ///
        if replication_2021 & producto_id == `product', ///
        absorb(distrito_id fecha_m) vce(cluster distrito_id) keepsingletons
    eststo T10_`product_name'_AsinhLog
}

esttab T10_G90_LogLog T10_G90_LevelLog T10_G90_LogLevel T10_G90_AsinhLog ///
    T10_G95_LogLog T10_G95_LevelLog T10_G95_LogLevel T10_G95_AsinhLog ///
    using "$TABLES/appendix_table_10_functional_forms.rtf", ///
    keep(ln_p precio_real) se star(* 0.10 ** 0.05 *** 0.01) ///
    mtitles("G90 log-log" "G90 level-log" "G90 log-level" "G90 asinh-log" ///
    "G95 log-log" "G95 level-log" "G95 log-level" "G95 asinh-log") ///
    stats(N, labels("Observations")) label replace ///
    title("Appendix Table 10. Alternative functional forms, 2021-2022")

esttab T10_G90_LogLog T10_G90_LevelLog T10_G90_LogLevel T10_G90_AsinhLog ///
    T10_G95_LogLog T10_G95_LevelLog T10_G95_LogLevel T10_G95_AsinhLog ///
    using "$TABLES/appendix_table_10_functional_forms.csv", ///
    keep(ln_p precio_real) se star(* 0.10 ** 0.05 *** 0.01) ///
    stats(N) label replace

* -----------------------------------------------------------------------------
* 9. Completion message
* -----------------------------------------------------------------------------

display as result "============================================================"
display as result "Replication script completed."
display as result "Tables: $TABLES"
display as result "Derived data: $OUTDATA"
display as result "Log: $LOGS/replication.log"
display as result "============================================================"

log close replication
exit, clear
