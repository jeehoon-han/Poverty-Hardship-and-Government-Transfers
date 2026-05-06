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
keep if cons5!=.

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
keep ref_year pov_urs_adj_*0 pov_urs_adj_*1 pov_urs_adj_*2 obs*
order ref_year pov_urs_adj_60 pov_urs_adj_20 pov_urs_adj_30 pov_urs_adj_40 pov_urs_adj_50 pov_urs_adj_70 pov_urs_adj_61 pov_urs_adj_21 pov_urs_adj_31 pov_urs_adj_41 pov_urs_adj_51 pov_urs_adj_71 obs*
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\AF5.xls", firstrow(var) keepcellfmt replace
restore
