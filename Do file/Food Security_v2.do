********************************************************************************

use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\CPS\FSS\FSS_1522", clear
keep if year>=2015
gen ref_year = year

** Age group
gen age_grp = age<=17 
replace age_grp =2 if age>=18 & age<=64
replace age_grp =3 if age>=65

* weight variable 
* Food Security Supplement Household Weight: fssuppwth 
* Food Security Supplement Person Weight: fssuppwt
gen inc_grp = faminc<=740
replace inc_grp=2 if faminc>=800 & faminc<=841
replace inc_grp=3 if faminc>=842 & faminc<=843


********************************************************************************
drop if fsstatus==98
gen lfs = fsstatus==2|fsstatus==3
gen vlfs = fsstatus==3
gen fsresp = fssuppwt>0

* drop no response to food security 
*drop if fsstatus==98


** Full sample, and subsample by age group
preserve
bysort ref_year: egen obs = sum(fsresp)
collapse (mean) lfs vlfs obs [w = fssuppwt], by(ref_year)
gen age_grp=0	
tempfile full
save `full'
list
restore
preserve
bysort ref_year age_grp: gen obs = _N
collapse (mean) lfs vlfs obs [w = fssuppwt], by(ref_year age_grp)
tempfile subsample
save `subsample'
list
restore
preserve
bysort ref_year inc_grp: gen obs = _N
collapse (mean) lfs vlfs obs [w = fssuppwt], by(ref_year inc_grp)
gen age_grp=4 
replace age_grp=5 if inc_grp==2
replace age_grp=6 if inc_grp==3
drop inc_grp
tempfile incsubsample
save `incsubsample'
list
restore

	
clear
use `full' 
append using `subsample'
append using `incsubsample'
sort ref_year age_grp
order ref_year age_grp
list


** reshape the data to fit in with the template.  
preserve
reshape wide lfs vlfs obs, i(ref_year) j(age_grp)
keep ref_year lfs* vlfs* obs*
order ref_year lfs* vlfs* obs*
export excel using fs_by_age.xls, firstrow(var) keepcellfmt replace
restore

********************************************************************************
*** adults food security

use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\CPS\FSS\FSS_1522", clear
keep if year>=2015
gen ref_year = year
gen fsresp = fssuppwt>0
* have children
gen child = 1
replace child = 2 if fsstatusc==99

** Age group
gen age_grp = age<=17 
replace age_grp =2 if age>=18 & age<=64
replace age_grp =3 if age>=65

drop if fsstatusa==98
gen lfs = fsstatusa==3|fsstatusa==4
gen vlfs = fsstatusa==4
** Full sample, and subsample by age group

preserve
bysort ref_year: egen obs = sum(fsresp)
collapse (mean) lfs obs [w = fssuppwt], by(ref_year)
gen child=0	
tempfile full
save `full'
list
restore
preserve
bysort ref_year child: gen obs = _N
collapse (mean) lfs obs [w = fssuppwt], by(ref_year child)
tempfile subsample
save `subsample'
list
restore

	
clear
use `full' 
append using `subsample'
sort ref_year child
order ref_year child
list


** reshape the data to fit in with the template.  
preserve
reshape wide lfs obs, i(ref_year) j(child)
keep ref_year lfs* obs*
order ref_year lfs* obs*
export excel using afs_by_age.xls, firstrow(var) keepcellfmt replace
restore


********************************************************************************
*** Child food security

use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\CPS\FSS\FSS_1522", clear
keep if year>=2015
gen ref_year = year
gen fsresp = fssuppwt>0
* have children
gen child = 1
replace child = 2 if fsstatusc==99

keep if child==1
drop if fsstatusc==98
gen lfs = fsstatusc==2|fsstatusc==3
gen vlfs = fsstatusc==3

preserve
bysort ref_year: egen obs = sum(fsresp)
collapse (mean) lfs obs [w = fssuppwt], by(ref_year)

export excel using cfs.xls, firstrow(var) keepcellfmt replace
restore


********************************************************************************
*** Household food security

use "C:\Users\jeehoon_han\Dropbox\Poverty\PostCovid_cons\CPS\FSS\FSS_1522", clear
keep if year>=2015
gen ref_year = year

* head of household
gen head = relate==101
keep if head==1

* have children
gen child = 1
replace child = 2 if fsstatusc==99

drop if fsstatus==98
gen lfs = fsstatus==2|fsstatus==3

** Full sample, and subsample by age group

preserve
bysort ref_year: gen obs = _N
collapse (mean) lfs obs [w = fssuppwth], by(ref_year)
gen child=0	
tempfile full
save `full'
list
restore
preserve
bysort ref_year child: gen obs = _N
collapse (mean) lfs obs [w = fssuppwth], by(ref_year child)
tempfile subsample
save `subsample'
list
restore

	
clear
use `full' 
append using `subsample'
sort ref_year child
order ref_year child
list


** reshape the data to fit in with the template.  
preserve
reshape wide lfs obs, i(ref_year) j(child)
keep ref_year lfs* obs*
order ref_year lfs* obs*
export excel using hh_fs.xls, firstrow(var) keepcellfmt replace
restore


