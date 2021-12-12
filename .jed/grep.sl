% JED interface to the grep command
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions
% --------
% 
% 0.9.1  2003/01/15
%   * A remake of Dino Sangois jedgrep under use of the new listing
%     and filelist modes. (Which are inspired by the old jedgrep by Dino!)
%   * grep_replace_cmd: Replace in the grep results
%     (both, result display and source files!)
% 0.9.2 2003/07/09
%   * bugfix contract_filename did not work properly (needs chdir() first)
% 0.9.3 2004-01-30
%   * solved bug with only one file (using -H option) [Peter Bengtson]
%   * recursive grep with special filename bang (!) (analog to kpathsea),
%     i.e. grep("pat", "dir/!") gets translated to `grep -r pat dir/`
% 0.9.4 2004-04-28
%   * close grep buffer, if the return value of the grep cmd is not 0
% 0.9.5 2005-11-07
%   * change _implements() to implements() (this will only affect re-evaluating
%     sl_utils.sl in a JED < 0.99.17, so if you are not a developer on an older
%     jed version, it will not harm).
% 0.9.6 2006-02-02 bugfix and code cleanup in grep_replace_*
%                  (using POINT instead of what_column(), as TAB expansion
%                   might differ between grep output and referenced buffer)
% 1.0 2006-03-09
%   * provide for --include pattern with recursive grep,
%   * escape the `what' argument with quotes
%     (this prevents ugly surprises with shell expansion but disables the
%     trick to put command line options into  `what').
%       grep("pat", "dir/*.sl!") --> `grep -r --include='*.sl', 'pat' dir/`
%   * change name of the custom var to Grep_Cmd to adhere to the
%     "<capitalized-modename>_*" convention.
% 1.1   2006-03-20  fixed cleanu p in zero-output handling in grep().
% 1.1.1 2006-06-28  fixed deletion of last empty line in grep() output
% 1.1.2 2006-09-20  bugfix in grep_fsearch(): did not find matches right
% 		    after the separator
% 1.1.3 2006-09-22  removed spurious debug output (report P Boekholt)
% 1.1.4 2007-02-23  bugfix: grep() did recursive grep for empty basename
% 		    in grep pattern
% 1.1.5 2007-04-19  added mode menu and more Customisation hints
% 1.1.6 2007-10-04  no DFA highlight in UTF-8 mode (it's broken)
%       2007-10-23  no DFA highlight cache (it's just one rule)
% 1.1.7 2007-12-20 name grep->grep_replace_cmd() to grep->replace_cmd()
% 		    rebind also cua_replace_cmd() to grep->replace_cmd()
%                   apply Jörg Sommer's DFA-UTF-8 fix and re-enable highlight
% Usage
% -----
%
% * from jed:  `M-x grep` (or bind to a key)
% 
% * from the command line: `grep -nH "sometext" * | jed --grep_mode`
% 
%   - You should have grep_mode in your autoload list for this to work.
%   - Does not work for xjed, use e.g. `xjed -f "grep(\"sometext\", \"*\")"`
%     or the X selection.
%
% * To open a file on a result line, go to the line press ENTER or double click
%   on it
%
% * To replace text across the matches (both, grep output buffer and source
%   files), use the keybinding for the replace_cmd() or the Mode menu.
%   
%   (Find it with 'Help>Where is Command' replace_cmd, in any buffer but the
%   *grep-output*)
%
% Customisation
% -------------
% 
% You can
% 
% * set the grep command to use with grep(), e.g in your .jedrc::
% 
%     variable Grep_Cmd = "rgrep -nH";
%
% * customize the jedgrep_mode using the "grep_mode_hook", e.g.::
%   
%     % give the result-buffer a number
%     autoload("number_buffer", "numbuf"); % jedmodes.sf.net/mode/numbuf/
%     define grep_mode_hook(mode)
%     {
%        number_buffer();
%     }
%   
% * use current word as default pattern :
%         
%   If you want the word at the cursor position (point)  as pattern (without
%   asking in the minibuffer), use something like
%   
%     definekey("^FG", "grep(get_word())")
%   
%   If you want the current word as default pattern (instead of the LAST_GREP
%   pattern), define a wrapper (and bind this to a key), e.g.
%   
%     define grep_word_at_point()
%     {
%        grep(read_mini("String to grep: ", get_word, ""));
%     }
%   
%   Or, with the word at point as init string (so it can be modified)
%   
%     define grep_word_at_point2()
%     {
%        grep(read_mini("String to grep: ", "", get_word,));
%     } 
%
% TODO: use search_file and list_dir if grep is not available
%       make it Windows-secure (filename might contain ":")

% _debug_info=1;

% --- Requirements --------------------------------------------- %{{{
% standard modes
require("keydefs");
autoload("replace_with_query", "srchmisc");
% nonstandard modes (from jedmodes.sf.net)
require("bufutils"); % autoloads "txtutils"
require("filelist"); % which requires "listing", "view", and "datutils"
autoload("contract_filename", "sl_utils");
autoload("get_word", "txtutils");
%}}}

% --- name it
provide("grep");
implements("grep");
private variable mode = "grep";

% --- Variables -------------------------------------------------%{{{

% the grep command
%!%+
%\variable{Grep_Cmd}
%\synopsis{shell command used by \slfun{grep}}
%\usage{variable Grep_Cmd = "grep -nH"}
%\description
%  The shell command which is called by \slfun{grep}.
%  Customize this to provide command line options or use a variant of grep
%  like `agrep`, `egrep`, or `fgrep`.
%\notes
%  In order to go to the filename and line-number, grep_mode assumes the
%  -n and -H argument set.
%\seealso{grep, grep_mode}
%!%-
custom_variable("Grep_Cmd", "grep -nH");

% remember the string to grep (as default for the next run) (cf. LAST_SEARCH)
static variable LAST_GREP = "";

%}}}

% --- Replace across files ------------------------------------- %{{{

% Return the number of open buffers
static define count_buffers()
{
   variable n = buffer_list();  % returns names and number of buffers
   _pop_n(n);                   % pop the buffer names
   return n;
}

% Compute the length of the statistical data in the current line
% (... as we have to skip spurious search results in this area)
static define grep_prefix_length()
{
   push_spot_bol();
   EXIT_BLOCK { pop_spot(); }
   loop(2)
     {
	() = ffind_char(get_blocal("delimiter", ':'));
	go_right_1();
     }
   return POINT; % POINT starts with 0, this offsets the go_right_1
}

% fsearch in the grep results, skipping grep's statistical data
% return the length of the pattern found or -1
private define grep_fsearch(pat)
{
   variable pat_len;
   do
     {
	pat_len = fsearch(pat);
	!if(pat_len)
	  break;
	if (POINT >= grep_prefix_length())
	  return pat_len;
     }
   while(right(1));
   return -1;
}

% The actual replace function
% (replace in both, the grep output and the referenced file)
private define grep_replace(new, len)
{
   variable buf = whatbuf(),
   no_of_bufs = count_buffers(),
   pos = POINT - grep_prefix_length(),
   old;

   % get (and delete) the string to be replaced
   push_mark(); () = right(len);
   old = bufsubstr_delete();
   push_spot();

   ERROR_BLOCK
     {
	% close referenced buffer, if it was not open before
	if (count_buffers > no_of_bufs)
	  {
	     save_buffer();
	     delbuf(whatbuf);
	  }
	% insert the replacement into the grep buffer
	sw2buf(buf);
	pop_spot();
        set_readonly(0);
        insert(old);
     }

   % open the referenced file and goto the right line and pos
   filelist_open_file();
   bol;
   go_right(pos);

   % abort if looking at something different
   !if (looking_at(old))
     {
	push_mark(); () = right(len);
	verror("File differs from grep output (looking at %s)", bufsubstr());
     }

   len = replace_chars(len, new);

   old = new;
   EXECUTE_ERROR_BLOCK; % close newly opened buffer, return to grep results

   return len;
}

% Replace across files found by grep (interactive function)
static define replace_cmd()
{
   variable old, new;

   % find default value (region or word under cursor)
   % and set point to begin of region
   if (is_visible_mark)
     check_region(0);
   else
     mark_word();
   exchange_point_and_mark; % set point to begin of region

   old = read_mini("Grep-Replace:", "", bufsubstr());
   !if (strlen (old))
     return;
   new = read_mini(sprintf("Grep-Replace '%s' with:", old), "", "");

   ERROR_BLOCK
     {
	REPLACE_PRESERVE_CASE_INTERNAL = 0;
	set_readonly(1);
	set_buffer_modified_flag(0);
     }

   set_readonly(0);
   REPLACE_PRESERVE_CASE_INTERNAL = REPLACE_PRESERVE_CASE;
   replace_with_query (&grep_fsearch, old, new, 1, &grep_replace);

   EXECUTE_ERROR_BLOCK;
   message ("done.");
}
%}}}

% grep mode 
% ---------

% %{{{

create_syntax_table(mode);

#ifdef HAS_DFA_SYNTAX
dfa_define_highlight_rule("^[^:]*:[0-9]+:", "keyword", mode);
% render non-ASCII chars as normal to fix a bug with high-bit chars in UTF-8
dfa_define_highlight_rule("[^ -~]+", "normal", mode);
dfa_build_highlight_table(mode);
enable_dfa_syntax_for_mode(mode);
#endif

!if(keymap_p(mode))
{
   copy_keymap(mode, "filelist");
   rebind("replace_cmd", "grep->replace_cmd", mode);
   rebind("cua_replace_cmd", "grep->replace_cmd", mode);
}

% --- the mode dependend menu
static define grep_menu(menu)
{
   filelist->filelist_menu(menu);
   menu_insert_item("&Grep", menu, "&Replace across matches", "grep->replace_cmd");
   menu_delete_item(menu + ".&Grep");
   menu_delete_item(menu + ".Tar");
}


%}}}

% Interface: %{{{

%!%+
%\function{grep_mode}
%\synopsis{Mode for results of the grep command}
%\usage{grep_mode()}
%\description
%   A mode for the file listing as returned by \sfun{grep} or the "grep -Hn"
%   command line tool. Provides highlighting and convenience functions. 
%\seealso{grep, grep_replace, filelist_mode}
%!%-
public define grep_mode()
{
   define_blocal_var("delimiter", ':');
   define_blocal_var("line_no_position", 1);
   filelist_mode();
   set_mode(mode, 0);
   use_syntax_table (mode);
   use_keymap(mode);
   mode_set_mode_info(mode, "init_mode_menu", &grep_menu);
   run_mode_hooks("grep_mode_hook");
}

% TODO: What does gnu grep expect on DOS, What should this be on VMS and OS2 ?
%!%+
%\function{grep}
%\synopsis{Grep interface}
%\usage{grep(String what=NULL, String path=NULL)}
%\description
%  Grep for "what" in the file(s) "path".
%
%  If the optional arguments are missing, they will be asked for in
%  the  minibuffer.
%
%  \sfun{grep} adds an extension to the shell pattern replacement mechanism:
%  the special filename bang (!) indicates a recursive grep in subdirs
%  (analog to kpathsea), i.e. grep("pat" "path/*.sl!") translates to
%  `$Grep_Cmd -r --include='*.sl', 'pat' path`
%
%  Other than this, normal shell expansion is applied to "path".
%
%  The grep command and options can be set with the custom
%  variable  \var{Grep_Cmd}.
%
%  The buffer is set to \sfun{grep_mode}, so you can go to the matching
%  lines  or find-and-replace accross the matches.
%
%\seealso{grep_mode, grep_replace, Grep_Cmd}
%!%-
public define grep() % ([what], [path])
{
   % optional arguments, ask if not given
   variable what, path;
   (what, path) = push_defaults( , , _NARGS);
   if (what == NULL)
     {
	what = read_mini("String to grep: ", LAST_GREP, "");
	LAST_GREP = what;
     }
   if (path == NULL)
     path = read_with_completion ("Where to grep: ", "", "", 'f');

   variable cmd, options = "", dir = buffer_dirname(), allfiles, status,
     basename = path_basename(path);
#ifdef UNIX
   allfiles = "*";
#elifdef IBMPC_SYSTEM
   allfiles = "*.*";
#else
   allfiles = "";
#endif

   % set the working directory
   () = chdir(dir);

   % Build the command string:

   % The output buffer will be set to the active buffer's dir
   % If the path starts with dir, we can strip it.
   % (Note: this maight fail on case insensitive filesystems).
   path = contract_filename(path);

   % recursive grep with special char '!' (analog to kpathsea)
   if (andelse{basename != ""}
	 {substr(basename, strlen(basename), 1 ) == "!"})
     {
	options = "-r";
	path = path_dirname(path);
	basename = strtrim_end(basename, "!");
	if (basename != "")
	  options += sprintf(" --include='%s'", basename);
     }
   % append wildcard, if no filename (or pattern) is given
   if (basename == "")
     path = path_concat(path, allfiles);

   cmd = strjoin([Grep_Cmd, options, what, path], " ");

   % Prepare the output buffer
   popup_buffer("*grep-output*", FileList_max_window_size);
   setbuf_info("", dir, "*grep-output*", 0);
   erase_buffer();
   set_buffer_modified_flag(0);

   % call the grep command
   flush("calling " + cmd);
   status = run_shell_cmd(cmd);

   switch (status)
     { case 0: message("matches found"); }
     { case 1: vinsert("No results for `%s`", cmd); }
     { case 2: vinsert("Error (or file not found) in `%s`", cmd); }
     { vinsert("`%s` returned %d", cmd, status); }
   if (bolp() and eolp())
     delete_line();
   fit_window(get_blocal("is_popup", 0));
   bob();
   set_status_line("Grep: " + cmd + " (%p)", 0);
   define_blocal_var("generating_function", [_function_name, what, path]);
   grep_mode();
}

%}}}

provide(mode);
