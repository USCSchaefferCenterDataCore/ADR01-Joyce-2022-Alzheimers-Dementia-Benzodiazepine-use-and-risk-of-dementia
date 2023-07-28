/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Pull Anti-depressant Claims and Summarize using Drug Pull Method;
* Input: bene_status_year, pde, fdb_ndc_extract;
* Output: antidep user descriptives;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2006;
%let maxyear=2017;

%macro pillpush;

%do year=&minyear %to &maxyear;
data &tempwork..pde&year.;
	set &outlib..opioid_pde0617 (where=(year(srvc_dt)=&year.) keep=bene_id srvc_dt dayssply);
	by bene_id;
run;
%end;

%macro opioidpull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data &tempwork..pde&year._1;
	&set. set &tempwork..pde&year.;
	&merge. merge &tempwork..pde&year. (in=a) &tempwork..pde&prev_year._6 (in=b keep=bene_id opioid_push_&prev_year.);
	by bene_id;
	&merge. if a;
run;

* If there are multiple claims on the same day for the same beneficiary, we think those
prescriptions are meant to be taken together, meaning that if it is two 30 day fills, it is worth
30 possession days, not 60. So, we will take the max of the two claims on the same day, and then drop
one of the observations. ;

proc sort data=&tempwork..pde&year._1; by bene_id srvc_dt dayssply; run;

data &tempwork..pde&year._2;
	set &tempwork..pde&year._1;
	by bene_id srvc_dt dayssply;
	if last.srvc_dt;
run;

* Early fills pushes
	- for people that fill their prescription before emptying their last, carry the extra pills forward
	- extrapill_push is the amount, from that fill date, that is superfluous for reaching the next fill date. Capped at 10;

data &tempwork..pde&year._3;
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in opioida;
	if _n_ ne obs then set &tempwork..pde&year._2 (firstobs=2 keep=srvc_dt rename=(srvc_dt=uplag_srvc_dt));
	set &tempwork..pde&year._2 nobs=obs;
	count+1;
run;

proc sort data=&tempwork..pde&year._3; by bene_id srvc_dt count; run;

proc sort data=&tempwork..pde&year._3; by bene_id srvc_dt count; run;

data &tempwork..pde&year._4;
	set &tempwork..pde&year._3;
	by bene_id srvc_dt;
	if last.bene_id then uplag_srvc_dt=.;
	
	* adjusting doy flags so that they are the same as dougs - will make an adjusted version;
	doy_srvc_dt=intck('day',mdy(1,1,&year),srvc_dt)+1;
	doy_uplag_srvc_dt=intck('day',mdy(1,1,&year),uplag_srvc_dt)+1;
	
	extrapill_push=(doy_srvc_dt+dayssply)-doy_uplag_srvc_dt; * will be blank at the end of the year;
	if extrapill_push<0 then extrapill_push=0;
	if extrapill_push>10 then extrapill_push=10;
	* pushstock is the accumulated stock of extra pills. Capped at 10;
	pushstock=extrapill_push;
	&merge. if first.bene_id then pushstock=sum(pushstock,opioid_push_&prev_year.);

	* The methodology below will do the following:
  	1. Add the previous pushstock to the current pushstock
  	2. Calculate the number of pills to be added to the dayssply, which is the minimum of the
  		 need or the pushstock. Dayssply2=sum(dayssply,min(need,pushstock1))
  	3. Subtract the need from the pushstock sum and capping the minimum at 0 so that pushstock will never be negative.
  		 E.g. if the need is 5 and the pushstock is 3, the pushstock will be the max of 0 and -2 which is 0.
    4. Make sure the max of the pushstock that gets carried into the next day is 10.
       E.g. if the pushstock before substracting the need is 15, need is 3 then the pushstock is 15-3=12
       the pushstock that gets carried over will be the min of 10 or 12, which is 10.;

 	* creating need variable;
 	need = doy_uplag_srvc_dt-(sum(doy_srvc_dt,dayssply));
 	if last.bene_id then need=365-(sum(doy_srvc_dt,dayssply));
 	if need < 0 then need = 0 ;

 	* pushing extra pills forward;
 	retain pushstock1; * first retaining pushstock1 so that the previous pushstock will get moved to the next one;
 	if first.bene_id then pushstock1=0; * resetting the pushstock1 to 0 at the beginning of the year;
 	pushstock1=sum(pushstock1,pushstock);
 	dayssply2=sum(dayssply,min(need,pushstock1));
 	pushstock1=min(max(sum(pushstock1,-need),0),10);

	if last.bene_id then do;
		* final push from early fills;
		earlyfill_push=min(max(pushstock1,0),10);
		* extra pills from last prescription at end of year is capped at 90;
		lastfill_push=min(max(doy_srvc_dt+dayssply-365,0),90);
	end;

	array opioid_a [*] opioid_a1-opioid_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i < sum(doy_srvc_dt,dayssply2) then opioid_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=&tempwork..pde&year._4 nway noprint;
	class bene_id;
	output out=&tempwork..pde&year._5 (drop=_type_ rename=_freq_=opioid_clms_&year.)
	sum(dayssply)=opioid_filldays_&year. min(srvc_dt)=opioid_minfilldt_&year. max(srvc_dt)=opioid_maxfilldt_&year.
	max(opioid_a1-opioid_a365 earlyfill_push lastfill_push)=;
run;

data &tempwork..pde&year._6;
	set &tempwork..pde&year._5;
	opioid_fillperiod_&year.=max(opioid_maxfilldt_&year.-opioid_minfilldt_&year.+1,0);
	opioid_push_&year.=.;
run;

/********** Bring in SNF **********/
data &tempwork..snf&year.;
	set %do mo=1 %to 9;
		rif&year..snf_claims_0&mo (keep=bene_id clm_from_dt clm_thru_dt)
		%end;
		%do mo=10 %to 12;
		rif&year..snf_claims_&mo (keep=bene_id clm_from_dt clm_thru_dt)
		%end;;
	by bene_id;
run;

* First merging to keep people of interest;
data &tempwork..pde&year._snf;
	merge &tempwork..pde&year._6 (in=a keep=bene_id) &tempwork..snf&year. (in=b);
	by bene_id;

	if a;

	doy_from_dt=intck('day',mdy(1,1,&year),clm_from_dt)+1;
	doy_thru_dt=intck('day',mdy(1,1,&year),clm_thru_dt)+1;

	array snf_a [*] snf_a1-snf_a365;

	do i=1 to 365;
		if doy_from_dt <= i <= doy_thru_dt then snf_a[i]=1;
	end;

	drop clm_from_dt clm_thru_dt doy_from_dt doy_thru_dt;
run;

proc means data=&tempwork..pde&year._snf nway noprint;
	class bene_id;
	output out=&tempwork..pde&year._snf1 (drop=_type_ _freq_) max(snf_a1-snf_a365)=;
run;


* Merging to entire class array data set;
data &tempwork..pde&year._7;
	merge &tempwork..pde&year._6 (in=a) &tempwork..pde&year._snf1 (in=b);
	by bene_id;
	if a;

	** SNF push;
	* snf_push is the extra days added for SNF days concurrent with drug days;

	array opioid_a [*] opioid_a1-opioid_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if opioid_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the opioid_a is 1, do nothing (already added it to the snf_push);
		* if the opioid_a spot is empty, then filling in with snf_push;
		if snf_push>0 and opioid_a[i]=. then do;
			opioid_a[i]=1;
			snf_push=snf_push-1;
			if snf_push>10 then snf_push=10;
		end;

	end;

	drop snf_a: i;
run;

/********* Bring in IP **********/
data &tempwork..ip&year.;
	set %do mo=1 %to 9;
		rif&year..inpatient_claims_0&mo (keep=bene_id clm_from_dt clm_thru_dt)
		%end;
		%do mo=10 %to 12;
		rif&year..inpatient_claims_&mo (keep=bene_id clm_from_dt clm_thru_dt)
		%end;;
	by bene_id;
run;

data &tempwork..pde&year._ip;
	merge &tempwork..pde&year._7 (in=a keep=bene_id) &tempwork..ip&year. (in=b);
	by bene_id;
	if a;

	doy_from_dt=intck('day',mdy(1,1,&year),clm_from_dt)+1;
	doy_thru_dt=intck('day',mdy(1,1,&year),clm_thru_dt)+1;
	
	array ips_a [*] ips_a1-ips_a365;

	do i=1 to 365;
		if doy_from_dt <= i <= doy_thru_dt then ips_a[i]=1;
	end;

	drop clm_from_dt clm_thru_dt doy_from_dt doy_thru_dt;
run;


proc means data=&tempwork..pde&year._ip nway noprint;
	class bene_id;
	output out=&tempwork..pde&year._ip1 (drop=_type_ _freq_)
	max(ips_a1-ips_a365)=;
run;

data &tempwork..pde&year._8;
	merge &tempwork..pde&year._7 (in=a) &tempwork..pde&year._ip1 (in=b);
	by bene_id;
	if a;

	** IP Push;
	* ips_push is the extra days added for ip days concurrent with drug days;

	array opioid_a [*] opioid_a1-opioid_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if opioid_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the opioid_a is 1, do nothing (already added to the ips_push);
		* if the opioid_a spot is not full then adding in the ips_push;
		if ips_push>0 and opioid_a[i]=. then do;
			opioid_a[i]=1;
			ips_push=ips_push-1;
			if ips_push>10 then ips_push=10;
		end;

	end;

	drop ips_a:;

run;

** Final consumption day calculations;
data &tempwork..pde&year._9;
	set &tempwork..pde&year._8;

	* The array is filled using dayssply2, which includes adjustments for early fills.
	Then, the array is adjusted further for IPS and SNF days. So, the sum of the ones in the array is
	the total &year. pumption days.;

	opioid_pdays_&year=max(min(sum(of opioid_a1-opioid_a365),365),0);

	drop opioid_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data &tempwork..pde&year._10;
	set &tempwork..pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  	opioid_push_&year.=max(lastfill_push,inyear_push);
  	if opioid_push_&year.<0 then opioid_push_&year.=0;
  	if opioid_push_&year.>90 then opioid_push_&year.=90;
  	keep bene_id opioid:;
run;

* create perm;
data &outlib..opioid_&year.p;
	set &tempwork..pde&year._10;
run;
%mend;

%do year=&minyear. %to &maxyear.;
	%let prev_year=%eval(&year-1);
	
	%if &year=2006 %then %do;
	%opioidpull(&year,&prev_year,*,);
	%end;
	%else %do;
	%opioidpull(&year,&prev_year,,*);
	%end;

%end;

/************ Merge All 06-16 ***********/
data &tempwork..opioid_&minyear._&maxyear.;
	merge %do year=&minyear %to &maxyear;
		&tempwork..pde&year._10 (in=_&year)
		%end;;
	by bene_id;
	%do year=&minyear %to &maxyear;
	yopioid&year.=_&year;
	%end;

	*timing variables;
	array yopioid [*] yopioid&minyear.-yopioid&maxyear.;
	array yopioiddec [*] %do year=&maxyear. %to &minyear. %by -1; yopioid&year %end;;

	do i=1 to dim(yopioid);
		if yopioid[i]=1 then opioid_lastyoo=i+%eval(&minyear.-1);
		if yopioiddec[i]=1 then opioid_firstyoo=%eval(&maxyear.+1)-i;
	end;

	opioid_yearcount=opioid_lastyoo-opioid_firstyoo+1;

	* utilization variables;
	array util [*] 
	%do year=&minyear. %to &maxyear.;
	opioid_fillperiod_&year. opioid_clms_&year. opioid_filldays_&year. opioid_pdays_&year.
	%end;;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	opioid_clms=sum(of opioid_clms_&minyear.-opioid_clms_&maxyear.);
	opioid_filldays=sum(of opioid_filldays_&minyear.-opioid_filldays_&maxyear.);
	opioid_pdays=sum(of opioid_pdays_&minyear.-opioid_pdays_&maxyear.);

	* timing variables;
	opioid_minfilldt=min(of opioid_minfilldt_&minyear.-opioid_minfilldt_&maxyear.);
	opioid_maxfilldt=max(of opioid_maxfilldt_&minyear.-opioid_maxfilldt_&maxyear.);
	format opioid_minfilldt opioid_maxfilldt mmddyy10.;

	opioid_fillperiod=opioid_maxfilldt - opioid_minfilldt+1;

	opioid_pdayspy=opioid_pdays/opioid_yearcount;
	opioid_filldayspy=opioid_filldays/opioid_yearcount;
	opioid_clmspy=opioid_clms/opioid_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* create perm;
data &outlib..opioid_&minyear._&maxyear.p;
	set &tempwork..opioid_&minyear._&maxyear.;
run;

%mend;
%pillpush;

proc contents data=&outlib..opioid_&minyear._&maxyear.p; run;
proc univariate data=&outlib..opioid_&minyear._&maxyear.p; run;


