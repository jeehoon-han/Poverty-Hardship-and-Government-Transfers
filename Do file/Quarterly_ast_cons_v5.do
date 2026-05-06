********************************************************************************
************                Quarterly Price Index                  *************
********************************************************************************


* 1) consturct quarterly CPI-U index 
import excel "C:\Users\jeehoon_han\Dropbox\Poverty\COVID19\cpi2015_2023.xlsx", sheet("BLS Data Series") cellrange(A12:M21) firstrow clear
rename (Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec Year) (m1 m2 m3 m4 m5 m6 m7 m8 m9 m10 m11 m12 year)
reshape long m, i(year) j(mo)
rename m cpiu

gen q = 1 if mo>=1 & mo<=3
replace q = 2 if mo>=4 & mo<=6
replace q = 3 if mo>=7 & mo<=9
replace q = 4 if mo>=10 & mo<=12
gen yq = year*10+q
collapse cpiu, by(yq)
save qcpi_u, replace

* 2) consturct quarterly CPI-U-RS index 
import excel "C:\Users\jeehoon_han\Dropbox\Poverty\COVID19\cpiurs2015_2023.xlsx", sheet("All items") cellrange(A12:M21) firstrow clear
rename (JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC YEAR) (m1 m2 m3 m4 m5 m6 m7 m8 m9 m10 m11 m12 year)
reshape long m, i(year) j(mo)
rename m cpiurs

gen q = 1 if mo>=1 & mo<=3
replace q = 2 if mo>=4 & mo<=6
replace q = 3 if mo>=7 & mo<=9
replace q = 4 if mo>=10 & mo<=12
gen yq = year*10+q
collapse cpiurs, by(yq)
merge 1:1 yq using qcpi_u
drop _merge

*normalize the value in 2015q1 to 1  
foreach var in cpiu cpiurs {
gen `var'20151 = `var'[1]
replace `var' = `var'/`var'20151 
}
* 3) consturct quarterly bias-corrected CPI-U-RS index
* growth of cpiurs
gen growth_urs = (cpiurs[_n]-cpiurs[_n-1])/cpiurs[_n-1]
gen growthls02 = growth_urs-0.002
gen adj_cpiurs = 1
replace adj_cpiurs = adj_cpiurs[_n-1]*(1+growthls02)  if yq!=20151
* compare yearly growth 
gen yr_growth_urs = (cpiurs[_n]-cpiurs[_n-4])/cpiurs[_n-4]+1
gen yr_growth_adj_urs = (adj_cpiurs[_n]-adj_cpiurs[_n-4])/adj_cpiurs[_n-4]+1
gen diff = yr_growth_urs-yr_growth_adj_urs
save qcpi_u, replace



********************************************************************************
***********        Quarterly Consumption Poverty Threshold         *************
********************************************************************************

* step 1) Find poverty thresholds in 2020Q1 for various consumption measures 
foreach yq in 20151 {
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
* reference quarter
gen rq = .
replace rq = 1 if intvmo>=3 & intvmo<=5
replace rq = 2 if intvmo>=6 & intvmo<=8
replace rq = 3 if intvmo>=9 & intvmo<=11
replace rq = 4 if intvmo==12|intvmo<=2
gen yq = ref_year*10+rq
keep if yq==`yq'
label var cons1 "Total expenditure" 
label var cons5 "Well measured consumption" 
label var cons6 "Total Consumption"

* Official Poverty Rate in 2015Q1
local OPR20151 13.5

* Consumption level that yields a poverty rate equal to the official poverty rate
foreach i in 1 5 6 {
pctile pct_cons_`i'=cons`i' [w=wgt20], nq(1000) genp(pct`i')
gen cons`i'_`yq' = pct_cons_`i' if pct`i'==float(`OPR`yq'') 
egen pct_cons`i' = min(cons`i'_`yq')
drop pct_cons_`i'
}

collapse pct_cons* 
gen anchor = `yq'

save C:\Users\jeehoon_han\Dropbox\Poverty\Stata\OPR_`yq', replace
}


********************************************************************************
***********         Calculate Consumption Poverty Rate             *************
********************************************************************************

* step 2) Determine poverty status by comparing a consumption to the threshold anchored in 1980 and 2015
foreach yq in 20151 {
clear
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
* reference quarter
gen rq = .
replace rq = 1 if intvmo>=3 & intvmo<=5
replace rq = 2 if intvmo>=6 & intvmo<=8
replace rq = 3 if intvmo>=9 & intvmo<=11
replace rq = 4 if intvmo==12|intvmo<=2
gen yq = ref_year*10+rq
keep if yq>=20151
gen anchor=`yq'

merge m:1 yq using qcpi_u
keep if _merge==3
drop _merge

label var cons1 "Total expenditure" 
label var cons5 "Well measured consumption" 
label var cons6 "Total consumption" 
merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\Stata\OPR_`yq'
keep if _merge==3
drop _merge
foreach i in 1 5 6 {
gen pov_u_`i' = 0
*replace pov_u_`i' = 1 if cons`i'<pct_cons`i'*cpiu // cpi-u
replace pov_u_`i' = 1 if cons`i'<pct_cons`i'*adj_cpiurs // adj-cpiurs
}

* step 3) Calculate poverty rates 
* All Age 
preserve
bysort yq: egen obs = sum(fam_size)
collapse (mean) pov_u_1 pov_u_5 pov_u_6 obs [w = wgt20], by(yq)
gen age_grp=0
tempfile full
save `full'
list
restore

* Age <18 
preserve
bysort yq: egen obs = sum(perslt18)
replace wgt21 = . if wgt21<0
collapse (mean) pov_u_1 pov_u_5 pov_u_6 obs [w = wgt21], by(yq)
gen age_grp=1
tempfile age_grp1
save `age_grp1'
list
restore

* Age btw 18-64
preserve
bysort yq: egen obs = sum(fam_size-perslt18-persot64)
replace wgt23 = . if wgt23<0
collapse (mean) pov_u_1 pov_u_5 pov_u_6 obs [w = wgt23], by(yq)
gen age_grp=2
tempfile age_grp2
save `age_grp2'
list
restore

* Age >=65
preserve
bysort yq: egen obs = sum(persot64)
replace wgt22 = . if wgt22<0
collapse (mean) pov_u_1 pov_u_5 pov_u_6 obs [w = wgt22], by(yq)
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
sort yq age_grp
order yq age_grp
list


preserve
reshape wide pov_u_1 pov_u_5 pov_u_6 obs, i(yq) j(age_grp)
keep yq pov_u_6* pov_u_1* obs*
order yq pov_u_60 pov_u_61 pov_u_10 pov_u_11 obs*
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\cons_pov_`yq'.xls", firstrow(var)  replace keepcellfmt
restore
}

********************************************************************************
***********              Quarterly Assets Holdings                 *************
********************************************************************************


use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
* Highschool or less
gen highedu = educ_ref>=13

* reference quarter
gen rq = .
replace rq = 1 if intvmo>=1 & intvmo<=3
replace rq = 2 if intvmo>=4 & intvmo<=6
replace rq = 3 if intvmo>=7 & intvmo<=9
replace rq = 4 if intvmo>=10& intvmo<=12
gen yq = (srv_year+1900)*10+rq
keep if yq>=20151

merge m:1 yq using qcpi_u
keep if _merge==3
drop _merge

* cash contribution
replace cashco = (cashcopq+cashcocq)/scale

* sample restricted to HH w/ consumption < 150% poverty threshold 
gen anchor=20151
merge m:1 anchor using C:\Users\jeehoon_han\Dropbox\Poverty\Stata\OPR_20151
keep if _merge==3
drop _merge
foreach i in 6 {
gen pov_u_`i' = 0
*replace pov_u_`i' = 1 if cons`i'<pct_cons`i'*cpiu*1.5  // cpi-u
*replace pov_u_`i' = 1 if cons`i'<pct_cons`i'*adj_cpiurs*1.5 // adj-cpi-urs
replace pov_u_`i' = 1 if cons`i'>=pct_cons`i'*adj_cpiurs*0.5 & cons`i'<pct_cons`i'*adj_cpiurs*1.5  // 50-150% pov line
*replace pov_u_`i' = 1 if  cons`i'<pct_cons`i'*adj_cpiurs*2  // adj-cpi-urs // <200% pov line
}


gen has_debt = tot_debt>0
replace has_debt=. if tot_debt==.


* convert the nominal value to the real value using the quarterly price index
foreach var in tot_assets tot_debt stockx liquidx stockyrx liqudyrx cashco {
*replace `var' = `var'/cpiu          // cpi-u
replace `var' = `var'/adj_cpiurs    // adj-cpi-urs
}


gen stock_chg = stockx-stockyrx
replace stock_chg=. if stockx==.|stockyrx==.

gen liquid_chg = liquidx-liqudyrx
replace liquid_chg=. if liquidx==.|liqudyrx==.

********************************************************************************
** Change relative to one year ago

gen ast_inc = tot_ass_chg>0
gen ast_sam = tot_ass_chg==0
gen ast_dec = tot_ass_chg<0
foreach var in ast_inc ast_sam ast_dec {
	replace `var' = . if tot_assets==.
}

gen sto_inc = stock_chg>0
gen sto_sam = stock_chg==0
gen sto_dec = stock_chg<0

gen liq_inc = liquid_chg>0
gen liq_sam = liquid_chg==0
gen liq_dec = liquid_chg<0


********************************************************************************
** sample restriction
*keep if tot_assets!=.

* step 3) Calculate poverty rates 


preserve
keep if pov_u_6==1
*keep if pov_u_6==1 & has_debt==1
bysort yq: egen obs = sum(fam_size)
collapse (p75) tot_assets tot_debt (p90) p90_assets = tot_assets p90_tot_debt = tot_debt (p50) p50_assets = tot_assets p50_tot_debt = tot_debt (mean) ast_inc ast_sam ast_dec cashco has_debt obs avg_debt = tot_debt [w = wgt20], by(yq)
tempfile pov15
save `pov15'
list
restore


* results by the presence of children 
preserve
keep if pov_u_6==1
*keep if pov_u_6==1 & has_debt==1
gen children = perslt18>0
bysort yq children: egen obs = sum(fam_size)
collapse (p75) tot_assets tot_debt (p90) p90_assets = tot_assets p90_tot_debt = tot_debt (p50) p50_assets = tot_assets p50_tot_debt = tot_debt (mean) ast_inc ast_sam ast_dec cashco has_debt obs avg_debt = tot_debt [w = wgt20], by(yq children)
reshape wide tot_assets tot_debt p90_assets p90_tot_debt p50_assets p50_tot_debt ast_inc ast_sam ast_dec cashco has_debt avg_debt obs, i(yq) j(children)
tempfile pov15_child
save `pov15_child'
list
restore


* Combine results together
clear
use `pov15' 
merge 1:1 yq using `pov15_child'
sort yq 
order yq
list

order yq tot_assets tot_assets1 p90_assets p90_assets1 tot_debt tot_debt1 p90_tot_debt p90_tot_debt1 p50_assets p50_assets1 has_debt has_debt1 p50_tot_debt p50_tot_debt1 ast_inc ast_sam ast_dec ast_inc1 ast_sam1 ast_dec1 ast_inc0 ast_sam0 ast_dec0 
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\Asset.xls", firstrow(var)  replace keepcellfmt




********************************************************************************
/*
* bottom 15 pct consumption  
clear
use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\postcovid_cons1522.dta", clear
* reference quarter
gen rq = .
replace rq = 1 if intvmo>=3 & intvmo<=5
replace rq = 2 if intvmo>=6 & intvmo<=8
replace rq = 3 if intvmo>=9 & intvmo<=11
replace rq = 4 if intvmo==12|intvmo<=2
gen yq = ref_year*10+rq
keep if yq>=20151

merge m:1 yq using qcpi_u
keep if _merge==3
drop _merge

foreach cpi in cpiu {
gen `cpi'20151 = `cpi' if yq==20151
egen `cpi'_20151 = min(`cpi'20151)
drop `cpi'20151
replace `cpi'_20151 = `cpi'/`cpi'_20151
}

replace cons1 = cons1/cpiu_20151
replace cons6 = cons6/cpiu_20151

* All Age 
preserve
bysort yq: egen obs = sum(fam_size)
collapse (p15) cons1 cons6 obs [w = wgt20], by(yq)
gen age_grp=0
tempfile full
save `full'
list
restore

* Age <18 
preserve
bysort yq: egen obs = sum(perslt18)
replace wgt21 = . if wgt21<0
collapse (p15) cons1 cons6 obs [w = wgt21], by(yq)
gen age_grp=1
tempfile age_grp1
save `age_grp1'
list
restore

* Combine results together
clear
use `full' 
append using `age_grp1'
sort yq age_grp
order yq age_grp
list


preserve
reshape wide cons1 cons6 obs, i(yq) j(age_grp)
keep yq cons6* cons1* obs*
order yq cons60 cons61 cons10 cons11 obs*
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\p15_cons.xls", firstrow(var)  replace keepcellfmt
restore




/*
* Family with children only
preserve
keep if pov_u_6==1
bysort yq: egen obs = sum(perslt18)
replace wgt21 = . if wgt21<0
collapse (p75) tot_assets tot_debt net_worth house_eq obs [w = wgt21], by(yq)
rename (tot_assets tot_debt net_worth house_eq obs) (tot_assets1 tot_debt1 net_worth1 house_eq1 obs1)
tempfile pov15_child
save `pov15_child'
list
restore
*/


* Combine results together
clear
use `pov15' 
merge 1:1 yq using `pov15_child'
sort yq 
order yq
list

order yq tot_assets* 
export excel using "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\Asset75.xls", firstrow(var)  replace keepcellfmt





