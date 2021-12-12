% help.sl
% 
% Hypertext help browser as drop-in replacement for the standard help.sl
%
% Copyright © 2006 Günter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions
% --------
% 
%   1.0   - added Guido Gonzatos function_help (renamed to
%   	    help_for_word_at_point()) 
%   	  - when no documentation is available, give message in minibuffer
%     	    instead of popping up a help window (customizable)
%   	  - help-mode
%   1.1   - set variable
%   	  - grep the definition of a library function
%   	  - mini-help: a one-line help string for display in the minibuffer
%   	  - help_for_help (aka help.hlp)
%   	  - documentation of global functions
%   1.2   - use blocal_hooks for mode-dependent context help
%         - better formatting of apropos output (optional, with csvutils.sl)
%         - showkey with Key_* Variables
%         - Help_Topic type replaced by array
%         - save version of set_variable: ask if type changed
%   1.2.1 - bugfix for describe_bindings and describe_mode
%   1.2.2 - new binding: i = insert_word_and_close, I = info_mode
%   	  - adapted to changes in csvutils.sl(1.0)
%   1.2.3 - describe_mode: if a <mode>.hlp list is in the jed_library_path,
%     	    do help(<mode>.hlp). This way non-standard modes can supply
%     	    online-help.
%         - siplified due to change in csvutils.sl(1.1)
%   1.3   - use readonly-map from view.sl
%   	  - describe_mode: one more fallback: if no online-help available
%     	    nor a mode.hlp file, use help_message() (from bufutils)
%   1.3.1 - bugfix in grep_definition()
%   1.4   - str = extract_mini_doc(str) now takes a string argument
%   	    instead of working on a buffer
%   1.4.1 - added provide("hyperhelp"), so other modes depending on the
%           "hyperhelp"-version of help.sl can do require("hyperhelp")
%   1.4.2 - window-bugfix in grep_definition: the w32 subshell needs an
%           additional set of \\ to escape the quotes (Thomas Koeckritz)
%           (TODO: how is this on DOS?)
%   1.4.3 - grep_definition() adapted to new grep() command
%   	    (needs grep.sl >= 0.9.4)
%   1.4.4 2004-11-09  grep_definition() expanded for variables (experimental)
%           	      corrected typo Help_file -> Help_File
%   1.5   2005-04-01  new fun grep_slang_sources() "outsourced" from grep_definition()
%   1.6   2005-04-11  dfa highlighting to reduce "visual clutter" (Paul Boekholt)
%    	  	      help_search(): Search for a string in on-line documentation (PB)
%    	  	      removed where_is_word_at_point(), as where_is() already
%    	  	      has word_at_point as default.
%   1.6.1 2005-11-01  bugfix in describe_bindings()
%   1.6.2 2005-11-08  changed _implements() to implements()
%   1.6.3 2005-11-22  hide functions with autoloads in site.sl from make_ini()
%   1.7   2006-01-25  rewrite of help history feature using #ifexists
%                     removing the custom_variable `Help_with_history'
%                     provide("hyperhelp") so modes depending on stuff not in
%                     the standard help could require("hyperhelp")
%   1.8   2006-03-02  new function help->get_mini_help()
%   	  	      use the internal doc files list for Jed >= 0.99.17
%   	  	      (this means that the source file name is no longer 
%   	  	      appended to the help text)
%   1.8.1 2006-09-07  Added Slang 2 keywords for exception handling
%                     fix help-string for internal functions
%                     fix help_display_list()
%   1.8.2 2006-09-21  trim buffer in help_display_list()
%   	  	      patches by Paul Boekholt:
%   	  	      append Jed_Doc_Files to doc_files instead of overwriting
%   	  	      keybindings can now also be references, adapt showkey()
%   	  	      sort inherited and new keys in describe_bindings()
%		      (Jörg Sommer)
%   1.9   2007-04-19  edited help_string, removed use of prompt_for_argument()
%   	  	      fix in help_search(), handle "namespace->object" notation
%   1.9.1 2007-05-31  bugfix in where_is(), removed spurious line
%   1.9.2 2007-10-01  optional extensions with #if ( )
%   1.9.3 2007-10-04  no DFA highlight in UTF-8 mode (it's broken)
%   1.9.4 2007-10-15  re-enable DFA highlight, as it is rather unlikely that
%   	  	      help text contains multibyte chars (hint P. Boekholt) 
%   1.9.5 2007-10-18  re-introduce the sprint_variable() autoload
%   1.9.6 2007-12-20  add Jöörg Sommer's fix for DFA highlight under UTF-8
%   	  	      new highlight rules for keyword and headings
%   1.9.7 2008-05-05  use call_function() instead of runhooks()
	  	      

% 
% Usage
% -----
%
% Place help.sl, txtutils.sl, bufutils.sl (and optional grep.sl, filelist.sl,
% and  circle.sl) in the "jed library path" (use get_jed_library_path() to see
% what your "jed library path" is)
%
% (I recommend a separate directory for the local extensions --
% so they won't be overwritten by upgrading to a new jed version.
% See http://jedmodes.sf.net/mode/libdir/ for a more info on how to do this)
%
% To increase the comfort, you can replace the "help_prefix" binding (^H in
% emacs emulation) with menu_select_menu("Global.&Help") so it pops up the
% Help menu for better visual feedback or define your own help-map, e.g.
% 
%    % ^H map:	       	         Help ...
%    setkey("apropos", 		 "^HA");
%    setkey("grep_definition",	 "^HD");
%    setkey("describe_function", "^HF");
%    setkey("help",   		 "^HH");
%    setkey("info_mode", 	 "^HI");
%    setkey("showkey", 		 "^HK");
%    setkey("describe_mode", 	 "^HM");
%    setkey("set_variable",	 "^HS");
%    setkey("unix_man",	      	 "^HU");
%    setkey("describe_variable", "^HV");
%    setkey("where_is", 	 "^HW");
%    
%  (these bindings will then show up in the Help menu) and optionally bind
%  another key to open the help menu, e.g.
%  
%    setkey("menu_select_menu(\"Global.&Help\")", Key_F1); % Jed >= 99.16
%  or  
%    setkey("ungetkey('h'); call(\"select_menubar\")", Key_F1); % Jed <= 99.15
%
%  you will need autoloads for all functions you want to bind
%  that are not present in the standard help.sl

#<INITIALIZATION>
_autoload("help_for_help", "help",
   "grep_definition", "help",
   "grep_slang_sources", "help",
   "context_help", "help",
   "help_for_word_at_point", "help",
   "set_variable", "help",
   "help_search", "help",
   7);
_add_completion("grep_definition", "set_variable", "help_search", 3);

define hyperhelp_load_popup_hook(menubar)
{
   menu_insert_item("&Info Reader", "Global.&Help",
                       "&Grep Definition", "grep_definition");
   menu_insert_item("&Info Reader", "Global.&Help",
                       "&/ Search in Help Docs", "help_search");
   menu_insert_separator("&Info Reader", "Global.&Help");
}
append_to_hook ("load_popup_hooks", &hyperhelp_load_popup_hook);
#</INITIALIZATION>

% Requirements
% ------------

% Standard modes, distributed with jed but not loaded by default
autoload("add_keyword_n", "syntax.sl");
require("keydefs");

% Functions from utility modes at http://jedmodes.sourceforge.net/
require("view"); %  readonly-keymap
autoload("run_function",        "sl_utils");
autoload("get_blocal",          "sl_utils");
autoload("push_array",          "sl_utils");
autoload("push_defaults",       "sl_utils");
autoload("get_word",           "txtutils");
autoload("bget_word",           "txtutils");
autoload("popup_buffer",        "bufutils");
autoload("close_buffer",        "bufutils");
autoload("strread_file",        "bufutils");
autoload("set_help_message",    "bufutils");
autoload("help_message",        "bufutils");
autoload("string_get_match",	"strutils");
autoload("strsplit", 		"strutils"); % >= 1.6

% Optional modes from http://jedmodes.sourceforge.net/
% (not really needed but nice to have)
%
% Detection of files fails with preparse for SLang1 (leaves '^A' on stack) !

% formatting of apropos list
#if (expand_jedlib_file("csvutils.sl") != "")
autoload("list2table", "csvutils.sl");
autoload("strjoin2d", "csvutils.sl");
% dummy autoload for byte-compiling
#if (autoload("list2table", "csvutils.sl"), 1)
#endif
#endif

% Help History: walk for and backwards in the history of help items
#if (expand_jedlib_file("circle.sl") != "")
require("circle");
% dummy autoload for byte-compiling
#if (autoload("create_circ", "circle"), 1)
#endif
#endif

% sprint_variable(): nice formatting of compound data types
#if (expand_jedlib_file("sprint_var.sl") != "")
autoload("sprint_variable", "sprint_var");
#endif

% Announcement and namespace
% --------------------------
% This help browser (with "hyperlinks") is a drop-in replacement for the
% standard help. Modes depending on extensions in this file should
% require "hyperhelp", e.g. via::
% 
%   #if (_jed_version < 9919)
%     require("hyperhelp", "help.sl");
%   #else % new syntax introduced in Jed 0.99.19
%     require("hyperhelp", "Global", "help.sl");
%   #endif

provide("help");
provide("hyperhelp");

implements("help");
private variable mode = "help";

% Custom variables 
% ----------------

% How big shall the help window be maximal
% (set this to 0 if you don't want it to be fitted)
custom_variable("Help_max_window_size", 0.7);
% for one line help texts, just give a message instead of open up a buffer
custom_variable("Help_message_for_one_liners", 0);
% Do you want full- or mini-help with help_for_word_at_point?
custom_variable("Help_mini_help_for_word_at_point", 0);
% The standard help file to display with help().
custom_variable("Help_File", "generic.hlp");

% Variables  
% ---------

% valid chars in function and variable definitions
static variable Slang_word_chars = "A-Za-z0-9_";

% the name of the syntax table for help listings (apropos, help_search)
private variable helplist = "helplist";

% The symbolic names for keystrings defined in keydefs.sl
% filled when needed by expand_keystring()
private variable Keydef_Keys;

static variable current_topic; % ["fun", "subject"]

% adapt help-message (defined in site.sl) extended help
help_for_help_string =
"a:Apropos f:Function h:Help k:Key q:Quit u:Unix-man v:Var w:Where /:Search";
set_help_message(help_for_help_string, mode);

% reserved keywords, taken from Klaus Schmidt's sltabc  %{{{
static variable Keywords =
  [
   "ERROR_BLOCK",         % !if not used here
   "EXECUTE_ERROR_BLOCK", % from syntax table
   "EXIT_BLOCK",
   "NULL",                % from syntax table
   "USER_BLOCK0", "USER_BLOCK1", "USER_BLOCK2", "USER_BLOCK3", "USER_BLOCK4",
   "__tmp", "_for",
   "abs", "and", "andelse",
   "break",
   "case", "catch", "chs", "continue",
   "define", "do", "do_while",
   "else", "exch",
   "finally", "for", "foreach", "forever",
   "if",
   "loop",
   "mod", "mul2",
   "not",
   "or", "orelse",
   "pop", "private", "public",
   "return",
   "shl", "shr", "sign", "sqr", "static", "struct", "switch",
   "throw", "try", "typedef",
   "using",
   "variable",
   "while",
   "xor"
  ];
%}}}

% backwards compatibility: feed Jed_Doc_Files to the internal doc files list
#ifexists set_doc_files
#ifexists Jed_Doc_Files  % might become obsoleted in 0.99.19
private variable docfile;
foreach (strchop(Jed_Doc_Files, ',', 0))
{
   docfile=();
   !if (length(where(docfile == get_doc_files())))
     add_doc_file(docfile);
}
#endif
#endif


% Auxiliary Functions 
% -------------------

% forward declarations
public  define help_mode();
static define help_for_object();

static define read_object_from_mini(prompt, default, flags)
{
   if (MINIBUFFER_ACTIVE) 
     return;

   variable objs = _apropos("Global", "", flags);
   objs = strjoin(objs[array_sort (objs)], ",");

   return read_string_with_completion(prompt, default, objs);
}

public  define read_function_from_mini(prompt, default)
{
   return read_object_from_mini(prompt, default, 0x3);
}

public  define read_variable_from_mini(prompt, default)
{
   return read_object_from_mini(prompt, default, 0xC);
}

% Return function or variable object at cursor position as string
% works also for static objects in "namespace->object" notation
static define get_object()
{
   mark_word(Slang_word_chars, -1);
   if (looking_at("->"))
      {
	 go_right(2);
	 skip_chars(Slang_word_chars);
      }
   exchange_point_and_mark();
   if (blooking_at("->"))
     {
	go_left(2);
	bskip_chars(Slang_word_chars);
     }
   exchange_point_and_mark();
   return bufsubstr();
}

% from sltabc.sl by Klaus Schmidt: filter array by regexp pattern
private define re_filter(a, pat)
{
   variable i = array_map(Integer_Type, &string_match, a, pat, 1);
   return a[where(i)];
}

% History
#ifexists create_circ
variable Help_History = create_circ(Array_Type, 30, "linear");

define previous_topic()
{
   call_function(push_array(circ_previous(Help_History)));
}

define next_topic()
{
   call_function(push_array(circ_next(Help_History)));
}
#endif

% Open a help buffer, insert str, set to help mode, and add to history list
define help_display(str)
{
   %  if help_str is just one line, display in minibuffer
   if (Help_message_for_one_liners and is_substr(str, "\n") == 0)
     return message(str);

   popup_buffer("*help*", Help_max_window_size);
   set_readonly(0);
   erase_buffer();
   TAB = TAB_DEFAULT; % in case it is set differently by apropos...
   insert(str);
   bob();
   fit_window(get_blocal("is_popup", 0));
   help_mode();
#ifexists create_circ
   if (length(where(current_topic != circ_get(Help_History))))
     circ_append(Help_History, @current_topic);
#endif   
}

static define help_display_list(a)
{
#ifexists list2table  % insert as formatted table (using csvutils.sl)
   a = list2table(a);
   help_display(strjoin2d(a, " ", "\n", "l"));
   set_readonly(0);
   trim_buffer();
#else                 % align columns by setting TAB
   help_display(strjoin(a, "\n"));
   set_readonly(0);
   buffer_format_in_columns();   
   fit_window(get_blocal("is_popup", 0));
#endif
   % define_blocal_var("Word_Chars", Slang_word_chars + "->");
   use_syntax_table(helplist);
   set_buffer_modified_flag(0);
   set_readonly(1);
}

% Basic Help 
% ----------

%!%+
%\function{help}
%\synopsis{Pop up a window containing a help file.}
%\usage{help(help_file=Help_File)}
%\description
% Displays help_file in the help buffer.
% The file read in is given by the optional argument or the
% (custom) variable \var{Help_File}.
%\seealso{help_for_help, help_mode, Help_File}
%!%-
public define help() % (help_file=Help_File)
{
   variable help_file;
   help_file = push_defaults(Help_File, _NARGS);

   current_topic = [_function_name, help_file];
   variable path = help_file;
   !if (path_is_absolute (path))
     path = expand_jedlib_file(path);
   if (file_status(path) != 1)
     verror ("Help error: File %s not found", help_file);
   % get the file and display in the help buffer
   help_display(strread_file(path));
}

%!%+
%\function{help_for_help}
%\synopsis{Display the help for help.}
%\usage{help_for_help()}
%\description
% Displays help.hlp in the help buffer.
%\seealso{help, help_mode}
%!%-
define help_for_help() {help("help.hlp");}

%!%+
%\function{apropos}
%\synopsis{List all defined objects that match a regular expression}
%\usage{apropos ([pattern])}
%\description
%   Apropos searches for defined functions and variables in the
%   global namespace that match a given regular expression. If the
%   optional search-string is missing, the user will be prompted for
%   a pattern in the minibuffer.
%\seealso{_apropos, help_mode, describe_function, describe_variable}
%!%-
public  define apropos() % ([pattern])
{
   !if (_NARGS)
     read_mini("apropos:", get_object(), ""); % push to stack
   variable pattern = ();

   variable namespace, namespaces, namespace_pattern, object_pattern,
     objects = String_Type[0];
   if (is_substr(pattern, "->"))
     {
	namespace_pattern = strsplit(pattern, "->")[0];
	object_pattern = strsplit(pattern, "->")[-1];
     }
   else
     {
	namespace_pattern = "Global";
	object_pattern = pattern;
     }
   namespaces = re_filter(_get_namespaces(), namespace_pattern);
   foreach namespace (namespaces)
     {
	if (namespace == "Global")
	  objects = [objects, _apropos(namespace, object_pattern, 0xF)];
	else
	  objects = [objects, namespace + "->" 
		     + _apropos(namespace, object_pattern, 0xF)];
     }
   vmessage ("Found %d matches.", length(objects));
   !if (length(objects))
     objects = ["No results for \"" + pattern + "\""];
   current_topic = [_function_name, pattern];
   help_display_list(objects[array_sort(objects)]);
}

% Search for \var{str} in the internal doc files list (or \var{Jed_Doc_Files})
define _do_help_search(str)
{
   variable result = String_Type[100], i=0;
   !if(strlen(str))
     error("nothing to search for");
   variable this_str, strs = strchop(str, ' ', '\\');
   variable docfile, matches_p;

   variable fp, buf="", pos=1, buffer, beg=0, len=0, entry;
   foreach (
#ifexists get_doc_files % get_doc_files() is not defined in jed <= 99.16
            get_doc_files()
#else
            strchop(Jed_Doc_Files, ',', 0) 
#endif
            )   
     {
	docfile=();
	fp = fopen(docfile, "r");
	if (fp == NULL)
	  continue;

	forever
	  {
	     % read a help entry in chunks of 1000 bytes
	     if (string_match(buf, "\n--*\n", pos))
	       {
		  (beg, len) = string_match_nth(0);
	       }
	     else
	       {
		  buf = buf[[pos-1:]];
		  pos = 1;
#ifnexists _slang_utf8_ok   % #if (_slang_version < 2000) doesnot preparse
		  if (-1 ==  fread(&buffer, Char_Type, 1000, fp))
#else
		  if (-1 ==  fread_bytes(&buffer, 1000, fp))
#endif
		    break;
		  buf +=buffer;
		  continue;
	       }
	     entry=buf[[pos-1:beg]];
	     matches_p=1;

	     foreach (strs)
	       {
		  this_str=();
		  !if (is_substr(entry, this_str))
		    matches_p=0;
	       }
	     if (matches_p)
	       {
		  result[i]=string_get_match(entry, "[^\n]+\n");
		  i++;
		  if (i==100) return result;
	       }
	     pos=beg+len;
	     if(feof(fp)) break;
	  }
     }
   !if (i> 0) return @String_Type[0];
   return result[[:i-1]];
}

%!%+
%\function{help_search}
%\synopsis{Search for \var{str} in the \var{Jed_Doc_Files}}
%\usage{help_search([str])}
%\description
%  This function does a full text search in the online help documents
%  and returns the function/variable names where \var{str} occures in
%  the help text.
%\seealso{apropos, describe_function, describe_variable, Jed_Doc_Files}
%!%-
public define help_search() % ([str])
{
   !if (_NARGS)
     read_mini("Search in help docs:", "", ""); % push to stack
   variable str = ();
   
   variable list = _do_help_search(str);
   vmessage ("Found %d matches.", length(list));
   !if (length(list))
     list = ["No results for \"" + str + "\""];
   current_topic = [_function_name, str];
   help_display_list(list[array_sort(list)]);
}

% Show Key
% --------

% Convert string into array of 1-char strings.
% 
% In contrast to bstring_to_array() or foreach str),  the array elements are
% of String_Type and in UTF-8 can contain several bytes.
define string_to_array(str)
{
   variable i, a = String_Type[strlen(str)];
   for (i = 0; i <strlen(str); i++)
     a[i] = substr(str, i+1, 1);
   return a;
}
   
%  Substitute control-characters by ^@ ... ^_
define strsub_control_chars(keystring)
{
   variable ch, outstr = "";
   foreach ch (string_to_array(keystring))
     {
	if (ch[0] < 32)
	  ch = "^" + char(ch[0]+64);
	outstr += ch;
     }
   return outstr;
}

%!%+
%\function{expand_keystring}
%\synopsis{Expand a keystring to easier readable form}
%\usage{String expand_keystring (String key)}
%\description
% This function takes a key string that is suitable for use in a 'setkey'
% definition and expands it to a easier readable form
%       For example, it expands ^I to the form "\\t", ^[ to "\\e",
%       ^[[A to Key_Up, etc...
%\seealso{setkey}
%!%-
public  define expand_keystring(key)
{
   variable keyname, keystring;
   % initialize the Keydef_Keys dictionary
   !if (__is_initialized (&Keydef_Keys))
     {
	Keydef_Keys = Assoc_Type[String_Type, ""];
	foreach keyname (_apropos("Global", "^Key_", 0xC))
	  {
	     keystring = strsub_control_chars(@__get_reference(keyname));
	     Keydef_Keys[keystring] = keyname;
	  }
     }
   % substitute control chars by ^@ ... ^_
   key = strsub_control_chars(key);
   % check for a symbolic keyname and return it if defined
   if (strlen(Keydef_Keys[key]))
     key = sprintf("%s (\"%s\")", Keydef_Keys[key], key);
   % two more readability replacements
   key = str_replace_all(key, "^I", "\\t");
   key = str_replace_all(key, "^[", "\\e");
   return key;
}

%!%+
%\function{showkey}
%\synopsis{Show a keybinding.}
%\usage{showkey([keystring])}
%\description
%   Ask for a key to be pressed and display its binding(s)
%   in the minibuffer.
%\seealso{where_is, help_for_help}
%!%-
public  define showkey() % ([keystring])
{
   variable ks, f, type;
   if (_NARGS)
     {
	ks = ();
	(type, f) = get_key_binding(ks);
     }
   else
     {
	flush("Show Key: ");
	(type, f) = get_key_binding();
	ks = expand_keystring(LASTKEY);
     }
   if (f == NULL)
     f = "";
   if (type == 4)
     f = sprintf("%S", f);

   variable help_str;
   variable description = [" is undefined.",
			   " runs the S-Lang function ",
			   " runs the internal function ",
			   " runs the keyboard macro ",
			   " inserts ",
			   " runs the intrinsic function "];

   if (andelse {type == 0} {is_defined(f) == 1})
     type = 4;

   if(is_substr(ks, "Key_"))
     help_str = ks;
   else
     help_str = strcat("Key \"", ks, "\"");

   help_str += description[type+1] + f;

   current_topic = [_function_name, ks];
   help_display(help_str);
}

%!%+
%\function{where_is}
%\synopsis{Show which key(s) a command is on}
%\usage{where_is([String cmd])}
%\description
%   If no argument is given, ask for a command.
%   Show the key that is bound to it.
%\seealso{get_key_binding, help_for_help}
%!%-
public  define where_is()
{
   !if (_NARGS)
     read_function_from_mini("Where is command:", get_object());
   variable cmd = ();
   variable n, help_str = cmd + " is on: ";

   n = which_key(cmd);
   !if (n)
     help_str = cmd + " is not on any keys.";
   loop(n)
     help_str += expand_keystring() + ",  ";
   help_str += "   Keymap: " + what_keymap();

   current_topic = [_function_name, cmd];
   help_display(help_str);
}

% Describe Function/Variable
% --------------------------

public  define is_keyword(name)
{
   return (length(where(name == Keywords)));
}

% return a string with a variable's name and value
static define variable_value_str(name)
{
   variable vref, type = "", value = "<Uninitialized>";
   switch (is_defined(name))
     { case 0: return "variable " + name + " undefined"; }
     { case 1 or case 2: return name + " is a function"; }
   
   vref = __get_reference(name);
   if (__is_initialized(vref))
     {
	value = @vref;
	type = typeof(value);
#ifexists sprint_variable
	value = sprint_variable(value); % get nice representation
	if (is_substr(value, "\n")) % multi-line string
	  value += "\n";
#endif
     }
   return sprintf("%S `%s' == %S", type, name, value);
}

% return a string with help for function/variable obj
static define help_for_object(obj)
{
   variable help_str = "",
   function_types = ["undefined",
		     "intrinsic function",
		     "library function",
		     "SLang keyword"],
     type = is_defined(obj),
     doc_str, file, vref;

   if (is_keyword(obj))
     type = 3;
   if (is_internal(obj))
     {
	help_str = strjoin(
	   [obj + ": internal function\n",
	    "Use call(\"" + obj + "\") to access from slang",
	    "or bind to a key using setkey or definekey."], " ");
	!if (type)
	  return help_str;
	else
	  help_str += "\n\n";
     }

   if (type < 0) % Variables
     help_str += variable_value_str(obj);
   else
     help_str += sprintf("%s: %s", obj, function_types[type]);

   % get doc string
#ifexists get_doc_files % the file argument to get_doc_string_from_file was 
   	  		% made optional with the introduction of 
   			% [s|g]et_doc_files in jed 0.99.17
   doc_str = get_doc_string_from_file(obj);
#else   
   foreach file (strchop(Jed_Doc_Files, ',', 0))
     {
	doc_str = get_doc_string_from_file (file, obj);
	if (doc_str != NULL)
	  break;
     }
#endif
   if (doc_str == NULL)
     help_str += "  Undocumented";
   else
     {
        help_str += doc_str[[strlen(obj):]];
	% in Jed >= 0.99.17, we do not determine the source file name
        % help_str += sprintf("\n\n(Obtained from file %s)", file);
     }

   return help_str;
}

%!%+
%\function{describe_function}
%\synopsis{Give help for a jed-function}
%\usage{describe_function ()}
%\description
%   Display the online help for \var{function} in the
%   help buffer.
%\seealso{describe_variable, help_for_help, help_mode}
%!%-
public  define describe_function () % ([fun])
{
   !if (_NARGS)
     read_function_from_mini("Describe Function:", 
	get_object());
   variable fun = ();
   current_topic = [_function_name, fun];
   help_display(help_for_object(fun));
}

%!%+
%\function{describe_variable}
%\synopsis{Give help for a jed-variable}
%\usage{describe_variable([var])}
%\description
%   Display the online help for \var{variable} in the
%   help buffer.
%\seealso{describe_function, help_for_help, help_mode}
%!%-
public  define describe_variable() % ([var])
{
   !if (_NARGS)
     read_variable_from_mini("Describe Variable:", 
	get_object());
   variable var = ();
   current_topic = [_function_name, var];
   help_display(help_for_object(var));
}

%!%+
%\function{describe_mode}
%\synopsis{Give help for the current mode}
%\usage{describe_mode ()}
%\description
%   Display the online help for the current editing mode
%   in the help buffer.
%\seealso{describe_function, help_for_help, help_mode}
%!%-
public  define describe_mode ()
{
   variable modstr = normalized_modename();
   current_topic = [_function_name, modstr];
   variable helpstr = help_for_object(modstr + "_mode");
   ERROR_BLOCK
     {
	_clear_error();
	help_message();
     }
   if (helpstr[[-12:]] != "Undocumented")
     help_display(helpstr);
   else
     help(modstr + ".hlp");
}

%!%+
%\function{describe_bindings}
%\synopsis{Show a list of all keybindings}
%\usage{describe_bindings ()}
%\description
%   Show a list of all keybindings in the help buffer
%\seealso{showkey, where_is, help_mode}
%!%-
public  define describe_bindings() % (keymap=what_keymap())
{
   !if (_NARGS)
     read_mini("Keymap:", what_keymap(), "");
   variable keymap = ();
   
   flush("Building bindings..");
   variable buf = whatbuf();
   current_topic = [_function_name, keymap];
   help_display("");
   set_readonly(0);
   dump_bindings(keymap);
   if (keymap != "global")
   {
       insert("\nInherited from the global keymap:\n");
       push_spot();
       dump_bindings("global");
       pop_spot();
 
       variable global_map = Assoc_Type[String_Type];
       while ( not eobp() )
       {
           push_mark();
           () = ffind("\t\t\t");
           variable key = bufsubstr();
           () = right(3);
           push_mark();
           eol();
           global_map[key] = bufsubstr();
           delete_line();
       }
 
       bob();
       forever
       {
           push_mark();
           () = ffind("\t\t\t");
           key = bufsubstr();
           if (key == "")
             break;
 
           if ( assoc_key_exists(global_map, key) )
           {
               () = right(3);
               push_mark();
               eol();
               if (bufsubstr() == global_map[key])
               {
                   delete_line();
                   push_spot();
                   eob();
                   insert(key + "\t\t\t" + global_map[key] + "\n");
                   pop_spot();
               }
               else
                 () = down(1);
           }
           else
             () = down(1);
       }
   }
   bob;
   insert("Keymap: " + keymap + "\n");
   % TODO:
   %    variable old_case_search = CASE_SEARCH;
   %    CASE_SEARCH = 1;
   % do
   %   expand_keystring;
   % while (down(1))
   % bob;
   set_buffer_modified_flag(0);
   set_readonly(1);
   % use_syntax_table(helplist); This also colours the keybindings
   fit_window(get_blocal("is_popup", 0));
}

% grep commands (need grep.sl)
#ifexists grep

%!%+
%\function{grep_slang_sources}
%\synopsis{Grep in the Slang source files of the jed library path}
%\usage{grep_slang_sources([what])}
%\description
%   If the grep.sl mode is installed, grep_slang_sources does a
%   grep for the regexp pattern \var{what} in all *.sl files in the
%   jed library path.
%\notes
%   Needs the grep.sl mode and the grep system command
%
%\seealso{grep, grep_definition, get_jed_library_path}
%!%-
public define grep_slang_sources() % ([what])
{
   !if (_NARGS)
     read_mini("Grep in Slang sources:", "", get_object());
   variable what = ();
   % build the search string and filename mask
   variable files = strchop(get_jed_library_path, ',', 0);
   files = files[where(files != ".")]; % filter the current dir
   files = array_map(String_Type, &path_concat, files, "*.sl");
   files = strjoin(files, " ");
   grep(what, files);
}

%!%+
%\function{grep_definition}
%\synopsis{Grep source code of definition}
%\usage{grep_definition([function])}
%\description
%  If the \sfun{grep} function is defined, grep_definition does a
%  grep for a function/variable definition in all directories of the
%  jed_library_path.
%\notes
%  The \sfun{grep} function is provided by grep.sl and needs the 'grep'
%  system command. It is checked for at evaluation (or byte_compiling)
%  time of help.sl by a preprocessor directive.
%\seealso{describe_function, grep, grep_slang_sources, get_jed_library_path}
%!%-
public define grep_definition() % ([obj])
{
   !if (_NARGS)
     read_object_from_mini("Grep Definition:", get_object(), 0xF);
   variable obj = ();
   variable type = is_defined(obj);
   if (abs(type) != 2)
     if (get_y_or_n(obj + ": not a library function|variable. Grep anyway?")
	!= 1)
       return;

   variable what, lib, files, results, grep_buf = "*grep_output*";

   % build the grep-pattern
   obj = strsplit(obj, "->")[-1]; % remove the namspace part
   if (type >= 0) % function or undefined
	what = sprintf("-s 'define %s[ (]'",  obj );
   else % variable
	what = sprintf("-s 'variable *(*\"*%s[\" ,=]'",  obj );

   % grep in the Slang source files of the jed library path
   grep_slang_sources(what);
   % find number of hits
   !if (bufferp(grep_buf))
     results = 0;
   else
     {
	eob;
	results = what_line;
	bob;
     }
   % if there is a unique find, go there directly
   if(results == 1)
     {
	define_blocal_var("FileList_Cleanup", 1);
	call_function("filelist_open_file");
	close_buffer(grep_buf);
     }
   message(sprintf("Grep for \"%s\": %d definition(s) found", obj, results));
}

% grep a function definition,
% defaults to the word under cursor or the current help topic
define grep_current_definition()
{
   variable obj = get_object();
   if (is_defined(obj) == 2) % library function
     grep_definition(obj);
   else if (current_topic[0] == "describe_function")
     grep_definition(current_topic[1]);
   else
     grep_definition();
}
#endif

%!%+
%\function{set_variable}
%\synopsis{Set a variable value}
%\usage{set_variable() % ([name])}
%\description
%   Set a variable to a new value, define the variable if undefined.
%   If the current word is no variable, ask for the variable name.
%   The new value must be a valid slang expression that will be evaluated
%   in the global namespace.
%
%   WARNING: Setting variables to unsensible values might cause jed
%            to stop working
%\seealso{eval, read_variable_from_mini}
%!%-
public define set_variable()
{
   variable name = get_object();
   if (andelse {whatbuf()=="*help*"}
	{is_substr(name, "_Type")}
       )
     name = current_topic[1];
   !if (is_defined(name) < 0) % variable
     name = read_variable_from_mini("Set Variable:", name);
   if (name == "")
     error("set_variable: Aborted");

   variable new = 0, var, value, def_string = "";

   % ensure var is globally defined
   if (is_defined (name) == 0)
     {
	new = 1;
	if (get_y_or_n("Variable "+name+" undefined, define") > 0)
	  eval("variable " + name);
	else
	  error("set_variable: Aborted");
     }
   % get pointer
   var = __get_reference(name);
   % evaluate value
   value = read_mini(variable_value_str(name) + " New value:","","");
   value = eval(value);
   % check for same datatype
   if (andelse {__is_initialized(var)} {typeof(@var) != typeof(value)})
     if ( get_y_or_n(
	  sprintf("Variable %s: change datatype from %S to %S?",
		name, typeof(@var), typeof(value)) ) != 1)
       error("set_variable: Aborted");
   % now set the variable
   @var = value;
   % display new value
   message(variable_value_str(name));
   % redisplay help window
   if (current_topic[0] == "describe_variable")
     describe_variable(name);
}

%!%+
%\function{extract_synopsis}
%\synopsis{return concise USAGE and SYNOPSIS info from the help_string}
%\usage{String help->extract_synopsis(help_str)}
%\description
%   Extract the USAGE and SYNOPSIS lines of the help_string
%   (assumning a documention string according to the format used in
%   Jed Help, e.g. jedfuns.txt). Convert to a more concise format and
%   return as string.
%\seealso{help_for_function, mini_help_for_object}
%!%-
define extract_synopsis(help_str)
{
   variable i, synopsis, word = extract_element(help_str, 0, ':');
   help_str = strchop(help_str, '\n', 0);
   % get index of synopsis line
   i = (where(help_str == " SYNOPSIS") + 1);
   % no SYNOPSIS
   !if (length(i))
     return "";
   % get the actual line
   synopsis = strtrim(help_str[i[0]]);
   if (synopsis == word)  % Phony synopsis
     return "";
   return synopsis;
}


%!%+
%\function{extract_usage}
%\synopsis{return concise USAGE and SYNOPSIS info from the help_string}
%\usage{String help->extract_usage(help_str)}
%\description
%   Extract the USAGE and SYNOPSIS lines of the help_string
%   (assumning a documention string according to the format used in
%   Jed Help, e.g. jedfuns.txt). Convert to a more concise format and
%   return as string.
%\seealso{help_for_function, mini_help_for_object}
%!%-
define extract_usage(help_str)
{
   variable i, usage;
   help_str = strchop(help_str, '\n', 0);
   % get index of usage line
   i = (where(help_str == " USAGE") + 1);
   % abort if not found
   !if (length(i))
     return "";
   % get the actual line
   usage = strtrim(help_str[i[0]]);
   
   % Replacements
   % insert "="
   !if (is_substr(usage, "="))
     (usage, ) = strreplace (usage, " ", " = ", 1);
   % strip Void/void
   usage = str_replace_all(usage, "Void = ", "");
   usage = str_replace_all(usage, "void = ", "");
   usage = str_replace_all(usage, "Void ", "");
   usage = str_replace_all(usage, "void ", "");
   % simple types -> small letters
   usage = str_replace_all(usage, "Integer_Type", "i");
   usage = str_replace_all(usage, "Int_Type", "i");
   usage = str_replace_all(usage, "Integer", "i");
   usage = str_replace_all(usage, "Double_Type", "x");
   usage = str_replace_all(usage, "Double", "x");
   % compound types -> capital letters
   usage = str_replace_all(usage, "String_Type", "Str");
   usage = str_replace_all(usage, "String", "Str");
   usage = str_replace_all(usage, "Array_Type", "Arr ");
   usage = str_replace_all(usage, "Array", "Arr");
   usage = str_replace_all(usage, "Assoc_Type", "Ass");
   usage = str_replace_all(usage, "Assoc", "Ass");

   % strip ";" and return
   return strtrim_end(usage, ";");
}

static define get_mini_help(obj)
{
   variable help_str = help_for_object(obj);
   % Help is already one-liner (e.g. "Undefined")
   !if (is_substr(help_str, "\n"))
     return help_str;
   return sprintf("%s; %s", 
      extract_usage(help_str), extract_synopsis(help_str));
}


%!%+
%\function{mini_help_for_object}
%\synopsis{Show concise help information in the minibuffer}
%\usage{mini_help_for_object(obj)}
%\description
%   Show the synopsis of the online help in the minibuffer.
%\seealso{describe_function, describe_variable}
%!%-
public define mini_help_for_object(obj)
{
   message(get_mini_help(obj));
}

%!%+
%\function{help_for_word_at_point}
%\synopsis{Give (mode dependend) help for word under cursor}
%\usage{help_for_word_at_point()}
%\description
%   Find the word under the cursor and give mode-dependend help using the
%   function defined in the blocal variable "help_for_word_hook".
%\notes
%   If a mode needs a different set of word_chars (like including the point
%   for object help in python), it can either set the buffer-local variable
%   "word_chars", use mode_set_mode_info("word_chars") or, if this is
%   not  desired, its help_for_word_hook can discard the provided word and
%   call e.g. bget_word("mode_word_chars").
%\seealso{describe_function, describe_variable, context_help}
%!%-
public define help_for_word_at_point()
{
   variable word_at_point = get_object();
   if (word_at_point == "")
     run_local_hook("context_help_hook");
   else
     run_local_hook("help_for_word_hook", word_at_point);
}

%!%+
%\function{context_help}
%\synopsis{Give context sensitive help}
%\usage{context_help()}
%\description
%  Give a mode-dependend help for the current context, e.g.
%  find the word under the cursor and give mode-dependend help.
%\notes
%  Uses \sfun{run_local_hook} to give a mode- or buffer local help.
%  It is up to the language modes to define a context_help_hook.
%  "hyperhelp" defines a \sfun{slang_context_help_hook} that calls
%  \sfun{describe_function} on the word-at-point.   
%\seealso{run_local_hook, describe_function, bget_word}
%!%-
public define context_help()
{
   !if (run_local_function("context_help_hook"))
     run_local_hook("help_for_word_hook", bget_word());
}

public  define slang_context_help_hook()
{
   variable word_at_point = get_object();
   if (word_at_point == "")
     describe_function();
   else
     describe_function(word_at_point);
}

public  define help_2click_hook (line, col, but, shift)
{
   context_help();
   return(0);
}

% fast moving in the help buffer (link to link skipping)
% ------------------------------------------------------

% skip forward to beg of next word  (move this to txtutils.sl?)
define skip_word() % ([word_chars])
{
   variable word_chars, skip;
   (word_chars, skip) = push_defaults(NULL, 0, _NARGS);
   if (word_chars == NULL)
     word_chars = get_blocal("Word_Chars", get_word_chars());

   skip_chars(word_chars);
   while (skip_chars("^"+word_chars), eolp())
     {
	!if (right(1))
	  break;
     }
}

% skip backwards to end of last word  (move this to txtutils.sl?)
define bskip_word() % ([word_chars])
{
   variable word_chars, skip;
   (word_chars, skip) = push_defaults(NULL, 0, _NARGS);
   if (word_chars == NULL)
     word_chars = get_blocal("Word_Chars", get_word_chars());

   bskip_chars(word_chars);
   while (bskip_chars("^"+word_chars), bolp())
     {
	!if (left(1)) break;
     }
}

% search forward for a defined word enclosed in ` '
static define fsearch_defined_word()
{
   variable word;
   push_mark;
   while (fsearch_char('`'))
     {
	go_right_1();
	word = get_word(Slang_word_chars);
	if (is_defined(word) and word != current_topic[1])
	  {
	     pop_mark_0;
	     return 1;
	  }
     }
   pop_mark_1;
   return 0;
}

% goto next word that is a defined function or variable
define goto_next_object()
{
   if (is_list_element("help_search,apropos", current_topic[0], ','))
     skip_word();
   else if (fsearch_defined_word())
     return;
   else if(push_spot, re_bsearch("^ +SEE ALSO"), pop_spot)
	skip_word();
   else if (re_fsearch("^ +SEE ALSO"))
     {
	eol();
	skip_word();
     }
   % wrap
   if (eobp)
     bob();
}

% goto previous word that is a defined function or variable
define goto_prev_object ()
{
   if (is_list_element("help_search,apropos", current_topic[0], ','))
     return bskip_word();
   !if(andelse {push_spot, re_bsearch("^ +SEE ALSO"), pop_spot}
	 {bskip_word(), not looking_at("ALSO")})
     {
        push_mark;
	while (andelse {bsearch_char('\'')} % skip back over word at point if any
		 {re_bsearch("`[_a-zA-Z]+'")})
	  {
	     go_right_1;
	     if (is_defined(get_word()))
	       {
		  pop_mark_0;
		  return;
	       }
	  }
	pop_mark_1;
     }
}

% Highlighting of "Links" (defined objects)
% -----------------------------------------

#ifdef HAS_DFA_SYNTAX
create_syntax_table(mode);
set_syntax_flags(mode, 0);

% dfa_define_highlight_rule("\\\".*\\\"", "Qstring", mode);
dfa_define_highlight_rule("->",           "operator", mode);
% Help topic (only word that starts on bol in standar help texts)
%dfa_define_highlight_rule("^[a-zA-Z0-9_]+",  "Kbold",  mode); 
dfa_define_highlight_rule("`[^']+'",      "QKstring",  mode);
dfa_define_highlight_rule(" [a-zA-Z0-9_]+,", "Knormal", mode);
% last item in SEE ALSO but not a heading
dfa_define_highlight_rule(" [a-zA-Z0-9_]+[a-z0-9_][a-zA-Z0-9_]*$", "Knormal", mode);
dfa_define_highlight_rule("^ +[A-Z ]+$",   "underline", mode);

% render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
dfa_define_highlight_rule("[^ -~]+", "normal", mode);

dfa_build_highlight_table(mode);
enable_dfa_syntax_for_mode(mode);
% keywords will be added by the function help_mark_keywords()

% special syntax table for listings (highlight all words in keyword colour)
create_syntax_table(helplist);
set_syntax_flags(helplist, 0);

dfa_define_highlight_rule("[A-Za-z0-9_]*", "keyword", helplist);
dfa_define_highlight_rule("->", "operator", helplist);
% render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
dfa_define_highlight_rule("[^ -~]+", "normal", helplist);

dfa_build_highlight_table(helplist);
enable_dfa_syntax_for_mode(helplist);
#endif

private define _add_keyword(keyword)
{
   variable word = strtrim(keyword, "`',(): \t");
   % show("adding keyword", keyword, is_defined(word));
   if( is_defined(word) > 0)      % function
     add_keyword(mode, keyword);
   if( is_defined(word) < 0)      % variable
     add_keyword_n(mode, keyword, 1);
}

% mark adorned words that match defined objects
static define help_mark_keywords()
{
   variable keyword, word, pattern,
     patterns = ["\\\`[_a-zA-Z0-9]+\\\'",
		 " [_a-zA-Z0-9]+,",
		 "[, ][_a-zA-Z0-9]+ ?$"
		 ];
   push_spot_bob();
   _add_keyword(get_word(Slang_word_chars));  % help object
   foreach pattern (patterns)
     {
	while (re_fsearch(pattern))
	  {
	     keyword = regexp_nth_match(0);
	     _add_keyword(keyword);
	     skip_word();
	  }
	% test for a SEE ALSO section (for second and third pattern)
	bob();
	!if (re_fsearch("^ *SEE ALSO"))
	  break;
     }
   pop_spot();
}

% Help Mode
% ---------

% Keybindings (customize with help_mode_hook)
!if (keymap_p (mode))
  copy_keymap (mode, "view");
definekey("context_help",     		"^M",          mode); % Return
definekey("help->goto_next_object",     "^I",          mode); % Tab
definekey("help->goto_prev_object",     Key_Shift_Tab, mode);
definekey("help->goto_next_object",     "n",          mode);
definekey("help->goto_prev_object",     "p",          mode);
definekey("help->goto_prev_object",     "b",          mode);
definekey("help_search",                "/",           mode);
definekey("apropos",                    "a",           mode);
definekey("help->grep_current_definition", "d",           mode);
definekey("describe_function",          "f",           mode);
definekey("close_and_insert_word",      "i",           mode);
definekey("close_and_replace_word",     "r",           mode);
definekey("info_mode",                  "I",           mode);
definekey("showkey",                    "k",           mode);
definekey("unix_man",                   "u",           mode);
definekey("set_variable",               "s",           mode);
definekey("describe_variable",          "v",           mode);
definekey("where_is",     		"w",           mode);
#ifexists create_circ
definekey ("help->next_topic",          ".",           mode); % dillo-like
definekey ("help->previous_topic",      ",",           mode); % dillo-like
definekey ("help->next_topic",       Key_Alt_Right,    mode); % Browser-like
definekey ("help->previous_topic",   Key_Alt_Left,     mode); % Browser-like
#endif


public define help_mode()
{
   set_readonly(1);
   set_buffer_modified_flag(0);
   set_mode(mode, 0);
   use_keymap(mode);
   help_mark_keywords();
   use_syntax_table(mode);
   set_buffer_hook("mouse_2click", &help_2click_hook);
   define_blocal_var("context_help_hook", &slang_context_help_hook);
   define_blocal_var("generating_function", current_topic);
   define_blocal_var("Word_Chars", Slang_word_chars);
   set_status_line(sprintf( "  %s   %s: %s  ",
		   whatbuf, current_topic[0], current_topic[1]), 0);
   run_mode_hooks("help_mode_hook");
   message(help_for_help_string);
}

provide(mode);
provide("hyperhelp");
