/**************************************************
  Christopher Mack
  2013.12.02

  Updated 2016.11.01
  David Tabano
  david.c.tabano@kp.org
  303-636-2449

  Download unpack and read the American Community Survey data.
  N.b., this program requires a large amount of space in the work directory.
  Then merge this data with the already created Census file.

  Download three files first.
  From ftp://ftp2.census.gov/acs2011_5yr/summaryfile/2007-2011_ACSSF_All_In_2_Giant_Files(Experienced-Users-Only)/
    1. 2011_ACS_Geography_Files.zip
    2. Tracts_Block_Groups_Only.tar.gz (download this one overnight)
  From ftp://ftp2.census.gov/acs2011_5yr/summaryfile/
    3. &seq_ref_table..sas7bdat
  All 3 must be in the temporary directory specified below.

  Outstanding issues:
    1. MGR_Female and MGR_Male include "Professional, scientific, and technical services."
       Unclear if we want to do that.
    2. Disability, Ins_Medicaid, and Ins_Medicare underlying data does not exist in 5 year estimates.
    3. Unemployment_Male denominator is defined as whole population (not just males).
    4. I may want to download ZCTA-level information in the future.
****************************************************/

/******** STEP 1- Download ACS_5yr_Seq_Table_Number_Lookup.sas7bdat from FTP location for the ACS Vintage of interest*************/

/******** STEP 2- Complete Edit Section*******************************************************************************************/
/* EDIT SECTION */
options mlogic mprint symbolgen;
%LET census_year = 2010;
/*ACS Vintage*/
*%LET ACS_YEAR = 2009_2013;
%LET ACS_YEAR = 2012_2016;

%LET codehome = \\Kpco-ihr-1.ihr.or.kp.org\analytic_projects_2016\2016_Steiner_CHORDS_EX\Data\VDW_Census_Demographics\ACS_&ACS_YEAR.;



%LET location_7zipa = \\rmlhofile001\users\M426654\7za\;
/*%LET location_7zip = \\rmlhofile001\users\M426654\7-Zip\;*/
%LET location_7zFM='C:\Program Files\7-Zip\7z.exe';

%LET location_curl = \\rmlhofile001.co.kp.org\users\M426654\curl;

/* Location of Census FTP server. */
*2013;
/*%LET ftp_location = ftp://ftp2.census.gov/acs2013_5yr/summaryfile/2009-2013_ACSSF_All_In_2_Giant_Files(Experienced-Users-Only);*/

*2016;
/*%LET ftp_location = ftp://ftp2.census.gov/programs-surveys/acs/summary_file/2015/data/5_year_entire_sf/;*/
%LET ftp_location = ftp://ftp2.census.gov/programs-surveys/acs/summary_file/2016/data/5_year_entire_sf/;


*NOTE depending on folder structure from ACS Downloads, may need to manually change extraction calls to map to correct folder heirarchy;


*for extraction of text files;
%let txtyr=2016;

/*%let seq_ref_table=SequenceNumberTableNumberLookup;*/
%let seq_ref_table=ACS_5yr_Seq_Table_Number_Lookup;


/*%LET acs_geo_name = 2013_ACS_Geography_Files.zip;*/
/*%LET acs_geo_name = 2014_ACS_Geography_Files.zip;*/
/*%LET acs_geo_name = 2015_ACS_Geography_Files.zip;*/
%LET acs_geo_name = 2016_ACS_Geography_Files.zip;

%LET acs_tract_block_name = Tracts_Block_Groups_Only.tar.gz;

/* END EDIT SECTION */

proc printto log="&codehome.\logs\Annual Read &ACS_YEAR. ACS 5yr data &sysdate..log" new; run;


*double-check all of these paths after the files are downloaded;
%LET download_dir = &CODEHOME.\Download_ACS_&ACS_YEAR.;
%LET temp_dir     = &CODEHOME.\temp;
%LET zipgeo       = &DOWNLOAD_DIR.\&ACS_GEO_NAME.;
%LET zipseg       = &DOWNLOAD_DIR.\&ACS_TRACT_BLOCK_NAME.;
libname _dload "&DOWNLOAD_DIR.";
libname _temp "&TEMP_DIR.";
libname _interim "&codehome.\interim";
libname _output "&CODEHOME.\output";

%put NOTE: Path to Zip files should be &zipgeo.;

%put NOTE: Path to Tar files should be &zipseg.;

options noxwait xsync mlogic mprint symbolgen noerrorabend compress=yes;

%macro downloadacs (table);

  %LET status = incomplete;
  /*
    %window getproxy
       #5 @5 'You must be authenticated before you can use the proxy server'
       #6 @5 'to download the necessary files from the Census FTP site.'
      #10 @5 'Please enter your userid:'
      #10 @32 id 30 attr=underline required=yes
      #12 @5 'And your password:'
      #12 @32 pass 50 attr=underline display=no required=yes
      #17 @5 'Then press [Enter].'
      #20 @5 "(Don't worry, I won't save your password.)";

    %display getproxy delete;
  */

  %LET _zip_location = &ftp_location./&table.;
  %LET _dl_dir = &DOWNLOAD_DIR.\&table.;
  /*    %LET _file_list = %STR(&_STATE_ABBR.)geo2010.sf1 %STR(&_STATE_ABBR.)000032010.sf1 %STR(&_STATE_ABBR.)000442010.sf1;*/

  /*  Attempt to read the file.
      If it returns an HTML message indicating a proxy error, try again up to 25 times. */
  filename attempt "&_DL_DIR.";
  %LET attempt_number = 0;

  /* Download from Census.gov FTP */

  %put &LOCATION_CURL.;
  %put &_ZIP_LOCATION.;
  %put &_DL_DIR.;
      %DOWNLOAD:
        options nomprint;
  x "&LOCATION_CURL.\curl.exe &_ZIP_LOCATION. --output &_DL_DIR. --verbose";

  FILENAME ftpfrom ftp "&_zip_location" host="&ftp_location";

  %LET attempt_number = &ATTEMPT_NUMBER. + 1;
  %LET fid            = %SYSFUNC(fopen(attempt));
  %LET size           = %SYSFUNC(finfo(&FID., File Size (bytes)));
  %PUT &fid.;
  %IF &SIZE. < 2000 %THEN %DO;
    %PUT NOTE:  Unable to download &table.. I will try again in 30 seconds.;
    %PUT Current time is %SYSFUNC(time(), time.);
    data _null_;
      slept = sleep(10, 5); /* Sleep for 30 seconds at a time */
    run;
    %LET fid = %SYSFUNC(fclose(&FID.));
    %IF &ATTEMPT_NUMBER. < 5 %THEN %DO;
      %GOTO download;
    %END;
    %ELSE %DO;
      %PUT ERROR:  I failed to download &table. data 5 consecutive times.;
      %PUT ERROR:  I will now quit.  Try again later.  Best of luck to you.;
      %GOTO exit;
    %END;
  %END;
  %LET fid = %SYSFUNC(fclose(&FID.));

  %PUT NOTE:  Downloaded the state of &table.;
  %PUT NOTE: The package for &ACS_GEO_NAME. contains &_FILE_LIST.;
%mend downloadacs;


/*%downloadacs (&ACS_GEO_NAME.);*/
/*%downloadacs (&acs_tract_block_name.);*/


/* Find the files that need to be uncompressed by looking up the required tables in &seq_ref_table. */
/* Enter the tables being used in the datalines below.                                                              */
/* N.b., there are a few tables that span multiple segments.  Fortunately we're not using them.                     */
/* But that's why the multilabel option (hlo 'M') is enabled.                                                       */
/* (Hint: It appears the first 5 characters of the ACS field number identify the table.)                            */
/* C18101 (disability) unavailable in ACS 2009-2013- replaced with C18108                     */
/* C27006 (Medicare) adn C27007 (Medicaid) now available                              */

/*****2009-2013 ACS 5YR TBLIDS*****
B15002 - SEX BY EDUCATIONAL ATTAINMENT FOR THE POPULATION 25 YEARS AND OVER
B19113 - MEDIAN FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
B17001 - POVERTY STATUS IN THE PAST 12 MONTHS BY SEX BY AGE
B19013 - MEDIAN HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
B19101 - FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
B19001 - HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)
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
B01001 - SEX BY AGE
B25026 - TOTAL POPULATION IN OCCUPIED HOUSING UNITS BY TENURE BY YEAR HOUSEHOLDER MOVED INTO UNIT
C27007 - MEDICAID/MEANS-TESTED PUBLIC COVERAGE BY SEX BY AGE

added to get race/ethinicty estimates from ACS
B01001A - SEX BY AGE (WHITE ALONE)
B01001B - SEX BY AGE (BLACK OR AFRICAN AMERICAN ALONE)
B01001C - SEX BY AGE (AMERICAN INDIAN AND ALASKA NATIVE ALONE)
B01001D - SEX BY AGE (ASIAN ALONE)
B01001E - SEX BY AGE (NATIVE HAWAIIAN AND OTHER PACIFIC ISLANDER ALONE)
B01001F - SEX BY AGE (SOME OTHER RACE ALONE)
B01001G - SEX BY AGE (TWO OR MORE RACES)
B01001H - SEX BY AGE (WHITE ALONE, NOT HISPANIC OR LATINO)
B01001I - SEX BY AGE (HISPANIC OR LATINO)

B01002 - MEDIAN AGE BY SEX
****************************/


/* 2009-2013, 2010-2014, 2011-2015, 2012-2016 ACS 5YR*/
data tables;
  length table $7.;
  input table $ @@;
  datalines;
B15002 B19113 B17001 B19013 B19013 B19101 B19001 B17026
B16007 B05001 B07001 B12001 C18108 B23001 C27006 B08201
B19057 B25091 B25077 B25014 B25115 C24040 B01001 B25026
B25001 C27007 B01002 B01001A B01001B B01001C B01001D B01001E
B01001F B01001G B01001H B01001I
;
run;

/*proc sort data=_dload.&seq_ref_table.(keep=tblid seq) nodupkey*/
proc sort data=_dload.&seq_ref_table.(keep=tblid seq) nodupkey
  out = SequenceNumberTableNumberLookup;
  by seq tblid;
run;

data fmt;
  set SequenceNumberTableNumberLookup;
  retain fmtname '$TableLookup' type 'c' hlo 'M';
  rename tblid=start seq=label;
run;

proc format cntlin=fmt;
run;

data tables_looked_up;
  set tables;
  file = put(table, $TableLookup.);
  if anyalpha(file) then do;
    put "WARNING: Sequence Lookup Error:";
    put "WARNING:  Table " table " did not have a sequence number.";
    put "WARNING:  No file will be downloaded.";
  end;
  else output;
run;

proc sort data=tables_looked_up(keep=file) nodupkey; by file; run;

*check you have all the fields you need;
proc sql;
create table sequence_check as
select *
from _dload.&seq_ref_table.
where tblid in (select distinct table from tables);
quit;

/* Extract just the CSV formats of the geography files.  They're smaller. */
%LET geo_output = &TEMP_DIR.\acs_&ACS_YEAR._geo_output;
libname geotest "&geo_output";

options mlogic mprint symbolgen xwait;

%MACRO read_geography_files();

  %IF %SYSFUNC(fileexist("&GEO_OUTPUT.")) = 0 %THEN %DO;
    x "mkdir &GEO_OUTPUT.";
  %END;
  /*  x "&LOCATION_7ZIP.\7za.exe e &ZIPGEO. geo\*.csv -o&GEO_OUTPUT.";*/
  /*  x "&LOCATION_7ZIP.\7z.exe e &ZIPGEO. tab4\sumfile\prod\2009thru2013\geo\*.csv -o&GEO_OUTPUT.";*/
  /*  x "&LOCATION_7ZIP.\7za e &ZIPGEO. *.csv -o&GEO_OUTPUT.";*/
  /*  x "&LOCATION_7ZIP.\7z e &ZIPGEO. geo\*.csv -o&GEO_OUTPUT.";*/
  x "&location_7zFM e &ZIPGEO. geo\*.csv -o&GEO_OUTPUT.";

  filename dirlist pipe "dir /B ""&GEO_OUTPUT.\*.csv""";
  data directory_list;
    length file_name $256.;
    infile dirlist length=reclen truncover;
    input file_name $varying256. reclen;
    if index(file_name, 'g20165us') then delete;
  run;

  data _temp.acs_&ACS_YEAR._geo_all(compress=yes);
    set directory_list;
    length geolevel $6.;
    filepath = "&GEO_OUTPUT.\" || file_name;
    infile dummy filevar=filepath length=reclen end=done missover dsd;
    length fileid $6. stusab $2. sumlevel $3. component $2. logrecno $7. us region division $1.
      statece state $2. county $3. cousub $5. place $5. tract $6. blockgp $1.;
    /* Read each file through the directory pipe */
    do while(not(done));
      input fileid stusab sumlevel component logrecno us region division
        statece state county cousub place tract blockgp;
      if sumlevel in ('140', '150') then do;
        if sumlevel = '140' then geolevel = "Tract";
        else if sumlevel = '150' then geolevel = "BlkGrp";
        output;
      end;
    end;
    keep logrecno state county tract blockgp;
  run;

  proc sort data=_temp.acs_&ACS_YEAR._geo_all; by state logrecno; run;

%MEND read_geography_files ;

/* %read_geography_files(); */




/* Extract just the 20 required files (from the 220 or so) for each of the 51 states/districts */
%LET seg_output = &TEMP_DIR.\acs_&ACS_YEAR._seg_output;
options xwait;
%MACRO extract_segment_files();
  %global UNZIP_LIST;
  %IF %SYSFUNC(fileexist("&SEG_OUTPUT.")) = 0 %THEN %DO;
    x "mkdir &SEG_OUTPUT.";
  %END;

  /* Create a wildcard pattern that will recursively include (-ir) only the segments identified above */
  %LET unzip_list = ;
  data _null_;
    set tables_looked_up end=done;
    length file_list_so_far $32000.;
    retain file_list_so_far;
    if _n_ = 1 then         file_list_so_far ="-ir!e&txtyr.5*" || file || "000.txt";
    else                    file_list_so_far = trim(file_list_so_far) || " -ir!e&txtyr.5*" || file || "000.txt";
    if done then call symput('UNZIP_LIST', trim(file_list_so_far));
  run;

  %put NOTE: unzipping files &UNZIP_LIST. from &ZIPSEG. to output location &SEG_OUTPUT.;
  /** Ungzip the file to standard output (-so) then untar through standard input (-si)   **/
  /** 7za x -so file.tar.gz | 7z l -si --ttar will list the contents of file.tar.gz file **/

  /*%sysexec("&LOCATION_7ZIP.\7z" e -so "&ZIPSEG." -y| "&LOCATION_7ZIP.\7z" e -si -ttar &UNZIP_LIST -o"&SEG_OUTPUT." -y);*/
  /*%sysexec("&LOCATION_7ZIP.7z" e -so "&ZIPSEG." -y| "&LOCATION_7ZIP.7z" e -si -ttar &UNZIP_LIST -o"&SEG_OUTPUT." -y);*/
  %sysexec("C:\Program Files\7-Zip\7z.exe" e -so "&ZIPSEG." -y| "C:\Program Files\7-Zip\7z.exe" e -si -ttar &UNZIP_LIST -o"&SEG_OUTPUT." -y);


  /*can't read the specific list with 64-bit laptop and 32-bit 7zip, so need to extract everything*/
  /*%sysexec("&LOCATION_7ZIP.\7z" e -so "&ZIPSEG." | "&LOCATION_7ZIP.\7z" e -si -ttar -o"&SEG_OUTPUT.");*/

%MEND extract_segment_files ;

/* %extract_segment_files(); */


/* From this point on the program can be run on SAS server for faster processing! */
options noxwait mlogic mprint symbolgen;
%MACRO read_segment_files();

  %PUT "Reading ACS Segments";
  proc sql noprint;
    select count(distinct(state)) into :state_count
      from _temp.acs_&ACS_YEAR._geo_all;
    select count(*) into :seg_count
      from tables_looked_up;
    select file into :seg_seq1 - :seg_seq%cmpres(&SEG_COUNT.)
      from tables_looked_up;
    create table state_list (
      file_name char(50)
    );
    %do i=1 %to %cmpres(&SEG_COUNT.);
    create table state_list&i.
    (file_name char(50));
    delete from state_list&i.;  /* Clear the list of states (unnecessary if this program is run from scratch) */
    %end;

    delete from state_list; /* Clear the list of states (unnecessary if this program is run from scratch) */
    create table acs_segment_merge_check (
      state     char(2),
      segment   char(4),
      match     num(8),
      geo_only  num(8),
      seg_only  num(8)
    );
  quit;

  %LET _state_abbr_list = al ak az ar ca co ct de dc fl ga hi id il in ia ks ky la me md ma mi
    mn ms mo mt ne nv nh nj nm ny nc nd oh ok or pa ri sc sd tn tx ut vt va wa wv wi wy pr;
  proc format;
    value $fips_xwalk
      'al'='01' 'ak'='02' 'az'='04' 'ar'='05' 'ca'='06' 'co'='08' 'ct'='09' 'de'='10' 'dc'='11'
      'fl'='12' 'ga'='13' 'hi'='15' 'id'='16' 'il'='17' 'in'='18' 'ia'='19' 'ks'='20' 'ky'='21'
      'la'='22' 'me'='23' 'md'='24' 'ma'='25' 'mi'='26' 'mn'='27' 'ms'='28' 'mo'='29' 'mt'='30'
      'ne'='31' 'nv'='32' 'nh'='33' 'nj'='34' 'nm'='35' 'ny'='36' 'nc'='37' 'nd'='38' 'oh'='39'
      'ok'='40' 'or'='41' 'pa'='42' 'ri'='44' 'sc'='45' 'sd'='46' 'tn'='47' 'tx'='48' 'ut'='49'
      'vt'='50' 'va'='51' 'wa'='53' 'wv'='54' 'wi'='55' 'wy'='56' 'pr'='72';
  run;

  %DO s = 1 %TO &SEG_COUNT.;        /* Outer loop:  each segment (file) */
    %LET seg_name = &&SEG_SEQ&S.;
    /* Generate the input & label statements for each segment */
    proc sql noprint;
      create table selected_infile_lines as (
        select tblid, order, tranwrd(title, "'", "''") as label from _dload.&seq_ref_table.
        where seq = "&SEG_NAME." and not(missing(order)) and order = int(order)
      );
      create table selected_title_lines as (
        select tblid, tranwrd(title, "'", "''") as label_prefix from _dload.&seq_ref_table.
        where seq = "&SEG_NAME." and not(missing(position))
      );
      select  cats(I.tblid, put(order, z3.)),
              cats(I.tblid, put(order, z3.), "='", label_prefix, ": ", label, "'")
        into  :input_list separated by " ",
              :label_list separated by " "
        from selected_infile_lines I, selected_title_lines T
        where I.tblid = T.tblid;
    quit;

    %DO st = 1 %TO &STATE_COUNT.;   /* Inner loop:  each state - generate list of input files*/
  /*    TESTING ON COLORADO ONLY*/
  /*    %DO st = 06 %TO 06;   /* Inner loop:  each state - generate list of input files */*/;
      %LET state_abbr = %SCAN(&_STATE_ABBR_LIST., &ST.);
      proc sql;
        insert into state_list /*This doesn't work- keep for posterity, but use code below*/
          set file_name = "e&txtyr.5&STATE_ABBR.&SEG_NAME.000.txt";
      quit;

      proc sql;
  /*      delete from state_list&S.;  */
        insert into state_list&S.  /*Try creating the state_list specific to the sequence you're on*/
          set file_name = "e&txtyr.5&STATE_ABBR.&SEG_NAME.000.txt";
      quit;
    %END;

    data acs_segno_&S.(compress=yes);
  /*  dct   set state_list;*/
    set state_list&S.; /*dct edit*/
      filepath = "&SEG_OUTPUT.\" || file_name;
      infile dummy filevar=filepath length=reclen end=done truncover dsd lrecl=3000;
      length fileid filetype $6. stusab state $2. chariter $3. sequence $4. logrecno $7.;
      do while(not(done));
        input fileid filetype stusab chariter sequence logrecno &INPUT_LIST.;
        state = put(stusab, $fips_xwalk.);
        output;
      end;
      drop file_name fileid filetype stusab chariter sequence;
      label &LABEL_LIST.;
    run;

    proc sort data=acs_segno_&S.; by state logrecno; run;

    proc sort data=_temp.acs_&ACS_YEAR._geo_all; by state logrecno; run;

    data acs_geo_segno_&S.(compress=yes) geo_only segno_only;
      %IF &S. = 1 %THEN %DO;
        merge _temp.acs_&ACS_YEAR._geo_all(in=g) acs_segno_&S.(in=s);
      %END;
      %ELSE %DO;
        merge acs_geo_segno_%EVAL(&S.-1)(in=g) acs_segno_&S.(in=s);
      %END;
      by state logrecno;
      if g and s then output acs_geo_segno_&S.;
        else if g then output geo_only;
        else if s then output segno_only;
    run;

    * Delete the current segment file and
      previous merged file to conserve disk space;
    proc datasets library=work noprint;
      delete acs_segno_&S. acs_geo_segno_%EVAL(&S.-1);
    run;

    %LET dsid       = %SYSFUNC(open(acs_geo_segno_&S., in));
    %LET nobs_match = %SYSFUNC(attrn(&dsid, nobs));
    %LET dsid       = %SYSFUNC(open(geo_only, in));
    %LET nobs_geo   = %SYSFUNC(attrn(&dsid, nobs));
    %LET dsid       = %SYSFUNC(open(segno_only, in));
    %LET nobs_seg   = %SYSFUNC(attrn(&dsid, nobs));
    %IF &DSID. > 0 %THEN %LET rc = %SYSFUNC(close(&DSID.));
    %IF &DSID. > 0 %THEN %LET rc = %SYSFUNC(close(&DSID.));
    %IF &DSID. > 0 %THEN %LET rc = %SYSFUNC(close(&DSID.));
    proc sql noprint;
      insert into acs_segment_merge_check
        set state    = "&STATE_ABBR.",
            segment  = "&SEG_NAME.",
            match    = &NOBS_MATCH.,
            geo_only = &NOBS_GEO.,
            seg_only = &NOBS_SEG.;
    quit;

  %END;

  /*  proc sort data=acs_geo_segno_%cmpres(&SEG_COUNT.) nodupkey;*/
  /*  by logrecno state county tract;*/
  /*  run;*/

  data _temp.acs_&ACS_YEAR._all(compress=yes);
    length geocode $15.;
    set acs_geo_segno_%cmpres(&SEG_COUNT.);
    geocode = cats(state, county, tract, blockgp);
    /* Create the calculated variables */
  /*B01001 - SEX BY AGE*/
    if missing(B01001001)=0 then do;
      &_siteabbr._ACS_Total_Pop        = B01001001;
      &_siteabbr._ACS_maleunder18pop   = sum(B01001003,B01001004,B01001005,B01001006);
      &_siteabbr._ACS_femaleunder18pop = sum(B01001027, B01001028, B01001029, B01001030);
      &_siteabbr._ACS_under18pop       = sum(B01001003,B01001004,B01001005,B01001006,B01001027, B01001028, B01001029, B01001030);
      &_siteabbr._ACS_male18overpop    = sum(B01001007,B01001008,B01001009,B01001010,B01001011,B01001012,B01001013, B01001014,B01001015,B01001016,B01001017,B01001018,B01001019,B01001020,B01001021,B01001022,B01001023,B01001024,B01001025);
      &_siteabbr._ACS_female18overpop  = sum(B01001031,B01001032,B01001033,B01001034,B01001035,B01001036,B01001037, B01001038,B01001039,B01001040,B01001041,B01001042,B01001043,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
      &_siteabbr._ACS_18overpop        = sum(B01001007,B01001008,B01001009,B01001010,B01001011,B01001012,B01001013,B01001014,B01001015,B01001016,B01001017,B01001018,B01001019, B01001020,B01001021,B01001022,B01001023,B01001024,B01001025,B01001031,B01001032,B01001033,B01001034,B01001035,B01001036,B01001037, B01001038,B01001039,B01001040,B01001041,B01001042,B01001043,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
      &_siteabbr._ACS_male25overpop    = sum(B01001011,B01001012,B01001013,B01001014,B01001015,B01001016,B01001017,B01001018,B01001019, B01001020,B01001021,B01001022,B01001023,B01001024,B01001025);
      &_siteabbr._ACS_female25overpop  = sum(B01001035,B01001036,B01001037, B01001038,B01001039,B01001040,B01001041,B01001042,B01001043,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
      &_siteabbr._ACS_25overpop        = sum(B01001011,B01001012,B01001013,B01001014,B01001015,B01001016,B01001017,B01001018,B01001019, B01001020,B01001021,B01001022,B01001023,B01001024,B01001025,B01001035,B01001036,B01001037,B01001038,B01001039,B01001040,B01001041,B01001042,B01001043,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
      &_siteabbr._ACS_male65overpop    = sum(B01001020,B01001021,B01001022,B01001023,B01001024,B01001025);
      &_siteabbr._ACS_female65overpop  = sum(B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
      &_siteabbr._ACS_65overpop        = sum(B01001020,B01001021,B01001022,B01001023,B01001024,B01001025,B01001044,B01001045,B01001046,B01001047,B01001048,B01001049);
    end;

  /*B01001A - SEX BY AGE (WHITE ALONE)*/
    if missing(B01001A001)=0 then do;
    &_siteabbr._ACS_Total_Pop_WH=B01001A001;
    &_siteabbr._ACS_WH=B01001A001/B01001001;
    end;

  /*B01001B - SEX BY AGE (BLACK OR AFRICAN AMERICAN ALONE)*/
    if missing(B01001B001)=0 then do;
    &_siteabbr._ACS_Total_Pop_BA=B01001B001;
    &_siteabbr._ACS_BA=B01001B001/B01001001;
    end;

  /*B01001C - SEX BY AGE (AMERICAN INDIAN AND ALASKA NATIVE ALONE)*/
    if missing(B01001C001)=0 then do;
    &_siteabbr._ACS_Total_Pop_IN=B01001C001;
    &_siteabbr._ACS_IN=B01001C001/B01001001;
    end;

  /*B01001D - SEX BY AGE (ASIAN ALONE)*/
    if missing(B01001D001)=0 then do;
    &_siteabbr._ACS_Total_Pop_AS=B01001D001;
    &_siteabbr._ACS_AS=B01001D001/B01001001;
    end;

  /*B01001E - SEX BY AGE (NATIVE HAWAIIAN AND OTHER PACIFIC ISLANDER ALONE)*/
    if missing(B01001E001)=0 then do;
    &_siteabbr._ACS_Total_Pop_HP=B01001E001;
    &_siteabbr._ACS_HP=B01001E001/B01001001;
    end;

  /*B01001F - SEX BY AGE (SOME OTHER RACE ALONE)*/
    if missing(B01001F001)=0 then do;
    &_siteabbr._ACS_Total_Pop_OT=B01001F001;
    &_siteabbr._ACS_OT=B01001F001/B01001001;
    end;

  /*B01001G - SEX BY AGE (TWO OR MORE RACES)*/
    if missing(B01001G001)=0 then do;
    &_siteabbr._ACS_Total_Pop_MU=B01001G001;
    &_siteabbr._ACS_MU=B01001G001/B01001001;
    end;

  /*B01001H - SEX BY AGE (WHITE ALONE, NOT HISPANIC OR LATINO)*/
    if missing(B01001H001)=0 then do;
    &_siteabbr._ACS_Total_Pop_NHWH=B01001H001;
    &_siteabbr._ACS_NHWH=B01001H001/B01001001;
    end;

  /*B01001I - SEX BY AGE (HISPANIC OR LATINO)*/
    if missing(B01001I001)=0 then do;
    &_siteabbr._ACS_Total_Pop_HS=B01001I001;
    &_siteabbr._ACS_HS=B01001I001/B01001001;
    end;

  /*B01002 - MEDIAN AGE BY SEX*/
    if missing(B01002001)=0 then medage= B01002001;

  /*B15002 - SEX BY EDUCATIONAL ATTAINMENT FOR THE POPULATION 25 YEARS AND OVER*/
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

  /*B19113 - MEDIAN FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)*/
    medfamincome = B19113001;

  /*B19101 - FAMILY INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)*/
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

  /*B19013 - MEDIAN HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)*/
    medhousincome = B19013001;

  /*B19001 - HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2013 INFLATION-ADJUSTED DOLLARS)*/
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

  /* B17001- POVERTY STATUS IN THE PAST 12 MONTHS BY SEX BY AGE*/
    if B17001001 then do;
      FAMPOVERTY=B17001002/B17001001;
    end;

  /*B17026 - RATIO OF INCOME TO POVERTY LEVEL OF FAMILIES IN THE PAST 12 MONTHS*/
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
      HOUSPOVERTY = B17026004/B17026001;
    end;

  /*B16007 - AGE BY LANGUAGE SPOKEN AT HOME FOR THE POPULATION 5 YEARS AND OVER*/
    if B16007001 then do;
      English_Speaker = sum(B16007003, B16007009, B16007015)/B16007001;
      Spanish_Speaker = sum(B16007004, B16007010, B16007016)/B16007001;
    end;

  /*B05001 - NATIVITY AND CITIZENSHIP STATUS IN THE UNITED STATES*/
    if B05001001 then BornInUS = (B05001002/B05001001);

  /*B07001 - GEOGRAPHICAL MOBILITY IN THE PAST YEAR BY AGE FOR CURRENT RESIDENCE IN THE UNITED STATES*/
    if B07001001 then MovedInLast12Mon = 1 - (B07001017/B07001001);

  /*B12001 - SEX BY MARITAL STATUS FOR THE POPULATION 15 YEARS AND OVER*/
    if B12001001 then do;
      Married = sum(B12001004, B12001013)/B12001001;
      Divorced = sum(B12001010, B12001019)/B12001001;
    end;

  /*C18108 - AGE BY NUMBER OF DISABILITIES*/
     if not(missing(sum(C18108006, C18108009/*, C18108016, C18108019*/))) then
      Disability = sum(C18108007, C18108008, C18108011, C18108012)/sum(C18108006, C18108009, C18108013);

  /*B23001 - SEX BY AGE BY EMPLOYMENT STATUS FOR THE POPULATION 16 YEARS AND OVER*/
    if B23001001 then do;
      Unemployment = sum(B23001008, B23001015, B23001022, B23001029, B23001036, B23001043, B23001050, B23001057,
        B23001064, B23001071, B23001076, B23001081, B23001086, B23001094, B23001101, B23001108, B23001115,
        B23001122, B23001129, B23001136, B23001143, B23001150, B23001157, B23001162, B23001167, B23001172)/B23001001;
      /* There's been some talk about whether the denominator should be
          total population (B23001001) or total males (B23001002) */
      Unemployment_Male = sum(B23001008, B23001015, B23001022, B23001029, B23001036, B23001043, B23001050, B23001057,
        B23001064, B23001071, B23001076, B23001081, B23001086)/B23001002;
    end;

  /*C27006 - MEDICARE COVERAGE BY SEX BY AGE*/
     if C27006001 then
      Ins_Medicare = sum(C27006004, C27006007, C27006010, C27006014, C27006017, C27006020)/C27006001;
     if C27007001 then
      Ins_Medicaid = sum(C27007004, C27007007, C27007010, C27007014, C27007017, C27007020)/C27007001;

  /*B08201 - HOUSEHOLD SIZE BY VEHICLES AVAILABLE*/
    if B08201001 then HH_NoCar = B08201002/B08201001;
    if B19057001 then HH_Public_Assistance = B19057002/B19057001;
    if B25091001 then do;
      Hmowner_costs_mort = B25091011/B25091001;
      Hmowner_costs_no_mort = B25091022/B25091001;
    end;

  /*B25077 - MEDIAN VALUE (DOLLARS)*/
    Homes_medvalue = B25077001;

  /*B25014 - TENURE BY OCCUPANTS PER ROOM*/
    if B25014001 then
      Pct_crowding = sum(B25014005, B25014006, B25014007, B25014011, B25014012, B25014013)/B25014001;

  /*B25115 - TENURE BY HOUSEHOLD TYPE AND PRESENCE AND AGE OF OWN CHILDREN*/
    if B25115001 then
      Female_Head_of_HH = sum(B25115011, B25115024)/B25115001;

  /*C24040 - SEX BY INDUSTRY FOR THE FULL-TIME, YEAR-ROUND CIVILIAN EMPLOYED POPULATION 16 YEARS AND OVER*/
    if C24040001 then do;
      MGR_Female = sum(C24040046, C24040045)/C24040001;
      MGR_Male = sum(C24040019, C24040018)/C24040001;
    end;

  /*B01001 - SEX BY AGE*/
    if B01001001 then
      Residents_65 = sum(B01001020, B01001021, B01001022, B01001023, B01001024, B01001025, B01001044,
        B01001045, B01001046, B01001047, B01001048, B01001049)/B01001001;

  /*B25026 - TOTAL POPULATION IN OCCUPIED HOUSING UNITS BY TENURE BY YEAR HOUSEHOLDER MOVED INTO UNIT*/
    if B25026001 then
      Same_residence = sum(B25026004, B25026005, B25026006, B25026007, B25026008, B25026011, B25026012,
        B25026013, B25026014, B25026015)/B25026001;
  /* B25001 - HOUSING UNITS */
    if B25001001 then
    &_siteabbr._ACS_HOUSES_N = B25001001;

    keep state county tract blockgp
      &_siteabbr._ACS_Total_Pop &_siteabbr._ACS_under18pop &_siteabbr._ACS_maleunder18pop &_siteabbr._ACS_femaleunder18pop
      &_siteabbr._ACS_18overpop &_siteabbr._ACS_male18overpop &_siteabbr._ACS_female18overpop
      &_siteabbr._ACS_25overpop &_siteabbr._ACS_male25overpop &_siteabbr._ACS_female25overpop
      &_siteabbr._ACS_65overpop &_siteabbr._ACS_male65overpop &_siteabbr._ACS_female65overpop
      &_siteabbr._ACS_Total_Pop_WH &_siteabbr._ACS_WH &_siteabbr._ACS_Total_Pop_BA &_siteabbr._ACS_BA &_siteabbr._ACS_Total_Pop_AS &_siteabbr._ACS_AS
      &_siteabbr._ACS_Total_Pop_HP &_siteabbr._ACS_HP
      &_siteabbr._ACS_Total_Pop_IN &_siteabbr._ACS_IN &_siteabbr._ACS_Total_Pop_NHWH &_siteabbr._ACS_NHWH &_siteabbr._ACS_Total_Pop_HS &_siteabbr._ACS_HS
      &_siteabbr._ACS_Total_Pop_MU &_siteabbr._ACS_MU &_siteabbr._ACS_Total_Pop_OT &_siteabbr._ACS_OT &_siteabbr._ACS_HOUSES_N
      education1-education8 medfamincome famincome1-famincome16 fampoverty
      medhousincome housincome1-housincome16 pov: HOUSPOVERTY english_speaker spanish_speaker borninus
      movedinlast12mon married divorced disability unemployment unemployment_male ins_medicare
      ins_medicaid hh_nocar hh_public_assistance hmowner_costs_mort hmowner_costs_no_mort
      homes_medvalue pct_crowding female_head_of_hh mgr_female mgr_male residents_65 same_residence;
    run;

%MEND read_segment_files ;

%read_segment_files();


footnote "Let's double check all this";
title "ACS Records by State";
proc freq data=_temp.acs_&ACS_YEAR._all;
  tables state;
run;

title "ACS Geo-Segment Matches";
proc print data=acs_segment_merge_check;
run;



options nomlogic nomprint nosymbolgen;

%macro extremes(table, var);
  proc sql noprint;
    create table &var._ext_hi as
    select *, input(blockgp,best12.) as block_group, input(tract,best12.) as tract_num
    from &table
    where &var.>1;
  quit;

  %let DSID  = %sysfunc(open(&var._ext_hi, IS));
  %let anobs = %sysfunc(attrn(&DSID, NOBS));
  %let rc    = %sysfunc(close(&DSID));
  %IF %eval(&anobs. = 0) %THEN %do;
    %put NOTE: There are no high extreme values > 1 for &var.;
  %end;
  %else %do;
    proc sql noprint;
      select sum(block_group) into:blockgpvalues from &var._ext_hi;
      select sum(tract_num) into:tractvalues from &var._ext_hi;
    quit;
    %if %eval(&blockgpvalues>.) %then %do;
      %put WARNING: Extreme high values for &var. in blockgroups;
    %end;
    title "Review distribution of var=&var. for extreme values";
    proc univariate data=&table.;
      var &var.;
      histogram;
    run;
    title;
    %if %eval(&tractvalues>.) %then %do;
      %put WARNING: Extreme high values for &var. in census tracts;
    %end;
    title "Review distribution of var=&var. for extreme values";
    proc univariate data=&table.;
      var &var.;
      histogram;
    run;
    title;
    %if %eval(&blockgpvalues>.) and %eval(&tractvalues>.) %then %do;
      %put WARNING: Extreme high values for &var. in county level;
    %end;
    title "Review distribution of var=&var. for extreme values";
    proc univariate data=&table.;
      var &var.;
      histogram;
    run;
    title;
    %let rc=%sysfunc(close(&DSID));
  %end;

  proc sql noprint;
    create table &var._ext_lo as
    select *, input(blockgp,best12.) as block_group, input(tract,best12.) as tract_num
    from &table
    where 0>&var.>.;
  quit;

  %let DSID  = %sysfunc(open(&var._ext_lo, IS));
  %let anobs = %sysfunc(attrn(&DSID, NOBS));
  %let rc    = %sysfunc(close(&DSID));
  %IF %eval(&anobs. = 0) %THEN %do;
    %put NOTE: There are no low extreme values between . and 0 for &var.;
  %end;
  %else %do;
    proc sql noprint;
      select sum(block_group) into:blockgpvalues from &var._ext_lo;
      select sum(tract_num) into:tractvalues from &var._ext_lo;
    quit;
    %if %eval(0>&blockgpvalues>.) %then %do;
      %put WARNING: Extreme low values for &var. in blockgroups;
    %end;
    title "Review distribution of var=&var. for extreme values";
    proc univariate data=&table.;
      var &var.;
      histogram;
    run;
    title;
    %if %eval(0>&tractvalues>.) %then %do;
      %put WARNING: Extreme low values for &var. in census tracts;
    %end;
    title "Review distribution of var=&var. for extreme values";
    proc univariate data=&table.;
      var &var.;
      histogram;
    run;
    title;
    %if %eval(0>&blockgpvalues>.) and %eval(&tractvalues>.) %then %do;
      %put WARNING: Extreme low values for &var. in county level;
    %end;
    title "Review distribution of var=&var. for extreme values";
    proc univariate data=&table.;
      var &var.;
      histogram;
    run;
    title;
    %let rc=%sysfunc(close(&DSID));
  %end;
%mend extremes ;


data _temp.acs_&ACS_YEAR._all;
  set _temp.acs_&ACS_YEAR._all;
  block=' ';
run;

* Knit together the Census and ACS Files to create the Census Demog file.;

* 1. Merge ACS estimates to Census estimates at blockgp level.;
proc sort data=_interim.census&CENSUS_YEAR.; by state county tract blockgp block; run;
proc sort data=_temp.acs_&ACS_YEAR._all; by state county tract blockgp block; run;

data match_blockgp census_bg_only acs_bg_only;
  merge _interim.census&CENSUS_YEAR.(in=c where=(not(missing(blockgp))))
        _temp.acs_&ACS_YEAR._all(in=a where=(not(missing(blockgp))));
  by state county tract blockgp block;
  if c then output match_blockgp;
  /*  if c and a then output match_blockgp;*/
  /*    else if c then output census_bg_only;*/
    else if a then output acs_bg_only;
run;

* 2. Merge ACS estimates to Census estimates at tract level.;
data match_tract census_tract_only acs_tract_only;
  merge _interim.census&CENSUS_YEAR.(in=c where=(not(missing(tract)) and missing(blockgp)))
        _temp.acs_&ACS_YEAR._all(in=a where=(not(missing(tract)) and missing(blockgp)));
  by state county tract;
  if c and a then output match_tract;
    else if c then output census_tract_only;
    else if a then output acs_tract_only;
run;

data _output.census_demog_&ACS_YEAR.;
  set match_tract match_blockgp;
run;

*Update format of KPCO_ACS_HOUSES_N for QA;
data _output.census_demog_&ACS_YEAR.(drop=KPCO_ACS_HOUSES_N rename=(KPCO_ACS_HOUSES_N2=KPCO_ACS_HOUSES_N));
  set _output.census_demog_&ACS_YEAR.;
  KPCO_ACS_HOUSES_N2=max(KPCO_ACS_HOUSES_N,0);
run;

proc sort data=_output.census_demog_&ACS_YEAR. nodupkey; by geocode; run;

proc sql;
  create index geocode on _output.census_demog_&ACS_YEAR.;
  create index state on _output.census_demog_&ACS_YEAR.;
quit;

*QA numeric/calculated fields for valeus <0 or >1;
%extremes(_output.census_demog_&ACS_YEAR., Disability)
%extremes(_output.census_demog_&ACS_YEAR., Divorced)
%extremes(_output.census_demog_&ACS_YEAR., English_Speaker)
%extremes(_output.census_demog_&ACS_YEAR., FAMPOVERTY)
%extremes(_output.census_demog_&ACS_YEAR., Female_Head_of_HH)
%extremes(_output.census_demog_&ACS_YEAR., HH_NoCar)
%extremes(_output.census_demog_&ACS_YEAR., HH_Public_Assistance)
/* %extremes(_output.census_demog_&ACS_YEAR., HOUSES_N) */
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_OCCUPIED)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_OWN)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_RENT)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_UNOCC_FORRENT)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_UNOCC_FORSALE)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_UNOCC_MIGRANT)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_UNOCC_OTHER)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_UNOCC_RENTSOLD)
%extremes(_output.census_demog_&ACS_YEAR., HOUSES_UNOCC_SEASONAL)
%extremes(_output.census_demog_&ACS_YEAR., HOUSPOVERTY)
%extremes(_output.census_demog_&ACS_YEAR., Hmowner_costs_mort)
%extremes(_output.census_demog_&ACS_YEAR., Hmowner_costs_no_mort)
/* %extremes(_output.census_demog_&ACS_YEAR., Homes_medvalue) */
%extremes(_output.census_demog_&ACS_YEAR., Ins_Medicaid)
%extremes(_output.census_demog_&ACS_YEAR., Ins_Medicare)
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_18overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_25overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_65overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_AS) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_BA) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_HP) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_HS) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_IN) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_MU) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_NHWH) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_OT) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_AS) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_BA) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_HP) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_HS) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_IN) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_MU) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_NHWH) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_OT) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_Total_Pop_WH) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_WH) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_female18overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_female25overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_female65overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_femaleunder18pop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_male18overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_male25overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_male65overpop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_maleunder18pop) */
/* %extremes(_output.census_demog_&ACS_YEAR., KPCO_ACS_under18pop) */
%extremes(_output.census_demog_&ACS_YEAR., MGR_Female)
%extremes(_output.census_demog_&ACS_YEAR., MGR_Male)
%extremes(_output.census_demog_&ACS_YEAR., Married)
%extremes(_output.census_demog_&ACS_YEAR., MovedInLast12Mon)
%extremes(_output.census_demog_&ACS_YEAR., Pct_crowding)
%extremes(_output.census_demog_&ACS_YEAR., RA_HIS_AM)
%extremes(_output.census_demog_&ACS_YEAR., RA_HIS_AS)
%extremes(_output.census_demog_&ACS_YEAR., RA_HIS_BL)
%extremes(_output.census_demog_&ACS_YEAR., RA_HIS_HA)
%extremes(_output.census_demog_&ACS_YEAR., RA_HIS_ML)
%extremes(_output.census_demog_&ACS_YEAR., RA_HIS_OT)
%extremes(_output.census_demog_&ACS_YEAR., RA_HIS_WH)
%extremes(_output.census_demog_&ACS_YEAR., RA_NHS_AM)
%extremes(_output.census_demog_&ACS_YEAR., RA_NHS_AS)
%extremes(_output.census_demog_&ACS_YEAR., RA_NHS_BL)
%extremes(_output.census_demog_&ACS_YEAR., RA_NHS_HA)
%extremes(_output.census_demog_&ACS_YEAR., RA_NHS_ML)
%extremes(_output.census_demog_&ACS_YEAR., RA_NHS_OT)
%extremes(_output.census_demog_&ACS_YEAR., RA_NHS_WH)
%extremes(_output.census_demog_&ACS_YEAR., Residents_65)
%extremes(_output.census_demog_&ACS_YEAR., Same_residence)
%extremes(_output.census_demog_&ACS_YEAR., Spanish_Speaker)
%extremes(_output.census_demog_&ACS_YEAR., Unemployment)
%extremes(_output.census_demog_&ACS_YEAR., Unemployment_Male)
/* %extremes(_output.census_demog_&ACS_YEAR., ZIP) */
%extremes(_output.census_demog_&ACS_YEAR., education1)
%extremes(_output.census_demog_&ACS_YEAR., education2)
%extremes(_output.census_demog_&ACS_YEAR., education3)
%extremes(_output.census_demog_&ACS_YEAR., education4)
%extremes(_output.census_demog_&ACS_YEAR., education5)
%extremes(_output.census_demog_&ACS_YEAR., education6)
%extremes(_output.census_demog_&ACS_YEAR., education7)
%extremes(_output.census_demog_&ACS_YEAR., education8)
%extremes(_output.census_demog_&ACS_YEAR., famincome1)
%extremes(_output.census_demog_&ACS_YEAR., famincome2)
%extremes(_output.census_demog_&ACS_YEAR., famincome3)
%extremes(_output.census_demog_&ACS_YEAR., famincome4)
%extremes(_output.census_demog_&ACS_YEAR., famincome5)
%extremes(_output.census_demog_&ACS_YEAR., famincome6)
%extremes(_output.census_demog_&ACS_YEAR., famincome7)
%extremes(_output.census_demog_&ACS_YEAR., famincome8)
%extremes(_output.census_demog_&ACS_YEAR., famincome9)
%extremes(_output.census_demog_&ACS_YEAR., famincome10)
%extremes(_output.census_demog_&ACS_YEAR., famincome11)
%extremes(_output.census_demog_&ACS_YEAR., famincome12)
%extremes(_output.census_demog_&ACS_YEAR., famincome13)
%extremes(_output.census_demog_&ACS_YEAR., famincome14)
%extremes(_output.census_demog_&ACS_YEAR., famincome15)
%extremes(_output.census_demog_&ACS_YEAR., famincome16)
%extremes(_output.census_demog_&ACS_YEAR., housincome1)
%extremes(_output.census_demog_&ACS_YEAR., housincome2)
%extremes(_output.census_demog_&ACS_YEAR., housincome3)
%extremes(_output.census_demog_&ACS_YEAR., housincome4)
%extremes(_output.census_demog_&ACS_YEAR., housincome5)
%extremes(_output.census_demog_&ACS_YEAR., housincome6)
%extremes(_output.census_demog_&ACS_YEAR., housincome7)
%extremes(_output.census_demog_&ACS_YEAR., housincome8)
%extremes(_output.census_demog_&ACS_YEAR., housincome9)
%extremes(_output.census_demog_&ACS_YEAR., housincome10)
%extremes(_output.census_demog_&ACS_YEAR., housincome11)
%extremes(_output.census_demog_&ACS_YEAR., housincome12)
%extremes(_output.census_demog_&ACS_YEAR., housincome13)
%extremes(_output.census_demog_&ACS_YEAR., housincome14)
%extremes(_output.census_demog_&ACS_YEAR., housincome15)
%extremes(_output.census_demog_&ACS_YEAR., housincome16)
/* %extremes(_output.census_demog_&ACS_YEAR., kpco_geolevel) */
/* %extremes(_output.census_demog_&ACS_YEAR., medfamincome) */
/* %extremes(_output.census_demog_&ACS_YEAR., medhousincome) */
%extremes(_output.census_demog_&ACS_YEAR., pov_100_124)
%extremes(_output.census_demog_&ACS_YEAR., pov_125_149)
%extremes(_output.census_demog_&ACS_YEAR., pov_150_174)
%extremes(_output.census_demog_&ACS_YEAR., pov_175_184)
%extremes(_output.census_demog_&ACS_YEAR., pov_185_199)
%extremes(_output.census_demog_&ACS_YEAR., pov_50_74)
%extremes(_output.census_demog_&ACS_YEAR., pov_75_99)
%extremes(_output.census_demog_&ACS_YEAR., pov_gt_200)
;

proc contents data=_output.census_demog_&ACS_YEAR. short;
run;




proc printto; run;

title1 "You're Welcome" ;
proc print data = sashelp.class ;
run ;


