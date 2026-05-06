
foreach ref_yr in 2015 {
clear
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
gen anchor=`ref_yr'
foreach index in cpi_u cpi_u_rs cpi_u_rs_adj pce {
gen `index'`ref_yr' = `index' if ref_year==`ref_yr'
egen `index'_`ref_yr' = max(`index'`ref_yr')
drop `index'`ref_yr'
replace `index'_`ref_yr' = `index'_`ref_yr'/`index'
}

label var cons6 "Total Consumption"

merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_OPR_`ref_yr'
keep if _merge==3
drop _merge
foreach i in 6 {
gen pov_deep_`i' = 0
replace pov_deep_`i' = 1 if cons`i'<pct_cons`i'*0.5/cpi_u_rs_adj_`ref_yr'
gen pov_near_`i' = 0
replace pov_near_`i' = 1 if cons`i'<pct_cons`i'*1.5/cpi_u_rs_adj_`ref_yr'
}


* step 3) Calculate poverty rates 
* All Age 
preserve
replace wgt20 = . if wgt20<0 //a few negative weight for years 1964-1975
bysort ref_year: egen obs = sum(fam_size)
collapse (mean) pov_deep_6 pov_near_6 obs [w = wgt20], by(ref_year)
gen age_grp=0
tempfile full
save `full'
list
restore

* Age <18 
preserve
bysort ref_year: egen obs = sum(perslt18)
replace wgt21 = . if wgt21<0
collapse (mean) pov_deep_6 pov_near_6 obs [w = wgt21], by(ref_year)
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
reshape wide pov_deep_6 pov_near_6 obs, i(ref_year) j(age_grp)
keep ref_year pov_deep_6* pov_near_6* obs*
order ref_year pov_deep_6* pov_near_6* obs*
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\deep_near_`ref_yr'.xls", firstrow(var) keepcellfmt replace
restore
}

