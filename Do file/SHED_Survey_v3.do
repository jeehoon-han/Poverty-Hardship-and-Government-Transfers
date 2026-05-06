********************************************************************************
** Clean and combine the 2019 and 2020 data

* 2019 data
* Key variables
* id: CaseID
* weight_pop: weight
* pphhsize: HH size 
* ppt18ov: Number of adults 
* ppeduc: highest edu
* ppeducat: education 
* ppt01: # children aged 0-1 
* ppt25: # children aged 2-5 
* ppt612 : # children aged 6-12
* ppt1317: # children aged 13-17
* ppmarit: Marital stat 
* ppwork: emp (current) 
* ppage: age 
* ppincimp: Income  
* B2: finance management  
* gh1: house ownership
* BK1: bank account
* C2A: credit card
* C3: any outstanding unpaid credit card debt?
* ED0: highest edu.
* K20: how much saved for retirement 
* I0_b: interest income
* I40: total income
* I41_a: received EITC
* I41_b: received SNAP
* I41_c: received WIC
* I20: spending relative to income
* EF1: have emergency funds for three months
* EF2: can cover 3 months expenses if lose main job.
* EF3_a, EF3_b, EF3_c: can pay for $400 emergency expense using money in bank or credit card (not borrowing or selling something)  
* EF5A: ability to pay all bills
* E1_a: cound't afforded Prescription medicine in the last 12 months
* E1_b: cound't see a doctor 
* E1_d: coudn't see dentist
* pph10001: physical health
* ppfs0596: total saving
* GH3_e: satisfied with housing condition


forvalues y = 2013/2023 { 
use public`y'.dta, clear
gen year=`y'
tempfile shed`y'
save `shed`y'', replace
}
use `shed2023', clear
forvalues y = 2013/2022 {
append using `shed`y'', force
}

*/





keep if year>=2015
foreach age in 01 25 612 1317 {
replace ppt`age'=PPT`age' if year<=2017
}
tostring ppcmdate, replace
gen month = substr(ppcmdate, 5, 2)
destring month, replace

*keep year CaseID weight_pop weight1b weight3b pphhsize ppt18ov ppeducat ppt* ppmarit* ppwork ppemploy ppage ppincimp B2 GH1 BK1 C2A K20 I40 I20 I21_* E2 EF1 EF2 EF5A E1_* I41_* ppfs0596 ppkid017 ppinc7 E4_* 

keep year CaseID weight_pop weight1b weight3b pphhsize ppt18ov ppeducat ppt01 ppt25 ppt612 ppt1317 ppmarit ppmarit5 ppwork ppemploy ppage ppincimp ppkid017 ///
B2 GH1 EF1 EF2 EF5A E1_a E1_b E1_c E1_d E2 E4_* I21_a I21_b ppfs0596 ppinc7

save shed13_23, replace
use shed13_23, clear

replace weight_pop = weight3b if year<=2017
replace weight_pop = weight1b if year==2018
drop weight1b weight3b 

replace ppmarit = ppmarit5 if year>=2021
gen married=ppmarit==1
drop ppmarit*

gen emp = 0
replace emp=1 if (ppwork>=1 & ppwork<=2)|(ppemploy>=1 & ppemploy<=2)
drop ppwork ppemploy


replace ppkid017= ppt01 + ppt25 + ppt612 + ppt1317 if year<2021
drop ppt01 ppt25 ppt612 ppt1317
gen havechild=ppkid017>0

replace ppinc7 = 2 if ppincimp!=. & ppincimp<=7   // <$25,000
replace ppinc7 = 3 if ppincimp!=. & ppincimp>=8  & ppincimp<=11  // <$49,999
replace ppinc7 = 4 if ppincimp!=. & ppincimp>=12 & ppincimp<=13  // <$74,999
replace ppinc7 = 5 if ppincimp!=. & ppincimp>=14 & ppincimp<=15  // <$99,999
replace ppinc7 = 6 if ppincimp!=. & ppincimp>=16 & ppincimp<=17  // <$149,999
replace ppinc7 = 7 if ppincimp!=. & ppincimp>=18 & ppincimp<=21  // >$150,000

gen ppinc6 = 1 
replace ppinc6=2 if ppinc7==3
replace ppinc6=3 if ppinc7==4
replace ppinc6=4 if ppinc7==5
replace ppinc6=5 if ppinc7==6
replace ppinc6=6 if ppinc7==7
drop ppincimp ppinc7

gen HSless = ppeducat<=2
gen SCless = ppeducat<=3
drop ppeducat

********************************************************************************
**** Construct wellbeing variables ****

* Overall, which one of the following best describes how well you are managing financially these days
gen no_finok = B2<=2
gen finok = B2>=3      
* Home ownership
*gen no_home = GH1>=3
* Do you [and/or your spouse/ and/or your partner] currently have a checking, savings or money market account?
*gen no_ba = BK1==0
* Do you have at least one credit card?
*gen no_cc = C2A==0
* Have you set aside emergency or rainy day funds that would cover your expenses for 3 months in the case of sickness, job loss, economic downturn, or other emergencies?
gen no_efund3mo = EF1==0
* If you were to lose your main source of income (e.g. job, government benefits), could you cover your expenses for 3 months by borrowing money, using savings, selling assets, or borrowing from friends/family?
gen no_means3mo = EF2==0
* Which best describes your ability to pay all of your bills in full this month? (Can't pay some bills)
gen no_allbill = EF5A==0
* During the past 12 months, was there a time when you needed Prescription medicine, but went without because you couldn't afford it?
gen no_medicine = E1_a==1
* During the past 12 months, was there a time when you needed Seeing a doctor, but went without because you couldn't afford it?
gen no_doctor = E1_b==1
* During the past 12 months, was there a time when you needed Dental care, but went without because you couldn't afford it?
gen no_dentist = E1_d==1
* During the past 12 months, was there a time when you needed Mental health care or counseling, but went without because you couldn't afford it?
gen no_mentalcare = E1_c==1
* During the past 12 months, have you had any unexpected major medical expenses that you had to pay out of pocket because they were not completely paid for by insurance?
gen moop = E2==1
* current health insurance status
gen hi = E4_a==1|E4_b==1|E4_c==1|E4_d==1|E4_e==1|E4_f==1

* income/spending relative to an year ago
gen inc_decr = I21_a==1
gen inc_same = I21_a==2
gen inc_incr = I21_a==3
gen spend_decr = I21_b==1
gen spend_same = I21_b==2	
gen spend_incr = I21_b==3	
gen spend_incr_inc_didnt = I21_b==3 & (I21_a==1|I21_a==2)
/*
** Government benefits 
* In the past 12 months, received EITC
gen eitc = I41_a==1
* In the past 12 months, received SNAP
gen snap = I41_b==1
* In the past 12 months, received WIC
gen wic = I41_c==1
* In the past 12 months, received Housing assistance
gen housasst = I41_d==1
* In the past 12 months, received free or reduced lunch
gen freelunch = I41_e==1
gen foodasst = snap==1|wic==1|freelunch==1
*/




* In the past month, would you say that your [and/or your spouse/parnter] total spending was: Same or more than your income)
*gen exp_ge_inc = I20>=2
* Income <50k
gen incless50k = ppinc6<=2

bysort year: sum ppage married emp havechild ppinc6 HSless no_* 
* all sample
preserve 
bysort year: gen obs = _N
collapse (mean) no_* inc_* spend_* hi obs [w=weight_pop], by(year)
sort year
** Export the data to an excel file 
export excel using SHED_full.xls, firstrow(var) replace keepcellfmt
restore



* HH by presence of children
preserve 
bysort year havechild: gen obs = _N
collapse (mean) no_* inc_* spend_* hi obs [w=weight_pop], by(year havechild)
order havechild year
sort havechild year
** Export the data to an excel file 
export excel using SHED_child.xls, firstrow(var) replace keepcellfmt
restore



* HH by education
preserve 
bysort year HSless: gen obs = _N
collapse (mean) no_* inc_* spend_* hi obs [w=weight_pop], by(year HSless)
order HSless year
sort HSless year
** Export the data to an excel file 
export excel using SHED_edu.xls, firstrow(var) replace keepcellfmt
restore


* HH by health insurance
preserve 
bysort year hi: gen obs = _N
collapse (mean) no_* inc_* spend_* obs [w=weight_pop], by(year hi)
order hi year
sort hi year
** Export the data to an excel file 
export excel using SHED_hi.xls, firstrow(var) replace keepcellfmt
restore


* HH by Children & education 
preserve 
bysort year havechild HSless: gen obs = _N
collapse (mean) no_* inc_* spend_* hi obs [w=weight_pop], by(year havechild HSless)
order havechild HSless year
sort havechild HSless year
** Export the data to an excel file 
export excel using SHED_child_edu.xls, firstrow(var) replace keepcellfmt
restore