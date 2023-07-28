/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Flag beneficiaries who are in EGWP or enhanced plans with drug use;
* Input: bene_status_year, pde, fdb_ndc_extract;
* Output: antidep user descriptives;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2006;
%let maxyear=2013;

%macro beneplans_yr;
%do year=&minyear. %to &maxyear.;

data &tempwork..bene_plans&year;
	set mbsf.mbsf_abcd_&year (in=_&year keep=bene_id ptd_cntrct_id_01-ptd_cntrct_id_12 ptd_pbp_id_01-ptd_pbp_id_12);
	by bene_id;

	* checking to see how often plans change;
	array contract [*] ptd_cntrct_id_01-ptd_cntrct_id_12;
	array plan [*] ptd_pbp_id_01-ptd_pbp_id_12;

	year=&year;
	do i=1 to 12;
		mo=i;
		contract_id=contract[i];
		plan_id=plan[i];
		output;
	end;

	keep bene_id year mo contract_id plan_id;
run;

data &tempwork..planchar&year;
	%if &year=2006 %then set pdch&year..plan_char_&year._extract (keep= contract_id plan_id egwp_indicator drug_benefit_type);;
	%if &year>=2007 %then set pdch&year..plan_char_&year._extract (keep= contract_id plan_id excluded_drugs egwp_indicator drug_benefit_type);;
	year=&year;
run;

proc sort data=&tempwork..bene_plans&year.; by year contract_id plan_id; run;
proc sort data=&tempwork..planchar&year.; by year contract_id plan_id; run;

data &tempwork..bene_plans&year._1;
	merge &tempwork..bene_plans&year. (in=a) &tempwork..planchar&year. (in=b);
	by year contract_id plan_id;
	if a;
	planchar=b;
run;

proc freq data=&tempwork..bene_plans&year._1;
	table planchar;
run;

proc sort data=&tempwork..bene_plans&year._1; by bene_id year mo; run;

data &tempwork..bene_specialplans_&year.;
	set &tempwork..bene_plans&year._1;
	by bene_id year mo;
	if first.year then do;
		mo_cnt&year.=0;
		specialpln_cnt&year.=0;
	end;
	retain mo_cnt&year. specialpln_cnt&year.;
	if contract_id not in("","N","0","X") then mo_cnt&year.+1;

	if year=2006 then do;
		if egwp_indicator="Y" or drug_benefit_type="4" then specialpln_cnt&year.+1;
	end;
	else if year>=2007 then do;
		if egwp_indicator="Y" or (drug_benefit_type="4" and excluded_drugs="Y") then specialpln_cnt&year.+1;
	end;

	if last.year and mo_cnt&year.>0 and mo_cnt&year.=specialpln_cnt&year. then specialpln_allyr&year.="Y"; else specialpln_allyr&year.="N";

	if last.year;
	keep bene_id specialpln_cnt&year. specialpln_allyr&year.;
run;

%end;
%mend;

%beneplans_yr;

data &outlib..bene_specialplans_0613;
	merge &tempwork..bene_specialplans_2006-&tempwork..bene_specialplans_2013;
	by bene_id;
run;


options obs=max;

