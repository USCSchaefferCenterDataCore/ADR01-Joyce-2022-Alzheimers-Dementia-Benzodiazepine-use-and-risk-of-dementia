/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Looking at benzo use in 2013-2014 but only for pain diagnoses and verified ADRD in 2016
* 1) Limit results to 3 month window around incident benzo diagnosis in 2013, everyone has a pain diagnosis from 
Q4 2012 to Q1 2014 to allow 3 month window around benzo use;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

* Sample:
- FFS & Part D from 2013-2016
- Pain dx in 2013
- No dx of depression, anxiety, fatigue, insomnia prior to end of observation window (2014)
- Merge in verfied ADRD in 2016;

proc format;
	value agegroup
	65-<70="1. 65-69"
	70-<75="2. 70-74"
	75-<80="3. 75-79"
	80-<85="4. 80-84"
	85-<90="5. 85-89"
	90-high="6. 90+";
run;

* Isolate pain dx;
%let pain_icd10="M5020","M5030","M5134","M5135","M5136","M5137","M4802","M542","M546","M545","M5430","M5489","M549","M5126","M5127",
"M5124","M5125","M4800","M4804","M48061","M4808";
%let pain_icd9="7220","7224","7226","7230","7231","7241","7242","7243","7245","72210","72211","72251","72252","72400","72401","72402","72409";

data &tempwork..first_insomnia;
	set &outlib..insomnia_dxdt_1999_2018 (where=(year(insomniadx_dt)<=2014));
	by bene_id insomniadx_dt;
	if first.bene_id;
	keep bene_id insomniadx_dt;
run;

data &tempwork..first_depranxi;
	set &outlib..depranxi_dxdt_1999_2018 (where=(year(depranxidx_dt)<=2014));
	by bene_id;
	if first.bene_id;
	keep bene_id depranxidx_dt;
run;

data &tempwork..first_antidepr_antipsych;
	set bpsd.bpsd_pde0618 (where=(max(antidepressants,atypical)=1 and dayssply>=30 and year(srvc_dt)<=2014));
	by bene_id;
	if first.bene_id;
	keep bene_id srvc_dt;
run;

%let displacement="7220" "72210" "72211" "7224" "72251" "72252" "7226";
%let stenosis="7230" "7231" "72400" "72401" "72402" "72409";
%let backpain="7241" "7242" "7243" "7245";

data &tempwork..backpain_2012q4_2014q1;
	set &outlib..pain_dxdt_1999_2018;
	by bene_id pain_dx_dt;
	array paindx [*] pain_dx1-pain_dx50;
	if mdy(10,1,2012)<=pain_dx_dt<=mdy(3,31,2015);
	keep=0;
	do i=1 to 50;
		if paindx[i] in(&pain_icd10,&pain_icd9) then keep=1;
		if paindx[i] in(&displacement) then displacement=1;
		if paindx[i] in(&stenosis) then stenosis=1;
		if paindx[i] in(&backpain) then backpain=1;
	end;
	if keep=1;
run;

proc means data=&tempwork..backpain_2012q4_2014q1 noprint nway;
	class bene_id;
	var displacement stenosis backpain;
	output out=&tempwork..paincat (drop=_type_ _freq_) max()=;
run;

proc transpose data=&tempwork..backpain_2012q4_2014q1 out=&tempwork..backpain_bene prefix=pain_dx_dt;
	by bene_id;
	var pain_dx_dt;
run;

* Finding incident benzo users within 3 months of any pain diagnosis;
%let cohortyr=2013;
%let nextyr=2014;

data &tempwork..benzoforpain_adrdv2018_window &tempwork..benzoforpain_adrdv2018_dropsw
	 &tempwork..benzoforpain_adrdunv2020_window &tempwork..benzoforpain_adrdunv2020_dropsw;
	merge &tempwork..backpain_bene (in=a keep=bene_id pain_dx_dt:) 
	base.samp_3yrffsptd_0620 (in=b keep=bene_id age_beg2013 sex race_bg insamp:)
	ad.adrdincv_1999_2020 (in=c keep=bene_id first_dx first_adrx scen_dxsymp_inc)
	&outlib..class1benzo_2006_2017p (in=d keep=bene_id class1benzo_minfilldt class1benzo_minfilldt_2013 
	class1benzo_clms_2013 class1benzo_clms_2014 class1benzo_pdays_2013 class1benzo_pdays_2014 class1benzo_minfilldt_2014 class1benzo_pdays_2015) 
	base.otcc0017 (keep=bene_id mulscl_medicare_ever alco_medicare_ever hivaids_medicare_ever)
	base.cc9917 (in=e keep=bene_id hypert_ever hyperl_ever ami_ever atrial_fib_ever diabetes_ever stroke_tia_ever)
	&tempwork..first_antidepr_antipsych (in=f)
	&tempwork..first_depranxi(in=g)
	&tempwork..first_insomnia(in=h)
	benzo.opioid_2006_2017p (in=i keep=bene_id opioid_pdays_2013 opioid_pdays_2014)
	benzo.zdrug_2006_2017p (in=j keep=bene_id zdrug_pdays_2006-zdrug_pdays_2017)
	&tempwork..paincat (in=k)
;
	by bene_id;

	* limit to 2013 pain dx;
	if a;

	* age group;
	age_group=put(age_beg2013,agegroup.);

	* limit to FFS/PtD until 2020 to allow for 2-year verification;
	array insamp [2013:2020] insamp2013-insamp2020;

	drop_samp=0;
	do yr=2013 to 2020;
		if insamp[yr] ne 1 then drop_samp=1;
	end;	

	* clear out any depression, insomnia, anxiety before end of obs window;
	if max(f,g,h) then drop_benzodx=1;

	* clear out prior ADRD and drug use;
	if .<year(scen_dxsymp_inc)<2018 or .<year(first_adrx)<2018 then drop_prioradrdv2018=1;
	if .<year(first_dx)<2020 or .<year(first_adrx)<2020 then drop_prioradrdunv2020=1;

	* outcome - ADRD inc;
	ADRDv2018=0;
	if year(scen_dxsymp_inc)=2018  then ADRDv2018=1;

	ADRDunv2020=0;
	if year(first_dx)=2020 then ADRDunv2020=1;

	* comorbids;
	cc_hypert=(.<hypert_ever<=mdy(12,31,2014));
	cc_hyperl=(.<hyperl_ever<=mdy(12,31,2014));
	cc_ami=(.<ami_ever<=mdy(12,31,2014));
	cc_atf=(.<atrial_fib_ever<=mdy(12,31,2014));
	cc_diab=(.<diabetes_ever<=mdy(12,31,2014));
	cc_stroke=(.<stroke_tia_ever<=mdy(12,31,2014));

	* Opioid Use;
	opioid_use=sum(opioid_pdays_2013,opioid_pdays_2014);
	opioid_ever=(opioid_use>=30);

	/***********************************************
	Benzo Use:
	- Benzo "users" initiate within 3 months before or after a pain diagnosis
	- Benzo users also have at least 30 day supply or are not considered benzo "users"
	- Benzo users with initiation date prior to 2013 are dropped from sample
	- Benzo uesrs who initiate in observation window but are not within 3 months of a pain diagnosis
	are dropped from sample
	************************************************/

	* Getting ever benzo use;
	if year(class1benzo_minfilldt)=2013 then benzo_use=sum(class1benzo_pdays_2013,class1benzo_pdays_2014);
	if year(class1benzo_minfilldt)=2014 then benzo_use=sum(class1benzo_pdays_2014,class1benzo_pdays_2015);
	benzo_ever=(benzo_use>=30);
	if benzo_use<30 then benzo_exp="0.NonUser";
	if 30<=benzo_use<=89 then benzo_exp="1. 30-89    ";
	if 90<=benzo_use<=179 then benzo_exp="2. 90-179";
	if 180<=benzo_use<365 then benzo_exp="3. 180-365";
	if 365<=benzo_use then benzo_exp="4. >365";

	* Finding in window incident benzo;
	array paindt [*] pain_dx_dt1-pain_dx_dt909;
	inwindow=0;
	format start end mmddyy10.;
	if benzo_ever=1 then do i=1 to dim(paindt);
		start=intnx('month',paindt[i],-3,'s');
		end=intnx('month',paindt[i],3,'s');
		if inwindow=0 then do;
			if year(class1benzo_minfilldt)=2013 and start<=class1benzo_minfilldt_2013<=end then inwindow=1;
			if year(class1benzo_minfilldt)=2014 and start<=class1benzo_minfilldt_2014<=end then inwindow=1;
		end;
	end;

	benzo_ever_inwindow=benzo_ever;
	benzo_exp_inwindow=benzo_exp;

	if inwindow=0 and benzo_ever=1 then do;
		benzo_ever_inwindow=.;
		benzo_exp_inwindow="";
	end;

	if .<year(class1benzo_minfilldt)<&cohortyr. then drop_notinc=1;

	* Z drug use;
	if year(class1benzo_minfilldt)=2013 then zdrugpdays=sum(zdrug_pdays_2013,zdrug_pdays_2014);
	else if year(class1benzo_minfilldt)=2014 then zdrugpdays=sum(zdrug_pdays_2014,zdrug_pdays_2015);
	else zdrugpdays=sum(zdrug_pdays_2013,zdrug_pdays_2014);

	if zdrugpdays>=30 then zdruguse=1; else zdruguse=0;

	* Pain dx categorical;
	if displacement=. then displacement=0;
	if backpain=. then backpain=0;
	if stenosis=. then stenosis=0;

	if max(drop_prioradrdv2018,drop_benzodx,drop_samp,drop_notinc) then output &tempwork..benzoforpain_adrdv2018_dropsw;
	else output &tempwork..benzoforpain_adrdv2018_window;

	if max(drop_prioradrdunv2020,drop_benzodx,drop_samp,drop_notinc) then output &tempwork..benzoforpain_adrdunv2020_dropsw;
	else output &tempwork..benzoforpain_adrdunv2020_window;

run;

* Case Control matching;
%macro benzoforpain(inv);
proc freq data=&tempwork..benzoforpain_adrd&inv._window noprint;
	where benzo_ever_inwindow=1;
	table sex*race_bg*age_group / out=&tempwork..case_cnts_&inv.;
run;

proc freq data=&tempwork..benzoforpain_adrd&inv._window noprint;
	where benzo_ever_inwindow=0;
	table sex*race_bg*age_group / out=&tempwork..control_cnts_&inv.;
run;

* Compare counts;
data &tempwork..compare_cnts_&inv.;
	merge &tempwork..case_cnts_&inv. (in=a) &tempwork..control_cnts_&inv. (in=b rename=(count=control_cnts percent=control_pct));
	by sex race_bg age_group;
	case5=count*5;
	if control_cnts<case5 then flag=1;
run;

proc sort data=&tempwork..benzoforpain_adrd&inv._window out=&tempwork..controls_&inv.;
	where benzo_ever_inwindow=0;
	by sex race_bg age_group;
run;

data &tempwork..controls_&inv._1;
	set &tempwork..controls_&inv.;
	by sex race_bg age_group;
	if first.age_group then do;
		group+1;
	end;
	random=ranuni(20200318);
run;

proc sort data=&tempwork..controls_&inv._1; by sex race_bg age_group random; run;

data &tempwork..controls_&inv._2;
	merge &tempwork..case_cnts_&inv. (in=a) &tempwork..controls_&inv._1;
	by sex race_bg age_group;
	if first.age_group then do;
		subgroup=0;
	end;
	subgroup+1;
	if subgroup<=(count*5);
run;

proc freq data=&tempwork..controls_&inv._2 noprint;
	table sex*race_bg*age_group / out=&tempwork..selected_ctrl_cnts5to1_&inv.;
run;

data &tempwork..selected_cntrl_ck5to1_&inv.;
	merge &tempwork..case_cnts_&inv. (in=a rename=count=case_cnt) &tempwork..selected_ctrl_cnts5to1_&inv. (rename=count=cntrl_cnt);
	by sex race_bg age_group;
run;

data &outlib..benzoforpain_5to1_adrd&inv.;
	set &tempwork..benzoforpain_adrd&inv._window (in=a where=(benzo_ever_inwindow=1)) 
		&tempwork..controls_&inv._2 (in=b where=(bene_id ne .));
run;

proc sort data=&outlib..benzoforpain_5to1_adrd&inv.; by bene_id; run;

proc freq data=&outlib..benzoforpain_5to1_adrd&inv.;
	table benzo_ever benzo_exp benzo_ever*benzo_ever_inwindow benzo_exp*benzo_exp_inwindow / missing;
run;

proc freq data=&tempwork..benzoforpain_adrd&inv._dropsw;
		table drop_prioradrd&inv.*drop_benzodx*drop_samp*drop_notinc / out=&tempwork..freq_drops_w&inv.;
run;

proc freq data=&outlib..benzoforpain_5to1_adrd&inv.;
	where benzo_ever_inwindow ne .;
	table ADRD&inv.*race_bg / out=&tempwork..race_byADRDv_w&inv.;
	table ADRD&inv.*sex / out=&tempwork..sex_byADRDv_w&inv.;
	table ADRD&inv.*age_group / out=&tempwork..age_byADRDv_w&inv.;
run;

proc means data=&outlib..benzoforpain_5to1_adrd&inv. noprint;
	where benzo_ever_inwindow ne .;
	class ADRD&inv.;
	var cc: opioid_ever;
	output out=&tempwork..cc_bycasecntrl_w mean()= sum()= / autoname;
run;

proc freq data=&outlib..benzoforpain_5to1_adrd&inv.;
	where benzo_ever_inwindow ne .;
	table benzo_ever_inwindow*race_bg / out=&tempwork..race_bybenzo_w&inv. outpct;
	table benzo_ever_inwindow*sex / out=&tempwork..sex_bybenzo_w&inv. outpct;
	table benzo_ever_inwindow*age_group / out=&tempwork..age_bybenzo_w&inv. outpct;
run;

proc freq data=&outlib..benzoforpain_5to1_adrd&inv.;
	where benzo_ever_inwindow ne .;
	table benzo_exp_inwindow*race_bg / out=&tempwork..race_bybenzoexp_w&inv. outpct;
	table benzo_exp_inwindow*sex / out=&tempwork..sex_bybenzoexp_w&inv. outpct;
	table benzo_exp_inwindow*age_group / out=&tempwork..age_bybenzoexp_w&inv. outpct;
run;

proc means data=&outlib..benzoforpain_5to1_adrd&inv. noprint;
	where benzo_ever_inwindow ne .;
	class benzo_ever_inwindow;
	var cc: opioid_ever zdruguse displacement backpain stenosis;
	output out=&tempwork..cc_bybenzo_w&inv. mean()= sum()= / autoname;
run;

proc means data=&outlib..benzoforpain_5to1_adrd&inv. noprint;
	where benzo_ever_inwindow ne .;
	class benzo_exp_inwindow;
	var cc: opioid_ever;
	output out=&tempwork..cc_bybenzoexp_w&inv. mean()= sum()= / autoname;
run;

proc freq data=&outlib..benzoforpain_5to1_adrd&inv.;
	where benzo_ever_inwindow ne .;
	table ADRD&inv.*benzo_ever_inwindow / out=&tempwork..ADRDv_benzoever_w&inv. outpct;
	table ADRD&inv.*benzo_exp_inwindow / out=&tempwork..ADRDv_benzoexp_w&inv. outpct;
run;

ods output parameterestimates=logit_base_est_w&inv.;
ods output oddsratios=logit_base_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_ever_inwindow sex race_bg age_group / param=ref ref=first;
	model ADRD&inv. = benzo_ever_inwindow sex race_bg age_group ;
run;

ods output parameterestimates=logit_cmd_est_w&inv.;
ods output oddsratios=logit_cmd_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_ever_inwindow sex race_bg age_group cc: / param=ref ref=first;
	model ADRD&inv. = benzo_ever_inwindow sex race_bg age_group cc: ;
run;

ods output parameterestimates=logit_opioid_est_w&inv.;
ods output oddsratios=logit_opioid_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_ever_inwindow sex race_bg age_group cc: opioid_ever / param=ref ref=first;
	model ADRD&inv. = benzo_ever_inwindow sex race_bg age_group cc: opioid_ever;
run;

ods output parameterestimates=logit_zdrug_est_w&inv.;
ods output oddsratios=logit_zdrug_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_ever_inwindow sex race_bg age_group cc: opioid_ever zdruguse / param=ref ref=first;
	model ADRD&inv. = benzo_ever_inwindow sex race_bg age_group cc: opioid_ever zdruguse;
run;

ods output parameterestimates=logit_pain_est_w&inv.;
ods output oddsratios=logit_pain_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_ever_inwindow sex race_bg age_group cc: opioid_ever zdruguse displacement stenosis backpain/ param=ref ref=first;
	model ADRD&inv. = benzo_ever_inwindow sex race_bg age_group cc: opioid_ever zdruguse displacement stenosis backpain;
run;

ods output parameterestimates=logit_expbase_est_w&inv.;
ods output oddsratios=logit_expbase_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_exp sex race_bg age_group  / param=ref ref=first;
	model ADRD&inv. = benzo_exp sex race_bg age_group ;
run;

ods output parameterestimates=logit_expcmd_est_w&inv.;
ods output oddsratios=logit_expcmd_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_exp sex race_bg age_group cc:/ param=ref ref=first;
	model ADRD&inv. = benzo_exp sex race_bg age_group cc: ;
run;

ods output parameterestimates=logit_expopioid_est_w&inv.;
ods output oddsratios=logit_expopioid_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_exp sex race_bg age_group cc: opioid_ever / param=reference ref=first;
	model ADRD&inv. = benzo_exp sex race_bg age_group cc: opioid_ever;
run;

ods output parameterestimates=logit_expzdrug_est_w&inv.;
ods output oddsratios=logit_expzdrug_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_exp sex race_bg age_group cc: opioid_ever zdruguse / param=reference ref=first;
	model ADRD&inv. = benzo_exp sex race_bg age_group cc: opioid_ever zdruguse;
run;

ods output parameterestimates=logit_exppain_est_w&inv.;
ods output oddsratios=logit_exppain_or_w&inv.;
proc logistic data=&outlib..benzoforpain_5to1_adrd&inv. descending;
	where benzo_ever_inwindow ne .;
	class benzo_exp sex race_bg age_group cc: opioid_ever zdruguse displacement stenosis backpain/ param=reference ref=first;
	model ADRD&inv. = benzo_exp sex race_bg age_group cc: opioid_ever zdruguse displacement stenosis backpain;
run;

/******************************** Counting Number of DX per Pain Diagnosis *****************************/
* Number of diagnosis and number of benes per pain diagnosis in final analytical data set;
data &tempwork..countpaindx&inv.;
	merge &outlib..benzoforpain_5to1_adrd&inv. (in=a keep=bene_id benzo_ever_inwindow where=(benzo_ever_inwindow ne .))
		  &tempwork..backpain_2012q4_2014q1 (in=b);	
	by bene_id;

	if a;
	dx=b;

	array pain_dx [*] pain_dx1-pain_dx50;

	do i=1 to 50;
		if pain_dx[i] in(&pain_icd10,&pain_icd9) then do;
			paindx=pain_dx[i];
			output;
		end;
	end;

run;

proc freq data=&tempwork..countpaindx&inv.;
	table dx;
run;

proc freq data=&tempwork..countpaindx&inv. noprint;
	table bene_id / out=&tempwork..beneck&inv.;
run;

* Number of dx;
proc freq data=&tempwork..countpaindx&inv. noprint;
	table paindx / out=&tempwork..count_paindx_w&inv.;
run;

* Count bene;
proc freq data=&tempwork..countpaindx&inv. noprint;
	table paindx*bene_id / out=&tempwork..count_painbene&inv.;
run;

proc freq data=&tempwork..count_painbene&inv. noprint;
	table paindx / out=&tempwork..count_painbene_w&inv.;
run;

%macro exportdesc(data);
proc export data=&tempwork..&data._w&inv.
	outfile="&rootpath./Projects/Programs/benzo/exports/benzoforpain_desc_w&inv..xlsx"
	dbms=xlsx 
	replace;
	sheet="&tempwork..&data._w&inv.";
run;
%mend;

%exportdesc(count_painbene);
%exportdesc(count_paindx);
%exportdesc(race_byadrdv);
%exportdesc(sex_byadrdv);
%exportdesc(age_byadrdv);
%exportdesc(race_bybenzo);
%exportdesc(sex_bybenzo);
%exportdesc(age_bybenzo);
%exportdesc(cc_bybenzo);
%exportdesc(ADRDv_benzoever);
%exportdesc(ADRDv_benzoexp);
%exportdesc(freq_drops);
%exportdesc(race_bybenzoexp);
%exportdesc(sex_bybenzoexp);
%exportdesc(age_bybenzoexp);
%exportdesc(cc_bybenzoexp);

%macro exportor(data);
proc export data=&data._w&inv.
	outfile="&rootpath./Projects/Programs/benzo/exports/benzoforpain_logit_w&inv..xlsx"
	dbms=xlsx 
	replace;
	sheet="&data._w&inv.";
run;
%mend;

%exportor(logit_base_est);
%exportor(logit_base_or);
%exportor(logit_cmd_est);
%exportor(logit_cmd_or);
%exportor(logit_expbase_est);
%exportor(logit_expbase_or);
%exportor(logit_expcmd_est);
%exportor(logit_expcmd_or);
%exportor(logit_opioid_est);
%exportor(logit_opioid_or);
%exportor(logit_expopioid_est);
%exportor(logit_expopioid_or);
%exportor(logit_zdrug_est);
%exportor(logit_zdrug_or);
%exportor(logit_expzdrug_est);
%exportor(logit_expzdrug_or);
%exportor(logit_pain_est);
%exportor(logit_pain_or);
%exportor(logit_exppain_est);
%exportor(logit_exppain_or);

%mend;

%benzoforpain(v2018);
%benzoforpain(unv2020);

options obs=max;

		


