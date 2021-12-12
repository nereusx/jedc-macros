%
% Syntax coloring for SQL
% 
% Create : 2004-02-23
% Update : 2004-12-08
% Author : Marko Mahnic
%
% Installation:
%   * put the file in a directory on jed_library_path
%   * to your .jedrc add:
%       autoload ("sql_mode", "sql");
%       autoload ("sql92_mode", "sql");
%       autoload ("sql99_mode", "sql");
%       autoload ("mssql_mode", "sql");
%       autoload ("mysql_mode", "sql");
%       autoload ("pgsql_mode", "sql");
%       autoload ("orsql_mode", "sql");
%       add_mode_for_extension ("sql", "sql");
%
%   * Use the mode-line to choose a particular SQL varaint:
%       -*- mode: pgsql; -*-
%   
% TODO: Analyse various SQL versions and modify keyword sets

require("keywords");

% If the mode is not specified in modeline, use this mode 
% as default for .sql files
custom_variable ("sql_default_mode", "sql92");


static define CreateSyntaxTable(sqlmode)
{
   create_syntax_table(sqlmode);
   define_syntax("--", "", '%', sqlmode);
   define_syntax("/*", "*/", '%', sqlmode);
   define_syntax('"', '"', sqlmode);
   define_syntax('\'', '\'', sqlmode);
   define_syntax ('\\', '#', sqlmode);  % preprocessor
   define_syntax ("([", ")]", '(', sqlmode);
   define_syntax ("0-9a-zA-Z_", 'w', sqlmode);  % words
   define_syntax ("-+0-9.", '0', sqlmode);      % Numbers
   define_syntax (",;.?", ',', sqlmode);
   define_syntax ("%$()[]-+/*=<>^#", '+', sqlmode);
   set_syntax_flags (sqlmode, 0x01 | 0x20); % case insensitive
}


static variable kwds_common =
   "having case null when cascade order user from float procedure table close commit " +
   "only decimal create grant primary rows double delete rollback then authorization " +
   "set foreign by constraints at as escape read execute real group of language else " +
   "not or on level is alter in exists fetch session to key constraint char using unique " +
   "insert write with time declare some asc option union add any and distinct revoke " +
   "all end where dec natural transaction view schema between like character begin for " +
   "desc cursor references int update smallint check numeric work varchar column select " +
   "values drop default into integer next intersect privileges except precision ";

static variable kwds_9299 =
   "temporary table_name more c open schema_name lower cast collation collation_catalog " +
   "row_count constraint_catalog scale varying whenever scroll catalog_name goto returned_length " +
   "subclass_origin pascal output condition_number found character_set_schema diagnostics " +
   "count match datetime_interval_precision connection_name unnamed indicator names current " +
   "translation cursor_name global uncommitted sql insensitive message_octet_length input " +
   "pad number cobol character_length trailing action go pli octet_length allocate timezone_hour " +
   "section connect length system_user upper disconnect national bit_length min convert " +
   "avg server_name repeatable preserve are public data date nullif size external overlaps " +
   "column_name immediate ada exec sqlstate cascaded exception identity end-exec value " +
   "deferrable leading returned_sqlstate module datetime_interval_code session_user prior " +
   "assertion mumps position space collate connection command_function describe continue " +
   "class_origin deferred name fortran message_length serializable translate get max " +
   "partial char_length committed zone returned_octet_length dynamic_function corresponding " +
   "sum message_text character_set_name collation_schema extract constraint_schema nullable " +
   "collation_name character_set_catalog coalesce interval initially deallocate current_user " +
   "descriptor timezone_minute catalog constraint_name ";

static variable kwds_99 =
   "free blob breadth parameter_name g k m called localtime static implementation call " +
   "trigger_name transforms ignore routine completion scope transactions_rolled_back " +
   "each method system user_defined_type_catalog parameter_mode referencing transaction_active " +
   "final array user_defined_type_schema source rollup dispatch deterministic cycle checked " +
   "routine_name overriding before routine_schema current_path nclob parameter large " +
   "path invoker parameters granted than binary key_type modify sqlexception simple parameter_specific_name " +
   "hold every constructor host similar alias ordinality row contains clob infix sublist " +
   "deref reads class security ref inout without specifictype role sets atomic limit " +
   "off modifies parameter_ordinal_position depth variable preorder new mod specific_name " +
   "transactions_committed self out operation parameter_specific_catalog overlay old " +
   "assignment none locator cardinality style generated object iterate start trigger_catalog " +
   "key_member savepoint instantiable state dynamic_function_code unnest abs options " +
   "aggregate defined definer postfix search existing treat asensitive localtimestamp " +
   "structure routine_catalog trigger under grouping destroy symmetric sequence initialize " +
   "boolean specific prefix destructor sensitive command_function_code current_role hierarchy " +
   "statement less dynamic admin transform map dictionary user_defined_type_name result " +
   "instance function chain bitvar after general terminate cube equals parameter_specific_schema " +
   "return asymmetric returns sqlwarning lateral recursive trigger_schema ";

static variable kwds_92 =
   "sqlcode sqlerror ";

static variable kwds_My =
   "nosort seconds append longfile selectivity atan disable java diagnose buffer rfill " +
   "locate open dbproc backup_pages wait sapr3 tablespace lower static selupd call ucase " +
   "asin ignore resource nolog pipe cosh vargraphic timezone reject snapshot synonym " +
   "indexname optimistic dayname tabid parse fversion whenever beginload minus ifnull " +
   "range degree subtime dayofmonth logfull label sysdba microsecond costlimit writer " +
   "usergroup variance page save initrans bufferpool week least verify maxtrans nominvalue " +
   "validproc log10 sqlmode curdate inproc volume lcase next_day address switch pages " +
   "error radians alterin modify floor count fixed toidentifier sinh defaultcode dsetpass " +
   "makedate tan indicator flush event sin current lfill instr get_schema sign format " +
   "alpha hours false raw autosave weekofyear nls_date_format container psm param minutes " +
   "tape shutdown clear costwarning monthname restore freepage number proc percent initcap " +
   "standby break pi role norewind adddate same now compute ln greatest unicode editproc " +
   "atan2 ascii if nls_sort dbprocedure zoned mod block nextval expand high pctused sqrt " +
   "months_between prev trunc pos stop decode overwrite timeout num connect obid length " +
   "hextoraw upper nvl optimize true priv migrate serverdb packed substr file vsize ceiling " +
   "topic nocycle min package soundex rowno userid replication extended addtime log subpages " +
   "jis object archive nls_date_language vtrace avg to_number ceil rtrim iso days currval " +
   "subtrans savepoint public identified state data sqlid date stat cachelimit noround " +
   "rowid round db_above_limit dayofweek rownum device bad abs curtime power unload lpad " +
   "medium add_months auto concat release to_char sysdate startpos stamp while dropin " +
   "bwhierarchy div cos cot synchronize blocksize quick oracle years trace monitor mapchar " +
   "pctfree ltrim value duplicates degrees acos log_above_limit db2 beginproc ansi reuse " +
   "dba chr explicit nowait dimension medianame long caches createin mbcs list subdate " +
   "nocache estimate space normal last_day serial timediff describe to_date get_objectname " +
   "continue endload unused nlssort remove db_below_limit name utcdiff months init hex " +
   "register fact tanh dynamic exp byte translate get max new_time digits rpad low internal " +
   "instance resume stddev endproc graphic try sum info uid catch dayofyear eur standard " +
   "enable remote debug rawtohex suspend nomaxvalue usa sounds parseid nls_language cancel " +
   "varchar2 microseconds config utcdate maketime sample current_schema return datediff " +
   "ping unlock catalog logwriter takeover recursive noorder ";

static variable kwds_Ms =
   "isdate nvarchar substring atan kill top money right lower cast rowguidcol collation " +
   "month bigint atn2 asin disk parsename second setuser unknown join getansinull domain " +
   "openquery varying newid isolation scroll over save nocheck distributed host_name " +
   "current_timestamp raiserror cross inner pascal output log10 first binary radians " +
   "last app_name image freetext diagnostics floor dummy both match identitycol tan datetime " +
   "hour nchar contains sin names rule translation getutcdate sign global insensitive " +
   "input shutdown datename restore pad proc openxml percent local break no character_length " +
   "compute getdate trailing action patindex bulk octet_length sqrt offsets readtext " +
   "timezone_hour host_id system_user upper permissions rand textvalid disconnect current_date " +
   "national bit_length include lineno ceiling tran text containstable trim replication " +
   "prepare log convert timestamp minute relative preserve year textsize are charindex " +
   "bit errlvl nullif round external overlaps freetexttable usage fillfactor ada abs " +
   "holdlock power dbcc uniqueidentifier stats_date opendatasource formatmessage sqlca " +
   "outer cos cascaded cot tsequal identity clustered identity_insert ntext value deferrable " +
   "leading absolute degrees acos waitfor left session_user smallmoney day isnull print " +
   "assertion load position collate openrowset connection user_name describe reconfigure " +
   "nonclustered restrict deny deferred checksum updatetext writetext rowcount varbinary " +
   "exp translate get partial smalldatetime ident_seed char_length browse dateadd zone " +
   "current_time corresponding tinyint square extract coalesce interval initially deallocate " +
   "current_user descriptor full textptr datediff datalength sqlwarning timezone_minute " +
   "catalog ident_incr isnumeric ";

static variable kwds_Pg =
   "nocreateuser temporary encoding unlisten called localtime cast trusted bigint oids " +
   "reset copy move each stable vacuum varying scroll excluding array inherits instead " +
   "procedural stdout path invoker simple freeze match offset similar ilike defaults " +
   "encrypted names listen rule global insensitive class security notnull input without " +
   "nothing recheck limit trailing action strict overlay old sysid handler assignment " +
   "national delimiter convert volatile stdin preserve reindex characteristics nullif " +
   "validator external overlaps immediate aggregate definer forward treat localtimestamp " +
   "owner pendant toast placing deferrable leading setof valid session_user isnull prior " +
   "assertion notify position createdb conversion collate template analyse statement " +
   "deferred backward immutable serializable abort unencrypted partial committed zone " +
   "lancompiler chain delimiters extract nocreatedb createuser coalesce interval initially " +
   "location verbose deallocate current_user operator access including ";

static variable kwds_Or =
   "minvalue nosort increment maxlogmembers minextents groups online disable columns " +
   "thread tablespace share logfile colauth maxlogfiles resource manage mount each snapshot " +
   "synonym successful restricted system raise lists minus crash range referencing array " +
   "pragma resetlogs variance tabauth initrans maxextents rowlabel cycle dismount before " +
   "force maxtrans nominvalue maxloghistory initial base_table switch explain elsif subtype " +
   "modify triggers noresetlogs noarchivelog assert entry archivelog layer extent flush " +
   "row run limited delay body do rowtype raw delta controlfile partition remr exception_init " +
   "statement_id number change task scn cobol role assign storage pli cluster clusters " +
   "new mod block nextval out pctused compile offline audit stop own manual comment validate " +
   "old until reverse externally record nocycle package debugoff sqlerrm archive quota " +
   "start tables currval savepoint identified rowid exclusive rownum sort optimal mlslabel " +
   "roles compress unlimited release debugon sysdate maxinstances views under segment " +
   "nocompress pctfree form maxdatafiles pctincrease sequence binary_integer profile " +
   "number_base boolean reuse dba nowait long loop freelists parallel char_base nocache " +
   "link lock events normal cache analyze type positive dispose others datafile statement " +
   "recover freelist shared sqlbuf abort admin notfound constant digits generic maxvalue " +
   "instance stddev contents noaudit uid indexes become enable after separate nomaxvalue " +
   "xor tracing terminate exceptions cancel mode private varchar2 definition rename data_base " +
   "accept access including arraylen noorder ";

static variable kwds_9299PgMy =
   "substring right month second unknown join domain isolation current_timestamp cross " +
   "inner first last both hour nchar local no current_date trim prepare timestamp minute " +
   "relative year bit usage outer absolute left day type restrict current_time full ";

static variable kwds_PgMy =
   "minvalue increment share cycle before index force restart explain binary password " +
   "hold statistics row do version inout show off storage cluster new out comment until " +
   "none start temp exclusive replace implicit trigger database sequence boolean lock " +
   "load cache analyze maxvalue checkpoint function after truncate mode rename returns ";

static variable kwds_MsOr =
   "temporary open plan sqlcode whenever goto sqlerror index found count statistics indicator " +
   "current false sql off dump go if allocate section connect true none file min avg " +
   "public date size immediate exec exit sqlstate while trigger exception database module " +
   "prior space continue backup fortran max checkpoint sum function use truncate return ";


public define sql92_mode ()
{
   variable sql = "sql92";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_9299PgMy);
      keywords->add_keywords(K, kwds_9299);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_92);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

public define sql99_mode ()
{
   variable sql = "sql99";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_9299PgMy);
      keywords->add_keywords(K, kwds_9299);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_99);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% PostgreSql
public define pgsql_mode ()
{
   variable sql = "pgsql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_9299PgMy);
      keywords->add_keywords(K, kwds_PgMy);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_Pg);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% MySql
public define mysql_mode ()
{
   variable sql = "mysql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_9299PgMy);
      keywords->add_keywords(K, kwds_PgMy);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_My);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% MS SQL mode
public define mssql_mode ()
{
   variable sql = "mssql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_MsOr);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_Ms);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

% Oracle
public define orsql_mode ()
{
   variable sql = "orsql";
   !if (keywords->check_language(sql))
   {
      variable K;
      CreateSyntaxTable(sql);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_common);
      keywords->add_keywords(K, kwds_MsOr);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 0);
      
      K = keywords->new_keyword_list();
      keywords->add_keywords(K, kwds_Or);
      keywords->sort_keywords(K);
      keywords->define_keywords(K, sql, 1);
      
      keywords->add_language(sql);
   }

   set_mode(sql, 4);
   use_syntax_table(sql);
}

public define sql_mode ()
{
   variable mode;
   mode = sprintf("%s_mode", sql_default_mode);
   if (is_defined(mode) > 0)
      eval(mode);
   else sql92_mode();
}

