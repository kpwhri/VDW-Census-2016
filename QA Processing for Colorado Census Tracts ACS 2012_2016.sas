/***************************************************************************************************************
Program Name; QA Processing for Colorado Census Tracts.sas
Author: David Tabano
		303-614-1348
		David.C.Tabano@kp.org

Description:
		This program is designed to QA American Community Survey (ACS) variables (vars) in the VDW Census_Demog
		tables. The program processes data from the various ACS table sources (ACS 5YR TBLIDS, listed below)
		and generates subsets of the Census_Demog by the each var. A PROC COMPARE is run against TBLIDS data imported
		from .csv files and the subsets of the Census_Demog. Any tables that are not an exact match should be
		investigated further.

Notes:
	1) Census tract-level .csv files should be downloaded from the American Factfinder website 
		(see below) prior to running this program. 
	2) All vars from Census_Demog that are checked in this program are ACS vars; vars in Census_Demog that are 
	   not qa'ed in this program are vars from the US Census 2010 data 
	   (these vars have been qa'ed with the virst vintage of Census_Demog created by Group Health). 
	3) Additional programming must be completed to process block group-level vars, although not all ACS
	   data is available at geographies below the census tract-level.
	4) The PROC IMPORT of the .csv file seems to be buggy- errors are generated when attempting to import 
	   some files, and the errors appear to be random. Need to investigate this further.
*****************************************************************************************************************/

*Download and unzip of files from American Factfinder prior to running this program;
***American Factfinder website-- http://factfinder.census.gov/faces/nav/jsf/pages/searchresults.xhtml?refresh=t   ;
*tables downloaded 11/10/2016 in 

OLD
\\kpco-ihr-1\analytic_projects_2016\2016_Steiner_CHORDS_EX\Data\Raw\QA Data from American Factfinder\ACS 2009_2013 2010_2014 Colorado CSV Output Census Tracts

NEW
\\Kpco-ihr-1.ihr.or.kp.org\analytic_projects_2016\2016_Steiner_CHORDS_EX\Data\Raw\QA Data from American Factfinder\ACS 2009_2013 2010_2014_2011_2015_2012_2016 Colorado CSV Output Census Tracts
;

/*List of tables to download from American Factfinder for 2009-2013 and 2010-2014 ACS 5YR TBLIDS*********************************
**Make sure you select "All Census Tracts within Colorado" under "Geographies"

B01001 - SEX BY AGE
B01001A	- SEX BY AGE (WHITE ALONE)
B01001B	- SEX BY AGE (BLACK OR AFRICAN AMERICAN ALONE)
B01001C	- SEX BY AGE (AMERICAN INDIAN AND ALASKA NATIVE ALONE)
B01001D	- SEX BY AGE (ASIAN ALONE)
B01001E	- SEX BY AGE (NATIVE HAWAIIAN AND OTHER PACIFIC ISLANDER ALONE)
B01001F	- SEX BY AGE (SOME OTHER RACE ALONE)
B01001G	- SEX BY AGE (TWO OR MORE RACES)
B01001H - SEX BY AGE (WHITE ALONE, NOT HISPANIC OR LATINO)
B01001I - SEX BY AGE (HISPANIC OR LATINO)
B01002 - MEDIAN AGE BY SEX

B15002 - SEX BY EDUCATIONAL ATTAINMENT FOR THE POPULATION 25 YEARS AND OVER
B19113 - MEDIAN FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
B17001 - POVERTY STATUS IN THE PAST 12 MONTHS BY SEX BY AGE
B19013 - MEDIAN HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)

B19101 - FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
B19001 - HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
B25026 - TOTAL POPULATION IN OCCUPIED HOUSING UNITS BY TENURE BY YEAR HOUSEHOLDER MOVED INTO UNIT

B17026 - RATIO OF INCOME TO POVERTY LEVEL OF FAMILIES IN THE PAST 12 MONTHS
B16007 - AGE BY LANGUAGE SPOKEN AT HOME FOR THE POPULATION 5 YEARS AND OVER
B05001 - NATIVITY AND CITIZENSHIP STATUS IN THE UNITED STATES
B07001 - GEOGRAPHICAL MOBILITY IN THE PAST YEAR BY AGE FOR CURRENT RESIDENCE IN THE UNITED STATES
B12001 - SEX BY MARITAL STATUS FOR THE POPULATION 15 YEARS AND OVER
C18108 - AGE BY NUMBER OF DISABILITIES
B23001 - SEX BY AGE BY EMPLOYMENT STATUS FOR THE POPULATION 16 YEARS AND OVER
C27006 - MEDICARE COVERAGE BY SEX BY AGE
B08201 - HOUSEHOLD SIZE BY VEHICLES AVAILABLE
B19057 - PUBLIC ASSISTANCE INCOME IN THE PAST 12 MONTHS FOR HOUSEHOLDS
B25091 - MORTGAGE STATUS BY SELECTED MONTHLY OWNER COSTS AS A PERCENTAGE OF HOUSEHOLD INCOME IN THE PAST 12 MONTHS
B25077 - MEDIAN VALUE (DOLLARS)
B25014 - TENURE BY OCCUPANTS PER ROOM
B25115 - TENURE BY HOUSEHOLD TYPE AND PRESENCE AND AGE OF OWN CHILDREN
C24040 - SEX BY INDUSTRY FOR THE FULL-TIME, YEAR-ROUND CIVILIAN EMPLOYED POPULATION 16 YEARS AND OVER
C27007 - MEDICAID/MEANS-TESTED PUBLIC COVERAGE BY SEX BY AGE
B25001 - HOUSING UNITS
********************************************************************************************************************************************************/
******************************************************************************************;
**  BEGIN user code
******************************************************************************************;
*RETIRED DO NOT USE %include '\\kpco-ihr-1\VDW Production\StdVars_SQLServer.sas'; *point to VDW Standard Vars;

%include '\\Kpco-ihr-1.ihr.or.kp.org\VDW Production\StdVars_SurveillanceOps.sas'; 
*Includes all records from Enrollment and Demographics;
*References:  VDW.ENROLLMENT      (&_VDW_ENROLL) VDW.DEMOGRAPHICS (&_VDW_DEMOGRAPHIC);

%include vdw_macs; *VDW CRN Macros;



*EDIT SECTION;
*location of census test data;
%let censusroot = \\Kpco-ihr-1.ihr.or.kp.org\analytic_projects_2016\2016_Steiner_CHORDS_EX;
%let interimdata= \\Kpco-ihr-1.ihr.or.kp.org\analytic_projects_2016\2016_Steiner_CHORDS_EX\Data\VDW_Census_Demographics\ACS_2012_2016\output;

proc printto log="&censusroot.\Logs\QA Processing for Colorado Census Tracts &sysdate..log" new; run;

*library where Census_Demog data is located;
*libname census "&censusroot.\data\raw";
libname census "&interimdata.";

libname share "&censusroot.\Data\For Export\Final Census Demographics Tables";


*location of QA data downloaded from American Factfinder (http://factfinder.census.gov/faces/nav/jsf/pages/searchresults.xhtml?refresh=t);
%let qadata = \\Kpco-ihr-1.ihr.or.kp.org\analytic_projects_2016\2016_Steiner_CHORDS_EX\Data\Raw\QA Data from American Factfinder\ACS 2013_2014_2015_2016 Colorado_CSV_Output_CTs;

*END EDIT SECTION;



/*****2009-2013 ACS 5YR TBLIDS VARIABLE CALCULATIONS FOR CENSUS DEMOG*****
B01001 - SEX BY AGE
		if missing(B01001001)=0 then do;
		&_siteabbr._ACS_Total_Pop=B01001001;
		&_siteabbr._ACS_under18pop=sum(B01001003,B01001004,B01001005,B01001006,B01001027, B01001028, B01001029, B01001030);
        &_siteabbr._ACS_18overpop=sum(B01001007,B01001008,B01001009,B01001010,B01001011,B01001012,B01001013,B01001014,B01001015,B01001016,B01001017,B01001018,B01001019,
						B01001020,B01001021,B01001022,B01001023,B01001024,B01001025,B01001031,B01001032,B01001033,B01001034,B01001035,B01001036,B01001037,
						B01001038,B01001039,B01001040,B01001041,B01001042,B01001043,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
		&_siteabbr._ACS_25overpop=sum(B01001011,B01001012,B01001013,B01001014,B01001015,B01001016,B01001017,B01001018,B01001019,
						B01001020,B01001021,B01001022,B01001023,B01001024,B01001025,B01001035,B01001036,B01001037,
						B01001038,B01001039,B01001040,B01001041,B01001042,B01001043,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
		&_siteabbr._ACS_65overpop=sum(B01001020,B01001021,B01001022,B01001023,B01001024,B01001025,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
		end;

B01001 - SEX BY AGE
		if B01001001 then
			Residents_65 = sum(B01001020, B01001021, B01001022, B01001023, B01001024, B01001025, B01001044,
				B01001045, B01001046, B01001047, B01001048, B01001049)/B01001001;


B01001A	- SEX BY AGE (WHITE ALONE)
		if missing(B01001A001)=0 then do;
		&_siteabbr._ACS_Total_Pop_WH=B01001A001;
		&_siteabbr._ACS_WH=B01001A001/B01001001;
		end;

B01001B	- SEX BY AGE (BLACK OR AFRICAN AMERICAN ALONE)
		if missing(B01001B001)=0 then do;
		&_siteabbr._ACS_Total_Pop_BA=B01001B001;
		&_siteabbr._ACS_BA=B01001B001/B01001001;
		end;

B01001C	- SEX BY AGE (AMERICAN INDIAN AND ALASKA NATIVE ALONE)
		if missing(B01001C001)=0 then do;
		&_siteabbr._ACS_Total_Pop_IN=B01001C001;
		&_siteabbr._ACS_IN=B01001C001/B01001001;
		end;

B01001D	- SEX BY AGE (ASIAN ALONE)
		if missing(B01001D001)=0 then do;
		&_siteabbr._ACS_Total_Pop_AS=B01001D001;
		&_siteabbr._ACS_AS=B01001D001/B01001001;
		end;

B01001E	- SEX BY AGE (NATIVE HAWAIIAN AND OTHER PACIFIC ISLANDER ALONE)
		if missing(B01001E001)=0 then do;
		&_siteabbr._ACS_Total_Pop_HP=B01001E001;
		&_siteabbr._ACS_HP=B01001E001/B01001001;
		end;

B01001F	- SEX BY AGE (SOME OTHER RACE ALONE)
		if missing(B01001F001)=0 then do;
		&_siteabbr._ACS_Total_Pop_OT=B01001F001;
		&_siteabbr._ACS_OT=B01001F001/B01001001;
		end;

B01001G	- SEX BY AGE (TWO OR MORE RACES)
		if missing(B01001G001)=0 then do;
		&_siteabbr._ACS_Total_Pop_MU=B01001G001;
		&_siteabbr._ACS_MU=B01001G001/B01001001;
		end;

B01001H - SEX BY AGE (WHITE ALONE, NOT HISPANIC OR LATINO)
		if missing(B01001H001)=0 then do;
		&_siteabbr._ACS_Total_Pop_NHWH=B01001H001;
		&_siteabbr._ACS_NHWH=B01001H001/B01001001;
		end;

B01001I - SEX BY AGE (HISPANIC OR LATINO)
		if missing(B01001I001)=0 then do;
		&_siteabbr._ACS_Total_Pop_HS=B01001I001;
		&_siteabbr._ACS_HS=B01001I001/B01001001;
		end;


B01002 - MEDIAN AGE BY SEX
		if missing(B01002001)=0 then medage= B01002001;

B15002 - SEX BY EDUCATIONAL ATTAINMENT FOR THE POPULATION 25 YEARS AND OVER
		if missing(B15002001)=0 then do;
			education1 = sum(B15002003, B15002004, B15002005, B15002006, B15002020, B15002021, B15002022, B15002023)/B15002001;
			education2 = sum(B15002007, B15002008, B15002009, B15002010, B15002024, B15002025, B15002026, B15002027)/B15002001;
			education3 = sum(B15002011, B15002028)/B15002001;
			education4 = sum(B15002012, B15002013, B15002029, B15002030)/B15002001;
			education5 = sum(B15002014, B15002031)/B15002001;
			education6 = sum(B15002015, B15002032)/B15002001;
			education7 = sum(B15002016, B15002017, B15002033, B15002034)/B15002001;
			education8 = sum(B15002018, B15002035)/B15002001;
		end;

B19113 - MEDIAN FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
		medfamincome = B19113001;

B19101 - FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
		if B19101001 then do;
			famincome1 = B19101002/B19101001;
			famincome2 = B19101003/B19101001;
			famincome3 = B19101004/B19101001;
			famincome4 = B19101005/B19101001;
			famincome5 = B19101006/B19101001;
			famincome6 = B19101007/B19101001;
			famincome7 = B19101008/B19101001;
			famincome8 = B19101009/B19101001;
			famincome9 = B19101010/B19101001;
			famincome10 = B19101011/B19101001;
			famincome11 = B19101012/B19101001;
			famincome12 = B19101013/B19101001;
			famincome13 = B19101014/B19101001;
			famincome14 = B19101015/B19101001;
			famincome15 = B19101016/B19101001;
			famincome16 = B19101017/B19101001;
		end;

B19013 - MEDIAN HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
		medhousincome = B19013001;

B19001 - HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
		if B19001001 then do;
			housincome1 = B19001002/B19001001;
			housincome2 = B19001003/B19001001;
			housincome3 = B19001004/B19001001;
			housincome4 = B19001005/B19001001;
			housincome5 = B19001006/B19001001;
			housincome6 = B19001007/B19001001;
			housincome7 = B19001008/B19001001;
			housincome8 = B19001009/B19001001;
			housincome9 = B19001010/B19001001;
			housincome10 = B19001011/B19001001;
			housincome11 = B19001012/B19001001;
			housincome12 = B19001013/B19001001;
			housincome13 = B19001014/B19001001;
			housincome14 = B19001015/B19001001;
			housincome15 = B19001016/B19001001;
			housincome16 = B19001017/B19001001;
		end;

B17026 - RATIO OF INCOME TO POVERTY LEVEL OF FAMILIES IN THE PAST 12 MONTHS
		if B17026001 then do;
			pov_lt_50 = B17026002/B17026001;
			pov_50_74 = B17026003/B17026001;
			pov_75_99 = B17026004/B17026001;
			pov_100_124 = B17026005/B17026001;
			pov_125_149 = B17026006/B17026001;
			pov_150_174 = B17026007/B17026001;
			pov_175_184 = B17026008/B17026001;
			pov_185_199 = B17026009/B17026001;
			pov_gt_200 = sum(B17026010, B17026011, B17026012, B17026013)/B17026001;
		end;

B16007 - AGE BY LANGUAGE SPOKEN AT HOME FOR THE POPULATION 5 YEARS AND OVER
		if B16007001 then do;
			English_Speaker = sum(B16007003, B16007009, B16007015)/B16007001;
			Spanish_Speaker = sum(B16007004, B16007010, B16007016)/B16007001;
		end;

B05001 - NATIVITY AND CITIZENSHIP STATUS IN THE UNITED STATES
		if B05001001 then BornInUS = (B05001002/B05001001);

B07001 - GEOGRAPHICAL MOBILITY IN THE PAST YEAR BY AGE FOR CURRENT RESIDENCE IN THE UNITED STATES
		if B07001001 then MovedInLast12Mon = 1 - (B07001017/B07001001);

B12001 - SEX BY MARITAL STATUS FOR THE POPULATION 15 YEARS AND OVER
		if B12001001 then do;
			Married = sum(B12001004, B12001013)/B12001001;
			Divorced = sum(B12001010, B12001019)/B12001001;
		end;

C18108 - AGE BY NUMBER OF DISABILITIES
		 if not(missing(sum(C18108006, C18108009))) then
			Disability = sum(C18108007, C18108008, C18108011, C18108012)/sum(C18108006, C18108009, C18108013);

B23001 - SEX BY AGE BY EMPLOYMENT STATUS FOR THE POPULATION 16 YEARS AND OVER
		if B23001001 then do;
			Unemployment = sum(B23001008, B23001015, B23001022, B23001029, B23001036, B23001043, B23001050, B23001057,
				B23001064, B23001071, B23001076, B23001081, B23001086, B23001094, B23001101, B23001108, B23001115,
				B23001122, B23001129, B23001136, B23001143, B23001150, B23001157, B23001162, B23001167, B23001172)/B23001001;
       There's been some talk about whether the denominator should be
          total population (B23001001) or total males (B23001002) 
			Unemployment_Male = sum(B23001008, B23001015, B23001022, B23001029, B23001036, B23001043, B23001050, B23001057,
				B23001064, B23001071, B23001076, B23001081, B23001086)/B23001002;
		end;

C27006 - MEDICARE COVERAGE BY SEX BY AGE
		 if C27006001 then
			Ins_Medicare = sum(C27006004, C27006007, C27006010, C27006014, C27006017, C27006020)/C27006001;
		 if C27007001 then
			Ins_Medicaid = sum(C27007004, C27007007, C27007010, C27007014, C27007017, C27007020)/C27007001;

B08201 - HOUSEHOLD SIZE BY VEHICLES AVAILABLE
		if B08201001 then HH_NoCar = B08201002/B08201001;
B19057 - PUBLIC ASSISTANCE INCOME
		if B19057001 then HH_Public_Assistance = B19057002/B19057001;

B25091 - MORTGAGE STATUS BY SELECTED MONTHLY OWNER COSTS AS A PERCENTAGE OF HOUSEHOLD INCOME IN THE PAST 12 MONTHS
		if B25091001 then do;
			Hmowner_costs_mort = B25091011/B25091001;
			Hmowner_costs_no_mort = B25091022/B25091001;
		end;
B25077 - MEDIAN VALUE (DOLLARS)
		Homes_medvalue = B25077001;

B25014 - TENURE BY OCCUPANTS PER ROOM
		if B25014001 then
			Pct_crowding = sum(B25014005, B25014006, B25014007, B25014011, B25014012, B25014013)/B25014001;

B25115 - TENURE BY HOUSEHOLD TYPE AND PRESENCE AND AGE OF OWN CHILDREN
		if B25115001 then
			Female_Head_of_HH = sum(B25115011, B25115024)/B25115001;

C24040 - SEX BY INDUSTRY FOR THE FULL-TIME, YEAR-ROUND CIVILIAN EMPLOYED POPULATION 16 YEARS AND OVER
		if C24040001 then do;
			MGR_Female = sum(C24040046, C24040045)/C24040001;
			MGR_Male = sum(C24040019, C24040018)/C24040001;
		end;

B25026 - TOTAL POPULATION IN OCCUPIED HOUSING UNITS BY TENURE BY YEAR HOUSEHOLDER MOVED INTO UNIT
		if B25026001 then
			Same_residence = sum(B25026004, B25026005, B25026006, B25026007, B25026008, B25026011, B25026012,
				B25026013, B25026014, B25026015)/B25026001;
 B25001 - HOUSING UNITS
		if B25001001 then
		&_siteabbr._ACS_HOUSES_N = B25001001;
**********************************/
*geocode state lookup (first two digits);
  proc format;
    value $fips_st
      '01'='Alabama' '17'='Illinois' '30'='Montana' '44'='Rhode Island'
      '02'='Alaska' '18'='Indiana' '31'='Nebraska' '45'='South Carolina'
      '04'='Arizona' '19'='Iowa' '32'='Nevada' '46'='South Dakota'
      '05'='Arkansas' '20'='Kansas' '33'='New Hampshire' '47'='Tennessee'
      '06'='California' '21'='Kentucky' '34'='New Jersey' '48'='Texas'
      '08'='Colorado' '22'='Louisiana' '35'='New Mexico' '49'='Utah'
      '09'='Connecticut' '23'='Maine' '36'='New York' '50'='Vermont'
      '10'='Delaware' '24'='Maryland' '37'='North Carolina' '51'='Virginia'
      '11'='District of Columbia' '25'='Massachusetts' '38'='North Dakota' '53'='Washington'
      '12'='Florida' '26'='Michigan' '39'='Ohio' '54'='West Virginia'
      '13'='Georgia' '27'='Minnesota' '40'='Oklahoma' '55'='Wisconsin'
      '15'='Hawaii' '28'='Mississippi' '41'='Oregon' '56'='Wyoming'
      '16'='Idaho' '29'='Missouri' '42'='Pennsylvania' '72'='Puerto Rico';
  run;


options nomlogic nomprint nosymbolgen;
*extract QA data to recreate VDW Census Demog Variables;
%macro qa_processing(tblid,ACS_YEAR);

%if &ACS_YEAR=2009_2013 %then %do;
%let yr=13;
%end;
%if &ACS_YEAR=2010_2014 %then %do;
%let yr=14;
%end;
%if &ACS_YEAR=2011_2015 %then %do;
%let yr=15;
%end;
%if &ACS_YEAR=2012_2016 %then %do;
%let yr=16;
%end;


/*PROC IMPORT */
/*OUT= ACS_&yr._5YR_&tblid._metadata*/
/*DATAFILE= "&qadata.\ACS_&yr._5YR_&tblid._metadata.csv" */
/*            DBMS=CSV REPLACE;*/
/*     GETNAMES=YES;*/
/*     DATAROW=2; */
/*RUN;*/

/**testing;*/
/**%let tblid=B01001;*/

PROC IMPORT 
OUT= ACS_&yr._5YR_&tblid._EST
DATAFILE= "&qadata.\ACS_&yr._5YR_&tblid._with_ann.csv" 
     DBMS=CSV REPLACE;
	 GETNAMES=YES;
     DATAROW=3; 
	 GUESSINGROWS=10000;
RUN;

/*PROC IMPORT */
/*OUT= ACS_&yr._5YR_&tblid._EST*/
/*DATAFILE= "&qadata.\ACS_&yr._5YR_&tblid._with_ann.csv" */
/*            DBMS=CSV REPLACE;*/
/*     GETNAMES=YES;*/
/*     DATAROW=3; */
/*RUN;*/


%let dsn=ACS_&yr._5YR_&tblid._EST;
  %if %sysfunc(exist(&dsn)) %then %do;
/*    proc print data = &dsn;*/
/*    run;*/
  %put NOTE: Data set &dsn. exists, import successful;
  %end;
  %else %do;
      %put ERROR: Data set &dsn. does not exist;
	  %put ERROR: Check import of ACS_&yr._5YR_&tblid._with_ann.csv;
	  %put ERROR: %qa_processing will end now;
	%return;
  %end;



*format imported data to match VDW Census Demog structure;
data &tblid._EST_tracts 
/*keep vars derived from American Factfinder data was selected (e.g. B01001)*/
(keep=geocode 
%if &tblid=B01001 %then %do;
&_siteabbr._ACS_Total_Pop &_siteabbr._ACS_under18pop &_siteabbr._ACS_18overpop &_siteabbr._ACS_25overpop &_siteabbr._ACS_65overpop Residents_65
%end;
%if &tblid=B01001A %then %do;&_siteabbr._ACS_Total_Pop_WH %end;
%if &tblid=B01001B %then %do;&_siteabbr._ACS_Total_Pop_BA %end;
%if &tblid=B01001C %then %do;&_siteabbr._ACS_Total_Pop_IN %end;
%if &tblid=B01001D %then %do;&_siteabbr._ACS_Total_Pop_AS %end;
%if &tblid=B01001E %then %do;&_siteabbr._ACS_Total_Pop_HP %end;
%if &tblid=B01001F %then %do;&_siteabbr._ACS_Total_Pop_OT %end;
%if &tblid=B01001G %then %do;&_siteabbr._ACS_Total_Pop_MU %end;
%if &tblid=B01001H %then %do;&_siteabbr._ACS_Total_Pop_NHWH %end;
%if &tblid=B01001I %then %do;&_siteabbr._ACS_Total_Pop_HS %end;
%if &tblid=B01002 %then %do; medage %end;
%if &tblid=B15002 %then %do; education1-education8 %end;
%if &tblid=B19113 %then %do; medfamincome %end;
%if &tblid=B19001 %then %do; housincome1-housincome16 %end;
%if &tblid=B17026 %then %do; 
pov_lt_50 pov_50_74 pov_75_99 pov_100_124 pov_125_149 pov_150_174 pov_175_184 pov_185_199 pov_gt_200
%end;
%if &tblid=B16007 %then %do;
English_Speaker Spanish_Speaker
%end;
%if &tblid=B05001 %then %do; BornInUS %end;
%if &tblid=B07001 %then %do; MovedInLast12Mon %end;
%if &tblid=B12001 %then %do;
Married Divorced
%end;
%if &tblid=C18108 %then %do; Disability %end;
%if &tblid=B23001 %then %do;
Unemployment Unemployment_Male
%end;
%if &tblid=C27006 %then %do; Ins_Medicare %end;
%if &tblid=C27007 %then %do; Ins_Medicaid %end;
%if &tblid=B08201 %then %do;
HH_NoCar 
%end;
%if &tblid=B19057 %then %do; HH_Public_Assistance %end;
%if &tblid=B25091 %then %do; Hmowner_costs_mort Hmowner_costs_no_mort %end;
%if &tblid=B25077 %then %do; Homes_medvalue %end;
%if &tblid=B25014 %then %do; Pct_crowding %end;
%if &tblid=B25115 %then %do; Female_Head_of_HH %end;
%if &tblid=C24040 %then %do;
MGR_Female MGR_Male
%end;
%if &tblid=B25026 %then %do; Same_residence %end;
/*%if &tblid=B17001 %then %do; FAMPOVERTY %end;*/
%if &tblid=B25001 %then %do; &_siteabbr._ACS_HOUSES_N %end;
);
length geocode $15.;
set ACS_&yr._5YR_&tblid._EST;
geocode=substr(geo_id,10,11);

/**********recreate census demog variables****************************************/
/* Example
/*
/* From Census Demog, Married and Divorce variables are coded as follows-
/* B12001 - SEX BY MARITAL STATUS FOR THE POPULATION 15 YEARS AND OVER
/*		if B12001001 then do;
/*			Married = sum(B12001004, B12001013)/B12001001;
/*			Divorced = sum(B12001010, B12001019)/B12001001;
/*		end;
/*
/* To create from downloaded .csv data, recode as follows from imported data-
/*
/*		B12001 = table id, B12001001=HD01_VD01 in ACS_&yr._B12001_metadata.csv
/*						   B12001002=HD01_VD02 in ACS_&yr._B12001_metadata.csv
/*						   B12001003=HD01_VD03 in ACS_&yr._B12001_metadata.csv
/*						   etc...
/* 		Derive Census Demog variables as follows-
/*		%if &tblid=B12001 %then %do;
/*			Married = sum(HD01_VD04, HD01_VD13)/HD01_VD01;
/*			Divorced = sum(HD01_VD10, HD01_VD19)/HD01_VD01;
/*		%end;
/**********************************************************************************/

%if &tblid=B01001 %then %do;
&_siteabbr._ACS_Total_Pop=HD01_VD01;
&_siteabbr._ACS_under18pop=sum(HD01_VD03,HD01_VD04,HD01_VD05,HD01_VD06,HD01_VD27,HD01_VD28,HD01_VD29,HD01_VD30);
&_siteabbr._ACS_18overpop=sum(HD01_VD07,HD01_VD08,HD01_VD09,HD01_VD10,HD01_VD11,HD01_VD12,HD01_VD13,HD01_VD14,HD01_VD15,HD01_VD16,HD01_VD17,HD01_VD18,HD01_VD19,
							  HD01_VD20,HD01_VD21,HD01_VD22,HD01_VD23,HD01_VD24,HD01_VD25,HD01_VD31,HD01_VD32,HD01_VD33,HD01_VD34,HD01_VD35,HD01_VD36,HD01_VD37,
							  HD01_VD38,HD01_VD39,HD01_VD40,HD01_VD41,HD01_VD42,HD01_VD43,HD01_VD44,HD01_VD45,HD01_VD46,HD01_VD47,HD01_VD48,HD01_VD49);
&_siteabbr._ACS_25overpop=sum(HD01_VD11,HD01_VD12,HD01_VD13,HD01_VD14,HD01_VD15,HD01_VD16,HD01_VD17,HD01_VD18,HD01_VD19,
							  HD01_VD20,HD01_VD21,HD01_VD22,HD01_VD23,HD01_VD24,HD01_VD25,HD01_VD35,HD01_VD36,HD01_VD37,
							  HD01_VD38,HD01_VD39,HD01_VD40,HD01_VD41,HD01_VD42,HD01_VD43,HD01_VD44,HD01_VD45,HD01_VD46,HD01_VD47,HD01_VD48,HD01_VD49);
&_siteabbr._ACS_65overpop=sum(HD01_VD20,HD01_VD21,HD01_VD22,HD01_VD23,HD01_VD24,HD01_VD25,HD01_VD44,HD01_VD45,HD01_VD46,HD01_VD47,HD01_VD48,HD01_VD49);

Residents_65=&_siteabbr._ACS_65overpop/&_siteabbr._ACS_Total_Pop;
%end;

%if &tblid=B01001A %then %do;&_siteabbr._ACS_Total_Pop_WH=HD01_VD01;%end;
%if &tblid=B01001B %then %do;&_siteabbr._ACS_Total_Pop_BA=HD01_VD01;%end;
%if &tblid=B01001C %then %do;&_siteabbr._ACS_Total_Pop_IN=HD01_VD01;%end;
%if &tblid=B01001D %then %do;&_siteabbr._ACS_Total_Pop_AS=HD01_VD01;%end;
%if &tblid=B01001E %then %do;&_siteabbr._ACS_Total_Pop_HP=HD01_VD01;%end;
%if &tblid=B01001F %then %do;&_siteabbr._ACS_Total_Pop_OT=HD01_VD01;%end;
%if &tblid=B01001G %then %do;&_siteabbr._ACS_Total_Pop_MU=HD01_VD01;%end;
%if &tblid=B01001H %then %do;&_siteabbr._ACS_Total_Pop_NHWH=HD01_VD01;%end;
%if &tblid=B01001I %then %do;&_siteabbr._ACS_Total_Pop_HS=HD01_VD01;%end;
%if &tblid=B01002 %then %do; medage=HD01_VD02; %end;

%if &tblid=B15002 %then %do;
education1=sum(HD01_VD03,HD01_VD04,HD01_VD05,HD01_VD06,HD01_VD20,HD01_VD21,HD01_VD22,HD01_VD23)/HD01_VD01; 
education2=sum(HD01_VD07,HD01_VD08,HD01_VD09,HD01_VD10,HD01_VD24,HD01_VD25,HD01_VD26,HD01_VD27)/HD01_VD01; 
education3=sum(HD01_VD11,HD01_VD28)/HD01_VD01; 
education4=sum(HD01_VD12,HD01_VD13,HD01_VD29,HD01_VD30)/HD01_VD01; 
education5=sum(HD01_VD14,HD01_VD31)/HD01_VD01; 
education6=sum(HD01_VD15,HD01_VD32)/HD01_VD01; 
education7=sum(HD01_VD16,HD01_VD17,HD01_VD33,HD01_VD34)/HD01_VD01; 
education8=sum(HD01_VD18,HD01_VD35)/HD01_VD01; 
%end;

%if &tblid=B19113 %then %do; medfamincome=HD01_VD01; %end;
%if &tblid=B19001 %then %do;
housincome1=HD01_VD02/HD01_VD01; 
housincome2=HD01_VD03/HD01_VD01; 
housincome3=HD01_VD04/HD01_VD01; 
housincome4=HD01_VD05/HD01_VD01; 
housincome5=HD01_VD06/HD01_VD01; 
housincome6=HD01_VD07/HD01_VD01;  
housincome7=HD01_VD08/HD01_VD01; 
housincome8=HD01_VD09/HD01_VD01;
housincome9=HD01_VD10/HD01_VD01; 
housincome10=HD01_VD11/HD01_VD01; 
housincome11=HD01_VD12/HD01_VD01; 
housincome12=HD01_VD13/HD01_VD01; 
housincome13=HD01_VD14/HD01_VD01; 
housincome14=HD01_VD15/HD01_VD01; 
housincome15=HD01_VD16/HD01_VD01; 
housincome16=HD01_VD17/HD01_VD01; 
%end;

%if &tblid=B17026 %then %do; 
pov_lt_50=HD01_VD02/HD01_VD01;
pov_50_74=HD01_VD03/HD01_VD01;
pov_75_99=HD01_VD04/HD01_VD01; 
pov_100_124=HD01_VD05/HD01_VD01; 
pov_125_149=HD01_VD06/HD01_VD01;
pov_150_174=HD01_VD07/HD01_VD01; 
pov_175_184=HD01_VD08/HD01_VD01; 
pov_185_199=HD01_VD09/HD01_VD01; 
pov_gt_200=sum(HD01_VD10,HD01_VD11,HD01_VD112,HD01_VD13)/HD01_VD01;;
%end;

%if &tblid=B16007 %then %do;
English_Speaker=sum(HD01_VD03,HD01_VD09,HD01_VD15)/HD01_VD01;
Spanish_Speaker=sum(HD01_VD04,HD01_VD10,HD01_VD16)/HD01_VD01;
%end;

%if &tblid=B05001 %then %do; BornInUS=HD01_VD02/HD01_VD01; %end;

%if &tblid=B07001 %then %do; MovedInLast12Mon=(1-(HD01_VD18/HD01_VD01)); %end; *references HD01_VD18 instead of HD01_VD17 (B07001017);
%if &tblid=B12001 %then %do; 
Married = sum(HD01_VD04, HD01_VD13)/HD01_VD01;
Divorced = sum(HD01_VD10, HD01_VD19)/HD01_VD01;
%end;
%if &tblid=C18108 %then %do; Disability = sum(HD01_VD07, HD01_VD08, HD01_VD11, HD01_VD12)/sum(HD01_VD06, HD01_VD09, HD01_VD13); %end;
%if &tblid=B23001 %then %do;
*coded differently for ACS 2009 2013. Always good to check metadata files; 
Unemployment = sum(HD01_VD08, HD01_VD15, HD01_VD22, HD01_VD29, HD01_VD36, HD01_VD43, HD01_VD50, HD01_VD57,
				HD01_VD64, HD01_VD71, HD01_VD77, HD01_VD83, HD01_VD89, HD01_VD97, HD01_VD104, HD01_VD111, HD01_VD118,
				HD01_VD125, HD01_VD132, HD01_VD139, HD01_VD146, HD01_VD153, HD01_VD160, HD01_VD166, HD01_VD172, HD01_VD178)/HD01_VD01;
Unemployment_Male = sum(HD01_VD08, HD01_VD15, HD01_VD22, HD01_VD29, HD01_VD36, HD01_VD43, HD01_VD50, HD01_VD57,
				HD01_VD64, HD01_VD71, HD01_VD77, HD01_VD83, HD01_VD89)/HD01_VD02;
%end;
%if &tblid=C27006 %then %do;
Ins_Medicare = sum(HD01_VD04, HD01_VD07, HD01_VD10, HD01_VD14, HD01_VD17, HD01_VD20)/HD01_VD01;
%end;
%if &tblid=C27007 %then %do;
Ins_Medicaid = sum(HD01_VD04, HD01_VD07, HD01_VD10, HD01_VD14, HD01_VD17, HD01_VD20)/HD01_VD01;
%end;
%if &tblid=B08201 %then %do; 
*refer to metadata.csv file - these calcs do not match processing for annaul read ACS 5yr;
HH_NoCar = HD01_VD03/HD01_VD01;
%end;
%if &tblid=B19057 %then %do;
HH_Public_Assistance = HD01_VD02/HD01_VD01;
%end;
%if &tblid=B25091 %then %do;
Hmowner_costs_mort = HD01_VD11/HD01_VD01;
Hmowner_costs_no_mort = HD01_VD22/HD01_VD01;
%end;
%if &tblid=B25077 %then %do; Homes_medvalue = HD01_VD01; %end;
%if &tblid=B25014 %then %do; Pct_crowding = sum(HD01_VD05, HD01_VD06, HD01_VD07, HD01_VD11, HD01_VD12, HD01_VD13)/HD01_VD01; %end;
%if &tblid=B25115 %then %do; Female_Head_of_HH = sum(HD01_VD11, HD01_VD24)/HD01_VD01; %end;

%if &tblid=C24040 %then %do; 
MGR_Female = sum(HD01_VD46, HD01_VD45)/HD01_VD01;
MGR_Male = sum(HD01_VD19, HD01_VD18)/HD01_VD01;
%end;
%if &tblid=B25026 %then %do; 			
Same_residence = sum(HD01_VD04, HD01_VD05, HD01_VD06, HD01_VD07, HD01_VD08, HD01_VD11, HD01_VD12,HD01_VD13, HD01_VD14, HD01_VD15)/HD01_VD01;
%end;
%if &tblid=B25001 %then %do; &_siteabbr._ACS_HOUSES_N=HD01_VD01; %end;
/*%if &tblid=B19057 %then %do;*/
if geocode ne '08';
/*%end;*/
run;


*select state QA data from American Factfinder data was selected;
data colorado_ACS_&ACS_YEAR.
(keep=geocode state county tract blockgp block

/*keep vars derived from American Factfinder data was selected (e.g. B01001)*/
%if &tblid=B01001 %then %do;
&_siteabbr._ACS_Total_Pop &_siteabbr._ACS_under18pop &_siteabbr._ACS_18overpop &_siteabbr._ACS_25overpop &_siteabbr._ACS_65overpop Residents_65
%end;
%if &tblid=B01001A %then %do;&_siteabbr._ACS_Total_Pop_WH %end;
%if &tblid=B01001B %then %do;&_siteabbr._ACS_Total_Pop_BA %end;
%if &tblid=B01001C %then %do;&_siteabbr._ACS_Total_Pop_IN %end;
%if &tblid=B01001D %then %do;&_siteabbr._ACS_Total_Pop_AS %end;
%if &tblid=B01001E %then %do;&_siteabbr._ACS_Total_Pop_HP %end;
%if &tblid=B01001F %then %do;&_siteabbr._ACS_Total_Pop_OT %end;
%if &tblid=B01001G %then %do;&_siteabbr._ACS_Total_Pop_MU %end;
%if &tblid=B01001H %then %do;&_siteabbr._ACS_Total_Pop_NHWH %end;
%if &tblid=B01001I %then %do;&_siteabbr._ACS_Total_Pop_HS %end;
%if &tblid=B01002 %then %do; medage %end;
%if &tblid=B15002 %then %do; education1-education8 %end;
%if &tblid=B19113 %then %do; medfamincome %end;
%if &tblid=B19001 %then %do; housincome1-housincome16 %end;
%if &tblid=B17026 %then %do; 
pov_lt_50 pov_50_74 pov_75_99 pov_100_124 pov_125_149 pov_150_174 pov_175_184 pov_185_199 pov_gt_200;
%end;
%if &tblid=B16007 %then %do;
English_Speaker Spanish_Speaker
%end;
%if &tblid=B05001 %then %do; BornInUS %end;
%if &tblid=B07001 %then %do; MovedInLast12Mon %end;
%if &tblid=B12001 %then %do;
Married Divorced
%end;
%if &tblid=C18108 %then %do; Disability %end;
%if &tblid=B23001 %then %do;
Unemployment Unemployment_Male
%end;
%if &tblid=C27006 %then %do; Ins_Medicare %end;
%if &tblid=C27007 %then %do; Ins_Medicaid %end;
%if &tblid=B08201 %then %do;
HH_NoCar
%end;
%if &tblid=B19057 %then %do;
HH_Public_Assistance 
%end;
%if &tblid=B25091 %then %do;
Hmowner_costs_mort Hmowner_costs_no_mort
%end;
%if &tblid=B25077 %then %do; Homes_medvalue %end;
%if &tblid=B25014 %then %do; Pct_crowding %end;
%if &tblid=B25115 %then %do; Female_Head_of_HH %end;
%if &tblid=C24040 %then %do;
MGR_Female MGR_Male
%end;
%if &tblid=B25026 %then %do; Same_residence %end;
%if &tblid=B25001 %then %do; &_siteabbr._ACS_HOUSES_N %end;
)
;
set census.Census_demog_&ACS_YEAR.;
if state='08' /*and blockgp ne ' '*/;
run;

data tracts (drop=state county tract blockgp block);
set colorado_ACS_&ACS_YEAR.;
if tract ne ' ' and (blockgp=' ' and block=' ');
run; 

*should be completely equal;
/*ods pdf file="&qadata.\QA Check of Colorado Census Tract ACS &ACS_YEAR. Estimates for TBLID &tblid..PDF";*/
title1 "PROC COMPARE OF VDW CENSUS DEMOG Colorado ACS &ACS_YEAR. data to American Factfinder Downloaded CSV Data";
%if &tblid.=B01001 %then %do; title2 "&tblid. - SEX BY AGE"; %end;
%if &tblid.=B01001A %then %do; title2 "&tblid. - SEX BY AGE (WHITE ALONE)"; %end;
%if &tblid.=B01001B %then %do; title2 "&tblid. - SEX BY AGE (BLACK OR AFRICAN AMERICAN ALONE)"; %end;
%if &tblid.=B01001C %then %do; title2 "&tblid. - SEX BY AGE (AMERICAN INDIAN AND ALASKA NATIVE ALONE)"; %end;
%if &tblid.=B01001D %then %do; title2 "&tblid. - SEX BY AGE (ASIAN ALONE)"; %end;
%if &tblid.=B01001E %then %do; title2 "&tblid. - SEX BY AGE (NATIVE HAWAIIAN AND OTHER PACIFIC ISLANDER ALONE)"; %end;
%if &tblid.=B01001F %then %do; title2 "&tblid. - SEX BY AGE (SOME OTHER RACE ALONE)"; %end;
%if &tblid.=B01001G %then %do; title2 "&tblid. - SEX BY AGE (TWO OR MORE RACES)"; %end;
%if &tblid.=B01001H %then %do; title2 "&tblid. - (WHITE ALONE, NOT HISPANIC OR LATINO)"; %end;
%if &tblid.=B01001I %then %do; title2 "&tblid. - SEX BY AGE (HISPANIC OR LATINO)"; %end;

%if &tblid.=B01002 %then %do; title2 "&tblid. - MEDIAN AGE BY SEX"; %end;
%if &tblid.=B15002 %then %do; title2 "&tblid. - SEX BY EDUCATIONAL ATTAINMENT FOR THE POPULATION 25 YEARS AND OVER"; %end;
%if &tblid.=B19113 %then %do; title2 "&tblid. - MEDIAN FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)"; %end;
%if &tblid.=B17001 %then %do; title2 "&tblid. - POVERTY STATUS IN THE PAST 12 MONTHS BY SEX BY AGE"; %end;
%if &tblid.=B19013 %then %do; title2 "&tblid. - MEDIAN HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)"; %end;
%if &tblid.=B19101 %then %do; title2 "&tblid. - FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)"; %end;
%if &tblid.=B19001 %then %do; title2 "&tblid. - HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)"; %end;
%if &tblid.=B17026 %then %do; title2 "&tblid. - RATIO OF INCOME TO POVERTY LEVEL OF FAMILIES IN THE PAST 12 MONTHS"; %end;
%if &tblid.=B16007 %then %do; title2 "&tblid. - AGE BY LANGUAGE SPOKEN AT HOME FOR THE POPULATION 5 YEARS AND OVER"; %end;
%if &tblid.=B05001 %then %do; title2 "&tblid. - NATIVITY AND CITIZENSHIP STATUS IN THE UNITED STATES"; %end;
%if &tblid.=B07001 %then %do; title2 "&tblid. - GEOGRAPHICAL MOBILITY IN THE PAST YEAR BY AGE FOR CURRENT RESIDENCE IN THE UNITED STATES"; %end;
%if &tblid.=B12001 %then %do; title2 "&tblid. - SEX BY MARITAL STATUS FOR THE POPULATION 15 YEARS AND OVER"; %end;
%if &tblid.=C18108 %then %do; title2 "&tblid. - AGE BY NUMBER OF DISABILITIES"; %end;
%if &tblid.=B23001 %then %do; title2 "&tblid. - SEX BY AGE BY EMPLOYMENT STATUS FOR THE POPULATION 16 YEARS AND OVER"; %end;
%if &tblid.=C27006 %then %do; title2 "&tblid. - MEDICARE COVERAGE BY SEX BY AGE"; %end;
%if &tblid.=B08201 %then %do; title2 "&tblid. - HOUSEHOLD SIZE BY VEHICLES AVAILABLE"; %end;
%if &tblid.=B19057 %then %do; title2 "&tblid. - PUBLIC ASSISTANCE INCOME IN THE PAST 12 MONTHS FOR HOUSEHOLDS"; %end;
%if &tblid.=B25091 %then %do; title2 "&tblid. - MORTGAGE STATUS BY SELECTED MONTHLY OWNER COSTS AS A PERCENTAGE OF HOUSEHOLD INCOME IN THE PAST 12 MONTHS"; %end;
%if &tblid.=B25077 %then %do; title2 "&tblid. - MEDIAN VALUE (DOLLARS)"; %end;
%if &tblid.=B25014 %then %do; title2 "&tblid. - TENURE BY OCCUPANTS PER ROOM"; %end;
%if &tblid.=B25115 %then %do; title2 "&tblid. - TENURE BY HOUSEHOLD TYPE AND PRESENCE AND AGE OF OWN CHILDREN"; %end;
%if &tblid.=C24040 %then %do; title2 "&tblid. - SEX BY INDUSTRY FOR THE FULL-TIME, YEAR-ROUND CIVILIAN EMPLOYED POPULATION 16 YEARS AND OVER"; %end;
%if &tblid.=B01001 %then %do; title2 "&tblid. - SEX BY AGE"; %end;
%if &tblid.=B25026 %then %do; title2 "&tblid. - TOTAL POPULATION IN OCCUPIED HOUSING UNITS BY TENURE BY YEAR HOUSEHOLDER MOVED INTO UNIT"; %end;
%if &tblid.=C27007 %then %do; title2 "&tblid. - MEDICAID/MEANS-TESTED PUBLIC COVERAGE BY SEX BY AGE"; %end;
%if &tblid.=B25001 %then %do; title2 "&tblid. - NUMBER OF HOUSEHOLDS"; %end;
footnote1 "&sysdate.";
/*ods output */
/*CompareDatasets=CompDS_&tblid.*/
/*CompareVariables=CompVar_&tblid.*/
/*CompareDifferences=CompDiff_&tblid.*/
/*;*/
proc compare data=tracts compare=&tblid._EST_tracts NOVALUES BRIEF;
run;
/*ods pdf close;*/
title1;
title2;
title3;
footnote1;
%mend;

*check block group population estimates match census tract population estimates;
%macro checkpopctsblkgps;
data co_&ACS_YEAR.;
set census.census_demog_&ACS_YEAR.;
if state='08' and tract ne ' ' and blockgp=' ' and block=' ';
run;

proc sql;
create table cotracts as
select distinct state, county, tract, houses_n, 
KPCO_ACS_Total_Pop,
KPCO_ACS_under18pop,
KPCO_ACS_18overpop,
KPCO_ACS_25overpop,
KPCO_ACS_65overpop
from co_&ACS_YEAR.;
quit;

proc sql;
create table coblkgps as
select distinct state, county, tract, sum(houses_n) as houses_n, 
sum(KPCO_ACS_Total_Pop) as KPCO_ACS_Total_Pop,
sum(KPCO_ACS_under18pop) as KPCO_ACS_under18pop,
sum(KPCO_ACS_18overpop) as KPCO_ACS_18overpop,
sum(KPCO_ACS_25overpop) as KPCO_ACS_25overpop,
sum(KPCO_ACS_65overpop) as KPCO_ACS_65overpop
from census.census_demog_&ACS_YEAR.
where state='08' and tract ne ' ' and blockgp ne ' ' and block=' '
/*geocode in (select distinct geocode from cotracts)*/
group by state, county, tract;
quit;

title "&ACS_YEAR. ACS Population Estimates at Census Tracts and Block Groups";
proc compare data=cotracts compare=coblkgps NOVALUES;
run;
title;
%mend;

%macro geographycheck;
title "&ACS_YEAR. State Geography Counts";
proc freq data=census.census_demog_&ACS_YEAR.;
tables state;
format state $fips_st.;
run;
title;
%mend;

/****************************************************************************************************************************/
/*****************************************BEGIN QA PROCESSING BELOW**********************************************************/
/****************************************************************************************************************************/

ods pdf file="\\Kpco-ihr-1.ihr.or.kp.org\analytic_projects_2016\2016_Steiner_CHORDS_EX\Output\QA Processing for Colorado Census Tracts &sysdate..pdf";
/*
*ACS Vintage of Census Demog and .csv QA data downloaded;
%let ACS_YEAR=2009_2013;
%qa_processing(B01001,&ACS_YEAR.);
%qa_processing(B01001A,&ACS_YEAR.);
%qa_processing(B01001B,&ACS_YEAR.);
%qa_processing(B01001C,&ACS_YEAR.);
%qa_processing(B01001D,&ACS_YEAR.);
%qa_processing(B01001E,&ACS_YEAR.);
%qa_processing(B01001F,&ACS_YEAR.);
%qa_processing(B01001G,&ACS_YEAR.);
%qa_processing(B01001H,&ACS_YEAR.);
%qa_processing(B01001I,&ACS_YEAR.);
%qa_processing(B01002,&ACS_YEAR.);
%qa_processing(B05001,&ACS_YEAR.);
%qa_processing(B07001,&ACS_YEAR.);
%qa_processing(B08201,&ACS_YEAR.);
%qa_processing(B12001,&ACS_YEAR.);
%qa_processing(B15002,&ACS_YEAR.);
%qa_processing(B16007,&ACS_YEAR.);
%qa_processing(B17026,&ACS_YEAR.);
%qa_processing(B19057,&ACS_YEAR.);
%qa_processing(B19113,&ACS_YEAR.);
%qa_processing(B19013,&ACS_YEAR.);
%qa_processing(B19101,&ACS_YEAR.);
%qa_processing(B19001,&ACS_YEAR.);
%qa_processing(B25014,&ACS_YEAR.);
%qa_processing(B25026,&ACS_YEAR.);
%qa_processing(B25077,&ACS_YEAR.);
%qa_processing(B25091,&ACS_YEAR.);
%qa_processing(B25115,&ACS_YEAR.);
%qa_processing(C18108,&ACS_YEAR.);
%qa_processing(C24040,&ACS_YEAR.);
%qa_processing(C27006,&ACS_YEAR.);
%qa_processing(C27007,&ACS_YEAR.);
%qa_processing(B23001,&ACS_YEAR.); 
%checkpopctsblkgps;
%geographycheck;

%let ACS_YEAR=2010_2014;
%qa_processing(B01001,&ACS_YEAR.);
%qa_processing(B01001A,&ACS_YEAR.);
%qa_processing(B01001B,&ACS_YEAR.);
%qa_processing(B01001C,&ACS_YEAR.);
%qa_processing(B01001D,&ACS_YEAR.);
%qa_processing(B01001E,&ACS_YEAR.);
%qa_processing(B01001F,&ACS_YEAR.);
%qa_processing(B01001G,&ACS_YEAR.);
%qa_processing(B01001H,&ACS_YEAR.);
%qa_processing(B01001I,&ACS_YEAR.);
%qa_processing(B01002,&ACS_YEAR.);
%qa_processing(B05001,&ACS_YEAR.);
%qa_processing(B07001,&ACS_YEAR.);
%qa_processing(B08201,&ACS_YEAR.);
%qa_processing(B12001,&ACS_YEAR.);
%qa_processing(B15002,&ACS_YEAR.);
%qa_processing(B16007,&ACS_YEAR.);
%qa_processing(B17026,&ACS_YEAR.);
%qa_processing(B19057,&ACS_YEAR.);
%qa_processing(B19113,&ACS_YEAR.);
%qa_processing(B19013,&ACS_YEAR.);
%qa_processing(B19101,&ACS_YEAR.);
%qa_processing(B19001,&ACS_YEAR.);
%qa_processing(B25014,&ACS_YEAR.);
%qa_processing(B25026,&ACS_YEAR.);
%qa_processing(B25077,&ACS_YEAR.);
%qa_processing(B25091,&ACS_YEAR.);
%qa_processing(B25115,&ACS_YEAR.);
%qa_processing(C18108,&ACS_YEAR.);
%qa_processing(C24040,&ACS_YEAR.);
%qa_processing(C27006,&ACS_YEAR.);
%qa_processing(C27007,&ACS_YEAR.);
%qa_processing(B23001,&ACS_YEAR.);
%checkpopctsblkgps;
%geographycheck;

%let ACS_YEAR=2011_2015;
%qa_processing(B01001,&ACS_YEAR.);
%qa_processing(B01001A,&ACS_YEAR.);
%qa_processing(B01001B,&ACS_YEAR.);
%qa_processing(B01001C,&ACS_YEAR.);
%qa_processing(B01001D,&ACS_YEAR.);
%qa_processing(B01001E,&ACS_YEAR.);
%qa_processing(B01001F,&ACS_YEAR.);
%qa_processing(B01001G,&ACS_YEAR.);
%qa_processing(B01001H,&ACS_YEAR.);
%qa_processing(B01001I,&ACS_YEAR.);
%qa_processing(B01002,&ACS_YEAR.);
%qa_processing(B05001,&ACS_YEAR.);
%qa_processing(B07001,&ACS_YEAR.);
%qa_processing(B08201,&ACS_YEAR.);
%qa_processing(B12001,&ACS_YEAR.);
%qa_processing(B15002,&ACS_YEAR.);
%qa_processing(B16007,&ACS_YEAR.);
%qa_processing(B17001,&ACS_YEAR.);
%qa_processing(B17026,&ACS_YEAR.);
%qa_processing(B19057,&ACS_YEAR.);
%qa_processing(B19113,&ACS_YEAR.); *missmatch with geocode but ok- black field for that census tract;
%qa_processing(B19013,&ACS_YEAR.); *missmatch with geocode;
%qa_processing(B19101,&ACS_YEAR.);
%qa_processing(B19001,&ACS_YEAR.);
%qa_processing(B25014,&ACS_YEAR.);
%qa_processing(B25026,&ACS_YEAR.);
%qa_processing(B25077,&ACS_YEAR.); *missmatch with geocode;
%qa_processing(B25091,&ACS_YEAR.);
%qa_processing(B25115,&ACS_YEAR.);
%qa_processing(C18108,&ACS_YEAR.);
%qa_processing(C24040,&ACS_YEAR.);
%qa_processing(C27006,&ACS_YEAR.);
%qa_processing(C27007,&ACS_YEAR.);
%qa_processing(B23001,&ACS_YEAR.);
%checkpopctsblkgps;
%geographycheck;
*/
%let ACS_YEAR=2012_2016;
%qa_processing(B25001,&ACS_YEAR.);
%qa_processing(B01001,&ACS_YEAR.);
%qa_processing(B01001A,&ACS_YEAR.);
%qa_processing(B01001B,&ACS_YEAR.);
%qa_processing(B01001C,&ACS_YEAR.);
%qa_processing(B01001D,&ACS_YEAR.);
%qa_processing(B01001E,&ACS_YEAR.);
%qa_processing(B01001F,&ACS_YEAR.);
%qa_processing(B01001G,&ACS_YEAR.);
%qa_processing(B01001H,&ACS_YEAR.);
%qa_processing(B01001I,&ACS_YEAR.);
%qa_processing(B01002,&ACS_YEAR.);
%qa_processing(B05001,&ACS_YEAR.);
%qa_processing(B07001,&ACS_YEAR.);
%qa_processing(B08201,&ACS_YEAR.);
%qa_processing(B12001,&ACS_YEAR.);
%qa_processing(B15002,&ACS_YEAR.);
%qa_processing(B16007,&ACS_YEAR.);
%qa_processing(B17001,&ACS_YEAR.);
%qa_processing(B17026,&ACS_YEAR.);
%qa_processing(B19057,&ACS_YEAR.);
%qa_processing(B19113,&ACS_YEAR.); *2015 missmatch with geocode but ok- black field for that census tract;
%qa_processing(B19013,&ACS_YEAR.); *2015 missmatch with geocode;
%qa_processing(B19101,&ACS_YEAR.);
%qa_processing(B19001,&ACS_YEAR.);
%qa_processing(B25014,&ACS_YEAR.);
%qa_processing(B25026,&ACS_YEAR.);
%qa_processing(B25077,&ACS_YEAR.); *2015 missmatch with geocode;
%qa_processing(B25091,&ACS_YEAR.);
%qa_processing(B25115,&ACS_YEAR.);
%qa_processing(C18108,&ACS_YEAR.);
%qa_processing(C24040,&ACS_YEAR.);
%qa_processing(C27006,&ACS_YEAR.);
%qa_processing(C27007,&ACS_YEAR.);
%qa_processing(B23001,&ACS_YEAR.);
%checkpopctsblkgps;
%geographycheck;
ods pdf close;
*/
/****************************************************************************************************************************/
/****************************************************************************************************************************/
/****************************************************************************************************************************/
/*
%let ACS_YEAR=2011_2015;
proc sql;
create table loc_no_demog_&ACS_YEAR. as
select *
from &_vdw_census_loc
where not geocode in (select distinct geocode from census.Census_demog_&ACS_YEAR.);
quit;

data loc_no_demog_&ACS_YEAR.;
set loc_no_demog_&ACS_YEAR.;
state=substr(geocode,1,2);
format state $fips_st.;
run;

proc freq data=loc_no_demog_&ACS_YEAR.;
tables state;
run;

proc freq data=census.Census_demog_&ACS_YEAR.;
tables state;
format state $fips_st.;
run;

/* PROC FREQ DATA=_INTERIM.CENSUS2010; */
/* tables state; */
/* format state $fips_st.; */
/* run; */
/*  */
/* data share.census_demog_2009_2013; */
/* retain CENSUS_YEAR CENSUS_DATA_SRC GEOCODE STATE COUNTY TRACT BLOCKGP BLOCK ZIP EDUCATION1-EDUCATION8 */
/* 	   MEDFAMINCOME FAMINCOME1-FAMINCOME16 FAMPOVERTY MEDHOUSINCOME HOUSINCOME1-HOUSINCOME16 */
/* 	   HOUSPOVERTY POV_LT_50 POV_50_74 POV_75_99 POV_100_124 POV_125_149 POV_150_174 POV_175_184 POV_185_199 */
/* 	   POV_GT_200 RA_NHS_WH RA_NHS_BL RA_NHS_AM RA_NHS_AS RA_NHS_HA RA_NHS_OT RA_NHS_ML RA_HIS_WH RA_HIS_BL */
/* 	   RA_HIS_AM RA_HIS_AS RA_HIS_HA RA_HIS_OT RA_HIS_ML HOUSES_N HOUSES_OCCUPIED HOUSES_OWN HOUSES_RENT */
/* 	   HOUSES_UNOCC_FORRENT HOUSES_UNOCC_FORSALE HOUSES_UNOCC_RENTSOLD HOUSES_UNOCC_SEASONAL HOUSES_UNOCC_MIGRANT HOUSES_UNOCC_OTHER */
/* 	   ENGLISH_SPEAKER SPANISH_SPEAKER BORNINUS MOVEDINLAST12MON MARRIED DIVORCED DISABILITY UNEMPLOYMENT UNEMPLOYMENT_MALE */
/* 	   INS_MEDICARE INS_MEDICAID HH_NOCAR HH_PUBLIC_ASSISTANCE HMOWNER_COSTS_MORT HMOWNER_COSTS_NO_MORT HOMES_MEDVALUE */
/* 	   PCT_CROWDING FEMALE_HEAD_OF_HH MGR_FEMALE MGR_MALE RESIDENTS_65 SAME_RESIDENCE */
/* 	   &_siteabbr._ACS_Total_Pop &_siteabbr._ACS_under18pop &_siteabbr._ACS_18overpop &_siteabbr._ACS_25overpop &_siteabbr._ACS_65overpop  */
/* 	   &_siteabbr._ACS_WH &_siteabbr._ACS_BA &_siteabbr._ACS_IN &_siteabbr._ACS_AS &_siteabbr._ACS_HP &_siteabbr._ACS_OT &_siteabbr._ACS_MU &_siteabbr._ACS_NHWH &_siteabbr._ACS_HS */
/* 	   &_siteabbr._geolevel  */
/* ; */
/* set census.census_demog_2009_2013; */
/* CENSUS_DATA_SRC="CENSUS 2010/ACS 2009-2013"; */
/* run; */
/*  */
/* data share.census_demog_2010_2014; */
/* retain CENSUS_YEAR CENSUS_DATA_SRC GEOCODE STATE COUNTY TRACT BLOCKGP BLOCK ZIP EDUCATION1-EDUCATION8 */
/* 	   MEDFAMINCOME FAMINCOME1-FAMINCOME16 FAMPOVERTY MEDHOUSINCOME HOUSINCOME1-HOUSINCOME16 */
/* 	   HOUSPOVERTY POV_LT_50 POV_50_74 POV_75_99 POV_100_124 POV_125_149 POV_150_174 POV_175_184 POV_185_199 */
/* 	   POV_GT_200 RA_NHS_WH RA_NHS_BL RA_NHS_AM RA_NHS_AS RA_NHS_HA RA_NHS_OT RA_NHS_ML RA_HIS_WH RA_HIS_BL */
/* 	   RA_HIS_AM RA_HIS_AS RA_HIS_HA RA_HIS_OT RA_HIS_ML HOUSES_N HOUSES_OCCUPIED HOUSES_OWN HOUSES_RENT */
/* 	   HOUSES_UNOCC_FORRENT HOUSES_UNOCC_FORSALE HOUSES_UNOCC_RENTSOLD HOUSES_UNOCC_SEASONAL HOUSES_UNOCC_MIGRANT HOUSES_UNOCC_OTHER */
/* 	   ENGLISH_SPEAKER SPANISH_SPEAKER BORNINUS MOVEDINLAST12MON MARRIED DIVORCED DISABILITY UNEMPLOYMENT UNEMPLOYMENT_MALE */
/* 	   INS_MEDICARE INS_MEDICAID HH_NOCAR HH_PUBLIC_ASSISTANCE HMOWNER_COSTS_MORT HMOWNER_COSTS_NO_MORT HOMES_MEDVALUE */
/* 	   PCT_CROWDING FEMALE_HEAD_OF_HH MGR_FEMALE MGR_MALE RESIDENTS_65 SAME_RESIDENCE */
/* 	   &_siteabbr._ACS_Total_Pop &_siteabbr._ACS_under18pop &_siteabbr._ACS_18overpop &_siteabbr._ACS_25overpop &_siteabbr._ACS_65overpop  */
/* 	   &_siteabbr._ACS_WH &_siteabbr._ACS_BA &_siteabbr._ACS_IN &_siteabbr._ACS_AS &_siteabbr._ACS_HP &_siteabbr._ACS_OT &_siteabbr._ACS_MU &_siteabbr._ACS_NHWH &_siteabbr._ACS_HS  */
/* 	   &_siteabbr._geolevel */
/* ; */
/* set census.census_demog_2010_2014; */
/* CENSUS_DATA_SRC="CENSUS 2010/ACS 2010-2014"; */
/* run; */
/*  */
/* data share.census_demog_2011_2015; */
/* retain CENSUS_YEAR CENSUS_DATA_SRC GEOCODE STATE COUNTY TRACT BLOCKGP BLOCK ZIP EDUCATION1-EDUCATION8 */
/* 	   MEDFAMINCOME FAMINCOME1-FAMINCOME16 FAMPOVERTY MEDHOUSINCOME HOUSINCOME1-HOUSINCOME16 */
/* 	   HOUSPOVERTY POV_LT_50 POV_50_74 POV_75_99 POV_100_124 POV_125_149 POV_150_174 POV_175_184 POV_185_199 */
/* 	   POV_GT_200 RA_NHS_WH RA_NHS_BL RA_NHS_AM RA_NHS_AS RA_NHS_HA RA_NHS_OT RA_NHS_ML RA_HIS_WH RA_HIS_BL */
/* 	   RA_HIS_AM RA_HIS_AS RA_HIS_HA RA_HIS_OT RA_HIS_ML HOUSES_N HOUSES_OCCUPIED HOUSES_OWN HOUSES_RENT */
/* 	   HOUSES_UNOCC_FORRENT HOUSES_UNOCC_FORSALE HOUSES_UNOCC_RENTSOLD HOUSES_UNOCC_SEASONAL HOUSES_UNOCC_MIGRANT HOUSES_UNOCC_OTHER */
/* 	   ENGLISH_SPEAKER SPANISH_SPEAKER BORNINUS MOVEDINLAST12MON MARRIED DIVORCED DISABILITY UNEMPLOYMENT UNEMPLOYMENT_MALE */
/* 	   INS_MEDICARE INS_MEDICAID HH_NOCAR HH_PUBLIC_ASSISTANCE HMOWNER_COSTS_MORT HMOWNER_COSTS_NO_MORT HOMES_MEDVALUE */
/* 	   PCT_CROWDING FEMALE_HEAD_OF_HH MGR_FEMALE MGR_MALE RESIDENTS_65 SAME_RESIDENCE */
/* 	   &_siteabbr._ACS_Total_Pop &_siteabbr._ACS_under18pop &_siteabbr._ACS_18overpop &_siteabbr._ACS_25overpop &_siteabbr._ACS_65overpop  */
/* 	   &_siteabbr._ACS_WH &_siteabbr._ACS_BA &_siteabbr._ACS_IN &_siteabbr._ACS_AS &_siteabbr._ACS_HP &_siteabbr._ACS_OT &_siteabbr._ACS_MU &_siteabbr._ACS_NHWH &_siteabbr._ACS_HS  */
/* 	   &_siteabbr._geolevel */
/* ; */
/* set census.census_demog_2011_2015; */
/* CENSUS_DATA_SRC="CENSUS 2010/ACS 2011-2015"; */
/* run; */

data share.census_demog_2012_2016;
retain CENSUS_YEAR CENSUS_DATA_SRC GEOCODE STATE COUNTY TRACT BLOCKGP BLOCK ZIP EDUCATION1-EDUCATION8
	   MEDFAMINCOME FAMINCOME1-FAMINCOME16 FAMPOVERTY MEDHOUSINCOME HOUSINCOME1-HOUSINCOME16
	   HOUSPOVERTY POV_LT_50 POV_50_74 POV_75_99 POV_100_124 POV_125_149 POV_150_174 POV_175_184 POV_185_199
	   POV_GT_200 RA_NHS_WH RA_NHS_BL RA_NHS_AM RA_NHS_AS RA_NHS_HA RA_NHS_OT RA_NHS_ML RA_HIS_WH RA_HIS_BL
	   RA_HIS_AM RA_HIS_AS RA_HIS_HA RA_HIS_OT RA_HIS_ML HOUSES_N HOUSES_OCCUPIED HOUSES_OWN HOUSES_RENT
	   HOUSES_UNOCC_FORRENT HOUSES_UNOCC_FORSALE HOUSES_UNOCC_RENTSOLD HOUSES_UNOCC_SEASONAL HOUSES_UNOCC_MIGRANT HOUSES_UNOCC_OTHER
	   ENGLISH_SPEAKER SPANISH_SPEAKER BORNINUS MOVEDINLAST12MON MARRIED DIVORCED DISABILITY UNEMPLOYMENT UNEMPLOYMENT_MALE
	   INS_MEDICARE INS_MEDICAID HH_NOCAR HH_PUBLIC_ASSISTANCE HMOWNER_COSTS_MORT HMOWNER_COSTS_NO_MORT HOMES_MEDVALUE
	   PCT_CROWDING FEMALE_HEAD_OF_HH MGR_FEMALE MGR_MALE RESIDENTS_65 SAME_RESIDENCE
	   &_siteabbr._ACS_Total_Pop &_siteabbr._ACS_under18pop &_siteabbr._ACS_18overpop &_siteabbr._ACS_25overpop &_siteabbr._ACS_65overpop 
	   &_siteabbr._ACS_WH &_siteabbr._ACS_BA &_siteabbr._ACS_IN &_siteabbr._ACS_AS &_siteabbr._ACS_HP &_siteabbr._ACS_OT &_siteabbr._ACS_MU &_siteabbr._ACS_NHWH &_siteabbr._ACS_HS 
	   &_siteabbr._ACS_Total_Pop_AS &_siteabbr._ACS_Total_Pop_BA &_siteabbr._ACS_Total_Pop_HP &_siteabbr._ACS_Total_Pop_HS &_siteabbr._ACS_Total_Pop_IN &_siteabbr._ACS_Total_Pop_MU 
	   &_siteabbr._ACS_Total_Pop_NHWH &_siteabbr._ACS_Total_Pop_OT &_siteabbr._ACS_Total_Pop_WH 
	   &_siteabbr._ACS_female18overpop &_siteabbr._ACS_female25overpop &_siteabbr._ACS_female65overpop &_siteabbr._ACS_femaleunder18pop 
	   &_siteabbr._ACS_male18overpop &_siteabbr._ACS_male25overpop &_siteabbr._ACS_male65overpop &_siteabbr._ACS_maleunder18pop
	   &_siteabbr._ACS_HOUSES_N &_siteabbr._geolevel
;
set census.census_demog_2012_2016;
CENSUS_DATA_SRC="CENSUS 2010/ACS 2012-2016";
run;

data share.chords_census_demog_2012_2016
(rename=(&_siteabbr._ACS_Total_Pop=CHORDS_ACS_Total_Pop) 
rename=(&_siteabbr._ACS_under18pop=CHORDS_ACS_under18pop)
rename=(&_siteabbr._ACS_18overpop=CHORDS_ACS_18overpop) 
rename=(&_siteabbr._ACS_25overpop=CHORDS_ACS_25overpop)
rename=(&_siteabbr._ACS_65overpop=CHORDS_ACS_65overpop) 
rename=(&_siteabbr._ACS_WH=CHORDS_ACS_WH) 
rename=(&_siteabbr._ACS_BA=CHORDS_ACS_BA) 
rename=(&_siteabbr._ACS_IN=CHORDS_ACS_IN) 
rename=(&_siteabbr._ACS_AS=CHORDS_ACS_AS) 
rename=(&_siteabbr._ACS_HP=CHORDS_ACS_HP) 
rename=(&_siteabbr._ACS_OT=CHORDS_ACS_OT) 
rename=(&_siteabbr._ACS_MU=CHORDS_ACS_MU) 
rename=(&_siteabbr._ACS_NHWH=CHORDS_ACS_NHWH) 
rename=(&_siteabbr._ACS_HS=CHORDS_ACS_HS) 
rename=(&_siteabbr._ACS_HOUSES_N=CHORDS_ACS_HOUSES_N) 
rename=(&_siteabbr._geolevel=CHORDS_geolevel)
rename=(&_siteabbr._ACS_Total_Pop_AS=CHORDS_ACS_Total_Pop_AS) 
rename=(&_siteabbr._ACS_Total_Pop_BA=CHORDS_ACS_Total_Pop_BA) 
rename=(&_siteabbr._ACS_Total_Pop_HP=CHORDS_ACS_Total_Pop_HP) 
rename=(&_siteabbr._ACS_Total_Pop_HS=CHORDS_ACS_Total_Pop_HS) 
rename=(&_siteabbr._ACS_Total_Pop_IN=CHORDS_ACS_Total_Pop_IN) 
rename=(&_siteabbr._ACS_Total_Pop_MU=CHORDS_ACS_Total_Pop_MU) 
rename=(&_siteabbr._ACS_Total_Pop_NHWH=CHORDS_ACS_Total_Pop_NHWH) 
rename=(&_siteabbr._ACS_Total_Pop_OT=CHORDS_ACS_Total_Pop_OT) 
rename=(&_siteabbr._ACS_Total_Pop_WH=CHORDS_ACS_Total_Pop_WH) 
rename=(&_siteabbr._ACS_female18overpop=CHORDS_ACS_female18overpop) 
rename=(&_siteabbr._ACS_female25overpop=CHORDS_ACS_female25overpop) 
rename=(&_siteabbr._ACS_female65overpop=CHORDS_ACS_female65overpop) 
rename=(&_siteabbr._ACS_femaleunder18pop=CHORDS_ACS_femaleunder18pop) 
rename=(&_siteabbr._ACS_male18overpop=CHORDS_ACS_male18overpop) 
rename=(&_siteabbr._ACS_male25overpop=CHORDS_ACS_male25overpop) 
rename=(&_siteabbr._ACS_male65overpop=CHORDS_ACS_male65overpop) 
rename=(&_siteabbr._ACS_maleunder18pop=CHORDS_ACS_maleunder18pop)
);
set share.census_demog_2012_2016;
run;

proc contents data=share.chords_census_demog_2012_2016;
run;

proc contents data=share.census_demog_2012_2016;
run;

data share.census_demog_2012_2016CTonly;
set share.census_demog_2012_2016;
if KPCO_GEOLEVEL='TRACT';
run;

proc contents data=share.census_demog_2012_2016CTonly;
run;

/* proc sql; */
/* select count(distinct geocode) */
/* from share.census_demog_2012_2016CTonly */
/* where state='08' and county='031'; */
/* quit; */

*VDW Census Demog;
ods package(ProdOutput) open nopf;

ods package(ProdOutput) 
	add file="&censusroot.\Data\For Export\Final Census Demographics Tables\census_demog_2012_2016.SAS7BDAT"
	;
ods package(ProdOutput) 
	add file="&censusroot.\Data\For Export\Final Census Demographics Tables\census_demog_2012_2016CTonly.SAS7BDAT"
	;
ods package(ProdOutput) 
    publish archive        
       properties
      (archive_name=  
                  "census_demog_2012_2016.zip"       
       archive_path="&censusroot.\Data\For Export\Final Census Demographics Tables\");
ods package(ProdOutput) close;

*CHORDS VDW Census Demog;
ods package(ProdOutput) open nopf;

ods package(ProdOutput) 
	add file="&censusroot.\Data\For Export\Final Census Demographics Tables\chords_census_demog_2012_2016.SAS7BDAT"
	;
ods package(ProdOutput) 
    publish archive        
       properties
      (archive_name=  
                  "CHORDS_census_demog_2012_2016.zip"       
       archive_path="&censusroot.\Data\For Export\Final Census Demographics Tables\");
ods package(ProdOutput) close;
proc printto; run;
