********************************************************************************
******************             Consumption Poverty           *******************
********************************************************************************
** add debt variables from the new version of the CE Data
preserve
use "C:\Users\jeehoon_han\Dropbox\Poverty\stata\cons_final_1960_2023_v2024_3.dta", clear
keep if year>=1980
sum cons6 qyear
keep newid qyear credtyrx othlnyrx stdntyrx debt4 debt5 debt6
tempfile debt
save `debt'
restore 

* step 0) make a new data with essential variables
use "C:\Users\jeehoon_han\Dropbox\Poverty\stata\cons_final_1960_2022_v2023_2.dta", clear
*use "C:\Users\jeehoon_han\Dropbox\Poverty\stata\cons_final_1960_2023_v2024_1.dta", clear
keep if year>=1980

merge 1:1 newid qyear using `debt'
keep if _merge==3
drop _merge
sum cons6 qyear
* delete some consumption measures 
drop cons1 cons2 cons3 cons5 cons7 cons9
rename cons4 cons1 // unadjusted total expenditure 

********************************************************************************
** added on 12/9 
bysort srv_year: tab interi
* debts 
drop tot_debt
gen tot_debt = debt1 + debt2 if qyear >= 1132 & !missing(qyear)
gen tot_debt_chg = debt1 + debt2 - (debt4 + debt5) if qyear >= 1132 & !missing(qyear)

*Restrict change in debts to those with observed debts
replace tot_debt_chg = . if missing(tot_debt)

* change in S-D
gen astdebt_chg = tot_ass_chg-tot_debt_chg

sum cons6 astdebt_chg tot_ass_chg tot_debt_chg tot_assets tot_debt stockx liquidx stockyrx liqudyrx debt1 debt2 debt4 debt5 if srv_year>115 & interi==4 



********************************************************************************



replace perinspq=0 if perinspq==.
replace perinscq=0 if perinscq==.
gen totexppq = foodpq+alcbevpq+houspq+apparpq+transpq+healthpq+entertpq+perscapq+readpq+educapq+tobaccpq+miscpq+cashcopq+perinspq
gen totexpcq = foodcq+alcbevcq+houscq+apparcq+transcq+healthcq+entertcq+perscacq+readcq+educacq+tobacccq+misccq+cashcocq+perinscq
gen totexpq = totexppq+totexpcq

gen cons2 = cons6+ (tot_ass_chg/scale/4) // C+S
gen cons3 = cons6+ (tot_ass_chg/scale/4) // C+S
gen cons4 = cons6+ ((tot_assets-tot_debt)/scale/4) // C+S-D (asset level)
gen cons5 = cons6+ (astdebt_chg/scale/4) // C+S-D
*gen cons7 = cons6 - (n_tot_vflow1+gasmopq+gasmocq+pubtrapq+pubtracq)/scale // total consumption less transportation
*gen cons7 = (educapq+educacq)/scale // education expenditure 
gen cons7 = cons6- (tot_debt_chg/scale/4) // C-D
*gen cons7 = nonincmx/scale // non-income money
* cons8: before-tax income - food stamps (fincbtax - fstamp) / scale
gen cons9 = lumpsumx_m_/scale // lumpsum money
replace cons9=0 if lumpsumx_m_==.
keep if ref_year>=2015


* keep savings sample (for Appendix Figure)
*keep if cons5!=.

* add chained CPI data (from sheet "AF2" in "pov_during_covid_revise_v1.xlsx")
gen ccpi=1
replace ccpi = 1.009328666 if ref_year==2016
replace ccpi = 1.027137658 if ref_year==2017
replace ccpi = 1.047868437 if ref_year==2018
replace ccpi = 1.063099779 if ref_year==2019
replace ccpi = 1.074518515 if ref_year==2020
replace ccpi = 1.122539628 if ref_year==2021
replace ccpi = 1.208728056 if ref_year==2022

save "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", replace
*/

********************************************************************************
* step 1) Find poverty thresholds in 1980, 2015 for various consumption measures 

use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
replace respstat=1 if srv_year>=114
keep if ref_year==2015
* Official Poverty Rate in 2015 
local OPR2015 13.5

* Consumption level that yields a poverty rate equal to the official poverty rate
forvalues i = 1/8 {
pctile pct_cons_`i'=cons`i' [w=wgt20], nq(1000) genp(pct`i')
gen cons`i'_2015 = pct_cons_`i' if pct`i'==float(`OPR2015') 
egen pct_cons`i' = max(cons`i'_2015)
drop pct_cons_`i'
}

collapse pct_cons* 
gen anchor = 2015
save C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_2015, replace


* step 2) Determine poverty status by comparing a consumption to the threshold anchored in 1980 and 2015
clear
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
gen anchor=2015
foreach index in cpi_u cpi_u_rs cpi_u_rs_adj pce ccpi {
gen `index'2015 = `index' if ref_year==2015
egen `index'_2015 = max(`index'2015)
drop `index'2015
replace `index'_2015 = `index'_2015/`index'
}

label var cons1 "Total Expenditure" 
label var cons2 "Food Expenditure" 
label var cons3 "Housing Expenditure"
label var cons4 "Transp. Expenditure"
label var cons5 "Other Expenditure" 
label var cons6 "Total Consumption"
label var cons7 "Savingadj Total Consumption"
label var cons8 "Total Income"

merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_2015
keep if _merge==3
drop _merge
forvalues i = 1/8 {
gen pov_u_`i' = cons`i'<pct_cons`i'/cpi_u_2015
gen pov_urs_`i' =  cons`i'<pct_cons`i'/cpi_u_rs_2015
gen pov_urs_adj_`i' = cons`i'<pct_cons`i'/cpi_u_rs_adj_2015
gen pov_pce_`i' = cons`i'<pct_cons`i'/pce_2015
gen pov_ccpi_`i' = cons`i'<pct_cons`i'/ccpi_2015

replace pov_u_`i'=. if cons`i'==.
replace pov_urs_`i'=. if cons`i'==.
replace pov_urs_adj_`i'=. if cons`i'==.
replace pov_pce_`i'=. if cons`i'==.
replace pov_ccpi_`i'=. if cons`i'==.
}


* step 3) Calculate poverty rates 
* All Age 
preserve
replace wgt20 = . if wgt20<0 //a few negative weight for years 1964-1975
bysort ref_year: egen obs = sum(fam_size)
bysort ref_year: egen obs6 = sum(cons6!=.)
bysort ref_year: egen obs4 = sum(cons4!=.)
bysort ref_year: egen obs5 = sum(cons5!=.)
collapse (mean) pov_urs_adj_* obs* [w = wgt20], by(ref_year)
gen age_grp=0
tempfile full
save `full'
list
restore

* Age <18 
preserve
bysort ref_year: egen obs = sum(perslt18)
replace wgt21 = . if wgt21<0
collapse (mean) pov_urs_adj_* obs [w = wgt21], by(ref_year)
gen age_grp=1
tempfile age_grp1
save `age_grp1'
list
restore

* Age btw 18-64
preserve
bysort ref_year: egen obs = sum(fam_size-perslt18-persot64)
replace wgt23 = . if wgt23<0
collapse (mean) pov_urs_adj_*  obs [w = wgt23], by(ref_year)
gen age_grp=2
tempfile age_grp2
save `age_grp2'
list
restore

* Age >=65
preserve
bysort ref_year: egen obs = sum(persot64)
replace wgt22 = . if wgt22<0
collapse (mean) pov_urs_adj_*  obs [w = wgt22], by(ref_year)
gen age_grp=3
tempfile age_grp3
save `age_grp3'
list
restore

* Combine results together
clear
use `full' 
append using `age_grp1'
append using `age_grp2'
append using `age_grp3'
sort ref_year age_grp
order ref_year age_grp
list


preserve
reshape wide pov_urs_adj_1 pov_urs_adj_2 pov_urs_adj_3 pov_urs_adj_4 pov_urs_adj_5 pov_urs_adj_6 pov_urs_adj_7 pov_urs_adj_8 obs obs6 obs4 obs5, i(ref_year) j(age_grp)
keep ref_year pov_urs_adj_*0 pov_urs_adj_*1 pov_urs_adj_*2 obs* pov_urs_adj_63
order ref_year pov_urs_adj_60 pov_urs_adj_20 pov_urs_adj_30 pov_urs_adj_40 pov_urs_adj_50 pov_urs_adj_70 pov_urs_adj_61 pov_urs_adj_21 pov_urs_adj_31 pov_urs_adj_41 pov_urs_adj_51 pov_urs_adj_71 obs* pov_urs_adj_62 pov_urs_adj_63
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons_2015.xls", firstrow(var) keepcellfmt replace
restore

********************************************************************************
*******************     Robustness check using ccpi      ***********************
********************************************************************************

clear
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
gen anchor=2015
foreach index in cpi_u cpi_u_rs cpi_u_rs_adj pce ccpi {
gen `index'2015 = `index' if ref_year==2015
egen `index'_2015 = max(`index'2015)
drop `index'2015
replace `index'_2015 = `index'_2015/`index'
}

merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_2015
keep if _merge==3
drop _merge
forvalues i = 6/6 {
gen pov_ccpi_`i' = 0
replace pov_ccpi_`i' = 1 if cons`i'<pct_cons`i'/ccpi_2015
}

* step 3) Calculate poverty rates 
* All Age 
preserve
replace wgt20 = . if wgt20<0 //a few negative weight for years 1964-1975
bysort ref_year: egen obs = sum(fam_size)
collapse (mean) pov_ccpi_* obs [w = wgt20], by(ref_year)
gen age_grp=0
tempfile full
save `full'
list
restore

* Age <18 
preserve
bysort ref_year: egen obs = sum(perslt18)
replace wgt21 = . if wgt21<0
collapse (mean) pov_ccpi_* obs [w = wgt21], by(ref_year)
gen age_grp=1
tempfile age_grp1
save `age_grp1'
list
restore


* Combine results together
clear
use `full' 
append using `age_grp1'
sort age_grp ref_year
order age_grp ref_year
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\F2ccpi.xls", firstrow(var) keepcellfmt replace


********************************************************************************
****    Assets/Debts for Families w/ consumption btw 50-150% poverty line   ****
********************************************************************************


use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
gen anchor=2015
foreach index in cpi_u cpi_u_rs cpi_u_rs_adj pce ccpi {
gen `index'2015 = `index' if ref_year==2015
egen `index'_2015 = max(`index'2015)
drop `index'2015
replace `index'_2015 = `index'_2015/`index'
}


merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_2015
keep if _merge==3
drop _merge
forvalues i = 1/8 {
gen pov_0515_`i' = 0
replace pov_0515_`i' = 1 if cons`i'>=pct_cons`i'*0.5/cpi_u_rs_adj_2015 & cons`i'<pct_cons`i'*1.5/cpi_u_rs_adj_2015
}


rename tot_debt2 tot_debtx 
egen tot_debty = rowtotal(debt1 debt2), missing

* convert the nominal value to the real value using the quarterly price index
foreach var in tot_assets tot_debtx tot_debty {
replace `var' = `var'*cpi_u_rs_adj_2015    // adj-cpi-urs
}

** Change relative to one year ago

gen ast_inc = tot_ass_chg>0
gen ast_sam = tot_ass_chg==0
gen ast_dec = tot_ass_chg<0
foreach var in ast_inc ast_sam ast_dec {
	replace `var' = . if tot_assets==.
}


preserve
keep if pov_0515_6==1
bysort intvyr: egen obs = sum(fam_size)
collapse (p75) tot_assets tot_debtx tot_debty (p90) p90_assets = tot_assets p90_tot_debtx = tot_debtx p90_tot_debty = tot_debty (p50) p50_assets = tot_assets (mean) ast_inc ast_sam ast_dec cashco obs [w = wgt20], by(intvyr)
tempfile pov15
save `pov15'
list
restore

* results by the presence of children 
preserve
keep if pov_0515_6==1
gen children = perslt18>0
bysort intvyr children: egen obs = sum(fam_size)
collapse (p75) tot_assets tot_debtx tot_debty (p90) p90_assets = tot_assets p90_tot_debtx = tot_debtx p90_tot_debty = tot_debty (p50) p50_assets = tot_assets (mean) ast_inc ast_sam ast_dec cashco obs [w = wgt20], by(intvyr children)
reshape wide tot_assets tot_debtx tot_debty p90_assets p90_tot_debtx p90_tot_debty p50_assets ast_inc ast_sam ast_dec cashco obs, i(intvyr) j(children)
tempfile pov15_child
save `pov15_child'
list
restore


* Combine results together
clear
use `pov15' 
merge 1:1 intvyr using `pov15_child'
sort intvyr 
order intvyr
list

order intvyr tot_assets tot_assets1 p90_assets p90_assets1 tot_debty tot_debty1 p90_tot_debty p90_tot_debty1 p50_assets p50_assets1 ast_inc ast_sam ast_dec ast_inc1 ast_sam1 ast_dec1 ast_inc0 ast_sam0 ast_dec0 
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\Annual_Asset.xls", firstrow(var)  replace keepcellfmt






********************************************************************************
**** Education Expenditure Share among the consumption poor (1.5*threshold) ****
********************************************************************************


use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
gen anchor=2015
foreach index in cpi_u cpi_u_rs cpi_u_rs_adj pce ccpi {
gen `index'2015 = `index' if ref_year==2015
egen `index'_2015 = max(`index'2015)
drop `index'2015
replace `index'_2015 = `index'_2015/`index'
}

merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_2015
keep if _merge==3
drop _merge
gen pov_urs_adj_6 = 0
replace pov_urs_adj_6 = 1 if cons6<pct_cons6*1.5/cpi_u_rs_adj_2015

replace cons1=. if cons1<0
gen frac_food = cons2/cons1
gen frac_hous = cons3/cons1
gen frac_tran = cons4/cons1
gen frac_othe = cons5/cons1
gen frac_edu = cons7/cons1 //share of total exp
gen frac_lumpsum = cons9/cons8


drop if ref_year==2023
keep if pov_urs_adj_6==1
replace wgt20 = . if wgt20<0 
collapse (mean) frac_edu frac_food frac_hous frac_tran frac_othe  [w = wgt20]
list




********************************************************************************
*******      Composition of Consumption among the consumption poor     *********
********************************************************************************


use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
gen anchor=2015
foreach index in cpi_u cpi_u_rs cpi_u_rs_adj pce ccpi {
gen `index'2015 = `index' if ref_year==2015
egen `index'_2015 = max(`index'2015)
drop `index'2015
replace `index'_2015 = `index'_2015/`index'
}

label var cons1 "Total Expenditure" 
label var cons2 "Food consumption" 
label var cons3 "Housing consumption"
label var cons4 "Transp. consumption"
label var cons5 "Other consumption" 
label var cons6 "Total Consumption"
label var cons8 "Total Income"

merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_2015
keep if _merge==3
drop _merge
forvalues i = 1/8 {
gen pov_u_`i' = 0
replace pov_u_`i' = 1 if cons`i'<pct_cons`i'/cpi_u_2015
gen pov_urs_`i' = 0
replace pov_urs_`i' = 1 if cons`i'<pct_cons`i'/cpi_u_rs_2015
gen pov_urs_adj_`i' = 0
replace pov_urs_adj_`i' = 1 if cons`i'<pct_cons`i'/cpi_u_rs_adj_2015
gen pov_pce_`i' = 0
replace pov_pce_`i' = 1 if cons`i'<pct_cons`i'/pce_2015
}

replace cons1=. if cons1<0
gen frac_food = cons2/cons1
gen frac_hous = cons3/cons1
gen frac_tran = cons4/cons1
gen frac_othe = cons5/cons1
gen frac_edu = cons7/cons1 //share of total exp
gen frac_lumpsum = cons9/cons8

* step 3) Calculate poverty rates 
* All Age 
preserve
keep if pov_urs_adj_6==1
replace wgt20 = . if wgt20<0 //a few negative weight for years 1964-1975
bysort ref_year: egen obs = sum(fam_size)
collapse (mean) frac_food frac_hous frac_tran frac_othe frac_edu frac_lumpsum cons1 cons2 cons3 cons4 cons5 obs [w = wgt20], by(ref_year)
gen age_grp=0
tempfile full
save `full'
list
restore

* Age <18 
preserve
keep if pov_urs_adj_6==1
replace wgt21 = . if wgt21<0
bysort ref_year: egen obs = sum(perslt18)
collapse (mean) frac_food frac_hous frac_tran frac_othe frac_edu frac_lumpsum cons1 cons2 cons3 cons4 cons5 obs [w = wgt21], by(ref_year)
gen age_grp=1
tempfile age_grp1
save `age_grp1'
list
restore


* Combine results together
clear
use `full' 
append using `age_grp1'
sort ref_year age_grp
order ref_year age_grp
list


preserve
reshape wide frac_food frac_hous frac_tran frac_othe frac_edu frac_lumpsum cons1 cons2 cons3 cons4 cons5 obs, i(ref_year) j(age_grp)
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\comp_cons_poor.xls", firstrow(var) keepcellfmt replace
restore






********************************************************************************
*******                       CE Income Poverty                         ********
********************************************************************************


/*
* step 1) Find poverty thresholds in 1980, 2015 for various consumption measures 
foreach ref_yr in 2015 {
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
drop ref_year
gen ref_year = year
replace ref_year = year-1 if intvmo<=6
replace respstat=1 if srv_year>=114
keep if ref_year==`ref_yr'
label var cons1 "Total Expenditure" 
label var cons6 "Total Consumption"
label var cons8 "Total Income"

* Official Poverty Rate in 1980, 2015 
local OPR1980 13
local OPR2015 13.5

* Consumption level that yields a poverty rate equal to the official poverty rate
foreach i in 1 6 8 {
pctile pct_cons_`i'=cons`i' [w=wgt20], nq(1000) genp(pct`i')
gen cons`i'_`ref_yr' = pct_cons_`i' if pct`i'==float(`OPR`ref_yr'') 
egen pct_cons`i' = max(cons`i'_`ref_yr')
drop pct_cons_`i'
}

collapse pct_cons* 
gen anchor = `ref_yr'

save C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_`ref_yr', replace
}


* step 2) Determine poverty status by comparing a consumption to the threshold anchored in 1980 and 2015
foreach ref_yr in 2015 {
clear
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
drop ref_year
gen ref_year = year
replace ref_year = year-1 if intvmo<=6
gen anchor=`ref_yr'
foreach index in cpi_u cpi_u_rs cpi_u_rs_adj pce ccpi {
gen `index'`ref_yr' = `index' if ref_year==`ref_yr'
egen `index'_`ref_yr' = max(`index'`ref_yr')
drop `index'`ref_yr'
replace `index'_`ref_yr' = `index'_`ref_yr'/`index'
}

label var cons1 "Total Expenditure" 
label var cons6 "Total Consumption"
label var cons8 "Total Income"

merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_`ref_yr'
keep if _merge==3
drop _merge
foreach i in 1 6 8 {
gen pov_u_`i' = 0
replace pov_u_`i' = 1 if cons`i'<pct_cons`i'/cpi_u_`ref_yr'
gen pov_urs_`i' = 0
replace pov_urs_`i' = 1 if cons`i'<pct_cons`i'/cpi_u_rs_`ref_yr'
gen pov_urs_adj_`i' = 0
replace pov_urs_adj_`i' = 1 if cons`i'<pct_cons`i'/cpi_u_rs_adj_`ref_yr'
gen pov_pce_`i' = 0
replace pov_pce_`i' = 1 if cons`i'<pct_cons`i'/pce_`ref_yr'
}


* step 3) Calculate poverty rates 
* All Age 
preserve
replace wgt20 = . if wgt20<0 //a few negative weight for years 1964-1975
bysort ref_year: egen obs = sum(fam_size)
collapse (mean) pov_urs_adj_1 pov_urs_adj_6 pov_urs_adj_8 obs [w = wgt20], by(ref_year)
gen age_grp=0
tempfile full
save `full'
list
restore

* Age <18 
preserve
bysort ref_year: egen obs = sum(perslt18)
replace wgt21 = . if wgt21<0
collapse (mean) pov_urs_adj_1 pov_urs_adj_6 pov_urs_adj_8 obs [w = wgt21], by(ref_year)
gen age_grp=1
tempfile age_grp1
save `age_grp1'
list
restore

* Age btw 18-64
preserve
bysort ref_year: egen obs = sum(fam_size-perslt18-persot64)
replace wgt23 = . if wgt23<0
collapse (mean) pov_urs_adj_1 pov_urs_adj_6 pov_urs_adj_8  obs [w = wgt23], by(ref_year)
gen age_grp=2
tempfile age_grp2
save `age_grp2'
list
restore

* Age >=65
preserve
bysort ref_year: egen obs = sum(persot64)
replace wgt22 = . if wgt22<0
collapse (mean) pov_urs_adj_1 pov_urs_adj_6 pov_urs_adj_8  obs [w = wgt22], by(ref_year)
gen age_grp=3
tempfile age_grp3
save `age_grp3'
list
restore

* Combine results together
clear
use `full' 
append using `age_grp1'
append using `age_grp2'
append using `age_grp3'
sort ref_year age_grp
order ref_year age_grp
list


preserve
reshape wide pov_urs_adj_1 pov_urs_adj_6 pov_urs_adj_8 obs, i(ref_year) j(age_grp)
keep ref_year pov_urs_adj_*0 pov_urs_adj_*1 pov_urs_adj_*2 obs*
order ref_year pov_urs_adj_61 pov_urs_adj_11 pov_urs_adj_81 pov_urs_adj_60 pov_urs_adj_10 pov_urs_adj_80 obs*
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\ce_inc_`ref_yr'.xls", firstrow(var) keepcellfmt replace
restore
}


