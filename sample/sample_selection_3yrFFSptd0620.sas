/*********************************************************************************************/
TITLE1 'Base';

* AUTHOR: Patricia Ferido;

* DATE: 8/20/2020;

* PURPOSE: Selecting Sample
					- Require over 65+ in year
					- Require FFS, Part D all year until death;

* INPUT: bene_status_yearYYYY, bene_demog2018;
* OUTPUT: samp_3yrffsptd_0620;;

options compress=yes nocenter ls=160 ps=200 errors=5  errorcheck=strict mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

***** Running header;
***%include "header.sas";

***** Formats;
proc format;
	value $raceft
		"0"="Unknown"
		"1"="Non-Hispanic White"
		"2"="Black"
		"3"="Other"
		"4"="Asian/Pacific Islander"
		"5"="Hispanic"
		"6"="American Indian/Alaska Native"
		"7"="All Races";
	value $sexft
		"1"="Male"
		"2"="Female";
	value agegroup
		low-<75 = "1. <75"
		75-84  = "2. 75-84"
		85 - high = "3. 85+";
	value agegroupa
		low-<70 = "1. <70  "
		70-74 = "2. 70-74"
		75-79  = "2. 75-89"
		80 - high = "3. 80+";
run;

***** Years of data;
%let demogyr=2020;

%let mindatayear=2004;
%let maxdatayear=2020;

***** Years of sample;
%let minsampyear=2006;
%let maxsampyear=2020;

options obs=max;
**** Step 1: Merge together bene_status yearly files;
%macro mergebene;
%do year=&mindatayear %to &maxdatayear;
%if &year<2006 %then %do;
	data &tempwork..bene&year;
		set &datalib..bene_status_year&year (keep=bene_id age_beg enrFFS_allyr enrAB_mo_yr);
		rename age_beg=age_beg&year enrFFS_allyr=enrFFS_allyr&year enrAB_mo_yr=enrAB_mo_yr&year;
	run;
%end;
%else %do;
	data &tempwork..bene&year;
		set &datalib..bene_status_year&year (keep=bene_id age_beg enrFFS_allyr enrAB_mo_yr ptD_allyr);
		rename age_beg=age_beg&year enrFFS_allyr=enrFFS_allyr&year enrAB_mo_yr=enrAB_mo_yr&year ptD_allyr=ptD_allyr&year;
	run;
%end;
%end;

data &tempwork..benestatus;
	merge &tempwork..bene&mindatayear-&tempwork..bene&maxdatayear;
	by bene_id;
run;
%mend; 

%mergebene;

**** Step 2: Merge to bene_demog which has standardized demographic variables & flag sample;
%macro sample;
data &outlib..samp_3yrffsptd_0620;
	merge &tempwork..benestatus (in=a) &datalib..bene_demog&demogyr. (in=b keep=bene_id dropflag race_bg sex birth_date death_date);
	by bene_id;
	if a and b;

	format birth_date death_date mmddyy10.;

	* Do not drop any race;
	* race_drop=(race_bg in("","0","3"));    
	if race_bg in("","0") then race_bg="3"; 
		
	%do year=&minsampyear %to &maxsampyear;
		
		%let prev1_year=%eval(&year-1);
		%let prev2_year=%eval(&year-2);

		* Age groups;
		age_group&year=put(age_beg&year,agegroup.);
		age_groupa&year=put(age_beg&year,agegroupa.);
		
		* First, doing Part D years where you cant look back due to enrollment issues in 2006;
		* Second, doing Part D year with only 1 year lookback;
		* Third, doing Part D years with two year lookback;
		%if &year<=2007 %then %do; 
		
			%let ptdprev1_year=&year;
			%let ptdprev2_year=&year;
			
			* limiting to age 67 and in FFS and Part D in 2 previous years;
			if age_beg&year>=67 
			and dropflag="N"
			and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12) 
			and (ptD_allyr&ptdprev2_year="Y" and ptd_allyr&ptdprev1_year="Y" and ptd_allyr&year="Y")
			then insamp&year=1;
			else insamp&year=0;
			
		%end;
		
		%if &year=2008 %then %do;
		
			%let ptdprev1_year=%eval(&year-1);
			%let ptdprev2_year=%eval(&year-1);
			
			* limiting to age 67 and in FFS and Part D in 2 previous years;
			if age_beg&year>=67 
			and dropflag="N"
			and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12) 
			and (ptD_allyr&ptdprev2_year="Y" and ptd_allyr&ptdprev1_year="Y" and ptd_allyr&year="Y")
			then insamp&year=1;
			else insamp&year=0;
			
		%end;
		
		%else %if &year>2008 %then %do;
			
			%let ptdprev1_year=%eval(&year-1);
			%let ptdprev2_year=%eval(&year-2);
			
			* Limiting to age 67 and in FFS and Part D in 2 previous years;
			if age_beg&year>=67 
			and dropflag="N"
			and (enrFFS_allyr&prev2_year="Y" and enrFFS_allyr&prev1_year="Y" and enrFFS_allyr&year="Y")
			and (enrAB_mo_yr&prev2_year=12 and enrAB_mo_yr&prev1_year=12) 
			and (ptD_allyr&ptdprev2_year="Y" and ptd_allyr&ptdprev1_year="Y" and ptd_allyr&year="Y")
			then insamp&year=1;
			else insamp&year=0;
			
		%end;
		
			
	%end;
	
	anysamp=max(of insamp&minsampyear-insamp&maxsampyear);
	
run;
%mend;

%sample;

***** Step 3: Sample Statistics;
%macro stats;

* By year;
%do year=&minsampyear %to &maxsampyear;
proc freq data=&outlib..samp_3yrffsptd_0620 noprint;
	where insamp&year=1;
	format race_bg $raceft. sex $sexft.;
	table race_bg / out=&tempwork..byrace_&year;
	table age_group&year / out=&tempwork..byage_&year;
	table age_groupa&year / out=&tempwork..byagea_&year;
	table sex / out=&tempwork..bysex_&year;
run;

proc transpose data=&tempwork..byrace_&year out=&tempwork..byrace_&year._t (drop=_name_ _label_); var count; id race_bg; run;
proc transpose data=&tempwork..byage_&year out=&tempwork..byage_&year._t (drop=_name_ _label_); var count; id age_group&year; run;
proc transpose data=&tempwork..byagea_&year out=&tempwork..byagea_&year._t (drop=_name_ _label_); var count; id age_groupa&year; run;
proc transpose data=&tempwork..bysex_&year out=&tempwork..bysex_&year._t (drop=_name_ _label_); var count; id sex; run;

proc contents data=&tempwork..byrace_&year._t; run;
proc contents data=&tempwork..byage_&year._t; run;
proc contents data=&tempwork..bysex_&year._t; run;

proc means data=&outlib..samp_3yrffsptd_0620 noprint;
	where insamp&year=1;
	output out=&tempwork..avgage_&year (drop=_type_ rename=_freq_=total_bene) mean(age_beg&year)=avgage;
run;

data &tempwork..stats&year;
	length year $7.;
	merge &tempwork..byrace_&year._t &tempwork..byage_&year._t &tempwork..byagea_&year._t &tempwork..bysex_&year._t &tempwork..avgage_&year;
	year="&year";
run;
%end;

* Overall - only from 2007 to 2013;
proc freq data=&outlib..samp_3yrffsptd_0620 noprint;
	where anysamp=1;
	format race_bg $raceft. sex $sexft.;
	table race_bg / out=&tempwork..byrace_all;
	table sex / out=&tempwork..bysex_all;
run;

proc transpose data=&tempwork..byrace_all out=&tempwork..byrace_all_t (drop=_name_ _label_); var count; id race_bg; run;
proc transpose data=&tempwork..bysex_all out=&tempwork..bysex_all_t (drop=_name_ _label_); var count; id sex; run;

data &tempwork..allages;
	set
	%do year=&minsampyear %to &maxsampyear;
		&outlib..samp_3yrffsptd_0620 (where=(insamp&year=1) keep=insamp&year bene_id age_beg&year rename=(age_beg&year=age_beg))
	%end;;
run;

proc means data=&tempwork..allages;
	var age_beg;
	output out=&tempwork..avgage_all (drop=_type_ _freq_) mean=avgage;
run;

data &tempwork..statsoverall;
	merge &tempwork..byrace_all_t &tempwork..bysex_all_t &tempwork..avgage_all;
	year="all";
run;

data samp_stats_ffsptd;
	set &tempwork..stats&minsampyear-&tempwork..stats&maxsampyear &tempwork..statsoverall;
run;

proc export data=samp_stats_ffsptd
	outfile="&rootpath./Projects/Programs/base/exports/samp_stats_3yrffsptd_0620.xlsx"
	dbms=xlsx
	replace;
	sheet="stats";
run;

proc contents data=&outlib..samp_3yrffsptd_0620; run;

%do year=&minsampyear. %to &maxsampyear.;
proc freq data=&outlib..samp_3yrffsptd_0620;
	where insamp&year.=1;
	table age_beg&year. / out=&tempwork..freq_1yragedist&year.;
run;

proc export data=&tempwork..freq_1yragedist&year.
	outfile="&rootpath./Projects/Programs/base/exports/samp_stats_3yrffsptd_0620.xlsx"
	dbms=xlsx
	replace;
	sheet="detail_age_dist&year.";
run;	
%end;

%mend;

%stats;


options obs=max;
