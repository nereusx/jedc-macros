% awk.sl
% 
% $Id: awk.sl,v 1.2 2005/11/19 17:14:49 paul Exp paul $
% Keywords: languages
%
% Copyright (c) 2004, 2005 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).

% Mode for editing awk sources.

provide("awk");
require("pcre");
implements("awk");

variable mode = "awk";

%{{{ syntax table

create_syntax_table (mode);
define_syntax ("#", "", '%', mode);
define_syntax ('"', '"', mode);
define_syntax ('\'', '\'', mode);
define_syntax ("([{", ")]}", '(', mode);
define_syntax ('\\', '\\', mode);
define_syntax ("0-9a-zA-Z_", 'w', mode);        % words
define_syntax ("-+0-9a-fA-F.xX", '0', mode);   % Numbers
define_syntax (";,", ',', mode);
define_syntax ("%-+/&*=<>|!~^`", '+', mode);	% operators
set_syntax_flags(mode, 0);
. mode "doifinor" 2 0
. mode "andcosexpforintlogsinsubxor" 3 0
. mode "elseexitgsubnextrandsqrt" 4 0
. mode "asortatan2breakclosecomplindexmatchprintsplitsrandwhile" 5 0
. mode "deletefflushgensublengthlshiftmktimeprintfreturnrshiftsubstrsystem" 6 0
. mode "getlinesprintfsystimetolowertoupper" 7 0
. mode "continuefunctionnextfilestrftimestrtonum" 8 0
. mode "dcgettext" 9 0
. mode "bindtextdomain" 14 0
. mode "FSNFNRRSRT" 2 1
. mode "ENDFNROFSORS" 3 1
. mode "ARGCARGVLINTOFMT" 4 1
. mode "BEGINERRNO" 5 1
. mode "ARGINDRSTARTSUBSEP" 6 1
. mode "BINMODECONVFMTENVIRONRLENGTH" 7 1
. mode "FILENAME" 8 1
. mode "IGNORECASETEXTDOMAIN" 10 1
. mode "FIELDWIDTHS" 11 1
loop (18)
    () = define_keywords_n();

#ifdef HAS_DFA_SYNTAX
%%% DFA_CACHE_BEGIN %%%
static define awk_dfa_callback (name)
{
   dfa_enable_highlight_cache(name +".dfa", name);
   dfa_define_highlight_rule("/([^/\\\\]|\\\\.)*/", "string", name);
   dfa_define_highlight_rule("#.*", "comment", name);
   dfa_define_highlight_rule("[A-Z][A-Z]*", "Knormal", name);
   dfa_define_highlight_rule("[a-z][a-z]*", "Knormal", name);
   dfa_define_highlight_rule("[A-Za-z_]+[0-9]+", "normal", name);
   dfa_define_highlight_rule("[0-9]+(\\.[0-9]*)?([Ee][\\+\\-]?[0-9]*)?",
			     "number", name);
   dfa_define_highlight_rule("0[xX][0-9A-Fa-f]*[LlUu]*", "number", name);
   dfa_define_highlight_rule("[0-9]+[LlUu]*", "number", name);
   dfa_define_highlight_rule("\"([^\"\\\\]|\\\\.)*\"", "string", name);
   dfa_define_highlight_rule("\"([^\"\\\\]|\\\\.)*\\\\?", "string", name);
   dfa_define_highlight_rule("'([^'\\\\]|\\\\.)*'", "string", name);
   dfa_define_highlight_rule("'([^'\\\\]|\\\\.)*\\\\?$", "string", name);
%   dfa_define_highlight_rule("[ \t]+", "normal", name);
   dfa_define_highlight_rule("[\\(\\[{}\\]\\),;\\?:]", "delimiter", name);
   dfa_define_highlight_rule("[%\\-\\+/&\\*=<>\\|!~\\^\\$]", "operator", name);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&awk_dfa_callback, "awk");
%%% DFA_CACHE_END %%%
#endif

%}}}
%{{{ help

variable awk_help_file = expand_jedlib_file("awk.txt");
variable awk_current_topic = "";

% syntax table for help

#ifdef HAS_DFA_SYNTAX
create_syntax_table ("awkhelp");
%%% DFA_CACHE_BEGIN %%%
static define awkhelp_dfa_callback (mode)
{
%   dfa_enable_highlight_cache(mode +".dfa", mode);
   dfa_define_highlight_rule ("`[a-z][a-z]+'", "Qkeyword0", mode);
   dfa_define_highlight_rule ("`[A-Z][A-Z]+'", "Qkeyword1", mode);
   dfa_define_highlight_rule ("\\*note", "Qkeyword0", mode);
   dfa_build_highlight_table(mode);
}
dfa_set_init_callback (&awkhelp_dfa_callback, "awkhelp");
%%% DFA_CACHE_END %%%
#endif


% from info.sl
define follow_xref ()
{
   if (looking_at("`"))
     go_right_1;
   if (blooking_at("`"))
     return help_for_word_at_point;
   !if(bfind("*note")) return;
   go_right (5); skip_chars (" \t\n");

   variable node;
   
   push_spot();
  
   !if (fsearch_char (':'))
     {
	pop_spot(); error ("Corrupt File?");
     }
   
   if (looking_at("::"))
     {
        push_mark();
        pop_spot();
        node = bufsubstr();
     }
   else
     {
        go_right_1 ();
        skip_white();
	if (eolp())
	  {
	     go_right_1 ();
	     skip_white();
	  }
        push_mark();
	if (looking_at_char('(')) () = ffind_char (')');
	skip_chars("^,\t.("); % does not skip newlines
	if (eolp) 
	  {
	     go_down_1;
	     skip_chars("^,\t.(");
	  }
	node = strcompress(bufsubstr(), " \n");
        pop_spot();
     }
   info_find_node(sprintf("(Gawk)%s", node));
}

% find next maybe awk-word or info xref
define awkhelp_next_word()
{
   while(re_fsearch("[*`][a-zA-Z]+"))
     {
	if (orelse
	    {looking_at("*note ")}
	      {looking_at("*note\n")}
	      {andelse
		   {orelse
			{re_looking_at("`[a-z]+'")}
			{re_looking_at("`[A-Z]+'")}}
		   {not(andelse
			{strlen(awk_current_topic)}
			  {looking_at(sprintf("`%s'",awk_current_topic))})}
		   {not re_looking_at("`g?awk'")}})
	  {
	     go_right_1;
	     break;
	  }
	go_right_1;
     }
}

define help_for_awk();

define awk_help_popup(h)
{
   popup_buffer("*awk help*");
   set_readonly(0);
   erase_buffer;
   insert(h);
   fit_window;
   bob;
   set_buffer_modified_flag(0);
   view_mode;
   use_syntax_table("awkhelp");
   use_dfa_syntax(1);
   local_setkey("indent_line", "\t");
   define_blocal_var("help_for_word_hook", &help_for_awk);
   set_buffer_hook("indent_hook", &awkhelp_next_word);
   set_buffer_hook ("newline_indent_hook", &follow_xref);
}

% Do a full text search on the help file and list the matching items.
% Separate multiple search keys with a space.
define awk_apropos()
{
   variable h = "";
   variable pattern = strlow(read_mini("apropos", "", ""));
   variable awk_cmd =
     "BEGIN { RS = \"\\n-+\"; split(pattern,array) } { entry=tolower($0); for (i in array) if (!(index(entry,array[i]))) next ; print \"`\" $1}";
   variable fp = popen(sprintf("awk -v pattern='%s' '%s'  %s", 
			       pattern, awk_cmd, awk_help_file), "r");
   if (fp != NULL)
#ifnexists _slang_utf8_ok
     () = fread (&h, Char_Type, 10000, fp);
#else
     () = fread_bytes (&h, 10000, fp);
#endif
   h = str_replace_all(h, "\n", "\'\n");
   () = pclose(fp);
   !if (strlen(h)) return message("No matches");
   awk_help_popup(h);
   awk_current_topic="";
}

define help_for_awk(w)
{
   variable h = "";
   if (awk_help_file == "") return message ("no helpfile found");
   h = get_doc_string_from_file(awk_help_file, w);
   if (h == NULL) return message ("Can't help you");
   awk_help_popup(h);
   awk_current_topic = w;
}

%}}}
%{{{ menu

define functions_popup_callback(popup)
{
   push_spot_bob;
   loop (20)
     {
	!if (re_fsearch("^function[\t ]+\\([0-9a-zA-Z_]+\\)")) break;
	menu_append_item(popup, regexp_nth_match(1),
			 &goto_line, what_line());
	eol;
     }
   pop_spot;
}

define awk_init_menu(menu)
{
   menu_append_popup(menu, "functions");
   menu_set_select_popup_callback (strcat (menu, ".functions"), &functions_popup_callback);
   menu_append_item (menu, "&Apropos", "awk->awk_apropos");
}

%}}}

public define awk_mode ()
{
   set_mode(mode, 1);
   mode_set_mode_info (mode, "init_mode_menu", &awk_init_menu);

   use_syntax_table (mode);
   % help hook in help.sl
   define_blocal_var("help_for_word_hook", &help_for_awk);
   % info_lookup in info_look.sl
   define_blocal_var("info_page", "Gawk");
   % completion hook in complete.sl
   define_blocal_var("complete_hook", "complete_from_file");
   run_mode_hooks("awk_mode_hook");
}

mode_set_mode_info (mode, "fold_info", "#{{{\r#}}}\r\r");
set_comment_info (mode, "# ", "", 0);
