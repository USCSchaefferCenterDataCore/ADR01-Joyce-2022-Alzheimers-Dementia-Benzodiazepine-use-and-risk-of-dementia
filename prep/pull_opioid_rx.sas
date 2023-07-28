/*********************************************************************************************/
title1 'Benzodiazepines';

* Author: PF;
* Purpose: Pull Anti-depressant Claims and Summarize using Drug Pull Method;
* Input: bene_status_year, pde, fdb_ndc_extract;
* Output: opioid user descriptives;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/
options obs=max;
%let minyear=2006;
%let maxyear=2017;

/***************** PDE Pull ********************/
%macro pde;
%do year=&minyear %to &maxyear;
	%do mo=1 %to 12;
		%if &mo<10 %then %do;
			proc sql;
				create table &tempwork..opioid_&year._&mo as
				select x.bene_id, x.srvc_dt as srvc_dt format=mmddyy10., x.pde_id, x.days_suply_num as dayssply, &year as year, 
				y.prdsrvid, y.bn, y.gnn, y.ingr
				from pde&year..pde_demo_&year._0&mo as x inner join benzo.opioid_ndc_year_ingr (where=(mat ne 1)) as y
				on x.prod_srvc_id=y.prdsrvid
				order by bene_id, year, srvc_dt;
			quit;
		%end;
		%else %do;
			proc sql;
				create table &tempwork..opioid_&year._&mo as
				select x.bene_id, x.srvc_dt as srvc_dt format=mmddyy10., x.pde_id, x.days_suply_num as dayssply, &year as year, 
				y.prdsrvid, y.bn, y.gnn, y.ingr
				from pde&year..pde_demo_&year._&mo as x inner join benzo.opioid_ndc_year_ingr (where=(mat ne 1)) as y
				on x.prod_srvc_id=y.prdsrvid
				order by bene_id, year, srvc_dt;
			quit;
		%end;
	%end;
%end;

%mend;

%pde;

***** Setting all together;
%macro setall;
data &outlib..opioid_pde0617;
	format year best4. srvc_dt mmddyy10.;
	set %do yr=&minyear. %to &maxyear.;
		&tempwork..opioid_&yr._1-&tempwork..opioid_&yr._12
	%end;;
	by bene_id year srvc_dt;
run;    
%mend;

%setall; 

