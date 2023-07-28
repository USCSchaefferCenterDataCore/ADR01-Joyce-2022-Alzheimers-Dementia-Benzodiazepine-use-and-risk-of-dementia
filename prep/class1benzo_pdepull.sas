/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Pull Benzo Claims and Summarize using Drug Pull Method;
* Input: bene_status_year, pde, fdb_ndc_extract;
* Output: class1benzo user descriptives;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

%let minyear=2006;
%let maxyear=2017;

/***************** Benzo PDE Pull ********************/
%macro pde;
%do year=2017 %to &maxyear;
	%do mo=1 %to 12;
		%if &mo<10 %then %do;
			proc sql;
				create table &tempwork..pde&year._clm_0&mo. as
				select x.bene_id, x.srvc_dt as srvc_dt format=mmddyy10., x.pde_id, x.days_suply_num as dayssply, &year as year, 
				y.*
				from pde&year..pde_demo_&year._0&mo as x inner join &outlib..benzo_ndcs as y
				on x.prod_srvc_id=y.ndc
				order by bene_id, year, srvc_dt;
			quit;
		%end;
		%else %do;
			proc sql;
				create table &tempwork..pde&year._clm_&mo. as
				select x.bene_id, x.srvc_dt as srvc_dt format=mmddyy10., x.pde_id, x.days_suply_num as dayssply, &year as year, 
				y.*
				from pde&year..pde_demo_&year._&mo as x inner join &outlib..benzo_ndcs as y
				on x.prod_srvc_id=y.ndc
				order by bene_id, year, srvc_dt;
			quit;
		%end;
	%end;
%end;

%mend;

%pde;

***** Setting all together;
data &outlib..benzos_0617;
	format year best4. srvc_dt mmddyy10.;
	set &tempwork..pde2017_clm_01-&tempwork..pde2017_clm_12
		&outlib..benzos_0616;
	by bene_id year srvc_dt;
run;        

%macro pillpush;

%do year=&minyear %to &maxyear;
data &tempwork..pde&year.;
	set &outlib..benzos_0617 (where=(class1 and year(srvc_dt)=&year.) keep=bene_id srvc_dt dayssply class1);
	by bene_id;
run;
%end;

%macro class1benzopull(year,prev_year,merge,set);
* set macro variable is for 2006, merge macro variable is for all other years which require a merge to the previous data;

data &tempwork..pde&year._1;
	&set. set &tempwork..pde&year.;
	&merge. merge &tempwork..pde&year. (in=a) &tempwork..pde&prev_year._6 (in=b keep=bene_id class1benzo_push_&prev_year.);
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
	* the following steps create a variable called uplag_srvc_dt which is the equivalent of [_n-1] in class1benzoa;
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
	&merge. if first.bene_id then pushstock=sum(pushstock,class1benzo_push_&prev_year.);

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

	array class1benzo_a [*] class1benzo_a1-class1benzo_a365;
	do i=1 to 365;
		if doy_srvc_dt <= i < sum(doy_srvc_dt,dayssply2) then class1benzo_a[i]=1;
	end;
	
	drop pushstock need extrapill_push pushstock1;
run;

proc means data=&tempwork..pde&year._4 nway noprint;
	class bene_id;
	output out=&tempwork..pde&year._5 (drop=_type_ rename=_freq_=class1benzo_clms_&year.)
	sum(dayssply)=class1benzo_filldays_&year. min(srvc_dt)=class1benzo_minfilldt_&year. max(srvc_dt)=class1benzo_maxfilldt_&year.
	max(class1benzo_a1-class1benzo_a365 earlyfill_push lastfill_push class1)=;
run;

data &tempwork..pde&year._6;
	set &tempwork..pde&year._5;
	class1benzo_fillperiod_&year.=max(class1benzo_maxfilldt_&year.-class1benzo_minfilldt_&year.+1,0);
	class1benzo_push_&year.=.;
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

	array class1benzo_a [*] class1benzo_a1-class1benzo_a365;
	array snf_a [*] snf_a1-snf_a365;

	snf_push=0;

	do i=1 to 365;
		if class1benzo_a[i]=1 and snf_a[i]=1 then snf_push=snf_push+1;

		* if the class1benzo_a is 1, do nothing (already added it to the snf_push);
		* if the class1benzo_a spot is empty, then filling in with snf_push;
		if snf_push>0 and class1benzo_a[i]=. then do;
			class1benzo_a[i]=1;
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

	array class1benzo_a [*] class1benzo_a1-class1benzo_a365;
	array ips_a [*] ips_a1-ips_a365;

	ips_push=0;

	do i=1 to 365;

		if class1benzo_a[i]=1 and ips_a[i]=1  then ips_push=ips_push+1;

		* if the class1benzo_a is 1, do nothing (already added to the ips_push);
		* if the class1benzo_a spot is not full then adding in the ips_push;
		if ips_push>0 and class1benzo_a[i]=. then do;
			class1benzo_a[i]=1;
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

	class1benzo_pdays_&year=max(min(sum(of class1benzo_a1-class1benzo_a365),365),0);

	drop class1benzo_a: i;

run;

/************ Calculate the number of extra push days that could go into next year ************/
* inyear_push = extra push days from early fills throughout the year, IPS days and SNF days (each of which was capped at 10, but I will still cap whole thing at 30).;
* lastfill_push is the amount from the last fill that goes into next year (capped at 90).;

data &tempwork..pde&year._10;
	set &tempwork..pde&year._9;
	inyear_push=min(sum(earlyfill_push,snf_push,ips_push),30);
  	class1benzo_push_&year.=max(lastfill_push,inyear_push);
  	if class1benzo_push_&year.<0 then class1benzo_push_&year.=0;
  	if class1benzo_push_&year.>90 then class1benzo_push_&year.=90;
  	keep bene_id class1benzo:;
run;

* create perm;
data &outlib..class1benzo_&year.p;
	set &tempwork..pde&year._10;
run;
%mend;

%do year=&minyear. %to &maxyear.;
	%let prev_year=%eval(&year-1);
	
	%if &year=2006 %then %do;
	%class1benzopull(&year,&prev_year,*,);
	%end;
	%else %do;
	%class1benzopull(&year,&prev_year,,*);
	%end;

%end;

/************ Merge All 06-16 ***********/
data &tempwork..class1benzo_&minyear._&maxyear.;
	merge %do year=&minyear %to &maxyear;
		&tempwork..pde&year._10 (in=_&year)
		%end;;
	by bene_id;
	%do year=&minyear %to &maxyear;
	yclass1benzo&year.=_&year;
	%end;

	*timing variables;
	array yclass1benzo [*] yclass1benzo&minyear.-yclass1benzo&maxyear.;
	array yclass1benzodec [*] %do year=&maxyear. %to &minyear. %by -1; yclass1benzo&year %end;;

	do i=1 to dim(yclass1benzo);
		if yclass1benzo[i]=1 then class1benzo_lastyoo=i+%eval(&minyear.-1);
		if yclass1benzodec[i]=1 then class1benzo_firstyoo=&maxyear.-i;
	end;

	class1benzo_yearcount=class1benzo_lastyoo-class1benzo_firstyoo+1;

	* utilization variables;
	array util [*] 
	%do year=&minyear. %to &maxyear.;
	class1benzo_fillperiod_&year. class1benzo_clms_&year. class1benzo_filldays_&year. class1benzo_pdays_&year.
	%end;;

	do i=1 to dim(util);
		if util[i]=. then util[i]=0;
	end;

	* total utilization;
	class1benzo_clms=sum(of class1benzo_clms_&minyear.-class1benzo_clms_&maxyear.);
	class1benzo_filldays=sum(of class1benzo_filldays_&minyear.-class1benzo_filldays_&maxyear.);
	class1benzo_pdays=sum(of class1benzo_pdays_&minyear.-class1benzo_pdays_&maxyear.);

	* timing variables;
	class1benzo_minfilldt=min(of class1benzo_minfilldt_&minyear.-class1benzo_minfilldt_&maxyear.);
	class1benzo_maxfilldt=max(of class1benzo_maxfilldt_&minyear.-class1benzo_maxfilldt_&maxyear.);
	format class1benzo_minfilldt class1benzo_maxfilldt mmddyy10.;

	class1benzo_fillperiod=class1benzo_maxfilldt - class1benzo_minfilldt+1;

	class1benzo_pdayspy=class1benzo_pdays/class1benzo_yearcount;
	class1benzo_filldayspy=class1benzo_filldays/class1benzo_yearcount;
	class1benzo_clmspy=class1benzo_clms/class1benzo_yearcount;

	if first.bene_id; 
	
	drop i;
run;

* create perm;
data &outlib..class1benzo_&minyear._&maxyear.p;
	set &tempwork..class1benzo_&minyear._&maxyear.;
run;

%mend;
%pillpush;

proc contents data=&outlib..class1benzo_&minyear._&maxyear.p; run;
proc univariate data=&outlib..class1benzo_&minyear._&maxyear.p; run;

