% bufutils.sl  Tools for buffer and windows handling
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms% of the GNU General Public License (version 2 or later).
%
% Versions
% --------
% 
%            1.0   first public version
%            1.1   bugfix: restore_buffer now resets the "changed on disk" flag
%            1.2   new: "blocal_hooks"
%            1.2.2 "outsourcing" of window_set_rows (hint by Thomas Clausen)
%	     1.3   moved most often used programming helpers to sl_utils.sl
%	           new: (key_prefix="") argument to rebind, rebind_reserved
%	                (hint and bugfix Paul Boekholt)
%	           rework of popup_buffer
%	             - do not reuse popups
%	             - reload old buffer when closing (Paul Boekholt)
%	     1.4   new: help_message(): Give mode-dependend help message
%	                arrayread_file(name): read file to array (P. Boekholt)
%	           changed: close_buffer calls blocal_hook
%	                    popup_buffer uses this
%	     	   moved next_buffer() to cuamisc.sl
%	     	   renamed restore_buffer() to reload_buffer() 
%	     1.4.1 bugfix popup_buffer/close_buffer/popup_close_buffer_hook
%	           bugfix reload_buffer()
% 2004-03-17 1.5   new function bufsubfile() (save region|buffer to a tmp-file)
% 2004-03-23 1.5.1 bugfix: spurious ";" in delete_temp_files()
%	     1.6   moved untab_buffer() from recode.sl here
%	     1.6.1 small bugfix in bufsubfile()
% 2005-03-24 1.7   bufsubfile() always writes a temp-file (hint P. Boekholt)
%	  	   (-> more consistency, no asking)
%	  	   removed custom var Bufsubfile_Save_Ask)
%	  	   bufsubfile() takes an optional argument `base`
% 2005-03-31 1.7.1 made slang-2 proof: A[[0:-2]] --> A[[:-2]]
% 2005-04-01 1.8   fast strread_file() (Paul Boekholt)
% 2005-04-08 1.8.1 made preparse-proof
% 	     	   "#if (_slang_version < 2000)" cannot be preparsed
% 	     1.8.2 bugfix in bufsubfile(): use path_basename() of whatbuf()
% 	           (important, if the buffer name is  e.g.
% 	           "http://jedmodes.sf.net")
% 2005-10-13 1.8.3 bugfix reload_buffer(): reset the changed on disk argument
%                  permanently
% 2005-11-08 1.8.4 simplified reload_buffer() again, as jed 0.99.17.135
% 	           will reset the buffer's ctime field if the changed-on-disk
% 	           flag is reset
% 2005-11-21 1.8.5 removed public from popup_buffer() definition
% 2005-11-25 1.8.6 bugfix in close_buffer():
%                  switch back to current buffer if closing a different one
% 2006-01-11 1.9   bugfix in close_and_insert_word and close_and_replace_word
%                  (report Paul Boekholt)
%                  revised approach to "backswitching" after a buffer is closed
% 2006-05-29 1.10  run_local_hook() tries mode_get_mode_info(hook) before
%                  get_blocal(hook)
% 	     	   custom var Jed_Temp_Dir renamed to Jed_Tmp_Directory
% 	     	   (which is new in site.sl since 0.99.17.165)
% 2006-06-19 1.11  fit_window(): abort if there is only one open window
% 2006-10-04 1.12  bufsubfile() uses make_tmp_file(), documentation update
% 2006-10-23 1.13  bugfix in bufsubfile() by Paul Boekholt
% 	     	   "\\/ " specifies a character class '/'
% 2006-11-23 1.13.1 bugfix in reload_buffer(): reset "changed on disk" flag
% 	     	    before erasing buffer (to prevent asking befor edit)
% 2007-04-18 1.14   new function run_local_function() (used in help.sl)
% 	     	    example for "Fit Window" menu entry
% 	     	    TODO: (should this become an INITIALIZATION block?)
% 2007-05-11 1.15   removed non-standard fun latex_compose() from documentation
% 		    run_local_function(): try mode-info also with 
% 		    normalized_modename()
% 		    use mode_info instead of global var for help_message()
% 2008-01-11 1.16   reload_buffer(): insert disk version, delete content later
% 	     	                     preventing an empty buffer after undo(),
%		    Minor code and doc edits (cleanup).
% 2008-01-21 1.17   fit_window(): recenter if window contains whole buffer
% 2008-05-05 1.17.1 reload_buffer(): backup buffer (if modified and backups
% 	     	    are not disabled) before re-loading)
% 2008-06-18 1.18   New function get_local_var()
% 2009-10-05 1.19   New function reopen_file()
% 2009-12-08 1.19.1 adapt to new require() syntax in Jed 0.99.19

provide("bufutils");

% Requirements 
% ------------

% Jed >= 0.99.17.135 for proper working of reload_buffer()
% but at least Jed >= 0.99.16 (mode_set_mode_info() with arbitrary fields)

% standard (but not loaded by default):
#if (_jed_version > 9918)
  require("keydefs", "Global");
#else
  require("keydefs"); % symbolic constants for many function and arrow keys
#endif

% jedmodes.sf.net modes:
autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");
autoload("run_function", "sl_utils");
autoload("get_word", "txtutils");
autoload("mark_word", "txtutils");

% Functions 
% ---------

% Convert the modename to a canonic form (the donwcased first part)
% This can be used for mode-dependend help, variables, ...
define normalized_modename() % (mode=get_mode_name())
{
   variable mode = push_defaults(get_mode_name, _NARGS);
   mode = extract_element(mode, 0, ' ');
   if (mode == "")
     mode = "no";
   return strlow (mode);
}

% Local variables, functions, and hooks
% -------------------------------------
%
% Tools for the definition and use of mode- or buffer local settings -- just like
% the indent_hook or the newline_and_indent_hook jed already provides. Extend
% this idea to additional settings that can be set by a mode and used by another.
% Allows customisation to be split in a "language" mode that provides
% functionality and an "emulation" mode that does the keybinding.
%
% Implementation is done via blocal vars and the mode_*_mode_info functions.
% 
% A hook can be defined either a pointer (reference) to a function or the function
% name as string.


%!%+
%\function{get_local_var}
%\synopsis{Return value of either buffer-local or mode-local variable.}
%\usage{get_local_var(name, default=NULL)}
%\description
%  Return the value of variable/setting \var{name}, either
%    * buffer-local (blocal) variable \var{name},
%    * mode-local (\sfun{with mode_get_mode_info}), or
%    * \var{default} (defaulting to \var{NULL})
%\notes
%  The value of a buffer- or mode-local setting is tested against
%  \var{NULL}, so e.g. a buffer-local variable with value NULL is treated 
%  like a non-existing blocal variable.
%\seealso{get_blocal_var, mode_get_mode_info, run_local_function, run_local_hook}
%!%-
define get_local_var() % (name, default=NULL)
{
   variable name, default;
   (name, default) = push_defaults( , NULL, _NARGS);
   variable value = get_blocal_var(name, NULL);
   if (value == NULL) {
      value = mode_get_mode_info(name);
      if (value == NULL) {
	 value = mode_get_mode_info(normalized_modename(), name);
	 if (value == NULL) {
	    value = default;
	 }
      }
   }
   return value;
}

%!%+
%\function{run_local_function}
%\synopsis{Run a local function if it exists, return if fun is found}
%\usage{Int_Type run_local_function(fun, [args])}
%\description
%  Similar to \sfun{run_local_hook}, but return an Integer indicating
%  whether a local function was found.
%\seealso{run_local_hook, run_function}
%!%-
define run_local_function() % (fun, [args])
{
   variable args = __pop_args(_NARGS-1);
   variable fun = ();

   variable lfun = get_local_var(fun);
   if (lfun == NULL)
     lfun = sprintf("%s_%s", normalized_modename(), fun);
   return run_function(lfun, __push_args(args));
}

%!%+
%\function{run_local_hook}
%\synopsis{Run a local hook if it exists}
%\usage{ Void run_local_hook(String hook, [args])}
%\description
%  The hook is looked for in the following places:
%
%    * the blocal variable \var{hook},
%    * the mode info field \var{hook}, or
%    * a function with name <modename>_\var{hook}
%      [i.e. sprintf("%s_%s", normalized_modename(), hook)]
%
%  and can be defined with one of
%#v+
%   define_blocal_var("<hook>", &<function_name>);
%   define_blocal_var("<hook>", "<function_name>");
%   mode_set_mode_info("<hook>", "<function_name>");
%   mode_set_mode_info("<modename>", "<hook>", "<function_name>");
%   define <modename>_<hook>() { <code> }
%#v-
%  This way a mode can set a mode- or buffer-dependent function to a common
%  keybinding.
%\example
% Set up a key to do a default action on a buffer ("run it"):
%#v+
%   define run_buffer() { run_local_hook("run_buffer_hook"); }
%   setkey("run_buffer", "^[^M");    % Alt-Return
%   mode_set_mode_info("SLang", "run_buffer_hook", "evalbuffer");
%   mode_set_mode_info("python", "run_buffer_hook", "py_exec");
%#v-
%\seealso{runhooks, run_local_function, get_blocal, run_buffer}
%!%-
define run_local_hook() % (hook, [args])
{
   variable args = __pop_args(_NARGS);
   % call run_local_function and discard the return value
   () = run_local_function(__push_args(args));
}

% deprecated, use run_local_hook instead
define run_blocal_hook() % (hook, [args])
{
   variable args = __pop_args(_NARGS-1);
   variable hook = ();
   () = run_function(get_blocal(hook, NULL), __push_args(args));
}

%!%+
%\function{run_buffer}
%\synopsis{"Run" the current buffer}
%\usage{Void run_buffer()}
%\description
%  "Run" the current buffer. The actual function performed is defined by
%  the local "run_buffer_hook" (see \sfun{run_local_hook}).
%\example
%  Some modes set the "run_buffer_hook" by themself, for others you can use
%  \sfun{mode_set_mode_info} (since Jed 0.99.17), e.g.
%#v+
%   mode_set_mode_info("SLang", "run_buffer_hook", "evalbuffer");
%#v-
%  or using mode_hooks (this variant is also proof for Jed <= 0.99.16)
%#v+
%   define calc_mode_hook ()
%   {
%      define_blocal_var("run_buffer_hook", "calc_make_calculation");
%      set_buffer_undo(1);
%   }
%#v-
%\seealso{run_local_hook, evalbuf}
%!%-
public define run_buffer()
{
   run_local_hook("run_buffer_hook");
}

% Set the mode-dependend string with help (e.g. on keybindings)
define set_help_message() % (str, mode=get_mode_name())
{
   variable str, mode; % optional argument
   (str, mode) = push_defaults(get_mode_name(), _NARGS-1);
   mode_set_mode_info(mode, "help_message", str);
}

% Show a mode-dependend string with help (e.g. on keybindings)
define help_message()
{
   variable str = get_local_var("help_message");
   if (str == NULL)
     str = sprintf("no help available for '%s' mode", get_mode_name());
   message(str);
}

% --- window operations ----------------------------------------------

%!%+
%\function{window_set_rows}
%\synopsis{Make the current window \var{n} rows big}
%\usage{window_set_rows(Int n)}
%\usage{window_set_rows(Double_Type n)}
%\description
% Resizes the current window:
%   If \var{n} is of Double_Type (e.g. 0.5), the window is rezized to
%   this fraction of the screen.
%   If there is only one window, a new window is created.
%   If \var{n} is zero, the window is deleted
%   If \var{n} is negative, the window is reduced by \var{n} lines.
%   (Use loop(n) enlargewin(); to get relative enlargement.)
%\notes
% If there are more than two windows open, the function might not work as
% desired.
%\seealso{fit_window, enlargewin, splitwindow, onewindow}
%!%-
define window_set_rows(n)
{
   % convert n from fraction to absolute if Double_Type:
   if (typeof(n) == Double_Type)
     n = int((SCREEN_HEIGHT - TOP_WINDOW_ROW - 2) * n);
   if (n == 0)
     	call("delete_window");
   if (n < 0)
       n += window_info('r');
   if (nwindows() - MINIBUFFER_ACTIVE == 1)
     splitwindow();
   if (n >= SCREEN_HEIGHT - TOP_WINDOW_ROW - 2)
     onewindow();
   variable misfit = n - window_info('r');
   if (misfit > 0) { % window too small
      loop(misfit)
	enlargewin();
   }
   if (misfit < 0) { % window too large
      otherwindow();
      loop(-misfit)
	enlargewin ();
      loop(nwindows() - 1)
	otherwindow();
   }
   if (eobp)
     recenter(n);
}

%!%+
%\function{fit_window}
%\synopsis{Fit the window size to the lenght of the buffer}
%\usage{fit_window (max_rows=1.0)}
%\description
% If there is more than one window open, the size of the current window is
% adapted to the length of the buffer it contains. The optional argument
% \var{max_rows} gives the upper limit for the window size, either as
% proportion of the total space (\var{Double_Type}) or as number of lines
% (\var{Integer_Type}). The default max_rows=1.0 means no limit, max_rows=0
% means: don't fit.
%\example
% To add a "Fit Window" entry to the "Windows" menu, you can define (or amend)
% a popup-hook e.g.
%#v+
%   autoload("fit_window", "bufutils");
%   define fit_window_load_popup_hook(menubar)
%   {
%      menu_insert_item(4, "Global.W&indows", "&Fit Window", "fit_window");
%   }
%   append_to_hook("load_popup_hooks", &fit_window_load_popup_hook);
%#v-
%\seealso{window_set_rows, enlargewin, popup_buffer}
%!%-
public define fit_window () % fit_window(max_rows = 1.0)
{
   variable max_rows = push_defaults(1.0, _NARGS);
   % abort, if there is only one window (or max_rows is 0)
   if (nwindows() - MINIBUFFER_ACTIVE == 1 or max_rows == 0)
     return;
   % convert max_rows from fraction to absolute if Double_Type:
   if (typeof(max_rows) == Double_Type)
     max_rows = int((SCREEN_HEIGHT - TOP_WINDOW_ROW - 1) * max_rows);
   % get the number of lines in the current buffer
   push_spot();
   eob;
   variable wanted_rows = what_line;
   pop_spot();
   % limit to max_rows
   if (wanted_rows > max_rows)
     wanted_rows = max_rows;
   % fit window
   window_set_rows(wanted_rows);
   % if window contains whole buffer, put last line at bottom line
   if (wanted_rows <= max_rows)
      recenter(what_line());
}

% --- closing the buffer -------------------------------------------------

%!%+
%\function{close_buffer}
%\synopsis{Close the current (or given) buffer}
%\usage{ Void close_buffer(buf = whatbuf())}
%\description
%   Close the current (or given) buffer.
%   Run the blocal "close_buffer_hook"
%\seealso{delbuf, close_window, popup_buffer, set_blocal_var}
%!%-
public define close_buffer() % (buf = whatbuf())
{
   variable buf = push_defaults(whatbuf(), _NARGS);
   variable currbuf = whatbuf();

   sw2buf(buf);
   run_local_hook("close_buffer_hook", buf);
   delbuf(buf);
   % make sure to stay in the current buffer after closing a different one
   if (currbuf != buf)
     sw2buf(currbuf);
}

% close buffer in second window if there are two windows
define close_other_buffer ()
{
   if (nwindows () - MINIBUFFER_ACTIVE > 1)
     {
	otherwindow();
	close_buffer();
     }
}

%!%+
%\function{close_and_insert_word}
%\synopsis{Close buffer, insert current word in calling buffer}
%\usage{close_and_insert_word()}
%\description
%  Close buffer, insert current word in the buffer indicated by
%  the buffer-local ("blocal") variable "calling_buffer".
%\notes
%  The \sfun{popup_buffer} function automatically records the calling
%  buffer.
%\seealso{close_and_replace_word, get_word, popup_buffer, close_buffer}
%!%-
define close_and_insert_word()
{
   variable word = get_word(),
   calling_buf = get_blocal("calling_buf", "");
   close_buffer();
   if (bufferp(calling_buf))
     sw2buf(calling_buf);
   else
     verror("calling buffer \"%s\" does not exist", calling_buf);
   insert(word);
}

%!%+
%\function{close_and_replace_word}
%\synopsis{Close buffer, replace current word in calling buffer}
%\usage{close_and_replace_word()}
%\description
%  Close buffer, insert current word into the buffer indicated by the blocal
%  variable "calling_buffer" replacing the current word (or visible region)
%  there.
%\notes
%  The \sfun{popup_buffer} function automatically records the calling
%  buffer.
%\seealso{close_and_insert_word, popup_buffer, close_buffer, get_blocal}
%!%-
define close_and_replace_word()
{
   variable word = get_word(),
   calling_buf = get_blocal("calling_buf", "");
   close_buffer();
   if (bufferp(calling_buf))
     sw2buf(calling_buf);
   else
     verror("calling buffer \"%s\" does not exist", calling_buf);
   !if (is_visible_mark)
     mark_word;
   del_region();

   insert(word);
}

% go to the buffer, if it is already visible (maybe in another window)
% open it in the current window otherwise
define go2buf(buf)
{
   if(buffer_visible(buf))
     pop2buf(buf);   % open in other window
   else
     sw2buf(buf);    % open in current window
}

% Popup Buffer
% ------------

custom_variable("Max_Popup_Size", 0.7);       % max size of one popup window

% TODO: do we want support for more than 1 popup window in parrallel 
% (i.e. more than 2 open windows):
% custom_variable("Popup_max_popups", 2);        % max number of popup windows
% custom_variable("Popup_max_total_size", 0.7);  % max size of all popup windows

% close popup window, if the buffer is visible and resizable
define popup_close_buffer_hook(buf)
{
   % abort if buffer is not attached to a window
   !if (buffer_visible(buf))
     return;

   variable replaced_buf = get_blocal("replaced_buf", "");
   variable calling_buf = get_blocal("calling_buf", "");

   % resizable popup window: close it
   if (get_blocal_var("is_popup") != 0)
     call("delete_window");
   else
     {
	if (bufferp(replaced_buf))
	  {
	     sw2buf(replaced_buf);
	     fit_window(get_blocal("is_popup", 0)); % resize popup window
	  }
     }
   % Return to the minibuffer line, if opened from there
   if (calling_buf == " <mini>" and MINIBUFFER_ACTIVE)
     loop (nwindows())
       {
          otherwindow();
          if (whatbuf() == " <mini>")
            break;
       }
   % Return to calling buffer (if it is visible, it might be annoying if
   % closing a help buffer pops up some buffer no longer in active use).
   else if (buffer_visible(calling_buf))
     sw2buf(calling_buf);
}

%!%+
%\function{popup_buffer}
%\synopsis{Open a "popup" buffer}
%\usage{popup_buffer(buf=whatbuf(), max_rows=Max_Popup_Size)}
%\description
% The "popup" buffer opens in a second window (using pop2buf).
% Closing with close_buffer closes the popup window (if new)
% or restores the previous buffer (if reused).
%
% The blocal variable "is_popup" marks the buffer as "popup".
% It contains the upper limit when fitting the window or 0 if the window
% should not be resized.
%
%\example
%  Open a popup window and fit (if applicable) after inserting stuff:
%#v+
%        popup_buffer(buf);
%        insert("hello world");
%        % insert_file("hello.txt");
%        fit_window(get_blocal("is_popup", 0));
%#v-
%
%\seealso{setbuf, sw2buf, close_buffer, fit_window, delete_window}
%!%-
define popup_buffer() % (buf=whatbuf(), max_rows = Max_Popup_Size)
{
   % get arguments
   variable buf, max_rows;
   (buf, max_rows) = push_defaults(whatbuf(), Max_Popup_Size, _NARGS);

   variable replaced_buf, calling_buf = whatbuf();
   variable open_windows = nwindows() - MINIBUFFER_ACTIVE; % before opening new
   % Open/go_to the buffer, store the replaced buffers name
   replaced_buf = pop2buf_whatbuf(buf);
   % The buffer is displayed
   %  a) in a new window or reusing a popup window
   %  -> we can savely fit the window and close it when closing the buffer
   % or
   %  b) in an existing "permanent" (non-popup) window.
   %  -> set max_rows to 0 to prevent meddling in existing split schemes.
   if (open_windows > 1)
     {
	sw2buf(replaced_buf);
	if (get_blocal("is_popup", 0) == 0)
	  max_rows = 0;
	sw2buf(buf);
     }
   define_blocal_var("is_popup", max_rows);
   define_blocal_var("close_buffer_hook", &popup_close_buffer_hook);
   define_blocal_var("replaced_buf", replaced_buf);
   if (buf != calling_buf)
     define_blocal_var("calling_buf", calling_buf);
}

% --- push_keymap/pop_keymap --- (turn on/off a minor mode) ----------------
%
% see also push_mode/pop_mode from pushmode.sl

private variable _stack_name = "keymap_stack";

% temporarily push the keymap
define push_keymap(new_keymap)
{
   !if (blocal_var_exists(_stack_name))
     define_blocal_var(_stack_name, {});
   variable keymaps = get_blocal_var(_stack_name);
   variable old_keymap = what_keymap();
   variable mode, flag;
   (mode, flag) = what_mode();
   
   use_keymap(new_keymap);
   % push the old keymap and mode name on blocal stack
   list_append(keymaps, mode);
   list_append(keymaps, old_keymap);
   % append the new keymap to the modename
   set_mode(sprintf("%s (%s)", mode, new_keymap), flag);
   %Test show("keymap stack is:", get_blocal(_stack_name));
   %Test show("current keymap is:", what_keymap());
}

define pop_keymap()
{
   variable keymaps = get_blocal_var(_stack_name);
   variable old_keymap = list_pop(keymaps, -1);
   variable old_mode = list_pop(keymaps, -1);
   variable flag;
   (, flag) = what_mode();
   
   use_keymap(old_keymap);
   set_mode(old_mode, flag);
   %Test show("keymap stack is:", get_blocal(_stack_name));
   %Test	show("current keymap is:", what_keymap());
}

%!%+
%\function{rebind}
%\synopsis{Rebind all keys bound to \var{old_fun} to \var{new_fun}.}
%\usage{rebind(old_fun, new_fun, keymap=what_keymap(), prefix="")}
%\description
% The function acts on the local keymap (if not told otherwise by the
% \var{keymap} argument. It scans for all bindings to \var{old_fun} with
% \sfun{which_key} and sets them to \var{new_fun}.
%\example
%  The email mode (email.sl) uses rebind to bind the mode-specific formatting
%  function to the key(s) used for format_paragraph:
%#v+
%  rebind("format_paragraph", "email_reformat", mode);
%#v-
%\notes
%  If the optional argument \var{prefix} is not empty, the prefix will be
%  prepended to the key to bind to. Use this to create "maps" of bindings
%  that reflect the users normal binding, e.g. with \var{_Reserved_Key_Prefix}
%  (this is what \sfun{rebind_reserved} does).
%\seealso{setkey, local_setkey, definekey, definekey_reserved}
%!%-
define rebind() % (old_fun, new_fun, keymap=what_keymap(), prefix="")
{
   variable old_fun, new_fun, keymap, prefix;
   (old_fun, new_fun, keymap, prefix) =
     push_defaults( , , what_keymap(),"", _NARGS);

   variable key;
   loop (which_key(old_fun))
   {
      key = ();
      definekey(new_fun, prefix + key, keymap);
   }
}

%!%+
%\function{rebind_reserved}
%\synopsis{Rebind a function prepending the \var{_Reserved_Key_Prefix}}
%\usage{ rebind_reserved(old_fun, new_fun, keymap)}
%\description
% Call \sfun{rebind} with \var{prefix} set to \var{_Reserved_Key_Prefix}.
%\notes
% The action is more a remodelling than a rebinding, the name should reflect
% the close relation to the \sfun{rebind} function.
%\seealso{rebind, definekey_reserved, setkey_reserved}
%!%-
define rebind_reserved(old_fun, new_fun, keymap)
{
   rebind(old_fun, new_fun, keymap, _Reserved_Key_Prefix);
}

% --- some more buffer related helpers ----------------------------------

%!%+
%\function{buffer_dirname}
%\synopsis{Return the directory associated with the buffer}
%\usage{Str buffer_dirname(buf=whatbuf())}
%\description
%   Return the directory associated with the buffer
%\seealso{getbuf_info, buffer_filename}
%!%-
define buffer_dirname()
{
   variable dir, args = __pop_args(_NARGS);
   ( , dir, , ) = getbuf_info(__push_args(args));
   return dir;
}

%!%+
%\function{arrayread_file}
%\synopsis{Read a file and return it as array of lines.}
%\usage{Array[String] arrayread_file(name)}
%\description
%   Read a file and return it as a String_Type array of lines.
%   Newlines are preserved.
%\notes
% To get rid of the newlines, you can do
%#v+
%  result = array_map(String_Type, &strtrim_end, arrayread_file(name), "\n");
%#v-
%\seealso{strread_file, fgetslines}
%!%-
define arrayread_file(name)
{
   variable fp = fopen (name, "r");
   if (fp == NULL) verror ("File %s not found", name);
   fgetslines(fp);
   () = fclose (fp);
}

%!%+
%\function{strread_file}
%\synopsis{Read a file and return as (binary) string}
%\usage{BString strread_file(String name)}
%\description
%   Read a file and return as string (\var{BString_Type}).
%\notes
%   If the file size exceeds the internal limit (currently 5MB),
%   an error is returned.
%\seealso{arrayread_file, find_file, fread, fread_bytes}
%!%-
define strread_file(name)
{
   % return strjoin(arrayread_file(name), "");
   variable size_limit = 5000000; % this should be a custom var
   variable fp = fopen(name, "r"), str;
   if (fp == NULL)
     verror ("Failed to open \"%s\"", name);
#ifnexists _slang_utf8_ok   % (_slang_version < 2000)
   if (-1 == fread(&str, Char_Type, size_limit, fp))
#else
   if (-1 == fread_bytes(&str, size_limit, fp))
#endif
     error("could not read file");
   !if (feof(fp))
     verror("file exceedes limit (%d bytes)", size_limit);
   return str;
}

%!%+
%\function{reload_buffer}
%\synopsis{Restore (or update) a buffer to the version on disk}
%\usage{reload_buffer()}
%\description
%  Replace the buffer contents with the content of the associated file.
%  This will restore the last saved version or update (if the file changed
%  on disk).
%\seealso{insert_file, find_file, write_buffer, make_backup_filename}
%!%-
public define reload_buffer()
{
   variable file, dir, name, flags;
   (file, dir, name, flags) = getbuf_info();
   variable col = what_column(), line = what_line();

   % save to backup file 
   if (flags & 0x001            % buffer modified
       and not(flags & 0x100))  % backups (not) disabled
     {
	% use write_region_to_file() to prevent attaching buffer to backup file
	mark_buffer();
	() = write_region_to_file(make_backup_filename(dir, file));
     }
   
   % Variant: only update (make this an option?)
   % !if (flags & 4)
   %   return;
     
   % reset the changed-on-disk flag
   setbuf_info(file, dir, name, flags & ~0x004);
   
   erase_buffer(whatbuf());
   () = insert_file(path_concat(dir, file));
   
   goto_line(line);
   goto_column_best_try(col);
   set_buffer_modified_flag(0);
}

%!%+
%\function{reopen_file}
%\synopsis{Re-open file \var{file}.}
%\usage{reopen_file(file)}
%\description
% In contrast to \sfun{reload_buffer}, \sfun{reopen_file} takes a 
% (full) filename as argument.
% 
% To prevent questions about changed versions on disk, it avoids switching
% to the buffer. Instead, it closes the buffer and re-loads the file with
% find_file(). 
% 
% Does nothing if file is up-to-date or not attached to any buffer.
%\seealso{}
%!%-
define reopen_file(file)
{
   % Put the list of buffers in an array instead of looping over
   % buffer_list(). This way leftovers after a `break` or `return` are 
   % automatically removed from the stack.
   variable buffers = [buffer_list(), pop];    
   variable buf, dir, f, flags;
   foreach buf (buffers) {
      (f, dir, ,flags) = getbuf_info(buf);
      if (dir + f == file and  flags & 4) { % file that changed on disk
	 delbuf(buf);
	 () = find_file(file);
	 % try to restore the point position from the recent files cache
	 call_function("recent_file_goto_point");   
	 break;
      }
   }
}

% ------- Write the region to a file and return its name. -----------------

% Directory for temporary files

% Backwards compatibility to earlier versions of bufutils.sl
#ifexists Jed_Temp_Dir
custom_variable("Jed_Tmp_Directory", Jed_Temp_Dir);
#endif

custom_variable("Jed_Tmp_Directory", getenv("TEMP"));
if (Jed_Tmp_Directory == NULL)
  Jed_Tmp_Directory = getenv("TMP");
if (Jed_Tmp_Directory == NULL)
  Jed_Tmp_Directory = "/tmp";

% list of files to delete at exit
% (defined with custom_variable, so a reevaluation of bufutils will not
%  delete the existing list.)
 custom_variable("Bufsubfile_Tmp_Files", "");

% cleanup at exit
static define delete_temp_files()
{
   variable file;
   foreach file (strchop(strtrim_beg(Bufsubfile_Tmp_Files), '\n', 0))
     if (file_status(file) == 1)
       delete_file(file);
   return 1;
}
add_to_hook("_jed_exit_hooks", &delete_temp_files);

%!%+
%\function{bufsubfile}
%\synopsis{Write region|buffer to a temporary file and return its name.}
%\usage{String = bufsubfile(delete=0, base=NULL)}
%\description
%   Write the region to a temporary file. If no visible region is defined,
%   write the whole buffer.
%
%   If \var{base} is not absolute, the file is written to the \var{Jed_Tmp_Directory}.
%   If \var{base} == NULL (default), the buffer-name is taken as basename
%   If \var{delete} != 0, delete the region|buffer after writing.
%
%   Return the full filename.
%
%   The temporary file will be deleted at exit of jed (if the calling
%   function doesnot delete it earlier).
%\notes
%   bufsubfile() enables shell commands working on files
%   to act on the current buffer and return the command output.
%    * run_shell_cmd() returns output but doesnot take input from jed,
%    * pipe_region() only takes input but outputs to stdout, but
%    * shell_cmd_on_region() uses bufsubfile() and run_shell_cmd() for
%      bidirectioal interaction
%   As some commands expect a certain file extension, the extension of
%   \var{base} is added to the temporary file's name.
%\seealso{make_tmp_file, is_visible_mark, push_visible_mark,
%\seealso{run_shell_cmd, shell_cmd_on_region, filter_region}
%!%-
define bufsubfile() % (delete=0, base=NULL)
{
   variable delete, base, filename, extension;
   (delete, base) = push_defaults(0, NULL, _NARGS);
   push_spot ();

   !if (is_visible_mark)
     mark_buffer();
   if (delete)
     () = dupmark();
   % create a unique filename (keeping the extension)
   if (base == NULL)
     base = str_delete_chars(path_basename(whatbuf()), "*+<>:/ \\");
   extension = path_extname(base);
   base = path_sans_extname(base);
   do
     {
        filename = strcat(make_tmp_file(base), extension);
     }
   while (file_status(filename));

   % write region/buffer to temporary input file
   () = write_region_to_file(filename);
   if (delete)
     del_region();
   % delete the file at exit
   Bufsubfile_Tmp_Files += "\n" + filename;
   pop_spot();

   % show("bufsubfile:", filename, Bufsubfile_Tmp_Files);
   return filename;
}

%!%+
%\function{untab_buffer}
%\synopsis{Untab the whole buffer}
%\usage{Void untab_buffer()}
%\description
%  Convert all hard tabs ("\\t") in the current buffer into spaces. The
%  buffer-local value of \var{TAB} determines how many spaces are used for the
%  substitution.
%\notes
%  Whether hard Tabs will be used for editing is defined by the
%  global variable \var{USE_TABS} and the buffer-local variable \var{TAB}.
%\seealso{untab}
%!%-
public define untab_buffer ()
{
   push_spot();
   mark_buffer();
   untab ();
   pop_spot();
}
