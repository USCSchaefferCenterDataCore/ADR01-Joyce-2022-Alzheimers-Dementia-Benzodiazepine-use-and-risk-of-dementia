/*********************************************************************************************/
title1 'Proposal';

* Author: PF;
* Purpose: Explore FDB Antipsychotic;
* Input: fdb_ndc_extract_current;
* Output:	;

options compress=yes nocenter ls=150 ps=200 errors=5 mprint merror
	mergenoby=warn varlenchk=warn dkricond=error dkrocond=error msglevel=i;
/*********************************************************************************************/

proc freq data=base.fdb_ndc_extract noprint;
	where find(hic3_desc,'ANTIPSYCH');
	table gtc_desc*hic3_desc*ahfs_desc*tc_desc / out=&tempwork..hic3_antipsych;
run;

proc freq data=base.fdb_ndc_extract noprint;
	where find(ahfs_desc,'ANTIPSYCH');
	table gtc_desc*hic3_desc*ahfs_desc*tc_desc / out=&tempwork..ahfs_antipsych;
run;

proc freq data=base.fdb_ndc_extract noprint;
	where find(gtc_desc,'PSYCHOTHERAPEUTIC');
	table gtc_desc*hic3_desc*ahfs_desc*tc_desc / out=&tempwork..gtc_antipsych;
run;

proc freq data=base.fdb_ndc_extract noprint;
	where find(gtc_desc,'PSYCHOTHERAPEUTIC');
	table gnn*bn / out=&tempwork..gnn_antipsych;
run;

proc freq data=base.fdb_ndc_extract noprint;
	where find(AHFS_DESC,'ANTIMANIC');
	table gtc_desc*hic3_desc*ahfs_desc*tc_desc / out=&tempwork..antimanic_antipsych;
run;

proc freq data=base.fdb_ndc_extract noprint;
	where find(gnn,'LITHIUM');
	table gtc_desc*hic3_desc*ahfs_desc*tc_desc / out=&tempwork..lithium_antipsych;
run;
* Hic3 - bipoloar, gtc_desc - psychotherapeutic, ahfs- antimanic;

proc freq data=base.fdb_ndc_extract noprint;
	where find(gnn,'PIMAVANSERIN');
	table gtc_desc*hic3_desc*ahfs_desc*tc_desc / out=&tempwork..pim_antipsych;
run;
* Hic3 - selective serotonin, ahfs_desc - atypical antipsychotics, gtc - psychotherapeutic;

/******************************** Build FDB Antipsych List ************************************/
/************** First Databank ******************/
***** List of all conditions;
* Creating macro variables out of conditions;
	%macro createmvar(list,var);
	data _null_;
		%global max;
		str="&list";
		call symput("max",countw(str));
	run;
		
	data _null_;
		str="&list";
		do i=1 to &max;
			v=scan(str,i,"");
			call symput(compress("var"||"&var"||i),strip(v));
		end;
	%mend;

%let classes=maoi snri ssri sari tricy alpha2 ndri depr_comb typ_antipsych atyp_antipsych atyp_antipsych_comb adhd narco antimanic misc;
	
%createmvar(&classes);run;

%let g_maoi=%nrstr("MAOIS - NON-SELECTIVE & IRREVERSIBLE","MONOAMINE OXIDASE(MAO) INHIBITORS");
%let g_snri=%nrstr("SEROTONIN-NOREPINEPHRINE REUPTAKE-INHIB (SNRIS)");
%let g_ssri=%nrstr("SELECTIVE SEROTONIN REUPTAKE INHIBITOR (SSRIS)","SELECTIVE SEROTONIN INHIB. (SSRIS)/DIET SUPP CMB.","SSRI & 5HT1A PARTIAL AGONIST ANTIDEPRESSANT","SSRI & ANTIPSYCH,ATYP,DOPAMINE&SEROTONIN ANTAG CMB","SSRI & SEROTONIN RECEPTOR MODULATOR ANTIDEPRESSANT");
%let g_sari=%nrstr("SEROTONIN-2 ANTAGONIST/REUPTAKE INHIBITORS (SARIS)","SSRI & SEROTONIN RECEPTOR MODULATOR ANTIDEPRESSANT","SEROTONIN-2 ANTAG,REUPTAKE INH/DIETARY SUPP. COMB.","SSRI & SEROTONIN RECEPTOR MODULATOR ANTIDEPRESSANT");
%let g_tricy=%nrstr("TRICYCLIC ANTIDEPRESSANTS & REL. NON-SEL. RU-INHIB","TRICYCLIC ANTIDEPRESSANT/BENZODIAZEPINE COMBINATNS","TRICYCLIC ANTIDEPRESSANT/PHENOTHIAZINE COMBINATNS");
%let g_alpha2=%nrstr("ALPHA-2 RECEPTOR ANTAGONIST ANTIDEPRESSANTS");
%let g_ndri=%nrstr("NOREPINEPHRINE & DOPAMINE INHIB.(NDRIS)/DIET SUPP","NOREPINEPHRINE AND DOPAMINE REUPTAKE INHIB (NDRIS)");
%let g_depr_comb=%nrstr("SSRI & 5HT1A PARTIAL AGONIST ANTIDEPRESSANT","SSRI & ANTIPSYCH,ATYP,DOPAMINE&SEROTONIN ANTAG CMB","TRICYCLIC ANTIDEPRESSANT/BENZODIAZEPINE COMBINATNS","TRICYCLIC ANTIDEPRESSANT/PHENOTHIAZINE COMBINATNS","SELECTIVE SEROTONIN INHIB. (SSRIS)/DIET SUPP CMB.",
	"SEROTONIN-2 ANTAG,REUPTAKE INH/DIETARY SUPP. COMB.","SSRI & SEROTONIN RECEPTOR MODULATOR ANTIDEPRESSANT","NOREPINEPHRINE & DOPAMINE INHIB.(NDRIS)/DIET SUPP");

%let g_typ_antipsych=%nrstr("ANTIPSYCH,DOPAMINE ANTAG.,DIPHENYLBUTYLPIPERIDINES","ANTIPSYCHOTICS, DOPAMINE & SEROTONIN ANTAGONISTS","ANTIPSYCHOTICS,DOPAMINE ANTAGONISTS, THIOXANTHENES","ANTIPSYCHOTICS,DOPAMINE ANTAGONISTS,BUTYROPHENONES","ANTIPSYCHOTICS,DOPAMINE ANTAGONST,DIHYDROINDOLONES","ANTI-PSYCHOTICS,PHENOTHIAZINES");
%let g_atyp_antipsych=%nrstr("ANTIPSYCHOTIC,ATYPICAL,DOPAMINE,SEROTONIN ANTAGNST","SELECTIVE SEROTONIN 5-HT2A INVERSE AGONISTS (SSIA)","ANTIPSYCHOTICS, ATYP, D2 PARTIAL AGONIST/5HT MIXED","ANTIPSYCHOTIC-ATYPICAL,D3/D2 PARTIAL AG-5HT MIXED","SSRI & ANTIPSYCH,ATYP,DOPAMINE&SEROTONIN ANTAG CMB","TRICYCLIC ANTIDEPRESSANT/PHENOTHIAZINE COMBINATNS");
%let g_atyp_antipsych_comb=%nrstr("ANTIPSYCHOTICS, ATYP, D2 PARTIAL AGONIST/5HT MIXED","ANTIPSYCHOTIC-ATYPICAL,D3/D2 PARTIAL AG-5HT MIXED","SSRI & ANTIPSYCH,ATYP,DOPAMINE&SEROTONIN ANTAG CMB","TRICYCLIC ANTIDEPRESSANT/PHENOTHIAZINE COMBINATNS");

%let g_adhd=%nrstr("TX FOR ADHD - SELECTIVE ALPHA-2 RECEPTOR AGONIST","TX FOR ATTENTION DEFICIT-HYPERACT(ADHD)/NARCOLEPSY","TX FOR ATTENTION DEFICIT-HYPERACT.(ADHD), NRI-TYPE","ADRENERGICS, AROMATIC, NON-CATECHOLAMINE");

%let g_narco=%nrstr("TX FOR ATTENTION DEFICIT-HYPERACT(ADHD)/NARCOLEPSY","NARCOLEPSY AND SLEEP DISORDER THERAPY AGENTS");

%let g_antimanic=%nrstr("BIPOLAR DISORDER DRUGS");

%let g_misc=%nrstr("HSDD AGENTS-MIXED SEROTONIN AGONIST/ANTAGONISTS");

%macro fdb_pull;
data base.fdb_antipsych;
	set base.fdb_ndc_extract (keep=ndc bn gnn gnn60 hic3_desc ahfs_desc gtc_desc);
	if gtc_desc="PSYCHOTHERAPEUTIC DRUGS";
	%do i=1 %to &max;
		%let condition=%scan(&classes,&i);
		if hic3_desc in(&&g_&condition) then &condition=1; else &condition=0;
	%end;
	any_antidep=max(of maoi--depr_comb);
	any_antipsych=max(of typ_antipsych--atyp_antipsych_comb);
	
	*if max(of maoi--atyp_comb);

	class1=0;
	class2=0;
	class3=0;

	/*Benzos*/
		* class 1;	
	if FIND(GNN60,"CHLORDIAZEPOXIDE") then do;
		class1=1;
		if find(gnn60,"/")=0 then chlordiazepoxide=1;
		else chlordiazepoxide_combo=1;
	end;
	if  FIND(GNN60,"CLORAZEPATE") then do;
		class1=1;
		if find(gnn60,"/")=0 then clorazepate=1;
		else clorazepate_combo=1;
	end;
	if FIND(GNN60,"DIAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then diazepam=1;
		else diazepam_combo=1;
	end;
	if FIND(GNN60,"FLURAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then flurazepam=1;
		else flurazepam_combo=1;
	end;
	if FIND(GNN60,"HALAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then halazepam=1;
		else halazepam_combo=1;
	end;
	if FIND(GNN60,"PRAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then prazepam=1;
		else prazepam_combo=1;
	end;
	if FIND(GNN60,"QUAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then quazepam=1;
		else quazepam_combo=1;
	end;
	if FIND(GNN60,"ALPRAZOLAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then alprazolam=1;
		else alprazolam_combo=1;
	end;
	if FIND(GNN60,"CLONAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then clonazepam=1;
		else clonazepam_combo=1;
	end;
	if FIND(GNN60,"ESTAZOLAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then estazolam=1;
		else estazolam_combo=1;
	end;
	if FIND(GNN60,"LORAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then lorazepam=1;
		else lorazepam_combo=1;
	end;
	if FIND(GNN60,"MIDAZOLAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then midazolam=1;
		else midazolam_combo=1;
	end;
	if FIND(GNN60,"OXAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then oxazepam=1;
		else oxazepam_combo=1;
	end;
	if FIND(GNN60,"TEMAZEPAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then temazepam=1;
		else temazepam_combo=1;
	end;
	if FIND(GNN60,"TRIAZOLAM") then do;
		class1=1;
		if find(gnn60,"/")=0 then triazolam=1;
		else triazolam_combo=1;
	end;
	
	* class 2;
	if FIND(GNN60,"ZALEPLON") then do;
		class2=1;
		if find(gnn60,"/")=0 then zaleplon=1;
		else zaleplon_combo=1;
	end;
	if FIND(GNN60,"ESZOPICLONE") then do;
		class2=1;
		if find(gnn60,"/")=0 then eszopiclone=1;
		else eszopiclone_combo=1;
	end;
	if FIND(GNN60,"ZOLPIDEM") then do;
		class2=1;
		if find(gnn60,"/")=0 then zolpidem=1;
		else zolpidem_combo=1;
	end;
	if FIND(GNN60,"ZOPICLONE") then do;
		class2=1;
		if find(gnn60,"/")=0 then zopiclone=1;
		else zopiclone_combo=1;
	end;
 
	* class 3;
	if FIND(GNN60,"BUSPIRONE") then do;
		class3=1;
		if find(gnn60,"/") then buspirone=1;
		else buspirone_combo=1;
	end;
	if FIND(GNN60,"HYDROXYZINE") then do;
		class3=1;
		if find(gnn60,"/") then hydroxyzine=1;
		else hydroxyzine_combo=1;
	end;
	if FIND(GNN60,"GABAPENTIN") then do;
		class3=1;
		if find(gnn60,"/") then gabapentin=1;
		else gabapentin_combo=1;
	end;
	if hic3_desc="ANTI-ANXIETY DRUGS" then do;
		class3=1;
	end;

	any=max(of class1,class2,class3,any_antidep,any_antipsych,adhd,narco,antimanic,misc);

	*if any;

	keep ndc bn gnn gnn60 hic3_desc ahfs_desc gtc_desc hic3_desc ahfs_desc maoi snri ssri sari tricy alpha2 ndri depr_comb typ_antipsych atyp_antipsych atyp_antipsych_comb adhd narco antimanic class1 class2 class3 misc any
	any_antidep any_antipsych; 

run;
%mend;

%fdb_pull;

proc freq data=base.fdb_antipsych noprint;
	table hic3_desc*ahfs_desc*maoi*snri*ssri*sari*tricy*alpha2*ndri*depr_comb*typ_antipsych*atyp_antipsych*atyp_antipsych_comb*adhd*narco*antimanic*class1*class2*class3*misc*any 
	/ out=&tempwork..fdb_anytipsych_ck;
run;

data &tempwork..proposalrx_check;
	set base.fdb_antipsych;

	* Check with drugs specified for the proposal;
	if find(lowcase(gnn),'pimavanserin') then pimavanserin=1; else pimavanserin=0;
	if find(lowcase(gnn),'aripiprazole') then aripiprazole=1; else aripiprazole=0;
	if find(lowcase(gnn),'asenapine') then asenapine=1; else asenapine=0;
	if find(lowcase(gnn),'chlorpromazine') then chlorpromazine=1; else chlorpromazine=0;
	if find(lowcase(gnn),'clozapine') then clozapine=1; else clozapine=0;
	if find(lowcase(gnn),'fluphenazine') then fluphenazine=1; else fluphenazine=0;
	if find(lowcase(gnn),'haloperidol') then haloperidol=1; else haloperidol=0;
	if find(lowcase(gnn),'iloperidone') then iloperidone=1; else iloperidone=0;
	if find(lowcase(gnn),'loxapine') then loxapine=1; else loxapine=0;
	if find(lowcase(gnn),'mesoridazine') then mesoridazine=1; else mesoridazine=0;
	if find(lowcase(gnn),'lurasidone') then lurasidone=1; else lurasidone=0;
	if find(lowcase(gnn),'olanzapine') then olanzapine=1; else olanzapine=0;
	if find(lowcase(gnn),'paliperidone') then paliperidone=1; else paliperidone=0;
	if find(lowcase(gnn),'perphenazine') then perphenazine=1; else perphenazine=0;
	if find(lowcase(gnn),'pimozide') then pimozide=1; else pimozide=0;
	if find(lowcase(gnn),'promazine') then promazine=1; else promazine=0;
	if find(lowcase(gnn),'quetiapine') then quetiapine=1; else quetiapine=0;
	if find(lowcase(gnn),'risperidone') then risperidone=1; else risperidone=0;
	if find(lowcase(gnn),'thioridazine') then thioridazine=1; else thioridazine=0;
	if find(lowcase(gnn),'thiothixene') then thiothixene=1; else thiothixene=0;
	if find(lowcase(gnn),'trifluoperazine') then trifluoperazine=1; else trifluoperazine=0;
	if find(lowcase(gnn),'ziprasidone') then ziprasidone=1; else ziprasidone=0;
	if find(lowcase(gnn),'lithium') then lithium=1; else lithium=0;
	
	any_proposal_rx=max(of pimavanserin--ziprasidone);

run;

proc means data=&tempwork..proposalrx_check noprint nway;
	class gnn;
	var pimavanserin--ziprasidone any_proposal_rx typ_antipsych atyp_antipsych;
	output out=&tempwork..proposalrx_check1 max()=;
run;
