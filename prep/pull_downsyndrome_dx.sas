/*********************************************************************************************/
title1 'Exploring AD Incidence Definition';

* Author: PF;
* Purpose: Pulling all claim dates with dementia diagnosis, keeping diagnosis info and 
					 diagnosing physician info;
* Input: Pull dementia claims; 
* Output: dementia_dx_[ctyp]_2001_&maxyear., dementia_carmrg_2001_&maxyear., dementia_dxdt_2001_&maxyear.;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

**%include "header.sas";

***** Years/Macro Variables;
%let minyear=1999;
%let maxyear=2018;
%let maxdx=26;

***** down syndrome Codes;
%let icd9="7580"; 
%let icd10="Q900" "Q901" "Q902" "Q909";

%macro getdx(ctyp,byear,eyear,dxv=,dropv=,keepv=,byvar=);
	%do year=&byear %to &eyear;
		data &tempwork..downsyndromedx_&ctyp._&year;
		
			set 
				
			%if &year<2017 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rif&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			%else %if &year>=2017 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..&ctyp._claims_0&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
					%else %if &mo>=10 %then %do;
						rifq&year..&ctyp._claims_&mo (keep=bene_id clm_thru_dt icd_dgns_cd: &dxv &keepv drop=&dropv)
					%end;
				%end;
			%end;
			;
			by bene_id &byvar;

		length downsyndromedx1-downsyndromedx&maxdx $ 5;
		
		* Count how many dementia-related dx are found, separately by ccw list and other list;
		*	Keep thru_dt as dx_date;
		* Keep first 5 dx codes found;
		
		array diag [*] icd_dgns_cd: &dxv;
		array downsyndromedx [*] downsyndromedx1-downsyndromedx&maxdx;
		
		year=year(clm_thru_dt);
		
		ndx=0;
		dxsub=0;
		
		do i=1 to dim(diag);
			if diag[i] in(&icd9,&icd10) then ndx=ndx+1; * Counting total number of mnd diagnoses;
			if diag[i] in (&icd9,&icd10) then do; 
				found=0;
				do j=1 to dxsub;
					if diag[i]=downsyndromedx[j] then found=j;
				end;
				if found=0 then do;
					dxsub=dxsub+1;
					if dxsub<=&maxdx then downsyndromedx[dxsub]=diag[i];
				end;
			end;
		end;
		
		if ndx=0 then delete;
		else downsyndromedx_dt=clm_thru_dt;
       
    length clm_typ $1;
    
    if "%substr(&ctyp,1,1)" = "i" then clm_typ="1"; /* inpatient */
    else if "%substr(&ctyp,1,1)" = "s" then clm_typ="2"; /* SNF */
    else if "%substr(&ctyp,1,1)" = "o" then clm_typ="3"; /* outpatient */
    else if "%substr(&ctyp,1,1)" = "h" then clm_typ="4"; /* home health */
    else if "%substr(&ctyp,1,1)" = "b" then clm_typ="5"; /* carrier */
    else clm_typ="X";  
    
		drop icd_dgns_cd: &dxv clm_thru_dt i j;
		rename dxsub=dx_max;
      
run;	
%if %upcase(&ctyp) ne BCARRIER %then %do;
proc sort data=&tempwork..downsyndromedx_&ctyp._&year; by bene_id year downsyndromedx_dt clm_typ; run;
%end;
%end;
%mend getdx;

%macro appenddx(ctyp);
	
data &tempwork..downsyn_&ctyp._&minyear._&maxyear;
		set 
	%do year=&minyear %to &maxyear;
		&tempwork..downsyndromedx_&ctyp._&year
	%end; ;
	by bene_id year downsyndromedx_dt clm_typ;
run;

%mend;

%getdx(bcarrier,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,keepv=clm_id,byvar=clm_id);

%getdx(hha,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);
%appenddx(hha);
		
%getdx(inpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);	
%appenddx(inpatient);
		
%getdx(outpatient,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);	
%appenddx(outpatient);

%getdx(snf,&minyear,&maxyear,dxv=prncpal_dgns_cd,dropv=,
			 keepv=clm_id);
%appenddx(snf);

* Car line diagnoses;
%macro carline(byear,eyear);
%do year=&byear %to &eyear;
data &tempwork..downsyndromedx_carline_&year;
		set 
			%if &year<2017 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rif&year..bcarrier_line_0&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id)
					%end;
					%if &mo>=12 %then %do;
						rif&year..bcarrier_line_&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id) 
					%end;
				%end;
			%end;
			%else %if &year>=2017 %then %do;
				%do mo=1 %to 12;
					%if &mo<10 %then %do;
						rifq&year..bcarrier_line_0&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id)
					%end;
					%if &mo>=12 %then %do;
						rifq&year..bcarrier_line_&mo (keep=bene_id clm_thru_dt line_icd_dgns_cd clm_id) 
					%end;
				%end;
			%end;				
				;
		by bene_id clm_id;

		length linedx 3;
		length clm_typ $1 line_dxtype $1;
		
		year=year(clm_thru_dt);
		
		linedx=line_icd_dgns_cd in(&icd9,&icd10);

		if linedx=0 then delete;
		downsyndromedx_dt=clm_thru_dt;
		clm_typ="6";
      
		drop clm_thru_dt;
run;
data &tempwork..downsyndromedx_carmrg_&year;
		merge &tempwork..downsyndromedx_bcarrier_&year (in=_inclm drop=year)
			  &tempwork..downsyndromedx_carline_&year  (in=_inline rename=(downsyndromedx_dt=linedx_dt));
		by bene_id clm_id;

		infrom=10*_inclm+_inline;
		
		length n_found n_added matchdt _maxdx in_line 3;
		length _downsyndromedx1-_downsyndromedx&maxdx $ 5;
		retain n_found n_added matchdt _maxdx in_line _downsyndromedx1-_downsyndromedx&maxdx _downsyndromedx_dt;
		
		array downsyndromedx [*] downsyndromedx1-downsyndromedx&maxdx;
		array _downsyndromedx [*] _downsyndromedx1-_downsyndromedx&maxdx;
		
		if first.clm_id then do;
				n_found=0;
				n_added=0;
				matchdt=0;
				if _inclm=1 then _maxdx=dx_max;
				else _maxdx=0;
				in_line=0;
				do i=1 to dim(downsyndromedx);
					_downsyndromedx[i]=downsyndromedx[i];
				end;
				if _inclm then _downsyndromedx_dt=downsyndromedx_dt;
				else _downsyndromedx_dt=linedx_dt;
		end;
		
		if clm_typ="" then clm_typ="5"; * treat linedx source as car;
		
		if _inline=1 then in_line=in_line+1; * count how many lines merge to a claim;
			
		if _inline then do; * if in line file then keeping track of new diagnoses;
			line_found=0;
			do i=1 to _maxdx;
				if line_icd_dgns_cd=_downsyndromedx[i] then line_found=1;
			end;
			if line_found=1 then do; * keep track of codes found on base file;
				n_found=n_found+1;
				matchdt=matchdt+(linedx_dt=downsyndromedx_dt);
			end;
			else do; * add unfound code;
				_maxdx=_maxdx+1;
				if 0<_maxdx<=&maxdx then _downsyndromedx[_maxdx]=line_icd_dgns_cd;
				n_added=n_added+1;
				if infrom=11 then matchdt=matchdt+(linedx_dt=downsyndromedx_dt);
				else if infrom=1 then _downsyndromedx_dt=linedx_dt;
			end;	
		
    end;

	if last.clm_id then do;
			dx_max=_maxdx;
			do i=1 to dim(downsyndromedx);
				downsyndromedx[i]=_downsyndromedx[i];
			end;
			downsyndromedx_dt=_downsyndromedx_dt;
			year=year(downsyndromedx_dt);
			output;
	end;
	
	drop line_icd_dgns_cd line_dxtype _maxdx i _downsyndromedx:;
	format linedx_dt downsyndromedx_dt mmddyy10.;
	
run;
proc sort data=&tempwork..downsyndromedx_carmrg_&year; by bene_id year downsyndromedx_dt clm_typ; run;
%end;
%mend;

%carline(&minyear,&maxyear);

%appenddx(carmrg);

%macro combine_dts(typ,dropv=);
	
		title2 downsyndromedx_&typ._&minyear._&maxyear to dementia_dxdt_&typ._&minyear._&maxyear;

		data &tempwork..downsyndt_&typ._&minyear._&maxyear.;
				format bene_id year downsyndromedx_dt;
				set &tempwork..downsyn_&typ._&minyear._&maxyear (drop=&dropv where=(not missing(bene_id)));
				by bene_id year downsyndromedx_dt;
				
				length _downsyndromedx1-_downsyndromedx&maxdx $ 5;
				length n_claim_typ  _dxmax _dxmax1 3;
				retain n_claim_typ _dxmax _dxmax1 _downsyndromedx1-_downsyndromedx&maxdx;
				
				array downsyndromedx [*] $ downsyndromedx1-downsyndromedx&maxdx;
				array _downsyndromedx [*] $ _downsyndromedx1-_downsyndromedx&maxdx;
				
				* First claim on this date. Save dementia dx-s into master list;
				if first.downsyndromedx_dt=1 then do;
						do i=1 to dim(downsyndromedx);
							_downsyndromedx[i]=downsyndromedx[i];
						end;
						_dxmax=dx_max;
						_dxmax1=dx_max;
						n_claim_typ=1;
				end;
				
				* subsequent claim on same date. Add any dementia dx not found in first claim;
				else do;
						n_claim_typ=n_claim_typ+1;
						do i=1 to dx_max;
							dxfound=0;
							do j=1 to _dxmax;
								if downsyndromedx[i]=_downsyndromedx[j] then dxfound=1;
							end;
							if dxfound=0 then do; * new dx, update list;
								_dxmax=_dxmax+1;
								if _dxmax<&maxdx then _downsyndromedx[_dxmax]=downsyndromedx[i];
								
            end;  /* dxfound = 0 */
         	end; /* do i=1 to _dxmax */
      	end;  /* multiple claims on same date */
      	
      	* output one obs per service_type and date;
      	if last.downsyndromedx_dt=1 then do;
    
      			do i=1 to dim(downsyndromedx);
      				downsyndromedx[i]=_downsyndromedx[i];
      			end;
      			n_add_typ=_dxmax-_dxmax1;
      			dx_max=_dxmax;
      			output;
      	end;
      	
            ;
        drop _downsyndromedx: _dxmax i j dxfound _dxmax1;
    run;
%mend combine_dts;

%combine_dts(inpatient);
%combine_dts(outpatient);
%combine_dts(snf);
%combine_dts(hha);
%combine_dts(carmrg);

data &outlib..downsyn_dxdt_&minyear._&maxyear.;
		
		merge &tempwork..downsyndt_inpatient_&minyear._&maxyear 
			  &tempwork..downsyndt_outpatient_&minyear._&maxyear
			  &tempwork..downsyndt_snf_&minyear._&maxyear 
			  &tempwork..downsyndt_hha_&minyear._&maxyear 
			  &tempwork..downsyndt_carmrg_&minyear._&maxyear;
		by bene_id year downsyndromedx_dt clm_typ;
				
		mult_clmtyp=(first.clm_typ=0 or last.clm_typ=0);
		
		* Output summarized events, across claim types on same date?;
		length claim_types $ 5  _downsyndromedx1-_downsyndromedx&maxdx $ 5;
		length n_claims n_add_dxdate _dxmax _dxmax1 dxfound 3;
		retain claim_types n_claims _dxmax _dxmax1 _downsyndromedx1-_downsyndromedx&maxdx;
		
		array downsyndromedx [*] $ downsyndromedx1-downsyndromedx&maxdx;
		array _downsyndromedx [*] $ _downsyndromedx1-_downsyndromedx&maxdx;
		
		if first.downsyndromedx_dt=1 then do;
			do i=1 to dim(downsyndromedx);
				_downsyndromedx[i]=downsyndromedx[i];
			end;
			_dxmax=dx_max;
			_dxmax1=dx_max;
			claim_types=clm_typ;
			n_claims=n_claim_typ;
		end;
		else do; * if multiple claims on same date, merge dx lists;
			n_claims=n_claims+n_claim_typ;
			if first.clm_typ=1 then claim_types=trim(left(claim_types))||clm_typ;
			do i=1 to dx_max;
					dxfound=0;
					do j=1 to _dxmax;
						if downsyndromedx[i]=_downsyndromedx[j] then dxfound=1;
					end;
					if dxfound=0 then do; * new dx, update list;
						_dxmax=_dxmax+1;
						if _dxmax<&maxdx then _downsyndromedx[_dxmax]=downsyndromedx[i];
						
					end;
			end;
		end;
			
		if last.downsyndromedx_dt=1 then do;
				* restore original variables with updated ones;
				do i=1 to dim(downsyndromedx);
						downsyndromedx[i]=_downsyndromedx[i];
				end;
				dx_max=_dxmax;
				n_add_dxdate=_dxmax-_dxmax1;

				output;
		end;
		
   	drop _downsyndromedx: _dxmax _dxmax1 i j dxfound clm_typ n_claim_typ n_add_typ;

run;

		
		
		
		
			
