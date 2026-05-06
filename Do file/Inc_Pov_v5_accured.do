********************************************************************************

clear
use "CPS1522"
keep if year>=2016
gen ref_year = year-1

* merge with the income test data for qualifying relative 
merge m:1 ref_year using inc_test
keep if _merge==3
drop _merge

recast long pernum

** deal with missing or N/A values for income variables
replace inctot=0 if inctot==999999999 

local eight_digit incwage incbus incfarm incretir 
foreach var of varlist `eight_digit' {
replace `var' = . if `var' ==99999999
replace `var' = 0 if `var' ==.
}

local seven_digit incsurv incdisab incdivid incint incvet incrent
foreach var of varlist `seven_digit' {
replace `var' = . if `var' ==9999999
replace `var' = 0 if `var' ==.
}

local six_digit incss incwelfr incssi incunemp incwkcom inceduc incchild
foreach var of varlist `six_digit' {
replace `var' = . if `var' ==999999
replace `var' = 0 if `var' ==.
}

drop incssi incsurv incrent inceduc incother

********************************************************************************
** identify Census family
* primary family & related subfamily: fam_type 1 */
gen fam_type = ftype==1|ftype==3 

/* unrelated subfamily is splited into multiple families based on the number of reference persons */
sort year serial ftype pernum
bysort year serial ftype: gen ref_person = sum(famrel==1) 
replace fam_type= ref_person+1 if ftype==4  /* maximum 2 unrelated families within a HH: fam_type 2-3 */

/* not family member (Nonfamily householder or Secondary individual) is a separate family */
sort year serial ftype pernum
bysort year serial: gen no_fam = sum(famrel==0) 
replace fam_type= no_fam+3 if famrel==0  /* maximum 15 non-family members within a HH fam_type: 4-19 */
drop no_fam
tab fam_type


********************************************************************************

** TAXSIM variables (ALLOW RELATED SUBFAMILIES TO BE SEPARATE FILERS)

* SOI codes
egen state = group(statefip)
* Marital status
gen mstat=1 
replace mstat=2 if marst==1|marst==2|marst==3 // married

*Code infants as "1"
gen age0 = age==0
replace age=1 if age==0

* identify each related-subfamily within fam_type=1
sort year serial fam_type pernum
bysort year serial fam_type: gen subfam = sum(famrel==1)

* identify full time students under age 24
gen ftstdnt23 = (schlcoll==1|schlcoll==3) & (age>=19 & age<=23)
replace age = 19 if ftstdnt23==1

* identify dependents 
* qualifying children
gen dep = (famrel==3|famrel==4) & age<=18 // all children aged 18 or less
replace dep= 1 if famrel==3 & ftstdnt23 ==1  // full-time students who are aged between 19 and 23 
replace dep= 1 if (famrel==3|famrel==4) & incdisab>0 // disabled 
* qualifying relative 
replace dep= 1 if famrel==4 & inctot-(incwelfr+incchild+incasist)<inc_test  // income test for qualifying relative 

* identify tax units within family 
* family head, spouse, and dependents as one tax unit (indep=0), 
* all others (non-qualifying children/reiatlve) in the family as separte tax units (indep=1)
gen indep = dep==0 & (famrel==3|famrel==4)  
sort year serial fam_type subfam indep pernum
bysort year serial fam_type subfam: gen ind_payer = sum(indep)

* Number of dependents
bysort year serial fam_type subfam ind_payer: egen depx = sum(dep) 


* Dependents by age 
sort year serial fam_type subfam ind_payer age pernum
bysort year serial fam_type subfam ind_payer: gen depnum = sum(dep) 

* age of the youngest three children
bysort year serial fam_type subfam ind_payer: gen dep1  = age if depnum==1 & dep==1
replace dep1=0 if dep1==.
bysort year serial fam_type subfam ind_payer: egen age1 = max(dep1)
bysort year serial fam_type subfam ind_payer: gen dep2  = age if depnum==2 & dep==1
replace dep2=0 if dep2==.
bysort year serial fam_type subfam ind_payer: egen age2 = max(dep2)
bysort year serial fam_type subfam ind_payer: gen dep3  = age if depnum==3 & dep==1
replace dep3=0 if dep3==.
bysort year serial fam_type subfam ind_payer: egen age3 = max(dep3)


* primary taxpayer variables
* head age
gen page = age
* head wage
gen pwages = incwage
replace pwages=0 if pwages<0
* head self-employment income
gen psemp = incbus+incfarm
replace psemp=0 if psemp<0


* spouse variables
* spouse age
bysort year serial fam_type subfam ind_payer: gen sp_age = age if famrel==2
replace sp_age=0 if sp_age==.
bysort year serial fam_type subfam ind_payer: egen sage = max(sp_age)
* spouse wage
bysort year serial fam_type subfam ind_payer: gen sp_wage = incwage if famrel==2
replace sp_wage=0 if sp_wage<0|sp_wage==.
bysort year serial fam_type subfam ind_payer: egen swages = max(sp_wage)
* spouse selfemp income
bysort year serial fam_type subfam ind_payer: gen sp_semp = incbus+incfarm if famrel==2
replace sp_semp=0 if sp_semp<0|sp_semp==.
bysort year serial fam_type subfam ind_payer: egen ssemp = max(sp_semp)




********************************************************************************
* Impute SNAP, school lunch, WIC, energey subsidy values  
* identify the first person in a given family
sort year serial famid pernum
bysort year serial famid: gen firstper = _n==1

* 1) SNAP and school lunch: use the Census imputed value for each family unit 

merge m:1 year serial famid using imp_snap
drop _merge
mi unset, asis
sort year serial famid pernum
order year serial famid foodstamp fsval

replace foodstamp=fsval*(round3==1|(round4==1 & rn<=10600)) if fsval!=. & ref_year==2015
replace foodstamp=fsval*(round3==1|(round4==1 & rn<=9680)) if fsval!=. & ref_year==2016
replace foodstamp=fsval*(round3==1|(round4==1 & rn<=30290)) if fsval!=. & ref_year==2017
replace foodstamp=fsval*(round3==1|(round4==1 & rn<=31700)) if fsval!=. & ref_year==2018
replace foodstamp=fsval*(round4==1|(round5==1 & rn<=9440)) if fsval!=. & ref_year==2019
replace foodstamp=fsval*(round3==1|(round4==1 & rn<=25030)) if fsval!=. & ref_year==2020
replace foodstamp=fsval*(round8==1|(round9==1 & rn<=25800)) if fsval!=. & ref_year==2021
replace foodstamp=fsval*(round10==1|(round11==1 & rn<=11600)) if fsval!=. & ref_year==2022

gen snapval = 0
replace snapval = foodstamp if firstper==1

* 1-1) school lunch: use the Census imputed value for each family unit 
replace schllunch=0 if schllunch==99999
gen lunchval = 0
replace lunchval = schllunch if firstper==1

* 2) energey subsidy: use the Census imputed value for a household
* assign to the householder's family
bysort year serial: egen heathh = max(heatsub==2)
gen energyval = 0
replace energyval = heatval if famid==1 & firstper==1

* 3) WIC: use the WIC receipt info. and then estimate the likely WIC recipients based on family composition, 
* then assign the average food cost per person to each likly recepient.
* WIC receipt per households
bysort year serial: egen wichh = max(gotwic==2)
* determine the number of likely recipients 
bysort year serial famid: egen mother1545 = max(sex==2 & age>=15 & age<=45)
bysort year serial famid: egen numunder2 = sum(age<=1)
bysort year serial famid: egen num2to5 = sum(age>=2 & age<=5)
gen numwic = numunder2+num2to5
* mother also receives if kid age<2 or no kids (pregnant women) 
replace numwic = numwic+1 if mother1545==1 & numunder2>0 
replace numwic = 1 if mother1545==1 & numwic==0

gen wiccost = 0
replace wiccost = 43.37*12 if ref_year==2015
replace wiccost = 42.77*12 if ref_year==2016
replace wiccost = 41.24*12 if ref_year==2017
replace wiccost = 40.94*12 if ref_year==2018
replace wiccost = 40.9*12 if ref_year==2019
replace wiccost = 38.48*12 if ref_year==2020
replace wiccost = 35.58*12 if ref_year==2021
replace wiccost = 47.74*12 if ref_year==2022

gen wicval = 0
replace wicval = wiccost*numwic if wichh==1 & firstper==1

* Compare to SPM values
sort year spmfamunit pernum
bysort year spmfamunit: gen firstspm = _n==1
gen spmwicval = 0
replace spmwicval = spmwic if firstspm==1


********************************************************************************
******************         Imputation of UI Benefits         *******************
********************************************************************************
** Step 1. combine with the UI benefit calculator 
preserve
import delimited using "State UI benefit calculations", clear
drop if statefip==.
drop state
tempfile UIrule
save `UIrule'
restore

*merge state rules data with CPS 
merge m:1 statefip using `UIrule'
drop _merge

** Step 2. Define weeks of unemployment 
* (1) reported unemp. spell last year  
gen wksunemly = wksunem1
replace wksunemly = 0 if wksunem1==99
gen unemly = wksunem1>0 & wksunem1<99

* 2) No reported unemp. spell last year, reported that currently (as of the interview time) unemployed that has lasted more than 12 weeks
* Assign the reported unemp spells minus 12 weeks as the last year's unemp. spell
gen unemnow = durunemp!=999
gen wksunemnow = 0
replace wksunemnow = max(durunemp-13,0) if unemnow==1   

* 3) non-employed for part of last year, but didn't look for work due to health/family reason, no work available, or other reasons in 2020-21
gen nonemp_covid = (actnlfly==10|actnlfly==20|actnlfly==50|actnlfly==52) & (ref_year==2020|ref_year==2021)
gen wksnonemp = 0
replace wksnonemp = 52-wkswork1 if nonemp_covid==1

* 4) Worked part time some weeks due to slack work in 2020-21. c
gen ptemp_covid = whyptly==3 & (ref_year==2020|ref_year==2021)
gen wkspt = 0
replace wkspt = ptweeks if ptemp_covid==1


** Step 4. Determine the unemployment duration
* Assign max of the two reported UI durations (interview month or last year) as UI duration
gen wksunem = 0
replace wksunem = max(wksunemly,wksunemnow) 
* cap UI duration to 52 weeks
replace wksunem=52 if wksunem>52 & wksunem!=.

* calculate weeks nilf (weeks non-employed - weeks unemployed) for those who were non-employed due to covid-related reasons
gen wksnilf = 0
replace wksnilf = wksnonemp - wksunem if nonemp_covid==1 
replace wksnilf=0 if wksnilf<0 
* calculate weeks partially unemployed (weeks worked part-time due to slack work) during covid 
gen wksptunem = 0 
replace wksptunem = wkspt if ptemp_covid==1
* cap weeks partially unemployed such that the total weeks (unemployed + not in labor force + partially unemployed) does not exceed 52 (this can happen b/c the weeks unemployed is calculated using the unemployment info. in the last year and current year)
gen totwks = wksunem+wksnilf+wksptunem
replace wksptunem = wksptunem-(totwks-52) if totwks>52

** Step 5. Define the PUA and regular UI eligibles  * indicator for UI eiglbie: unmployed or non-employed who didn't look for job b/c 1) ill or disabled, 2) taking care of home/family, 3) no work available

gen selfemp = (incbus!=0|incfarm!=0) & incwage==0
gen work3mo = wkswork1>=13

* Regular UI eligibles: wage workers who reported UI duration with sufficeint work history (3mo)   
gen RUI_elig = wksunem>0 & (selfemp==0 & work3mo==1)

* PUA eligibles
* 1) the self-employed who reported UI duration
* 2) wage workers with insufficient work history who reported UI durations  
* 2) non-employed or part-time employed due to COVID related reasons
gen PUA1_elig = wksunem>0 & (selfemp==1|work3mo==0) & (ref_year==2020|ref_year==2021)
gen PUA2_elig = nonemp_covid==1
gen PUA3_elig = ptemp_covid==1
gen PUA_elig = PUA1_elig==1|PUA2_elig==1|PUA3_elig==1

gen UI_elig = RUI_elig==1|PUA_elig==1

gen earnings = incwage+incbus+incfarm

* the average quarterly earnings last year while working (lower bound of the base earnings for UI)
gen qtrearn=(earnings/wkswork1)*13


********************************************************************************
** Step 4. Impute UI benefits 

* UI benefits for regular UI eligibles
gen regben=min(maxben,max(minben,qtrearn*replacement_rate))
label var regben "Estimated Weekly UI benefit (WBA)"

* UI benefits for PUA recipients (max. of regular UI and min PUA benefits) 
gen puaben = max(regben,pua_min) 
	
* zero benefits to those who are not eligible for UI
replace regben = 0 if UI_elig==0
replace puaben = 0 if UI_elig==0


********************************************************************************
*** The cumulative UI benefits: WBA*#weeks unemployed (https://www.bea.gov/help/faq/1415)
gen PUC = 0
gen RUI = 0
gen PUA1 = 0
gen PUA2 = 0
gen PUA3 = 0
gen PUA = 0
gen MEUC = 0

** PUC (any UI eligibles qualify for PUC)
gen totdur = wksunem+wksnilf+wksptunem
replace PUC = 600*totdur if UI_elig==1 & ref_year==2020          
replace PUC = 300*min(totdur,35) if UI_elig==1 & ref_year==2021  //PUC expired in Sep 2021. 

** Regular UI
replace RUI = (regben*wksunem) if RUI_elig==1 

** PUA 
* 1) those with reported UI duration
replace PUA1 = (puaben*wksunem) if PUA1_elig==1 & ref_year==2020     
replace PUA1 = (puaben*min(wksunem,35)) if PUA1_elig==1 & ref_year==2021
* 2) non-employed due to COVID related reasons
replace PUA2 = (puaben*wksnilf) if PUA2_elig==1 & ref_year==2020     
replace PUA2 = (puaben*min(wksnilf,35)) if PUA2_elig==1 & ref_year==2021
* 3) part-time employed due to slack work (assign 50% benefits)
replace PUA3 = (0.5*puaben*wksptunem) if PUA3_elig==1 & ref_year==2020     
replace PUA3 = (0.5*puaben*min(wksptunem,35)) if PUA3_elig==1 & ref_year==2021
replace PUA = PUA1+PUA2+PUA3

** Mixed Earners Unemployment Compensation (regular UI eligibles who also have a self-employed income)
replace MEUC = 100*min(wksunem,35) if RUI_elig==1 & (incbus>0|incfarm>0) & ref_year==2021   // 2021 only

** Sum of UI benefits
gen UI=RUI+PUC+PUA+MEUC
replace UI = incunemp if incunemp>0 // assign reporetd UI if reported UI is positive


* randomly select UI eligibles to cap the total UI amounts 
set seed 1234
sort year serial pernum
bysort year: gen rnum0 = runiformint(1, 1000)

replace UI = UI*(rnum0<=635) if ref_year==2015
replace UI = UI*(rnum0<=665) if ref_year==2016
replace UI = UI*(rnum0<=645) if ref_year==2017
replace UI = UI*(rnum0<=635) if ref_year==2018
replace UI = UI*(rnum0<=600) if ref_year==2019
replace UI = UI*(rnum0<=680) if ref_year==2020
replace UI = UI*(rnum0<=820) if ref_year==2021
replace UI = UI*(rnum0<=550) if ref_year==2022

** Policy simulation 1 (No UI for Appendix Table 3)
*replace UI=0

********************************************************************************

* income variables
bysort year serial fam_type subfam ind_payer: egen dividends = sum(incdivid)
bysort year serial fam_type subfam ind_payer: egen intrec  = sum(incint)
bysort year serial fam_type subfam ind_payer: egen pensions= sum(incretir)
bysort year serial fam_type subfam ind_payer: egen gssi    = sum(incss)
*bysort year serial fam_type subfam ind_payer: egen ui      = sum(incunemp) // reported ui income, another line below needs to be changed to calculate the poverty rate with reported UI (search "reported")
bysort year serial fam_type subfam ind_payer: egen ui      = sum(UI) // imputed ui income
bysort year serial fam_type subfam ind_payer: egen transfers = sum(incwelfr+incwkcom+incvet)

** calculate tax using TAXSIM model (need to run only once)
* accured CTC/ODC
preserve
* adjustment for TAXSIM error for CTC/ODC calculation in 2021 
gen age17 = age==17
replace age = age-1 if age17==1 & ref_year==2021
* change age-related taxsim variables
drop dep1 dep2 dep3 age1 age2 age3 page sp_age sage 
* head age
gen page = age
* spouse age
bysort year serial fam_type subfam ind_payer: gen sp_age = age if famrel==2
replace sp_age=0 if sp_age==.
bysort year serial fam_type subfam ind_payer: egen sage = max(sp_age)
* dependent age 
bysort year serial fam_type subfam ind_payer: gen dep1  = age if depnum==1 & dep==1
replace dep1=0 if dep1==.
bysort year serial fam_type subfam ind_payer: egen age1 = max(dep1)
bysort year serial fam_type subfam ind_payer: gen dep2  = age if depnum==2 & dep==1
replace dep2=0 if dep2==.
bysort year serial fam_type subfam ind_payer: egen age2 = max(dep2)
bysort year serial fam_type subfam ind_payer: gen dep3  = age if depnum==3 & dep==1
replace dep3=0 if dep3==.
bysort year serial fam_type subfam ind_payer: egen age3 = max(dep3)

keep if famrel==0|famrel==1|ind_payer==1 //family head or independent tax payer
replace year=year-1 // now year is the reference year
taxsimlocal35, replace full
gen tax=(fiitax+siitax+(fica/2))
gen agi = v10
gen nrf_ctcodc=v22 // non-refundable part
gen rf_ctc=v23 // refundable part (accured)
gen ctcodc = nrf_ctcodc+rf_ctc
gen eitc=v25
gen eip=v45
replace year=year+1 // now year is the survey year
replace ctcodc = rf_ctc if year==2022 // all were refundable in tax year 2021
keep year serial pernum tax agi ctcodc nrf_ctcodc rf_ctc eip eitc
save tax_ctc, replace
restore

* received CTC (except for 2021-22)
preserve

* adjustment for TAXSIM error for CTC/ODC calculation in 2021 
gen age17 = age==17
replace age = age-1 if age17==1 & ref_year==2022
* change age-related taxsim variables
drop dep1 dep2 dep3 age1 age2 age3 page sp_age sage 
* head age
gen page = age
* spouse age
bysort year serial fam_type subfam ind_payer: gen sp_age = age if famrel==2
replace sp_age=0 if sp_age==.
bysort year serial fam_type subfam ind_payer: egen sage = max(sp_age)
* dependent age 
bysort year serial fam_type subfam ind_payer: gen dep1  = age if depnum==1 & dep==1
replace dep1=0 if dep1==.
bysort year serial fam_type subfam ind_payer: egen age1 = max(dep1)
bysort year serial fam_type subfam ind_payer: gen dep2  = age if depnum==2 & dep==1
replace dep2=0 if dep2==.
bysort year serial fam_type subfam ind_payer: egen age2 = max(dep2)
bysort year serial fam_type subfam ind_payer: gen dep3  = age if depnum==3 & dep==1
replace dep3=0 if dep3==.
bysort year serial fam_type subfam ind_payer: egen age3 = max(dep3)

keep if famrel==0|famrel==1|ind_payer==1 //family head or independent tax payer
replace year=year-2 // now year is the reference year-1
taxsimlocal35, replace full
gen tax2=(fiitax+siitax+(fica/2))
gen agi2 = v10
gen nrf_ctcodc2=v22 // non-refundable part
gen rf_ctc2=v23 // refundable part (received except for 2021-22)
gen ctcodc2 = nrf_ctcodc2+rf_ctc2
gen eitc2=v25
replace year=year+2 // now year is the survey year
replace ctcodc2 = rf_ctc2 if year==2023 // all were refundable in tax year 2021
keep year serial pernum tax2 agi2 ctcodc2 rf_ctc2 eitc2
save tax_ctc2, replace
restore
*/

merge 1:1 year serial pernum using tax_ctc
drop _merge
merge 1:1 year serial pernum using tax_ctc2
drop _merge

********************************************************************************
* Impute received CTC 
* randomly select tax units 
set seed 1234
sort year serial fam_type subfam ind_payer pernum
bysort year serial fam_type subfam ind_payer: gen rnum2 = runiformint(1, 100)
 
* years other than 2021-2022
gen r_ctcodc = ctcodc2
* 2021
*replace r_ctcodc = ctcodc/2+ctcodc2 if ref_year==2021
replace r_ctcodc = ctcodc2 + ctcodc/2*(rnum2<=86) if ref_year==2021 // exclude ACTC from a random sample of children in 2021
* 2022
*replace r_ctcodc = ctcodc2/2 if ref_year==2022
replace r_ctcodc = ctcodc2/2 + ctcodc2/2*(rnum2<=14) if ref_year==2022 // add 50% exp. CTC to a random sample of children in 2022

********************************************************************************
* Simulate CTC 
gen sim1_ctcodc = r_ctcodc
gen sim2_ctcodc = r_ctcodc
* simulation 1: original CTC (To years Y before 2022, assign CTC accured for Tax Year Y-1. To year 2022, assign CTC accured for Tax Year 2022)
replace sim1_ctcodc = ctcodc2 
replace sim1_ctcodc = ctcodc if ref_year==2022
* simulation 2: extend expanded CTC to 2022 (to year 2022, assign CTC accured for Tax Year 2021)  
replace sim2_ctcodc = ctcodc2 if ref_year==2022


* CPS imputed CTC
replace actccrd=0 if actccrd==99999 
replace ctccrd=0 if ctccrd==999999 
gen cps_ctc = ctccrd+actccrd


********************************************************************************
** Impute the EIPs
gen eip1 = 0 
gen eip2 = 0
gen eip3 = 0 
* count the number of qualifying children
gen qdep = dep==1 & age<17
bysort year serial fam_type subfam ind_payer: egen qdepx = sum(qdep) 

* count the number of qualified individuals
gen qadultx=1 // non-married 
replace qadultx=2 if mstat==2 // married

* calculate total EIP in a tax unit (single or married)
replace eip1 = 1200*qadultx+500*qdepx if agi<=75000*qadultx
replace eip1 = max(0, 1200*qadultx+500*qdepx-0.05*(agi-75000*qadultx)) if agi>75000*qadultx 
replace eip2 = 600*qadultx+600*qdepx if agi<=75000*qadultx
replace eip2 = max(0, 600*qadultx+600*qdepx-0.05*(agi-75000*qadultx)) if agi>75000*qadultx 
replace eip3 = 1400*qadultx+1400*depx if agi<=75000*qadultx
replace eip3 = max(0, (1400*qadultx+1400*depx)*(1-(agi-75000*qadultx)/(5000*qadultx))) if agi>75000*qadultx 

* the payment is reduced to $0 if 
replace eip1 = 0 if agi>=99000*qadultx+10000*qdepx
replace eip2 = 0 if agi>=99000*qadultx+10000*qdepx
replace eip3 = 0 if agi>=80000*qadultx


* calculate total EIP in a tax unit (head of household)
gen hh = (famrel==0|famrel==1) & mstat==1 & depx>0
replace eip1 = 1200*qadultx+500*qdepx if agi<=112500*qadultx & hh==1
replace eip1 = max(0, 1200*qadultx+500*qdepx-0.05*(agi-112500*qadultx)) if agi>112500*qadultx & hh==1
replace eip2 = 600*qadultx+600*qdepx if agi<=112500*qadultx & hh==1
replace eip2 = max(0, 600*qadultx+600*qdepx-0.05*(agi-112500*qadultx)) if agi>112500*qadultx & hh==1
replace eip3 = 1400*qadultx+1400*depx if agi<=120000*qadultx & hh==1
replace eip3 = max(0, (1400*qadultx+1400*depx)*(1-(agi-112500*qadultx)/(7500*qadultx))) if agi>112500*qadultx & hh==1

* the payment is reduced to $0 if 
replace eip1 = 0 if agi>=136500*qadultx+10000*qdepx & hh==1
replace eip2 = 0 if agi>=136500*qadultx+10000*qdepx & hh==1
replace eip3 = 0 if agi>=120000*qadultx & hh==1

* assign EIP to family head or independent tax payer only
replace eip1 = 0 if famrel!=0 & famrel!=1 & ind_payer!=1
replace eip2 = 0 if famrel!=0 & famrel!=1 & ind_payer!=1
replace eip3 = 0 if famrel!=0 & famrel!=1 & ind_payer!=1
replace eip1 = 0 if ref_year!=2020
replace eip2 = 0 if ref_year<2020
replace eip3 = 0 if ref_year<2020

gen EIP_elig1 = eip1>0
gen EIP_elig2 = eip2>0

* a randomly selected part of the EIP eligibles
set seed 1234
sort year serial fam_type pernum
bysort year serial fam_type: gen rnum1 = runiformint(1, 1000)


replace eip1 = eip1*(rnum1<=950)
replace eip2 = eip2*(rnum1<=892) if ref_year>=2020
********************************************************************************
* merge with housing subsidy 

sort year serial
merge m:1 year serial using IPUMS_hs
keep if _merge==3
drop _merge


* family level income
*bysort year serial fam_type: egen tot_inc = sum(inctot)  // w/ reported UI
bysort year serial fam_type: egen tot_inc = sum(inctot-incunemp+UI)   // w/ imputed UI
bysort year serial fam_type: egen taxes  = sum(tax)
bysort year serial fam_type: egen acr_ctcodc  = sum(ctcodc)
bysort year serial fam_type: egen rec_ctcodc  = sum(r_ctcodc)
bysort year serial fam_type: egen s1_ctcodc  = sum(sim1_ctcodc)
bysort year serial fam_type: egen s2_ctcodc  = sum(sim2_ctcodc)
bysort year serial fam_type: egen tot_eitc  = sum(eitc)
bysort year serial fam_type: egen acr_eip  = sum(eip)
bysort year serial fam_type: egen tot_eip1  = sum(eip1)
bysort year serial fam_type: egen tot_eip2  = sum(eip2)
bysort year serial fam_type: egen tot_eip3  = sum(eip3)
bysort year serial fam_type: egen tot_snap  = sum(snapval)
bysort year serial fam_type: egen tot_lunch = sum(lunchval)
bysort year serial fam_type: egen tot_energy = sum(energyval)
bysort year serial fam_type: egen tot_wic = sum(wicval)
bysort year serial fam_type: egen tot_spmwic = sum(spmwicval)



** Age group
gen age_grp1 = age<=17 
replace age_grp1 =2 if age>=18 & age<=64
replace age_grp1 =3 if age>=65

bysort year serial fam_type: gen famsize = _N
bysort year serial fam_type: egen numkids = sum(age<18)

gen scale1=(famsize-numkids+(.7*numkids))^.7

********************************************************************************
*** Construct income measures (two variables (ctcodc and eip) are for accured year)  

* aftertax income + noncash benefits 
gen inc1a = (tot_inc-taxes) + tot_snap + tot_lunch + tot_energy + tot_wic + hous_sub  // after-tax income (w/ my calculation of EIP1/EIP2 instead of taxsim version)
replace inc1a = inc1a-acr_eip+tot_eip1+tot_eip2 if ref_year==2020

* after-tax income + EIPs/CTC when received 
/*
gen inc2a = inc1a + (-acr_ctcodc+rec_ctcodc)  // received CTC/ODC, received EIP
replace inc2a = inc2a - tot_eip2 if ref_year==2020  
replace inc2a = inc2a + tot_eip2 if ref_year==2021  
*/

* robustness. use year accured for CTC/EIP
gen inc2a = inc1a   



* exclude EIPs 
/*
gen inc3a = inc2a  
replace inc3a = inc2a - tot_eip1 if ref_year==2020  // exclude eip1 in 2020
replace inc3a = inc2a - tot_eip2 - tot_eip3 if ref_year==2021  // exclude eip2,eip3 in 2021 
*/

* robustness. use year accured for EIP2
gen inc3a = inc2a  
replace inc3a = inc2a - tot_eip1 - tot_eip2 if ref_year==2020  // exclude eip1,eip2 in 2020
replace inc3a = inc2a - tot_eip3 if ref_year==2021  // exclude eip3 in 2021




* CTC simulation 
*gen inc4a = inc2a - rec_ctcodc + s1_ctcodc
*gen inc5a = inc2a - rec_ctcodc + s2_ctcodc

* robustness 1. use year accured for CTC
* CTC simulation 1
gen inc4a = inc2a - acr_ctcodc + s1_ctcodc
gen inc5a = inc2a - acr_ctcodc + s2_ctcodc

* EIP simulation 
gen inc6a = inc2a
replace inc6a = inc2a + tot_eip2 + tot_eip3 if ref_year==2022 


* apply scale 
forvalues i = 1/6 {
replace inc`i'a = inc`i'a/scale1
}


********************************************************************************
*** Calculate EIP and CTC amounts by year and family income
gen pov100 = tot_inc<cutoff
gen pov200 = tot_inc<cutoff*2
gen pov500 = tot_inc<cutoff*5

bysort ref_year: egen agg_eip = sum(eip*asecwt/1000000000) // TAXSIM (accured)
bysort ref_year: egen agg_eip1 = sum(eip1*asecwt/1000000000)
bysort ref_year: egen agg_eip2 = sum(eip2*asecwt/1000000000)
bysort ref_year: egen agg_eip3 = sum(eip3*asecwt/1000000000)
bysort ref_year: egen agg_acr_ctcodc = sum(ctcodc*asecwt/1000000000) // TAXSIM (Accured)
bysort ref_year: egen agg_acr_ctcodc2 = sum(ctcodc2*asecwt/1000000000) // TAXSIM (received, w/o adjustment for Exp. CTC in 2021 and 2022)
bysort ref_year: egen agg_rec_ctcodc = sum(r_ctcodc*asecwt/1000000000) // TAXSIM (received, w/ adjustment for Exp. CTC in 2021 and 2022)
bysort ref_year: egen agg_actc21 = sum(ctcodc/2*(rnum2<=86)*asecwt/1000000000)
bysort ref_year: egen agg_actc22 = sum(ctcodc2/2*(rnum2<=14)*asecwt/1000000000)
bysort ref_year: egen agg_ui_rep = sum(incunemp*asecwt/1000000000)
bysort ref_year: egen agg_ui_imp = sum(UI*asecwt/1000000000)


* # children receiving CTC
bysort ref_year: egen agg_pop = sum(asecwt) // total children
gen child = age<18
bysort ref_year: egen agg_children = sum(child*asecwt) // total children
gen age17 = age==17
bysort ref_year: egen agg_age0 = sum(age0*asecwt) // child age 0
bysort ref_year: egen agg_age17 = sum(age17*asecwt) // child age 17

bysort year serial fam_type subfam ind_payer: egen ctca  = sum(ctcodc)  // CTC accured 
bysort year serial fam_type subfam ind_payer: egen ctcr  = sum(ctcodc2)  // CTC received 
bysort year serial fam_type subfam ind_payer: egen actc21  = sum(ctcodc*(rnum2<=86))  // ACTC received in 2021
bysort year serial fam_type subfam ind_payer: egen actc22  = sum(ctcodc2*(rnum2<=14)) // ACTC received in 2022
bysort year serial fam_type subfam ind_payer: egen agi_taxunit  = max(agi)

gen ctcachild = child==1 & ctca>0
bysort ref_year: egen agg_ctcachild = sum(ctcachild*asecwt) // total children with CTC accured
gen ctcrchild = child==1 & ctcr>0
bysort ref_year: egen agg_ctcrchild = sum(ctcrchild*asecwt) // total children with CTC received
gen actc21child = child==1 & actc21>0
bysort ref_year: egen agg_actc21child = sum(actc21child*asecwt) // total children ACTC received in 2021
gen actc22child = child==1 & actc22>0
bysort ref_year: egen agg_actc22child = sum(actc22child*asecwt) // total children receiving ACTC received in 2022

* Aggregate non cash benefits 
bysort year serial: egen snap  = sum(snapval)
bysort year serial: egen lunch = sum(lunchval)
bysort year serial: egen energy = sum(energyval)
bysort year serial: egen wic = sum(wicval)
drop spmwic
bysort year serial: egen spmwic = sum(spmwicval)


* assign 0 to all individuals except for the household head  
foreach var in stampval hous_sub snap lunch energy wic spmwic {
	replace `var' = 0 if relate!=101
}
bysort ref_year: egen agg_snap = sum(stampval*asecwt/1000000000)
bysort ref_year: egen agg_houssub = sum(hous_sub*asecwt/1000000000)
bysort ref_year: egen agg_lunch = sum(lunch*asecwt/1000000000)
bysort ref_year: egen agg_energy = sum(energy*asecwt/1000000000) 
bysort ref_year: egen agg_wic = sum(wic*asecwt/1000000000)
bysort ref_year: egen agg_spmwic = sum(spmwic*asecwt/1000000000)
bysort ref_year: sum agg_*


********************************************************************************
***********        Generate poverty thresholds anchored in 2015        *********
********************************************************************************


preserve
keep if ref_year==2015
local pov_rate2015 13.5
local ref_yr = 2015
forvalues i = 1/6 {
pctile pct_inc_`i'=inc`i'a [w=asecwt], nq(1000) genp(pct`i')
gen inc`i'_`ref_yr' = pct_inc_`i' if pct`i'==float(`pov_rate`ref_yr'') 
egen pct_inc`i' = max(inc`i'_`ref_yr')
}
collapse pct_inc1 pct_inc2 pct_inc3 pct_inc4 pct_inc5 pct_inc6
gen anchor = `ref_yr'
tempfile thresh
save `thresh'
restore

** combine with price indices 
preserve 
import excel "C:\Users\jeehoon_han\Dropbox\Poverty\stata\price_indices22_JH.xlsx", sheet("dat_file `ref_yr'") firstrow clear
rename Year ref_year
rename cpiursadj cpiurs_adj
gen anchor = `ref_yr'
tempfile price`ref_yr'
save `price`ref_yr''
restore

preserve 
use `thresh', clear
merge 1:m anchor using `price`ref_yr''
drop _merge
save pov_rate_2015, replace
restore

********************************************************************************
****************    Calculating Poverty Rate (1987 onward)    ******************
********************************************************************************
merge m:1 ref_year using pov_rate_2015


forvalues i = 1/6 {
gen pov`i'= 0
replace pov`i' = 1 if inc`i'a*scale1<cutoff 
gen pov_u_`i' = 0
replace pov_u_`i' = 1 if inc`i'a<pct_inc`i'*cpiu
gen pov_urs_`i' = 0
replace pov_urs_`i' = 1 if inc`i'a<pct_inc`i'*cpiurs
gen pov_urs_adj_`i' = 0
replace pov_urs_adj_`i' = 1 if inc`i'a<pct_inc`i'*cpiurs_adj
gen pov_pce_`i' = 0
replace pov_pce_`i' = 1 if inc`i'a<pct_inc`i'*pce
gen pov_deep_`i' = 0
replace pov_deep_`i' = 1 if inc`i'a<pct_inc`i'*cpiurs_adj*0.5
gen pov_near_`i' = 0
replace pov_near_`i' = 1 if inc`i'a<pct_inc`i'*cpiurs_adj*1.5
}


** Full sample, and subsample by age group
preserve
bysort ref_year: gen obs = _N
collapse (mean) pov_urs_adj_1 pov_urs_adj_2 pov_urs_adj_3 pov_urs_adj_4 pov_urs_adj_5 pov_urs_adj_6 pov_deep_2 pov_near_2 obs [w = asecwt], by(ref_year)
gen age_grp1=0
tempfile full
save `full'
list
restore
preserve
bysort ref_year age_grp1: gen obs = _N
collapse (mean) pov_urs_adj_1 pov_urs_adj_2 pov_urs_adj_3 pov_urs_adj_4 pov_urs_adj_5 pov_urs_adj_6 pov_deep_2 pov_near_2 obs [w = asecwt], by(ref_year age_grp1)
tempfile subsample
save `subsample'
list
restore

clear
use `full' 
append using `subsample'
sort ref_year age_grp1
order ref_year age_grp1
list


** reshape the data to fit in with the template.   (Full sample: pov*_20, Children: pov*_21, Age1864: pov*_22, Age65+: pov*_23)
preserve
reshape wide pov_urs_adj_* pov_deep_2 pov_near_2 obs, i(ref_year) j(age_grp1)
keep ref_year pov_urs_adj_2* pov_near_20 pov_near_21 pov_deep_20 pov_deep_21 pov_urs_adj_30 pov_urs_adj_40 pov_urs_adj_50 pov_urs_adj_60 pov_urs_adj_31 pov_urs_adj_41 pov_urs_adj_51 pov_urs_adj_61 obs* 
order ref_year pov_urs_adj_2* pov_near_20 pov_near_21 pov_deep_20 pov_deep_21 pov_urs_adj_30 pov_urs_adj_40 pov_urs_adj_50 pov_urs_adj_60 pov_urs_adj_31 pov_urs_adj_41 pov_urs_adj_51 pov_urs_adj_61 obs* 
export excel using inc_pov_accured.xls, firstrow(var) keepcellfmt replace
restore


