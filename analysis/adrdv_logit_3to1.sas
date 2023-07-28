/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Do logit 
* Input: pde0616_benzo;
* Output: benzo & ssri/snri stats;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

options obs=max;
data &tempwork..first_insomnia;
	set &outlib..insomnia_dxdt_1999_2018;
	by bene_id insomniadx_dt;
	if first.bene_id;
	keep bene_id insomniadx_dt;
run;

data &tempwork..first_adrx;
	set demdx.addrugs_dts_0617;
	by bene_id srvc_dt;
	if first.bene_id;
run;

data &tempwork..first_antidepr_antipsych;
	set base.antipsych_pde0617 (where=(max(any_antidep,any_antipsych)=1 and dayssply>=30));
	by bene_id srvc_dt;
	if first.bene_id;
run;

%macro exportdesc(out);
proc export data=&tempwork..&out.
	outfile="&rootpath./Projects/Programs/benzo/exports/sample_desc.xlsx"
	dbms=xlsx 
	replace;
	sheet="&out";
run;
%mend;

%macro exportor(out);
proc export data=&tempwork..&out.
	outfile="&rootpath./Projects/Programs/benzo/exports/logit_bybenzos_or.xlsx"
	dbms=xlsx 
	replace;
	sheet="&out";
run;
%mend;


%macro logit(cohortyr);
%let nextyr=%eval(&cohortyr.+1);
data &tempwork..depr_anxi&cohortyr.;
	set &outlib..depranxi_dxdt_1999_2018 (where=(year(depranxidx_dt) in(&cohortyr,&nextyr)));
	by bene_id;
	if first.bene_id;
	keep bene_id;
run;

data &tempwork..antidepr_antipsych_pde&cohortyr.;
	set base.antipsych_pde0617 (where=(max(any_antidep,any_antipsych)=1 and dayssply>=30 and year(srvc_dt) in(&cohortyr.,&nextyr.)));
	by bene_id;
	if first.bene_id;
	keep bene_id;
run;

data &tempwork..logitprep&cohortyr.;
	merge &outlib..casecontrols_3to1_&cohortyr. (in=a) 
	&tempwork..first_insomnia (in=c)
	base.otcc0017 (in=d keep=bene_id depsn_medicare_ever anxi_medicare_ever) 
	base.cc9917 (in=e keep=bene_id hypert_ever hyperl_ever ami_ever atrial_fib_ever diabetes_ever stroke_tia_ever) 
	&tempwork..first_antidepr_antipsych (in=f keep=bene_id srvc_dt rename=(srvc_dt=first_antidepr_antipsych))
	&outlib..class1benzo_2006_2017p (in=g)
	&tempwork..depr_anxi&cohortyr. (in=i)
	&tempwork..antidepr_antipsych_pde&cohortyr. (in=j);
	by bene_id;

	if a;
	
	* requiring incidence benzo use in year;
	if year(class1benzo_minfilldt)=&cohortyr. then benzo_use=sum(class1benzo_pdays_&cohortyr.,class1benzo_pdays_&nextyr.); 
	
	if benzo_use>=30 then benzo_ever=1; else benzo_ever=0;

	* only measuring exposure for those who initiated in that year;
	if benzo_use<30 then benzo_exp="0.NonUser";
	if 30<=benzo_use<=89 then benzo_exp="1. 30-89    ";
	if 90<=benzo_use<=179 then benzo_exp="2. 90-179";
	if 180<=benzo_use<365 then benzo_exp="3. 180-365";
	if 365<=benzo_use then benzo_exp="4. >365";

	cc_hypert=(.<hypert_ever<=mdy(12,31,&nextyr.));
	cc_hyperl=(.<hyperl_ever<=mdy(12,31,&nextyr.));
	cc_ami=(.<ami_ever<=mdy(12,31,&nextyr.));
	cc_atf=(.<atrial_fib_ever<=mdy(12,31,&nextyr.));
	cc_diab=(.<diabetes_ever<=mdy(12,31,&nextyr.));
	cc_stroke=(.<stroke_tia_ever<=mdy(12,31,&nextyr.));
	
	cmd_depr=(.<depsn_medicare_ever<=mdy(12,31,&nextyr.));
	cmd_insomnia=(.<insomniadx_dt<=mdy(12,31,&nextyr.));
	cmd_anxi=(.<anxi_medicare_ever<=mdy(12,31,&nextyr.));
	*cmd_fatigue=(.<fatiguedx_dt<=mdy(12,31,&nextyr.));

	antidep_antipsych_ever=(.<first_antidepr_antipsych<=mdy(12,31,&nextyr.));

	depr_anxi_dxinyr=i;
	antidep_antipsych_rxinyr=j;

	race_dw=(race_bg='1');
	race_db=(race_bg='2');
	race_da=(race_bg='4');
	race_dh=(race_bg='5');
	race_dn=(race_bg='6');

	female=(sex='2');

	agegroup1=(age_group="1. 65-69");
	agegroup2=(age_group="2. 70-74");
	agegroup3=(age_group="3. 75-79");
	agegroup4=(age_group="4. 80-84");
	agegroup5=(age_group="5. 85-89");
	agegroup6=(age_group="6. 90+");

run;

proc freq data=&tempwork..logitprep&cohortyr.;
	table ADRDv*race_bg / out=&tempwork..race_bycase&cohortyr. outpct;
	table ADRDv*sex / out=&tempwork..sex_bycase&cohortyr. outpct;
	table ADRDv*age_group / out=&tempwork..age_bycase&cohortyr. outpct;
	table ADRDv*benzo_ever / out=&tempwork..benzo_bycase&cohortyr. outpct;
run;

proc means data=&tempwork..logitprep&cohortyr. noprint;
	class ADRDv;
	var cc: antidep_antipsych_ever antidep_antipsych_rxinyr cmd: depr_anxi_dxinyr;
	output out=&tempwork..cc_bycase&cohortyr. mean()= sum()= / autoname;
run;

proc freq data=&tempwork..logitprep&cohortyr.;
	table benzo_ever*race_bg / out=&tempwork..race_bybenzo&cohortyr. outpct;
	table benzo_ever*sex / out=&tempwork..sex_bybenzo&cohortyr. outpct;
	table benzo_ever*age_group / out=&tempwork..age_bybenzo&cohortyr. outpct;
run;

proc means data=&tempwork..logitprep&cohortyr. noprint;
	class benzo_ever;
	var female race_d: agegroup: cc: antidep_antipsych_ever antidep_antipsych_rxinyr cmd: depr_anxi_dxinyr;
	output out=&tempwork..cc_bybenzo&cohortyr. mean()= sum()= / autoname;
run;

proc means data=&tempwork..logitprep&cohortyr. noprint;
	where race_dn ne 1;
	class benzo_ever;
	var female race_d: agegroup: cc: antidep_antipsych_ever antidep_antipsych_rxinyr cmd: depr_anxi_dxinyr;
	output out=&tempwork..cc_bybenzo_na&cohortyr. mean()= sum()= / autoname;
run;

proc freq data=&tempwork..logitprep&cohortyr.;
	table ADRDv*benzo_ever / out=&tempwork..ADRDv_benzoever&cohortyr. outpct;
	table ADRDv*benzo_exp / out=&tempwork..ADRDv_benzoexp&cohortyr. outpct;
run;

ods output parameterestimates=&tempwork..base_est&cohortyr.;
ods output oddsratios=&tempwork..base_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. descending;
	class benzo_ever sex race_bg age_group / param=ref ref=first;
	model ADRDv = benzo_ever sex race_bg age_group ;
run;

ods output parameterestimates=&tempwork..cmd_est&cohortyr.;
ods output oddsratios=&tempwork..cmd_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. descending;
	class benzo_ever sex race_bg age_group cc: / param=ref ref=first;
	model ADRDv = benzo_ever sex race_bg age_group cc: ;
run;

ods output parameterestimates=&tempwork..mentalhlth_est&cohortyr.;
ods output oddsratios=&tempwork..mentalhlth_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. descending;
	class benzo_ever sex race_bg age_group cc: cmd: antidep_antipsych_ever / param=ref ref=first;
	model ADRDv = benzo_ever sex race_bg age_group cc: cmd: antidep_antipsych_ever ;
run;

ods output parameterestimates=&tempwork..mentalhlth_inyr_est&cohortyr.;
ods output oddsratios=&tempwork..mentalhlth_inyr_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. (drop=cmd_depr cmd_anxi) descending;
	class benzo_ever sex race_bg age_group cc: cmd: depr_anxi_dxinyr antidep_antipsych_rxinyr / param=ref ref=first;
	model ADRDv = benzo_ever sex race_bg age_group cc: cmd: depr_anxi_dxinyr antidep_antipsych_rxinyr;
run;

ods output parameterestimates=&tempwork..exp_base_est&cohortyr.;
ods output oddsratios=&tempwork..exp_base_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. descending;
	class benzo_exp sex race_bg age_group  / param=ref ref=first;
	model ADRDv = benzo_exp sex race_bg age_group ;
run;

ods output parameterestimates=&tempwork..exp_cmd_est&cohortyr.;
ods output oddsratios=&tempwork..exp_cmd_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. descending;
	class benzo_exp sex race_bg age_group cc:/ param=ref ref=first;
	model ADRDv = benzo_exp sex race_bg age_group cc: ;
run;

ods output parameterestimates=&tempwork..exp_mentalhlth_est&cohortyr.;
ods output oddsratios=&tempwork..exp_mentalhlth_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. descending;
	class benzo_exp sex race_bg age_group cc: cmd: antidep_antipsych_ever / param=ref ref=first;
	model ADRDv = benzo_exp sex race_bg age_group cc: cmd: antidep_antipsych_ever;
run;

ods output parameterestimates=&tempwork..exp_mentalhlth_inyr_est&cohortyr.;
ods output oddsratios=&tempwork..exp_mentalhlth_inyr_or&cohortyr.;
proc logistic data=&tempwork..logitprep&cohortyr. (drop=cmd_depr cmd_anxi) descending;
	class benzo_exp sex race_bg age_group cc: cmd: depr_anxi_dxinyr antidep_antipsych_rxinyr / param=ref ref=first;
	model ADRDv = benzo_exp sex race_bg age_group cc: cmd: depr_anxi_dxinyr antidep_antipsych_rxinyr ;
run;

%exportdesc(cc_bycase&cohortyr.);
%exportdesc(race_bycase&cohortyr.);
%exportdesc(age_bycase&cohortyr.);
%exportdesc(sex_bycase&cohortyr.);
%exportdesc(cc_bybenzo&cohortyr.);
%exportdesc(cc_bybenzo_na&cohortyr.);
%exportdesc(race_bybenzo&cohortyr.);
%exportdesc(age_bybenzo&cohortyr.);
%exportdesc(sex_bybenzo&cohortyr.);
%exportdesc(ADRDv_benzoever&cohortyr.);
%exportdesc(ADRDv_benzoexp&cohortyr.);
%mend;

%logit(2007);
%logit(2008);
%logit(2009);
%logit(2010);
%logit(2011);
%logit(2012);
%logit(2013);

%macro output(data);

%do cohortyr=2007 %to 2013;
	data &tempwork..&data._est&cohortyr.;
		set &tempwork..&data._est&cohortyr.;
		n=_n_;
	run;

	data &tempwork..&data._or&cohortyr.;
		set &tempwork..&data._or&cohortyr.;
		n=_n_+1;
	run;

	proc sort data=&tempwork..&data._est&cohortyr.;
		by n;
	run;

	proc sort data=&tempwork..&data._or&cohortyr.;
		by n;
	run;

	data &tempwork..&data.&cohortyr.;
		merge &tempwork..&data._est&cohortyr. 
			  &tempwork..&data._or&cohortyr.;
		by n;
	run;

	%exportor(&data.&cohortyr.);
%end;

%mend;

%output(exp_base);
%output(exp_cmd);
%output(exp_mentalhlth);
%output(exp_mentalhlth_inyr);
%output(base);
%output(cmd);
%output(mentalhlth);
%output(mentalhlth_inyr);

options obs=max;

