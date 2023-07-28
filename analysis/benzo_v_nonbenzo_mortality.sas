/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Get rates of mortality for benzo and non-benzo users along cohort;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

/* The following program works with cohorts from 2007 to 2015
   - Cohorts have to be in FFS and Part D from cohort year until 2018 or death
   - Benzo users in cohort are incident benzo users with at least 30 day use of benzo in cohort year or next
   - Mortality outcome is percent died by end of 2018
   - Limit to EGWP plans before 2013
   - Models are age-adjusted - shown stratified by age band and age-adjusted 


	*** 3 parts to this program ***
    1. Build cohort base analytical data set
	2. Compare mortality rates between benzo vs non-benzo
	   - Raw unadjusted
	   - Age-adjusted
	3. Compare ADRD rates between benzo vs non-benzo for whole population, survived population & died population
	   - Trying to understand bias when limiting to subpopulation who survived
	   - Age-adjusted

*/
 
proc format;
	value agegroup
	65-<70="1. 65-69"
	70-<75="2. 70-74"
	75-<80="3. 75-79"
	80-<85="4. 80-84"
	85-<90="5. 85-89"
	90-high="6. 90+";
run;

%macro export(data);
proc export data=&tempwork..&data
	outfile="&rootpath./AD/ProjPgm/benzos/exports/benzomortality_update.xlsx"
	dbms=xlsx 
	replace;
	sheet="&data";
run;
%mend;

/********************************************************** 1. Build Base **********************************************************************/
%macro base(byr,eyr,adrd_var_in,adrd_var_out,adrd_var_yr);

%do cohortyr=&byr %to &eyr.;

%let nextyr=%eval(&cohortyr+1);

data &tempwork..mortality&cohortyr. drops_&cohortyr.;
	merge 
	ad.adrdincv_1999_2020  (in=a keep=bene_id first_dx scen_dxsymp_inc) 
	%if &cohortyr.<2013 %then &outlib..bene_specialplans_0613 (in=b keep=bene_id specialpln_allyr&cohortyr. specialpln_allyr&nextyr.) ;
	base.samp_3yrffsptd_0618 (in=c keep=bene_id anysamp insamp: age_beg&cohortyr. race_bg sex birth_date death_date where=(anysamp=1)) 
	&outlib..class1benzo_2006_2017p (in=d keep=bene_id class1benzo_minfilldt class1benzo_pdays_&cohortyr. class1benzo_pdays_&nextyr.) ;

	by bene_id;
	if c;
	addata=a;

	/* Identify sample */
	* clear out everyone who had benzo use prior to observation year;
	if .<class1benzo_minfilldt<mdy(1,1,&cohortyr) then drop_priorbenzo=1;

	* clear out everyone who is not continuously enrolled in FFS and Part D from cohort year to 2018, and in a special plan in observation window;
	array insamp [2006:2018] insamp2006-insamp2018;
	death_yr=year(death_date);
	if .<death_yr<&cohortyr. then drop_samp=1;
	else do yr=&cohortyr to min(death_yr,2018);
		if insamp[yr] ne 1 then drop_samp=1;
	end;
	%if &cohortyr<=2012 %then %do;
		if specialpln_allyr&cohortyr ne 'Y' or specialpln_allyr&nextyr ne 'Y' then drop_pln=1;
	%end;

	* drop everyone who had ADRD prior to cohort year - only looking at incident ADRD;
	if .<&adrd_var_in.<=max(class1benzo_minfilldt,mdy(1,1,&cohortyr.)) then drop_priorADRD=1;
	
	* age group is age in cohort year;
	age_group=put(age_beg&cohortyr.,agegroup.);
	rename age_beg&cohortyr.=age;

	* drops - prior benzo, switchers, and non-EGWP pre-2013;
	if max(drop_priorbenzo,drop_samp,drop_pln,drop_priorADRD)=1 then drop=1; 

	/* Create variables */
	* identify ADRD - verified and unverified;
	if .<year(&adrd_var_in.)<=&adrd_var_yr. then &adrd_var_out.=1; else &adrd_var_out.=0; 

	* benzo use - must be incident;
	if year(class1benzo_minfilldt)=&cohortyr. then benzo_use=sum(class1benzo_pdays_&cohortyr.,class1benzo_pdays_&nextyr.); 
	if benzo_use>=30 then benzo_ever=1; else benzo_ever=0;
	
	* death;
	if death_yr ne . then died=1; else died=0;

	/* Outputting data set */
	if drop=1 then output drops_&cohortyr;
	else output &tempwork..mortality&cohortyr.;

run;

proc freq data=&tempwork..mortality&cohortyr.;
	table benzo_ever*(age_group sex race_bg died) addata;
run;

proc means data=&tempwork..mortality&cohortyr. noprint;
	output out=&tempwork..mortality&cohortyr._ck;
run;
%end;

* Setting all together to make a long data set;
data &tempwork..mortality_long&byr.&eyr.;
	set %do yr=&byr %to &eyr;
		&tempwork..mortality&yr. (in=_&yr. keep=bene_id age age_group race_bg sex birth_date death_date &adrd_var_out. died benzo_ever)
		%end;;
	%do yr=&byr %to &eyr;
		if _&yr. then year=&yr.;
	%end;
	format birth_date death_date mmddyy10.;
run;

%mend;

%base(2007,2015,scen_dxsymp_inc,adrdv,2016);

/********************************************************** 2. Mortality **********************************************************************/

%let byr=2007;
%let eyr=2015;

* Unadjusted;
proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=1;
	var died;
	class year;
	output out=&tempwork..benzo_mort_unadj (drop=_type_ rename=(_freq_=benzo_N))
	mean()=benzo_avg lclm()=benzo_lclm uclm()=benzo_uclm / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=0;
	var died;
	class year;
	output out=&tempwork..nonbenzo_mort_unadj (drop=_type_ rename=(_freq_=nonbenzo_N))
	mean()=nonbenzo_avg lclm()=nonbenzo_lclm uclm()=nonbenzo_uclm / autoname;
run;

data &tempwork..mort_unadj;
	merge &tempwork..benzo_mort_unadj &tempwork..nonbenzo_mort_unadj;
	by year;
run;

* Age-adjusted age-bands;
%macro mortality_ageband(byr,eyr);

%do yr=&byr. %to &eyr.;
proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=1 and year=&yr.;
	var died;
	class age_group;
	output out=&tempwork..benzo_mort_ageband&yr. (drop=_type_ rename=(_freq_=benzo_N))
	mean()=benzo_avg lclm()=benzo_lclm uclm()= benzo_uclm / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=0 and year=&yr.;
	var died;
	class age_group;
	output out=&tempwork..nonbenzo_mort_ageband&yr. (drop=_type_ rename=(_freq_=nonbenzo_N))
	mean()=nonbenzo_avg lclm()=nonbenzo_lclm uclm()=nonbenzo_uclm / autoname;
run;

data &tempwork..mort_ageband&yr.;
	merge &tempwork..benzo_mort_ageband&yr. &tempwork..nonbenzo_mort_ageband&yr.;
	by age_group;
run;
%end;

%mend;

%mortality_ageband(2007,2015);

* Age-adjusted - Using the distribution of age in the 2007 sample so that you can compare across years
  as well as between benzo and non-benzo;

* Distribution of age in standard year - 2007;
proc freq data=&tempwork..mortality2007 noprint;
	table age / out=&tempwork..agedist2007 (drop=count rename=percent=pct07);
run;

* Distribution of age in each year;
proc freq data=&tempwork..mortality_long&byr.&eyr. noprint;
	table age*year / out=&tempwork..agedist_long (keep=age year count);
run;

* Merging together and getting weight for each age-year pair;
data &tempwork..age_weight;
	merge &tempwork..agedist_long (in=a) &tempwork..agedist2007 (in=b);
	by age;
	dist=b;
	weight=(pct07/100)/count;
run;

* Merge back to mortality long to be used for age-adjusted calculations;
proc sort data=&tempwork..mortality_long&byr.&eyr.; by age year; run;

data &tempwork..mortality_long&byr.&eyr.w;
	merge &tempwork..mortality_long&byr.&eyr. (in=a) &tempwork..age_weight (in=b);
	by age year;
	w=b;
run;

proc freq data=&tempwork..mortality_long&byr.&eyr.w;
	table w;
run;

* Checking that weights add up to 100 for each year;
proc means data=&tempwork..mortality_long&byr.&eyr.w nway sum;
	class year;
	var weight;
run;

* Finally, getting age-adjusted;
proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=1;
	weight weight;
	var died;
	class year;
	output out=&tempwork..benzo_mort_ageadj (drop=_type_ rename=(_freq_=benzo_N))
	mean()=benzo_avg lclm()=benzo_lclm uclm()=benzo_uclm / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=0;
	weight weight;
	var died;
	class year;
	output out=&tempwork..nonbenzo_mort_ageadj (drop=_type_ rename=(_freq_=nonbenzo_N))
	mean()=nonbenzo_avg lclm()=nonbenzo_lclm uclm()=nonbenzo_uclm / autoname;
run;

data &tempwork..mort_ageadj;
	merge &tempwork..benzo_mort_ageadj &tempwork..nonbenzo_mort_ageadj;
	by year;
run;


/********************************************************** 3a. ADRDv **********************************************************************/

* Unadjusted;

	* Whole population;
proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=1;
	var adrdv;
	class year;
	output out=&tempwork..benzo_adrdv_unadj_all (drop=_type_ rename=(_freq_=benzo_N))
	mean()=benzo_avg_all lclm()=benzo_lclm_all uclm()=benzo_uclm_all / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=0;
	var adrdv;
	class year;
	output out=&tempwork..nonbenzo_adrdv_unadj_all (drop=_type_ rename=(_freq_=nonbenzo_N))
	mean()=nonbenzo_avg_all lclm()=nonbenzo_lclm_all uclm()=nonbenzo_uclm_all / autoname;
run;

	* Survived population;
proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=1 and died=0;
	var adrdv;
	class year;
	output out=&tempwork..benzo_adrdv_unadj_surv (drop=_type_ rename=(_freq_=benzo_N_surv))
	mean()=benzo_avg_surv lclm()=benzo_lclm_surv uclm()=benzo_uclm_surv / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=0 and died=0;
	var adrdv;
	class year;
	output out=&tempwork..nonbenzo_adrdv_unadj_surv (drop=_type_ rename=(_freq_=nonbenzo_N_surv))
	mean()=nonbenzo_avg_surv lclm()=nonbenzo_lclm_surv uclm()=nonbenzo_uclm_surv / autoname;
run;

	* Died population;
proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=1 and died=1;
	var adrdv;
	class year;
	output out=&tempwork..benzo_adrdv_unadj_died (drop=_type_ rename=(_freq_=benzo_N_died))
	mean()=benzo_avg_died lclm()=benzo_lclm_died uclm()=benzo_uclm_died / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=0 and died=1;
	var adrdv;
	class year;
	output out=&tempwork..nonbenzo_adrdv_unadj_died (drop=_type_ rename=(_freq_=nonbenzo_N_died))
	mean()=nonbenzo_avg_died lclm()=nonbenzo_lclm_died uclm()=nonbenzo_uclm_died / autoname;
run;

data &tempwork..adrdv_unadj;
	merge 
	&tempwork..benzo_adrdv_unadj_all &tempwork..nonbenzo_adrdv_unadj_all
	&tempwork..benzo_adrdv_unadj_surv &tempwork..nonbenzo_adrdv_unadj_surv
	&tempwork..benzo_adrdv_unadj_died &tempwork..nonbenzo_adrdv_unadj_died;
	by year;
run;

* Age-adjusted age-bands;
%macro adrdv_ageband(byr,eyr);

%do yr=&byr. %to &eyr.;
* All;
proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=1 and year=&yr.;
	var adrdv;
	class age_group;
	output out=&tempwork..benzo_adrdv_ageband&yr._all (drop=_type_ rename=(_freq_=benzo_N))
	mean()=benzo_avg_all lclm()=benzo_lclm_all uclm()= benzo_uclm_all / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=0 and year=&yr.;
	var adrdv;
	class age_group;
	output out=&tempwork..nonbenzo_adrdv_ageband&yr._all (drop=_type_ rename=(_freq_=nonbenzo_N))
	mean()=nonbenzo_avg_all lclm()=nonbenzo_lclm_all uclm()=nonbenzo_uclm_all / autoname;
run;

* Survived;
proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=1 and year=&yr. and died=0;
	var adrdv;
	class age_group;
	output out=&tempwork..benzo_adrdv_ageband&yr._surv (drop=_type_ rename=(_freq_=benzo_N_surv))
	mean()=benzo_avg_surv lclm()=benzo_lclm_surv uclm()= benzo_uclm_surv / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=0 and year=&yr. and died=0;
	var adrdv;
	class age_group;
	output out=&tempwork..nonbenzo_adrdv_ageband&yr._surv (drop=_type_ rename=(_freq_=nonbenzo_N_surv))
	mean()=nonbenzo_avg_surv lclm()=nonbenzo_lclm_surv uclm()=nonbenzo_uclm_surv / autoname;
run;

* Died;
proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=1 and year=&yr. and died=1;
	var adrdv;
	class age_group;
	output out=&tempwork..benzo_adrdv_ageband&yr._died (drop=_type_ rename=(_freq_=benzo_N_died))
	mean()=benzo_avg_died lclm()=benzo_lclm_died uclm()= benzo_uclm_died / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr. noprint nway;
	where benzo_ever=0 and year=&yr. and died=1;
	var adrdv;
	class age_group;
	output out=&tempwork..nonbenzo_adrdv_ageband&yr._died (drop=_type_ rename=(_freq_=nonbenzo_N_died))
	mean()=nonbenzo_avg_died lclm()=nonbenzo_lclm_died uclm()=nonbenzo_uclm_died / autoname;
run;

data &tempwork..adrdv_ageband&yr.;
	merge 
	&tempwork..benzo_adrdv_ageband&yr._all &tempwork..nonbenzo_adrdv_ageband&yr._all
	&tempwork..benzo_adrdv_ageband&yr._surv &tempwork..nonbenzo_adrdv_ageband&yr._surv
	&tempwork..benzo_adrdv_ageband&yr._died &tempwork..nonbenzo_adrdv_ageband&yr._died;
	by age_group;
run;
%end;

%mend;

%adrdv_ageband(2007,2015);

* Age-adjusted;

	* Whole population;
proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=1;
	weight weight;
	var adrdv;
	class year;
	output out=&tempwork..benzo_adrdv_ageadj_all (drop=_type_ rename=(_freq_=benzo_N))
	mean()=benzo_avg_all lclm()=benzo_lclm_all uclm()=benzo_uclm_all / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=0;
	weight weight;
	var adrdv;
	class year;
	output out=&tempwork..nonbenzo_adrdv_ageadj_all (drop=_type_ rename=(_freq_=nonbenzo_N))
	mean()=nonbenzo_avg_all lclm()=nonbenzo_lclm_all uclm()=nonbenzo_uclm_all / autoname;
run;

	* Survived population;
proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=1 and died=0;
	weight weight;
	var adrdv;
	class year;
	output out=&tempwork..benzo_adrdv_ageadj_surv (drop=_type_ rename=(_freq_=benzo_N_surv))
	mean()=benzo_avg_surv lclm()=benzo_lclm_surv uclm()=benzo_uclm_surv / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=0 and died=0;
	weight weight;
	var adrdv;
	class year;
	output out=&tempwork..nonbenzo_adrdv_ageadj_surv (drop=_type_ rename=(_freq_=nonbenzo_N_surv))
	mean()=nonbenzo_avg_surv lclm()=nonbenzo_lclm_surv uclm()=nonbenzo_uclm_surv / autoname;
run;

	* Died population;
proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=1 and died=1;
	weight weight;
	var adrdv;
	class year;
	output out=&tempwork..benzo_adrdv_ageadj_died (drop=_type_ rename=(_freq_=benzo_N_died))
	mean()=benzo_avg_died lclm()=benzo_lclm_died uclm()=benzo_uclm_died / autoname;
run;

proc means data=&tempwork..mortality_long&byr.&eyr.w noprint nway;
	where benzo_ever=0 and died=1;
	weight weight;
	var adrdv;
	class year;
	output out=&tempwork..nonbenzo_adrdv_ageadj_died (drop=_type_ rename=(_freq_=nonbenzo_N_died))
	mean()=nonbenzo_avg_died lclm()=nonbenzo_lclm_died uclm()=nonbenzo_uclm_died / autoname;
run;

data &tempwork..adrdv_ageadj;
	merge 
	&tempwork..benzo_adrdv_ageadj_all &tempwork..nonbenzo_adrdv_ageadj_all
	&tempwork..benzo_adrdv_ageadj_surv &tempwork..nonbenzo_adrdv_ageadj_surv
	&tempwork..benzo_adrdv_ageadj_died &tempwork..nonbenzo_adrdv_ageadj_died;
	by year;
run;


/**************************************** Exports ****************************************************/

%macro exports(byr,eyr);
%export(mort_unadj);
%export(mort_ageadj);
%export(ADRDv_ageadj);
%export(ADRDv_unadj);
%do yr=&byr %to &eyr.;
%export(adrdv_ageband&yr.);
%end;
%do yr=&byr %to &eyr;
%export(mort_ageband&yr.);
%end;
%mend;

%exports(2007,2015);

options obs=max;

