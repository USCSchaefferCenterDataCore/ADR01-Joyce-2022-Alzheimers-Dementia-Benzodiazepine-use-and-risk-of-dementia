/*********************************************************************************************/
title1 'Antipsychotics';

* Author: PF;
* Purpose: Read in excel sheet with drug list and create FDB data set;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=error dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

data psy.raw_atc_drug_class_list;
	infile "&rootpath./Projects/Programs/antipsych/atc_drug_classes.csv" dlm='2c'x dsd 
		lrecl=32767 missover firstobs=2;
	informat
		class $50.
		subclass $50.
		drug $50.;
	format
		class $50.
		subclass $50.
		drug $50.;
	input
		class $
		subclass $
		drug $;
	if class="" then delete;
	if drug="VALPROATE" then drug='VALPROIC ACID';
	if drug='ARIPIRAZOLE' then drug='ARIPIPRAZOLE';
	if drug='ZIRPASIDONE' then drug='ZIPRASIDONE';
	if drug='FLUEPHENAZINE' then drug='FLUPHENAZINE';
run;

proc sort data=psy.raw_atc_drug_class_list out=&tempwork..raw_atc_s_drug; by drug; run;

data &tempwork..raw_atc_dupcheck;
	set &tempwork..raw_atc_s_drug;
	by drug;
	if not(first.drug and last.drug);
run;

data &tempwork..druglist1;
	set psy.raw_atc_drug_class_list nobs=obs;
	do i=1 to obs;
		if _n_=i then do;
			call symput('drug'||compress(i),scan(drug,1));
			call symput('class'||compress(i),scan(class,1));
			call symput('subclass'||compress(i),scan(subclass,1));
		end;
	end;
	call symput('totaldrugs',obs);
run;

%put &totaldrugs;
%put &class120;
%put &subclass120;

%macro fdb_flag;
data &tempwork..druglist_fdb;
	set base.fdb_ndc_extract_historical;
	format class subclass $50.;
	%do i=1 %to &totaldrugs;
		&&drug&i=0;
		&&class&i=0;
		&&subclass&i=0;
	%end;
	%do i=1 %to &totaldrugs;
		if find(gnn60,"&&drug&i")>0 then do;
			&&drug&i=1;
			&&class&i=1;
			&&subclass&i=1;
			class="&&class&i";
			subclass="&&subclass&i";
		end;
	%end;
	if dihydrocodeine=1 then do;
		codeine=0;
	end;
	if find(gnn60,'HCOD') then do;
		opioids=1;
		hydrocodone=1;
		class='OPIOIDS';
		subclass='OPIOIDS';
	end;
	any=max(of &drug1--&drug120);
	any_sum=sum(%do i=1 %to 119; &&drug&i, %end; &drug120);
	if find(gnn,'APOMORPHINE') then any=0;
	if find(gnn,'METHYLNALTREXONE') then any=0;
	if find(gnn60,'TROPIUM') then any=0;
	if gnn60='LITHIUM ASPARTATE' then any=0;
run;

proc freq data=&tempwork..druglist_fdb noprint;
	where any=1;
	table gnn*class*subclass*atc*atc_desc / out=&tempwork..druglist_fdb_atc;
run;
%mend;

%fdb_flag;

proc sort data=&tempwork..druglist_fdb_atc; by class subclass atc; run;

proc means data=&tempwork..druglist_fdb noprint nway;
	where any=1;
	class gnn atc atc_desc;
	output out=&tempwork..druglist_fdb_max max(&drug1--&drug120)=;
run;

proc transpose data=&tempwork..druglist_fdb_max out=&tempwork..druglist_fdb_max_t; run;

* Check the opposites - in the ATC categories listed but not on our list;
data &tempwork..InListCheck;
	set &tempwork..druglist_fdb (where=(any=1));
	atc_cat=substr(atc,1,5);
	if atc_cat ne "" or any=1;
	keep atc_cat ndc class subclass;
run;

proc sort data=&tempwork..InListCheck nodupkey; by atc_cat ndc; run;

data &tempwork..druglist_fdb_InListCheck;
	set &tempwork..druglist_fdb;
	atc_cat=substr(atc,1,5);
run;

proc sort data=&tempwork..druglist_fdb_InListCheck; by atc_cat ndc; run;

data &tempwork..druglist_fdb_InListCheck1;
	format atc_cat class subclass gnn60;
	merge &tempwork..druglist_fdb_InListCheck (in=a drop=class subclass) &tempwork..InListCheck (in=b);
	by atc_cat ndc;
	inatc=b;
run;

proc means data=&tempwork..druglist_fdb_InListCheck1 noprint nway;
	class atc_cat;
	var inatc;
	output out=&tempwork..druglist_fdb_InListCheck2 mean()= sum()= / autoname;
run;

/* Adding the drugs from ATC categories on our list, but were missing drugs 
	- Check how many drugs in the ATC category were included
	- If a high proportion were excluded, but not all - check the ones that were missing
	- If look valid, adding back in */

data &tempwork..druglist_fdb_added;
	set &tempwork..druglist_fdb_InListCheck1;
	anticonvulsant_mood=0;
	if anticonvulsant=1 then do;
		anticonvulsant_mood=1;
		subclass='ANTICONVULSANT MOOD';
	end;
	anticonvulsant_add=0;
	dezocine=0;
	primidone=0;
	mephobarbital=0;
	RUFINAMIDE=0;
	ESLICARBAZEPINE=0;
	VIGABATRIN=0;
	PHENACEMIDE=0;
	RASAGILINE=0;
	ACEPROMAZINE=0;
	TRIFLUPROMAZINE=0;
	PROMAZINE=0;
	MESORIDAZINE=0;
	DROPERIDOL=0;
	MOLINDONE=0;
	HALAZEPAM=0;
	AMOBARBITAL=0;
	PENTOBARBITAL=0;
	BARBITAL=0;
	added=0;
	if gnn60='DEZOCINE' then do;
		dezocine=1;
		opioids=1;
		class="OPIOIDS";
		subclass="OPIOIDS";
		added=1;
	end;
	if gnn60='PRIMIDONE' then do;
		primidone=0;
		anxiolytics=1;
		BARBITUATES=1;
		class="ANXIOLYTICS";
		subclass="BARBITUATES";
		added=1;
	end;
	if gnn60='MEPHOBARBITAL' then do;
		mephobarbital=1;
		anxiolytics=1;
		BARBITUATES=1;
		class="ANXIOLYTICS";
		subclass="BARBITUATES";
		added=1;
	end;
	if find(gnn60,'ESLICARBAZEPINE ACETATE') then do;
		ESLICARBAZEPINE=1;
		anticonvulsant=1;
		class='ANTICONVULSANT';
		SUBCLASS='ANTICONVULSANT';
		anticonvulsant_add=1;
		added=1;
	end;
	IF GNN60='VIGABATRIN' THEN DO;
		VIGABATRIN=1;
		anticonvulsant=1;
		class='ANTICONVULSANT';
		SUBCLASS='ANTICONVULSANT';
		anticonvulsant_add=1;
		added=1;
	end;
	IF GNN60='PHENACEMIDE' THEN DO;
		PHENACEMIDE=1;
		anticonvulsant=1;
		class='ANTICONVULSANT';
		SUBCLASS='ANTICONVULSANT';
		anticonvulsant_add=1;
		added=1;
	END;
	IF GNN60='EZOGABINE' THEN DO;
		EZOGABINE=1;
		anticonvulsant=1;
		class='ANTICONVULSANT';
		SUBCLASS='ANTICONVULSANT';
		anticonvulsant_add=1;
		added=1;
	END;
	IF GNN60='BRIVARACETAM' THEN DO;
		BRIVARACETAM=1;
		anticonvulsant=1;
		class='ANTICONVULSANT';
		SUBCLASS='ANTICONVULSANT';
		anticonvulsant_add=1;
		added=1;
	END;
	IF GNN60='PERAMPANEL' THEN DO;
		PERAMPANEL=1;
		anticonvulsant=1;
		class='ANTICONVULSANT';
		SUBCLASS='ANTICONVULSANT';
		anticonvulsant_add=1;
		added=1;
	END;
	if gnn60='RASAGILINE MESYLATE' then do;
		RASAGILINE=1;
		antidepressants=1;
		maoi=1;
		class='ANTIDEPRESSANTS';
		SUBCLASS='MAOI';
		ADDED=1;
	END;
	if gnn60='ACEPROMAZINE MALEATE' then do;
		ACEPROMAZINE=1;
		antipsychotics=1;
		TYPICAL=1;
		class='ANTIPSYCHOTIC';
		subclass='TYPICAL';
		ADDED=1;
	END;
	IF GNN60='TRIFLUPROMAZINE HCL' THEN DO;
		TRIFLUPROMAZINE=1;
		antipsychotics=1;
		TYPICAL=1;
		class='ANTIPSYCHOTIC';
		subclass='TYPICAL';
		ADDED=1;
	END;
	IF GNN60='PROMAZINE HCL' then do;
		PROMAZINE=1;
		antipsychotics=1;
		TYPICAL=1;
		class='ANTIPSYCHOTIC';
		subclass='TYPICAL';
		ADDED=1;
	END;
	if gnn60='ACEPROMAZINE MALEATE' then do;
		ACEPROMAZINE=1;
		antipsychotics=1;
		TYPICAL=1;
		class='ANTIPSYCHOTICS';
		subclass='TYPICAL';
		ADDED=1;
	END;
	IF GNN60='MESORIDAZINE BESYLATE' THEN DO;
		MESORIDAZINE=1;
		antipsychotics=1;
		TYPICAL=1;
		class='ANTIPSYCHOTICS';
		subclass='TYPICAL';
		ADDED=1;
	END;
	IF GNN60='DROPERIDOL' THEN DO;
		DROPERIDOL=1;
		antipsychotics=1;
		TYPICAL=1;
		class='ANTIPSYCHOTICS';
		subclass='TYPICAL';
		ADDED=1;
	END;
	IF GNN60='MOLINDONE HCL' THEN DO;
		MOLINDONE=1;
		antipsychotics=1;
		TYPICAL=1;
		class='ANTIPSYCHOTICS';
		subclass='TYPICAL';
		ADDED=1;
	END;
	IF GNN60='HALAZEPAM' then do;
		HALAZEPAM=1;
		anxiolytics=1;
		benzodiazepines=1;
		class='ANXIOLYTICS';
		subclass='BENZODIAZEPINES';
		ADDED=1;
	END;
	IF GNN60='AMOBARBITAL SODIUM' THEN DO;
		AMOBARBITAL=1;		
		anxiolytics=1;
		BARBITUATES=1;
		class="ANXIOLYTICS";
		subclass="BARBITUATES";
		added=1;
	END;
	IF GNN60 in('BARBITAL','BARBITAL SODIUM') THEN DO;
		BARBITAL=1;
		anxiolytics=1;
		BARBITUATES=1;
		class="ANXIOLYTICS";
		subclass="BARBITUATES";
		added=1;
	END;
	IF FIND(GNN60,'PENTOBARBITAL') THEN DO;
		PENTOBARBITAL=1;
		anxiolytics=1;
		BARBITUATES=1;
		class="ANXIOLYTICS";
		subclass="BARBITUATES";
		added=1;
	END;
	if loxapine=1 then do;
		antidepressants=0;
		tricyclics=0;
		class='ANTIPSYCHOTICS';
		SUBCLASS='TYPICAL';
	end;
	if maprotiline=1 then do;
		tricyclics=0;
	end;
	ANY=MAX(ANY,ADDED);
	if any;
	keep ndc atc gnn60 class subclass aripiprazole--added;
RUN;

* Creating a version unique by gnn60 for export;
proc sort data=&tempwork..druglist_fdb_added out=&tempwork..druglist_fdb_added_gnn60_s (drop=ndc) nodupkey;
	by gnn60 class subclass atc aripiprazole--added;
run;

data &tempwork..druglist_fdb_added_gnn60_sck;
	set &tempwork..druglist_fdb_added_gnn60_s;
	by gnn60;
	if not(first.gnn60 and last.gnn60);
run;

proc sort data=&tempwork..druglist_fdb_added_gnn60_s out=&tempwork..druglist_fdb_class_s;
	by class subclass gnn60 atc aripiprazole--added;
run;

proc export data=&tempwork..druglist_fdb_class_s
	outfile="&rootpath./Projects/Programs/antipsych/exports/multum_drug_list.xlsx"
	dbms=xlsx
	replace;
	sheet="drugs";
run;

* Create perm;
proc sort data=&tempwork..druglist_fdb_added out=psy.antipsych_ndclist_multum; by ndc; run;









	


		



