/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Identify ADRD incident ;
* Input: pde0616_benzo;
* Output: benzo & ssri/snri stats;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

proc format;
	value agegroup
	65-<70="1. 65-69"
	70-<75="2. 70-74"
	75-<80="3. 75-79"
	80-<85="4. 80-84"
	85-<90="5. 85-89"
	90-high="6. 90+";
run;

* Identifying first dates of HIV, MND, MS and alcohol abuse;
data &tempwork..first_mnd;
	set &outlib..mnd_dxdt_1999_2018;
	by bene_id mnd_dx_dt;
	if first.bene_id;
	keep bene_id mnd_dx_dt;
run;

data &tempwork..first_adrx;
	set ad.addrugs_dts_0617;
	by bene_id srvc_dt;
	if first.bene_id;
run;

data &tempwork..first_downsyn;
	set &outlib..downsyn_dxdt_1999_2018;
	by bene_id downsyndromedx_dt;
	if first.bene_id;
	keep bene_id downsyndromedx_dt;
run;


*Setting up case and control data sets for matching - will match on sex race and age;
%macro match(cohortyr);
%let nextyr=%eval(&cohortyr+1);

data &tempwork..cases_&cohortyr &tempwork..controls_&cohortyr &tempwork..drops_&cohortyr;
	merge ad.adrdincv_1999_2020  (in=a keep=bene_id first_dx scen_dxsymp_inc) 
	&outlib..bene_specialplans_0613 (in=b) 
	base.samp_3yrffsptd_0620 (in=c where=(insamp&cohortyr.=1)) 
	&outlib..class1benzo_2006_2017p (in=d keep=bene_id class1benzo_minfilldt class1benzo_pdays_&cohortyr. class1benzo_pdays_&nextyr.) 
	&tempwork..first_mnd &outlib..otcc (keep=bene_id mulscl_medicare_ever alco_medicare_ever hivaids_medicare_ever)
	&tempwork..first_adrx (rename=srvc_dt=first_adrx) 
	&tempwork..first_downsyn;

	by bene_id;
	if c;

	* clear out everyone with history of HIV, MS, alcohol abuse, MND;
	if .<min(mnd_dx_dt,msdx_dt,hivaidsdx_dt,alcoholdx_dt,mulscl_medicare_ever,alco_medicare_ever,hivaids_medicare_ever,downsyndromedx_dt)<=mdy(12,31,2016) then drop_dxhistory=1;

	* clear out everyone who had benzo use prior to observation year;
	if .<class1benzo_minfilldt<mdy(1,1,&cohortyr) then drop_priorbenzo=1;

	* clear out prior ADRD;
	if .<year(scen_dxsymp_inc)<2015 then drop_priorADRD=1;
	
	* clear out prior ADRX;
	if .<year(first_adrx)<2015 then drop_priorADRX=1;

	* clear out everyone who is not continuously enrolled in FFS and Part D from cohort year to 2018, and in a special plan in observation window;
	array insamp [2006:2016] insamp2006-insamp2016;
	do yr=&cohortyr to 2016;
		if insamp[yr] ne 1 then drop_samp=1;
	end;
	%if &cohortyr<=2012 %then %do;
		if specialpln_allyr&cohortyr ne 'Y' or specialpln_allyr&nextyr ne 'Y' then drop_pln=1;
	%end;
	
	* age group is age in 2018;
	age_group=put(age_beg2016,agegroup.);
	
	* identify cases as ADRD incident in 2017 or 2018, and controls as at-risk in 2017-2018;
	if max(drop_dxhistory,drop_priorbenzo,drop_priorADRD,drop_priorADRX,drop_samp,drop_pln)=1 then output &tempwork..drops_&cohortyr;
	else if year(scen_dxsymp_inc) in (2015,2016) then output &tempwork..cases_&cohortyr;
	else if scen_dxsymp_inc=. or scen_dxsymp_inc>2016 then output &tempwork..controls_&cohortyr;
run;

* Get unique counts of all the different index groups in the cases;
proc freq data=&tempwork..drops_&cohortyr noprint;
	table drop_dxhistory*drop_samp*drop_pln*drop_priorADRD*drop_priorADRX*drop_priorbenzo / out=&tempwork..dropfreq_&cohortyr.;
run;

proc freq data=&tempwork..cases_&cohortyr noprint;
	table sex*race_bg*age_group / out=&tempwork..case_cnts_&cohortyr.;
run;

proc freq data=&tempwork..controls_&cohortyr noprint;
	table sex*race_bg*age_group / out=&tempwork..control_cnts_&cohortyr.;
run;

* Compare counts;
data &tempwork..compare_cnts_&cohortyr.;
	merge &tempwork..case_cnts_&cohortyr. (in=a) &tempwork..control_cnts_&cohortyr. (in=b rename=(count=control_cnts percent=control_pct));
	by sex race_bg age_group;
	case4=count*3;
	if control_cnts<case4 then flag=1;
run;

proc sort data=&tempwork..controls_&cohortyr.; by sex race_bg age_group; run;

data &tempwork..controls_&cohortyr._1;
	set &tempwork..controls_&cohortyr.;
	by sex race_bg age_group;
	if first.age_group then do;
		group+1;
	end;
	random=ranuni(20191023);
run;

proc sort data=&tempwork..controls_&cohortyr._1; by sex race_bg age_group random; run;

data &tempwork..controls_&cohortyr._2;
	merge &tempwork..case_cnts_&cohortyr. (in=a) &tempwork..controls_&cohortyr._1;
	by sex race_bg age_group;
	if first.age_group then do;
		subgroup=0;
	end;
	subgroup+1;
	if subgroup<=(count*3);
run;

proc freq data=&tempwork..controls_&cohortyr._2 noprint;
	table sex*race_bg*age_group / out=&tempwork..selected_ctrl_cnts3to1_&cohortyr.;
run;

data &tempwork..selected_cntrl_ck3to1_&cohortyr.;
	merge &tempwork..case_cnts_&cohortyr. (in=a rename=count=case_cnt) &tempwork..selected_ctrl_cnts3to1_&cohortyr. (rename=count=cntrl_cnt);
	by sex race_bg age_group;
run;

data &outlib..casecontrols_3to1_&cohortyr;
	set &tempwork..cases_&cohortyr. (in=a) &tempwork..controls_&cohortyr._2 (in=b where=(bene_id ne .));
	ADRDv=a;
	keep bene_id race_bg insamp: sex age_group ADRDv first_adrddx scen_dxsymp_inc;
run;

proc sort data=&outlib..casecontrols_3to1_&cohortyr.; by bene_id; run;
%mend;

%match(2007);
%match(2008);
%match(2009);
%match(2010);
%match(2011);
%match(2012);
%match(2013);

options obs=max;

