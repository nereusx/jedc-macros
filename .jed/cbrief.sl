%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	BRIEF emulation for JED
%%
%%	Copyleft (c) 2016-17 Nicholas Christopoulos.
%%	Released under the terms of the GNU General Public License (ver. 3 or later)
%%
%%	2017-07-17 Nicholas Christopoulos
%%		RE help added
%%	2016-09-05 Nicholas Christopoulos
%%		Rewritten the old brief.sl from scratch, the old module
%%		still included as mm-brief.sl file and it is used.
%%	2019-11-26 Nicholas Christopoulos
%%		xclip used for clipboard, allows to copy/paste text even from terminal version.
%%		Alt+Ctrl+C = xcopy, Alt+Ctrl+V = xpaste, Alt+Ctrl+X = xcut
%%	2021-01-09 Nicholas Christopoulos
%%		'<!' and '<' at command line
%%
%%	Based on: BRIEF v3.1, 1991 and secondary on BRIEF v2.1, 1988
%%	
%%	Brief Manual:
%%	=============
%%	BRIEF is a "modeless" editor, meaning that the commands have
%%	the same meaning almost all the time.
%%
%%	Missing:
%%		* set macro buffer (the reverse function of get_last_macro) - ndc patch - test
%%		* region must extends to the cursor (its cell) - ndc patch - ok, test column
%%		* correct line-block selection with whole lines highlight - ndc patch - ok
%%		* windows and listboxes (eye-candy/ergonomic)
%%		* moving around empty space without adding characters
%%		* I have no detailed manual about each macro parameters, I have to check all
%%			to see whatever I ll find.
%%
%%	Wishes:
%%		* the newt libraty is based on slang, you can include it
%%			Actually I found a listbox and a popup menu that is what
%%			are missing. May Jed help me how to use his menu popup
%%			without menus.
%%		* better blink_match, by changing the attribute of the
%%			second matching char <-- waitting, for now it is disabled
%%		* is_xjed() or is_???jed() should be internal of jed
%%			at compile time <-- jed said XWINDOWS do that
%%		* status line string with size format (example %03c for
%%			columns, %5u for lines); without the size, by moving
%%			the cursor, moving the whole status line and that
%%			 is annoying. -- ndc-patch - ok
%%		* Regular expression manual... At least, is it POSIX? <-- check utf8
%%		* Whitesmiths/Ratliff C Style mode. <-- todo
%%		* One ESC after 1 sec to be \e\e\e, somehow to enable/disable
%%			<-- just an idea, i personal have no problem...
%%
%%	Notes:
%%	
%%		* Console
%%		
%%		The console (F10) executes BRIEF's macros as we remember,
%%		assign_to_key, brace, slide_in, etc (see help/macros)
%%		
%%		but, if the first character(s) is(are):
%%		==================================================================
%% $	then executes in the shell the following commands with eval(); this
%%		means slang code.
%%	
%% ?	it prints whatever it follows. (slang)
%%		Example: '? 60*sin(0.8), buffer_filename()'
%%
%% !	executes the rest commands with the shell and insert the output
%%		to a new buffer.
%%
%% &	executes the rest commands with the shell in the background and
%%		in new terminal.
%%
%% <!	executes the rest commands with the shell and inserts the output
%%		in the current buffer
%%
%% <	insert the contents of the file to current position, if file is not specified
%% 		then it will prompt for the name.
%%
%% >	writes the selected text to a new file.
%%
%% >>	appends the selected text to a file.
%%
%% |	(pipe) sends the selected text as standard input to the command
%%		that follows.
%%
%%	Notes 4 JED:
%%		* In Unix command line option +N moves to N line. (-g N)
%%	
%%	Tested:
%%		On my Slackware64 14.2 box, with JED pre0.99.20-117 and SLang 2.3.0
%%
%%	Requirements:
%%		x-keydefs.sl	-- fixed keys and keypad codes from jedmodes package
%%						This is a simple file, does req. nothing.
%%						(http://jedmodes.sourceforge.net/)
%%
%%	Recommended:
%%		hyperman.sl		-- a much better man-page viewer from jedmodes
%%						(http://jedmodes.sourceforge.net/)
%%
%%	Required for X Clipboard:
%%		xclip CLI utility
%%	
%%	Install:
%%		Copy cbrief.sl, cbufed.sl, chelp.sl and mm-briefmsc.sl
%%		to your $JED_HOME or $JED_ROOT/lib
%%		
%%		Add this line to your config file ($JED_HOME/.jedrc) as the
%%		first module.
%%		
%%			require("cbrief");
%%

() = evalfile("sys/mouse.sl");
require("sys/x-keydefs");			% fixed keys and keypad codes (jedmodes package)
require("mm-briefmsc");				% Guenter Milde and Marko Mahnic BRIEF module
require("cbufed");					% list_buffers() replacement
require("chelp");					% help() replacement
require("sys/mini");
require("tabs");					% Tab_Stops and tabs_edit()
require("dired");					% Nice addon for F11

% --- compile.sl ---
% 
%   compile_parse_errors                parse next error
%   compile_previous_error              parse previous error
%   compile_parse_buf                   parse current buffer as error messages
%   compile                             run program and parse it output
%   compile_select_compiler             set compiler for parsing error messages
%   compile_add_compiler                add a compiler to database
%
%   Compile_Default_Compiler			public variable
% 
require("compile");

%% --- before start -------------------------------------------------------
private variable jed_home = Jed_Home_Directory;

public define is_xjed()
{
	if ( is_defined("x_server_vendor") )
		return 1;
	return 0;
}
private variable term = NULL;
if ( is_xjed() )
	term = "xjed";
else
	term = getenv("TERM");
if ( term == NULL ) term = "ansi";

variable x_copy_region_to_selection_p;
if ( is_defined("x_server_vendor") )
	x_copy_region_to_selection_p = __get_reference("x_copy_region_to_selection");
else
	x_copy_region_to_selection_p = NULL;

variable x_insert_selection_p = __get_reference("x_insert_selection");
if ( is_defined("x_server_vendor") )
	x_insert_selection_p = __get_reference("x_insert_selection");
else
	x_insert_selection_p = NULL;

%% 
private variable Key_Enter = Key_Return;
private variable Key_Alt_Enter = Key_Alt_Return;
private variable Key_Ctrl_Enter = Key_Ctrl_Return;
private variable Key_KP_Minus =	Key_KP_Subtract;
private variable Key_KP_Plus = Key_KP_Add;
private variable Key_KP_Del = Key_KP_Delete;
private variable Key_KP_Ins = Key_KP_0;

%% --- start here ---------------------------------------------------------

provide("cbrief");

_Jed_Emulation = "cbrief";
private variable _help_file = "cbrief.hlp";
Help_File = _help_file;

private variable _help_buf = "*help*";	% help-buffer name
private variable _long_help_file = "cbrief-l.hlp"; % full help file

% run-time flags
private variable _block_search = 1;		% 1 = search/translate only inside blocks
private variable _search_forward = 1;	% search direction, >0 = forward, <0 = backward
private variable _regexp_search = 0;	% 1 = search/translate use regular expressions
private variable _search_case = 1;		% 1 = case sensitive search

private variable _has_set_last_macro = is_defined("set_last_macro");
#ifndef CBRIEF_PATCH_V1
private variable CBRIEF_FLAGS = 1;
private variable CBRIEF_SELCOLPOS = 1;
private define set_last_macro(s) { }
#else
%% This integer is the communication with the C code.
%% 0x01 = X11 reversed cursor
%% 0x02 = Inclusive selection mode
%% 0x04 = Line selection mode
%% 0x08 = Column selection mode
CBRIEF_FLAGS = 0x01;
CBRIEF_SELCOLPOS = 1;
#endif

private define _setbf(v,n)				{ @v = @v | n;  }
private define _unsetbf(v,n)			{ @v = @v & ~n; }
private define cbrief_set_flags(n)		{ CBRIEF_FLAGS = CBRIEF_FLAGS | n;  }
private define cbrief_unset_flags(n)	{ CBRIEF_FLAGS = CBRIEF_FLAGS & ~n; }

%!%+
%\variable{_cbrief_version}
%\synopsis{Numeric value of script version}
%\description
%	Numeric value of script version.
%!%-
public variable _cbrief_version = 0x10003;

%!%+
%\variable{_cbrief_version_string}
%\synopsis{String value of script version}
%\description
%	String value of script version.
%!%-
public variable _cbrief_version_string = "1.0.3";

%!%+
%\variable{CBRIEF_KBDMODE}
%\synopsis{keyboard mode}
%\description
%	Integer CBRIEF_KBDMODE = 0x20 | 0x08 | 0x04 | 0x02 | 0x01;
%	
%	This variable controls how the CBRIEF should work with keyboard.
%
%	Keyboard mode
%		0x00 = Default, Minimum BRIEF keys.
%		0x01 = Extentions in case of non-keypad/non-f-keys (alt+f/ctrl+f,..)
%		0x02 = Add Windows Clipboard keys (ctrl+c,x,v)
%		0x04 = Get control of window-keys
%		0x08 = Additional keys (alt+],alt+<,alt+>,...)
%		0x10 = Get control of line_indent
%		0x20 = Get control of Tabs
%		0x40 = LAPTOP mode (ctrl+left/right = home/end, ctrl+up/down = page up/down)
%		0x80 = Readline Home/End (ctrl+a/e = home/end)
%!%-
custom_variable("CBRIEF_KBDMODE", 0x20 | 0x08 | 0x04 | 0x02 | 0x01 | 0x40 | 0x80);

%!%+
%\variable{CBRIEF_OPTSF}
%\synopsis{CBRIEF Options}
%\description
%	Integer CBRIEF_OPTSF = 0;
%	
%	This variable controls how the CBRIEF should take care
%	several matters.
%
%	0x01 = Alt+Z = Suspend JED; otherwise it runs in a shell.
%!%-
custom_variable("CBRIEF_OPTSF", 0x00);

%!%+
%\variable{CBRIEF_XTERM}
%\synopsis{x terminal emulator}
%\description
% This variable is the x-terminal emulator that will be used by CBRIEF.
% By default has code to assign one when its needed.
% If user want something else can be set it in this variable.
%!%-
custom_variable("CBRIEF_XTERM", "");

%% --- utilities ----------------------------------------------------------
private define cbrief_readline_mode()	{ return (CBRIEF_KBDMODE & 0x80); }
private define cbrief_laptop_mode()		{ return (CBRIEF_KBDMODE & 0x40); }
private define cbrief_control_tabs()	{ return (CBRIEF_KBDMODE & 0x20); }
private define cbrief_control_indent()	{ return (CBRIEF_KBDMODE & 0x10); }
private define cbrief_more_keys()		{ return (CBRIEF_KBDMODE & 0x08); }
private define cbrief_control_wins()	{ return (CBRIEF_KBDMODE & 0x04); }
private define cbrief_windows_keys()	{ return (CBRIEF_KBDMODE & 0x02); }
private define cbrief_nopad_keys()		{ return (CBRIEF_KBDMODE & 0x01); }
public  define cbrief_setlaptopmode()	{ CBRIEF_KBDMODE |= 0x40; }

private define _argc(argv)		{ return (NULL == argv) ? 0 : length(argv); }
%private define _isyes(s)		{ return (string_match(s, "[1YyTt]") != 0); }
private define onoff(val)		{ return ( val ) ? "on" : "off"; }

public define cbrief_reset();

%% returns the numeric value of the hexadecimal digit 'ch'
private define _chex2dig(ch)
{
	if ( isdigit(ch) )				return ch - '0';
	if ( ch >= 'a' && ch <= 'f')	return (ch - 'a') + 10;
	if ( ch >= 'A' && ch <= 'F' )	return (ch - 'A') + 10;
	return 0;
}

%%
private define _get_symbol(ch)
{
	if ( _slang_utf8_ok ) {
		% notes: latin-1 characters can be used also in 8bit, in almost all european languages
		switch ( ch )
			{ case 'f' or case 'd':	return '↓'; } % latin-1
			{ case 'b' or case 'u':	return '↑'; } % latin-1
			{ case 'l': return '←'; } % latin-1
			{ case 'r': return '→'; } % latin-1
			{ case '@': return '■'; } % latin-1
			{ case '.': return '…'; }
			{ case '`': return '“'; }
			{ case '\'': return '”'; }
			{ case '[': return '‹'; }
			{ case ']': return '›'; }
			{ case 'x': return '※'; } % reference mark
			{ case '+': return '†'; } % dagger
			{ case '#': return '‡'; } % double dagger
			{ case '-': return '─'; } % (box drawing horz. line)
			{ case '|': return '│'; } % (box drawing vert. line)
			{ case 'p': return '±'; } % plus/minus (latin-1)
			{ case '2': return '²'; } % (latin-1)
			{ case '3': return '³'; } % (latin-1)
			{ case 's': return '§'; } % section sign (latin-1)
			{ case '*': return '•'; } % bullet
			{ case 'T': return '‥'; } % PASCALoid 'TO'
			{ case 'o': return '°'; } % degrees (latin-1)
			{ case '<': return '«'; } % frensh/greek quotes (latin-1)
			{ case '>': return '»'; } % frensh/greek quotes (latin-1)
			{ case 'E': return '⏎'; }
			{ case '\0': return '␀'; }
			{ case '\e': return '␛'; }
			{ case ' ': return '␠'; }
			{ case '\t': return '␉'; }
			{ case '\r': return '␍'; }
			{ case '\n': return '␊'; }
			{ case '\a': return '␇'; }
			{ case '\b': return '␈'; }
			{ case '\v': return '␋'; }
			{ case '\f': return '␌'; }
			% greek
			{ case '·': return '·'; } % middle-dot (keyboard's ano teleia)  -> greek ano teleia
			{ case '&': return 'ϗ'; } % ambersand
			{ case 'Q': return 'Ϙ'; } % koppa (number 90, archaic, modern is like thunderstrike, i hate it)
			{ case 'q': return 'ϙ'; } % koppa
			{ case 'Τ': return 'Ϛ'; } % stigma (number 6), digraph of CT
			{ case 'τ': return 'ϛ'; } % stigma
			{ case 'Γ': return 'Ϝ'; } % digamma (number 6)
			{ case 'γ': return 'ϝ'; } % digamma
			{ case 'Σ': return 'Ϲ'; } % secondary sigma 
			{ case 'σ': return 'ϲ'; } % secondary sigma
			{ case 'ε': return 'ϵ'; } % secondary e, the capital is missing!
			{ case 'Μ': return 'Ϡ'; } % sampi (number 900)
			{ case 'μ': return 'ϡ'; } % sampi
			{ case ':': return '⁝'; } % tricolon
		}
	return ch;
}

%%
private define _get_ssymbol(str)
{
	if ( str == ">" ) { % scroll/right
		if ( _slang_utf8_ok )
			return "…";
		}
	else if ( str == "<" ) { % scroll/right
		if ( _slang_utf8_ok )
			return "…";
		}
	return str;
}

%!%+
%\function{strfit}
%\synopsis{Cuts string to fit in width-columns}
%\usage{String_Type strfit(str, width, dir)}
%\description
% Cuts the string \var{str} to fit in \var{width} columns.
% If \var{dir} > 0 then cuts the right part; otherwise cuts the left part of string.
%!%-
private variable right_edge = _get_ssymbol(">");	%% (>>) here would be nice if slang had constants or macros
private variable left_edge  = _get_ssymbol("<");	%% (<<) or ldots of utf8
public define strfit(str, width, dir)
{
	variable len = strlen(str);
	if ( len < 2 )	return str;
	if ( width < 4 ) width = 4;
	if ( len > width ) 
		return ( dir > 0 ) ?
			strcat(substr(str, 1, width - strlen(right_edge)), right_edge) : % >>
			strcat(left_edge, substr(str, (len - width) + strlen(left_edge) + 1, width)); % <<
	return str;
}

%% error message (not error() and quit)
private variable color_error = color_number("error");
public define uerror()
{
	variable s = ( _NARGS ) ? () : "";
	s = strfit(s, window_info('w'), 1);
	vmessage("\ec%c%s", color_error + '\001', s);
}

%% error message formatted
public define uerrorf()
{
	variable args = __pop_args (_NARGS), s;
	s = sprintf(__push_args (args));
	uerror(s);
}

%% message formatted
public define vmess()
{
	variable args = __pop_args (_NARGS), s;
	s = sprintf (__push_args (args));
	s = strfit(s, window_info('w'), 1);
	message(s);
}

%%
private define _inputv_int(argc, argv, prompt, val)
{
	variable n, in = (argc > 1) ? argv[1] : read_mini(prompt, val, "");
	return atoi(in);
}

%% User defined data type didn't work as expected
%% (slang version 2.3.0, slackware64 14.2+)
private define _get_spos()
{ return (what_line() << 12) | what_column(); }

private define _set_spos(p)
{ goto_line(p >> 12); goto_column(p & 0xfff); }

%% show help window, short version
define cbrief_help()
{
	if ( bufferp(_help_buf) && whatbuf() != _help_buf ) {
		delbuf(_help_buf);
		onewindow();
		}
	else
		chelp(_help_file);
}

%% one window, the whole help file
define cbrief_long_help()
{
	variable file = expand_jedlib_file(_long_help_file);
	if ( bufferp(_help_buf) && whatbuf() != _help_buf ) {
		delbuf(_help_buf);
		onewindow();
		}
	else
		chelp(file, 1);
}

%% --- keyboard -----------------------------------------------------------

%% quote - insert the keycode
define cbrief_quote()
{
	message("Press key:"); update (1);
	forever {
		variable c = getkey ();
		insert((c == 0) ? "^@" : char(c));
		ifnot ( input_pending(1) )	break;
		}
}

%% handle ESC/Quit key (\e\e\e)
define cbrief_escape()
{
	if ( is_visible_mark() )	pop_mark(0);
	call("kbd_quit");
	if ( input_pending(1) )	flush_input();
}

%% the enter key
define cbrief_enter()
{
	variable flags;
	(,,,flags) = getbuf_info();
	
	newline();
	ifnot ( flags & 0x10 ) % not overwrite mode
		indent_line();
}

%% the backspace key
define cbrief_backspace()
{
	% creates RTE in minibuf
	try { call("backward_delete_char"); } catch AnyError: { }
}

%% clear keyboard buffer
define cbrief_flush_input()
{
	ifnot ( EXECUTING_MACRO or DEFINING_MACRO )
		if ( input_pending(1) )
			flush_input();
}

%% insert() macro
define cbrief_insert()
{
	variable in = (_NARGS) ? () : read_mini("Enter the text to insert:", "", "");
	if ( strlen(in) ) insert(in);
}

%% copy from emacsmsc
define scroll_up_in_place ()
{
	variable m = window_line ();
	if (down_1 ()) recenter (m);
	bol();
}

%% copy from emacsmsc
define scroll_down_in_place ()
{
	variable m = window_line ();
	if (up_1 ()) recenter (m);
	bol();
}

%% --- basic commands -----------------------------------------------------

%% display BRIEF's version
define cbrief_disp_ver()
{
	vmess("JED:%s, SLang:%s, CBRIEF:%s", _jed_version_string, _slang_version_string, _cbrief_version_string);
}

%% display the current buffer filename
define cbrief_disp_file()
{
	variable file = buffer_filename();
	if ( buffer_modified() )	file += "*";
	vmessage("File: %s", strfit(file, window_info('w') - 6, -1));
}

%%
define cbrief_next_word()
{
	if ( isalnum(what_char()) )	skip_word_chars();
	skip_non_word_chars();
}

%%
define cbrief_prev_word()
{
	if ( isalnum(what_char()) )	bskip_word_chars();
	bskip_non_word_chars();
	bskip_word_chars();
}

%%
define cbrief_goto_line()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	variable n = _inputv_int(argc, argv, "Go to line:", 0);
	if ( n >= 1 ) goto_line(n);
}

%%
define cbrief_exit()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	if ( argc > 1 ) { if (argv[1] == "w") save_buffers(); }
	exit_jed();
}

%% write region or file to disk
define cbrief_write()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	variable ex, nl = 0, err = 0, file, st1, st2;

	if ( is_visible_mark() ) {
		if ( argc > 1 )	file = argv[1];
		ifnot ( strlen(file) )
			file = strtrim(read_file_from_mini("Write block as:"));
		if ( strlen(file) ) {
			try(ex) { nl = write_region_to_file(file); }
			catch AnyError: { uerrorf("Caught %s, %s:%d -- %s", ex.descr, ex.file, ex.line, ex.message); err = 1; }
			ifnot ( err ) message("Write successful.");
			}
		else uerror("Command canceled.");
		}
	else {
		file = (argc > 1) ? argv[1] : buffer_filename();
		if ( buffer_modified() ) {
			ifnot ( strlen(file) )	file = strtrim(read_file_from_mini("Write to file:"));
			if ( strlen(file) ) {
				try(ex) { nl = write_buffer(file); }
				catch AnyError: { uerrorf("Caught %s, %s:%d -- %s", ex.descr, ex.file, ex.line, ex.message); err = 1; }
				ifnot ( err ) { message("Write successful."); }
				}
			else uerror("Command canceled.");
			}
		else message("File has not been modified -- not written.");
		}
}

%% warning: does not save the file, it just change the name in its memory; like the original BRIEF
define cbrief_output_file()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	variable dir, file, flags, name, e;

	ifnot ( is_readonly() ) {
		file = (argc > 1) ? argv[1] : buffer_filename();
		file = strtrim(read_mini("Enter new output file name:", file, ""));

		e = file_status(file);
		if ( e == 0 || e == 1 ) {
			(, dir, name, flags) = getbuf_info ();
			if ( path_is_absolute(file) ) {
				dir = path_dirname(file);
				file = path_basename(file);
				name = file;
				}
			else {
				file = path_basename(file);
				name = file;
				}
			setbuf_info(file, dir, name, flags);
			set_buffer_modified_flag(1);
			message("Name change successful.");
			}
		else uerror("Invalid output file name.");
		}
	else uerror("Buffer is read-only.");
}

%% inserts character by ascii code
define cbrief_ascii_code()
{
	variable n, in = (_NARGS) ? () : read_mini("ASCII code:", "", "");
	n = ( typeof(in) == String_Type ) ? atoi(in) : in;
	insert((char)(n));
}

%% --- toggles ------------------------------------------------------------

%% set_backup macro
define	cbrief_toggle_backup()
{
	_toggle_buffer_flag(0x100);
	vmess("Backup is: %s", onoff(_test_buffer_flag(0x100)));
}

%%
define	cbrief_toggle_autosave()
{
	_toggle_buffer_flag(0x02);
	vmess("Autosave is: %s", onoff(_test_buffer_flag(0x02)));
}

%% toggle_re macro
define cbrief_toggle_re()
{
	_regexp_search = not (_regexp_search);
	vmess("Regular expression search is %s.", onoff(_regexp_search));
}

%% search_case macro
define cbrief_search_case()
{
	_search_case = not (_search_case);
	vmess("Case sensitive search is %s.", onoff(_search_case));
}

%% block_search macro
define cbrief_block_search()
{
	_block_search = not (_block_search);
	vmess("Block search is %s.", onoff(_block_search));
}

%% --- bookmarks ----------------------------------------------------------

private variable max_bookmarks = 10;
private variable bookmarks = Mark_Type[max_bookmarks];

%%
define	cbrief_bkdrop()
{
	variable n, in = (_NARGS) ? () : NULL;

	if ( in == NULL ) in = read_mini("Drop bookmark [1-10]:", "", "");
	n = (String_Type == typeof(in)) ? atoi(in) : in; n --;
	if ( n < 0 || n > (max_bookmarks - 1) )
		uerror("Invalid bookmark number.");
	else {
		bookmarks[n] = create_user_mark();
		message("Bookmark dropped.");
		}
}

%%
define	cbrief_bkgoto()
{
	variable n, in = (_NARGS) ? () : NULL;

	if ( in == NULL )
		in = read_mini("Go to bookmark [1-10]:", "", "");
	n = (String_Type == typeof(in)) ? atoi(in) : in; n --;
	if ( n < 0 || n > (max_bookmarks - 1) )
		uerror("Invalid bookmark number.");
	else {
		variable mrk = bookmarks[n];
		if ( mrk == NULL )
			uerror("That bookmark does not exist.");
		else {
			sw2buf(mrk.buffer_name);
			goto_user_mark(mrk);
			}
		}
}

%% --- regions ------------------------------------------------------------

%% what content type we have in scrap
private variable _scrap_type = 0;

%% X Windows Copy/Paste
%% copy selection to X
define cbrief_xcopy() {
#ifdef MOUSE
	copy_kill_to_mouse_buffer();
#endif
%	if ( x_copy_region_to_selection_p != NULL )
%		x_copy_region_to_selection_p();
	pipe_region("xclip -selection c");
	message("Text copied to clipboard");
}

%% cut selection to X 
define cbrief_xcut() {
#ifdef MOUSE
	copy_kill_to_mouse_buffer();
#endif
%	if ( x_copy_region_to_selection_p != NULL )
%		x_copy_region_to_selection_p();
	pipe_region("xclip -selection c");
	brief_kill_region();
	message("Text cut to clipboard");
}

%% paste from X
define cbrief_xpaste()
{
%	if ( x_insert_selection_p != NULL )
%		() = x_insert_selection_p();

	variable file, dir, flags, name;
	variable mode, mflags;
	(file, dir, name, flags) = getbuf_info ();
	(mode, mflags) = what_mode();
	set_mode("text", 0);
	setbuf_info(file, dir, name, flags | 0x10); % set overwrite mode
	run_shell_cmd("xclip -o");
	set_mode(mode, mflags);
	setbuf_info(file, dir, name, flags);
	message("Text inserted from clipboard");
}

#ifndef CBRIEF_PATCH_V1
private variable cur_line_mark3;
private variable start_line_mark3;
private define cbrief_mark3_update_hook ()
{
	if ( is_visible_mark() && Brief_Mark_Type == 3 ) 
		cur_line_mark3 = create_line_mark(color_number("region"));
}
#endif

%%
define cbrief_mark()
{
	variable n = (_NARGS) ? () : 0;
	if ( typeof(n) == String_Type )	n = atoi(n);

	% reset --- we dont know what brief-* command did yet
	% 		pop_mark() must be do with cbrief_mark(0);
#ifndef CBRIEF_PATCH_V1
	start_line_mark3 = NULL;
	cur_line_mark3 = NULL;
	unset_buffer_hook("update_hook");
#endif
	Brief_Mark_Type = 0;
	cbrief_unset_flags(0x06);
	if ( is_visible_mark() ) {
		pop_mark_0;
		return;
		}

	%
	switch ( n )
		{ case 0: Brief_Mark_Type = 0; }
		{ case 1:
#ifdef CBRIEF_PATCH_V1
			cbrief_set_flags(0x02); % inclusive
#endif
			brief_set_mark_cmd(1);
			}
		{ case 2:
		    Brief_Mark_Type = 2;
#ifdef CBRIEF_PATCH_V1
			CBRIEF_SELCOLPOS = what_column();
			cbrief_set_flags(0x08 | 0x02); % colomn & inclusive
#endif
		    set_mark_cmd ();
    		message("Column mark set.");
			}
		{ case 3:
			Brief_Mark_Type = 3;
#ifdef CBRIEF_PATCH_V1
			cbrief_set_flags(0x04);
#endif
			bol();set_mark_cmd();eol();
#ifndef CBRIEF_PATCH_V1
			start_line_mark3 = create_line_mark (color_number("region"));
			set_buffer_hook("update_hook", &cbrief_mark3_update_hook);
			eol(); % well, I need an internal jed function here!!!! position of the cursor it is marked line too, JED help
#endif
			message ("Line mark set.");
			}
		{ case 4: brief_set_mark_cmd(4); }
		{ uerror("Use 'mark 0..4'"); }
}

define cbrief_reset_mark()	{ cbrief_mark(0); }		% remove any selection if exist...
define cbrief_stdmark()		{ cbrief_mark(1); }		% standard mark (include cursor point)
define cbrief_mark_column() { cbrief_mark(2); }		% column mark (include cursor point)
define cbrief_line_mark()	{ cbrief_mark(3); }		% line block mark
define cbrief_noinc_mark()	{ cbrief_mark(4); }		% non-inclusive mark

%% cut
define cbrief_cut()
{
	ifnot ( Brief_Mark_Type) Brief_Mark_Type = 3; % copy current line
	_scrap_type = Brief_Mark_Type;
	if ( is_visible_mark() && (CBRIEF_FLAGS & 0x02)
		 && ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2) ) {
		check_region(0);
		call("next_char_cmd");
		}
	brief_kill_region();
	cbrief_mark(0);
}

%% copy
define cbrief_copy()
{
	ifnot ( Brief_Mark_Type ) Brief_Mark_Type = 3; % copy current line
	_scrap_type = Brief_Mark_Type;
	push_spot();
	if ( is_visible_mark() && (CBRIEF_FLAGS & 0x02)
		 && ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2) ) {
		check_region(0);
		call("next_char_cmd");
		}
	brief_copy_region();
	cbrief_mark(0);
	pop_spot();
}

%% paste
define cbrief_paste()
{
	switch ( _scrap_type )
		{ case 1 or case 4: call("yank"); message ("Scrap inserted.");}
		{ case 2: insert_rect(); message ("Columns inserted."); }
		{ case 3: bol(); call("yank"); message ("Lines inserted."); }
		{ uerror("No scrap to insert."); }
}

%% delete block or character
define cbrief_delete()
{
	if ( is_visible_mark() ) {
		if ( (CBRIEF_FLAGS & 0x02)
			 && ( Brief_Mark_Type == 1 || Brief_Mark_Type == 2 ) ) {
			check_region(0);
			call("next_char_cmd");
			}
		brief_delete();
		cbrief_mark(0);
		}
	else 
		del();
}

%% for each line of the region calls the do_line
private define cbrief_block_do(do_line)
{
	if ( is_visible_mark() ) {
		dupmark();
		check_region(0);
		variable end_line = what_line();
		exchange_point_and_mark();
		loop ( end_line - what_line() + 1 )  {
			(@do_line)();
			go_down_1();
			}
		pop_mark(0);
		}
}

%% transform block (xform_region parameters)
define cbrief_block_to(c)
{
	push_spot();
	if ( is_visible_mark() ) {
		if ( Brief_Mark_Type == 3 ) % line mark
			eol();
		xform_region(c);
		}
	else {
		bol();
		set_mark_cmd();
		eol();
		xform_region(c);
		pop_mark_0();
		}
	pop_spot();
}

%% --- tabs ---------------------------------------------------------------

%%
%%	Brief Manual
%%	------------
%%	Normally, Tab moves the cursor to the next tab stop on the current line.
%%	Back Tab moves the cursor to the previoys tab stop,	or to the beginning
%%	of the line.
%%
%%	A block is marked...
%%	
%%	In this situation, Tab acts as though it had been pressed at the first
%%	character of every line in the block, which shifts the block right by
%%	one tab stop.
%%
%%	Back Tab has the opposite effect, shifting a block left by one tab stop.
%%	It only shifts lines that begin with tabs or spaces.
%%

%% use_tab_char(t/f)
define	cbrief_use_tab()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	variable o;
	
	if ( argc > 1 )
		o = argv[1];
	else
		o = read_mini("Fill with tab chars?", "", ((USE_TABS)?"y":"n"));
	if ( o[0] =='n' || o[0] == 'N' || o[0] == '0' || o[0] == 'f' )
		USE_TABS = 0;
	else
		USE_TABS = 1;
	return USE_TABS;	% current value
}

%%
define cbrief_line_indent()
{
	if ( is_readonly() ) return;
	bol();
	insert("\t");
}

%%
define cbrief_line_outdent()
{
	variable c;
	
	if ( is_readonly() ) return;
	bol();
	loop ( TAB ) {
		if ( eolp() )
			break;
		c = what_char();
		switch ( c )
			{ case ' ':  del(); }
			{ case '\t': del(); break; }
			{ break; }
		}
}

%% tab			
define cbrief_slide_in()
{
	variable normal_tab = 0;
	
	if ( _NARGS ) {
		normal_tab = ();
		if ( typeof(normal_tab) == String_Type )
			normal_tab = atoi(normal_tab);
		}
	if ( is_readonly() ) return;

	push_spot();
	if ( is_visible_mark() )
		cbrief_block_do(&cbrief_line_indent);
	else if ( normal_tab == 0 )
		cbrief_line_indent();
	else {
		pop_spot();
		insert("\t");
		return;
		}
	pop_spot();
}

%%
define cbrief_back_tab()
{
	variable c, pre, goal, i;
	
	c = what_column ();
	pre = 1; goal = 1;
	foreach ( Tab_Stops ) {
		pre = goal;
		goal = ();
		if ( goal >= c ) break;
		}
	goto_column(pre);
}

%% back tab - slide_out
define cbrief_slide_out() {
	variable normal_tab = 0;
	
	if ( _NARGS ) {
		normal_tab = ();
		if ( typeof(normal_tab) == String_Type )
			normal_tab = atoi(normal_tab);
		}
	
	push_spot();
	if ( is_visible_mark() )
		cbrief_block_do(&cbrief_line_outdent());
	else if ( normal_tab == 0 )
		cbrief_line_outdent();
	else {
		pop_spot();
		cbrief_back_tab();
		return;
		}
	pop_spot();
}

%% in brief this function asks the whole tab stops for example 
%% tabs 5 % tab = 4
%% tabs 5 9
define cbrief_tabs()
{
	variable argv = (_NARGS) ? () : NULL;

	if ( argv == NULL ) {
		edit_tab_stops();
		return;
		}
	
	variable in, w, i;
	variable argc = length(argv);
	
	if ( argc == 1 )
		edit_tab_stops();
	else if ( argc == 2 ) {
		w = atoi(argv[1]) - 1;
		if ( w > 0 ) {
			TAB = w;
			Tab_Stops = [0:19] * TAB + 1;
			}
		else
			edit_tab_stops();
		}
	else {
		for ( i = 1; i < argc; i ++ ) 
			Tab_Stops[i-1] = atoi(argv[i]);
%		Tab_Stops[[i:]] = 0;
		}
}

%% --- search -------------------------------------------------------------

%%
define cbrief_delim_match()
{
	variable er, re = "[\{\}\(\)]", ch = what_char();

	if ( ch == '(' || ch == '[' || ch == '{' ||
		 ch == ')' || ch == ']' || ch == '}' ) {

		er = find_matching_delimiter(ch);
		if ( er != 1 )
			uerrorf("'%c' mismatch...", (char)(ch));
		else
			message("Found.");
		}
	else % otherwise go to the next delimiter
		er = re_fsearch(re);
}

%% search for a string in direction 'dir'
define	cbrief_search(dir, argc, argv)
{
	variable prompt, pattern, found = 0, r = 0;
	
	CASE_SEARCH = _search_case;
	prompt = sprintf("%c Search for (%s %s):",
					 (dir > 0) ? _get_symbol('f') : _get_symbol('b'),
					 (_regexp_search) ? "re" : "--",
					 (_search_case) ? "cs" : "ci");
	
	if ( argc > 1 ) pattern = argv[1];
	else { pattern = read_mini(prompt, LAST_SEARCH, ""); }
	
	ifnot ( strlen(pattern) ) {
		uerror("No pattern specified.");
		return;
		}

	_search_forward = (dir > 0) ? 1 : 0;
	LAST_SEARCH = pattern;

	% search only in the block
	variable bWiden = 0;
	if ( _block_search && markp() ) {
		push_spot ();
		narrow_to_region();
		bob(); 	bWiden = 1;
		}

	CASE_SEARCH = _search_case;
	if ( dir > 0 ) r = right(1);
	if ( _regexp_search )
		found = (dir > 0) ? re_fsearch(LAST_SEARCH) : re_bsearch(LAST_SEARCH);
	else 
		found = (dir > 0) ? fsearch(LAST_SEARCH) : bsearch(LAST_SEARCH);
	ifnot (dir > 0 && found) go_left(r);

	% if block only, return to normal
	if ( bWiden ) {
		widen_region ();
		pop_spot();
		}
	
	message((found) ? "Search completed." : "Not Found");
}

%% UI search_fwd
define cbrief_search_fwd()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	cbrief_search(1, argc, argv);
}

%% UI search_back
define cbrief_search_back()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	cbrief_search(-1, argc, argv);
}

%% find next
define cbrief_find_next()
{
	if ( strlen(LAST_SEARCH) ) {
		% search only in the block
		variable bWiden = 0;
		if ( _block_search && markp() ) {
			push_spot ();
			narrow_to_region();
			bob();
			bWiden = 1;
			}
		% this is the search
		CASE_SEARCH = _search_case;
		variable r = right(1);
		variable found = (_regexp_search) ? re_fsearch(LAST_SEARCH) : fsearch(LAST_SEARCH);
		ifnot (found) go_left(r);
		% if block only, return to normal
		if ( bWiden ) {
			widen_region ();
			pop_spot();
			}
		message((found) ? "Search completed." : "Not Found");
		}
	else cbrief_search_fwd();
}

%% find previous
define cbrief_find_prev()
{
	if ( strlen(LAST_SEARCH) ) {
		% search only in the block
		variable bWiden = 0;
		if ( _block_search && markp() ) {
			push_spot ();
			narrow_to_region();
			bob();
			bWiden = 1;
			}
		% this is the search
		CASE_SEARCH = _search_case;
		variable found = (_regexp_search) ? re_bsearch(LAST_SEARCH) : bsearch(LAST_SEARCH);
		% if block only, return to normal
		if ( bWiden ) {
			widen_region ();
			pop_spot();
			}
		message((found) ? "Search completed." : "Not Found");
		}
	else cbrief_search_back();
}

%% incremental search
define cbrief_i_search()
{ if  (_search_forward ) isearch_forward(); else isearch_backward(); }

%% search_again
define cbrief_search_again()
{ if ( _search_forward ) cbrief_find_next(); else cbrief_find_prev(); }

%% search_again reversed
define cbrief_search_again_r()
{ if ( _search_forward ) cbrief_find_prev(); else cbrief_find_next(); }

%% --- replace ------------------------------------------------------------

private variable last_search_repl = "";
private variable last_replacement = "";
private variable last_trans_dir   = 1;

%%
private define re_fsearch_f(pat)		{ return re_fsearch(pat) - 1; }
private define re_bsearch_f(pat)		{ return re_bsearch(pat) - 1; }
private define ss_fsearch_f(pat)		{ return fsearch(pat); }
private define ss_bsearch_f(pat)		{ return bsearch(pat); }
private define re_replace_f(str, len)	{ ifnot ( replace_match(str, 0) ) return 0; return 1; }
private define ss_replace_f(str, len)	{ replace_chars(len, str); return 1; }

%% it leaves a push_mark
define cbrief_mark_next_nchars(n, dir)
{
	set_line_hidden (0);
	push_visible_mark();
	go_right(n);
	if ( dir < 0 )
		exchange_point_and_mark();
}

% The search function is to return: 0 if non-match found or the length of the item matched.
% search_fun takes the pattern to search for and returns the length of the pattern matched. If no match occurs, return -1.
% rep_fun returns the length of characters replaced.
define cbrief_replace_with_query(search_f, pat, rep, replace_f)
{
	variable prompt, ch, patdist, global = 0, count = 0;
	variable replacement_length = strlen(rep);

	prompt = "Change [Yes|No|Global|One|ESC/Quit]?";

	while ( patdist = @search_f(pat), patdist > 0 ) {

		if ( global ) { 
			ifnot ( @replace_f(rep, patdist) )	return;
			count ++;
			continue;
			}
		
		recenter(window_info('r') / 2);
		cbrief_mark_next_nchars(patdist, -1);
		flush(prompt);
		update(1);
		ch = get_mini_response(prompt);
		CASE_SEARCH = _search_case;
		pop_mark_0();

        switch ( ch )
			{ case 'y' or case 'Y' or case 'o' or case 'O' or case 'g' or case 'G':
				ifnot ( @replace_f(rep, patdist) )	return;
				count ++;
				if ( ch == 'o' || ch == 'O' )	break;
				if ( ch == 'g' || ch == 'G' )	global = 1;
				}
			{ case 'n' or case 'N': go_right_1(); continue; }
			{ case 'q' or case '' or case '\e': break; }
		}
	
	return count;
}

%%
define cbrief_translate_main(dir, argc, argv)
{
	variable prompt, pattern, repl, num = 0;
	
	CASE_SEARCH = _search_case;
	prompt = sprintf("%c Pattern (%s %s):",
					 (dir > 0) ? _get_symbol('f') : _get_symbol('b'),
					 (_regexp_search) ? "re" : "--",
					 (_search_case) ? "cs" : "ci");
	
	if ( argc > 1 ) pattern = argv[1];
	else { pattern = read_mini(prompt, LAST_SEARCH, ""); }
	
	ifnot ( strlen(pattern) ) {
		uerror("No pattern specified.");
		return;
		}

	if ( argc > 2 ) repl = argv[2];
	else { repl = read_mini("Replacement:", last_replacement, ""); }

	%	prompt = "Change [Yes|No|Global|One]?";
	%	vmess("Translation complete; %d occurrences changed.", num);
	LAST_SEARCH = pattern;
	last_search_repl = pattern;
	last_replacement = repl;
	last_trans_dir = dir;

	% translate only in the block
	variable bWiden = 0;
	if ( _block_search && markp() ) {
		push_spot ();
		narrow_to_region();
		bob();
		bWiden = 1;
		}

	CASE_SEARCH = _search_case;
	if ( _regexp_search)
		num = cbrief_replace_with_query( (dir > 0) ? &re_fsearch_f : &re_bsearch_f, pattern, repl, &re_replace_f);
	else
		num = cbrief_replace_with_query( (dir > 0) ? &ss_fsearch_f : &ss_bsearch_f, pattern, repl, &ss_replace_f);

	% if block only, return to normal
	if ( bWiden ) {
		widen_region ();
		pop_spot();
		}
	
	vmess("Translation complete; %d occurrences changed.", num);
}

%%
define cbrief_translate()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	cbrief_translate_main(1, argc, argv);
}

%%
define cbrief_translate_back()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	cbrief_translate_main(-1, argc, argv);
}

%%
define cbrief_translate_again()
{
	variable num;
	
	% translate only in the block
	variable bWiden = 0;
	if ( _block_search && markp() ) {
		push_spot ();
		narrow_to_region();
		bob();
		bWiden = 1;
		}
	
	CASE_SEARCH = _search_case;
	if ( _regexp_search )
		num = cbrief_replace_with_query(
				(last_trans_dir > 0) ? &re_fsearch_f : &re_bsearch_f,
				last_search_repl, last_replacement, &re_replace_f);
	else
		num = cbrief_replace_with_query(
				(last_trans_dir > 0) ? &ss_fsearch_f : &ss_bsearch_f,
				last_search_repl, last_replacement, &ss_replace_f);

	% if block only, return to normal
	if ( bWiden ) {
		widen_region ();
		pop_spot();
		}
	
	vmess("Translation complete; %d occurrences changed.", num);
}

%% --- dired --------------------------------------------------------------

%% dired hack: setup keymap
define cbrief_dired_init(km)
{
	variable e;
	if ( km == NULL ) km = "cbrief_dired";

	ifnot (keymap_p(km)) make_keymap (km);

	foreach e ( ["\r", "e", "E", "\ee"] )
		definekey ("dired_find", e, km);
	definekey ("dired_find", "f",  km);
	
	foreach e ( ["v", "V"] )
		definekey ("dired_view", e, km);

	foreach e ( ["d", "D", "t", "T"] )
		definekey ("dired_tag", e,  km);
	
	foreach e ( ["u", "U"] )
		definekey (". 1 dired_untag", e, km);
	
	foreach e ( ["m", "M", Key_F6] )
		definekey ("dired_move", e,    km);
	
	foreach e ( ["x", "X", Key_Del, Key_KP_Minus] )
		definekey ("dired_delete", e,  km);
	
	definekey (". 1 dired_point",   "^N",   km);
	definekey (". 1 dired_point",   "n",    km);
	definekey (". 1 dired_point",   " ",    km);
	definekey (". 1 chs dired_point",       "^P",   km);
	definekey (". 1 chs dired_point",       "p",    km);
#ifdef UNIX
	definekey (". 1 chs dired_untag",       "^?",   km); % DEL key
#elifdef IBMPC_SYSTEM
	definekey (". 1 chs dired_untag",       "\xE0S",km);   %  DELETE
	definekey (". 1 chs dired_untag",       "\eOn", km);   %  DELETE
#endif
	definekey ("dired_flag_backup", "~",    km);
	foreach e ( ["r", "R", Key_Shift_F6] )
		definekey ("dired_rename", e, km);
	definekey ("dired_reread_dir",  "g",    km);
	definekey ("describe_mode",     "h",    km);
	definekey ("dired_quick_help",  "?",    km);
	foreach e ( ["\e\e\e", "`",  "q", "Q", "q"] )
		definekey ("dired_quit", e, km);

	definekey("cbrief_change_win",			Key_F1,		km);
	definekey("cbrief_resize_win",			Key_F2,		km);
	definekey("one_window",					Key_Alt_F2,	km);
	definekey("cbrief_create_win",			Key_F3,		km);
	definekey("cbrief_delete_win",			Key_F4,		km);
	definekey("one_window",					"^Z",		km);
}

%% dired hack: show current line
private variable dired_line_mark;
define cbrief_update_dired_hook()
{
	dired_line_mark = create_line_mark(color_number("preprocess"));
}

%% dired hack: hook
public define dired_hook()
{
	Dired_Quick_Help = " (E)dit, (V)iew, (T)ag, (U)ntag, (X) Delete, (R)ename, (M)ove, (H)elp, (Q)uit, ?:this";
	set_buffer_hook ("update_hook", &cbrief_update_dired_hook);
	cbrief_reset();
	use_keymap("cbrief_dired");
}

%% dired hack: call
private variable old_dired_help;
define cbrief_dired()
{
	old_dired_help = Dired_Quick_Help;
	dired();
	Dired_Quick_Help = old_dired_help;
}

%%
define cbrief_buf_list()
{
#ifdef CBRIEF_PATCH_V5
	cbrief_bufpu();
#else
	cbrief_bufed();
#endif
}

%% --- files --------------------------------------------------------------

%% select a file
private define cbrief_select_file(argc, argv, prompt)
{
	return (argc < 2) ? read_with_completion(prompt, "", getcwd(), 'f') : argv[1];
}

%% execute do_f for a selected file
private define cbrief_file_do(argc, argv, prompt, do_f)
{
	variable n, ex, file = cbrief_select_file(argc, argv, prompt);

	if ( strlen(file) ) {
%		variable st = file_stat(file);
		n = file_status(file);
		if ( n == 0 && do_f != &find_file ) {
			uerror("File does not exist.");
			}
		else if ( n == 0 || n == 1 ) {
				try ( ex ) { n = (@do_f)(file); }
				catch AnyError: { uerrorf("Caught %s, %s:%d -- %s", ex.descr, ex.file, ex.line, ex.message); n = -1; }
				if ( n > 0 )
					vmess("%d lines inserted.", n);
				}
		else if ( n == 2 ) {
			uerror("This is a directory.");
			}
		else
			{ uerror("Access denied."); }
		}
}

#ifdef CBRIEF_PATCH_V5
%% this is the completion of filenames (the TAB in command-line)
public define cbrief_file_completion(filepat)
{
	variable s, idx;
	variable count, list, table, i;
	variable dname = path_dirname(filepat);

	count = directory(strcat(filepat, "*"));
	if ( count ) {
		list  = __pop_list(count);
		table = list_to_array(list);
		table = table[array_sort(table, &strcmp)];
		s = "";
		for ( i = 0; i < count; i ++ )
			s = sprintf("%s%s\n", s, table[i]);
		if ( strlen(s) ) {
			idx = 0;
			idx = popup_menu(s, idx);
			if ( idx >= 0 ) 
				return (path_concat(dname, table[idx]), 1);
			}
		}
	return 0;
}
#endif

%% edit_file(fname) -- open file
define cbrief_edit_file()
{
	variable argv = (_NARGS) ? () : NULL;
	variable n, argc = _argc(argv);
	
#ifdef CBRIEF_PATCH_V5
	set_expansion_hook("cbrief_file_completion");
	cbrief_file_do(argc, argv, "File to edit:", &find_file);
	set_expansion_hook("");
#else
	cbrief_file_do(argc, argv, "File to edit:", &find_file);
#endif
}

%% read_file(fname) -- inserts file into buffer
define cbrief_read_file()
{
	variable argv = (_NARGS) ? () : NULL;
	variable n, argc = _argc(argv);
#ifdef CBRIEF_PATCH_V5
	set_expansion_hook("cbrief_file_completion");
	cbrief_file_do(argc, argv, "File to read:", &insert_file);
	set_expansion_hook("");
#else
	cbrief_file_do(argc, argv, "File to read:", &insert_file);
#endif
}

%% change directory
define cbrief_chdir()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	variable in, e = 0;
	
	if ( argc < 2 )
		vmess("%s", getcwd());
	else {
		in = argv[1];
		if ( file_status(in) == 2 ) {
			e = change_default_dir(in);
			if ( e == 0 )
				vmess("Success: %s", getcwd());
			else
				uerrorf("Failed: %s", errno_string(errno));
			}
		else
			uerror("This is not a directory.");
		}
}

%% delete file
define cbrief_delete_file()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	variable e, file = cbrief_select_file(argc, argv, "Delete file:");

	if ( strlen(file) ) {
		variable st = file_status(file);
		switch ( st )
			{ case 0: uerror("File does not exist."); }
			{ case 2: uerror("This is a directory."); }
			{ case 1: 
				e = delete_file(file);
				if ( e == 0 )	message("Success");
				else uerrorf("Failed: %s", errno_string(errno));
			}
			{ uerror("Access denied."); }
		}
}

%% execute do_f for two file names 
private define cbrief_file_to(argc, argv, prompt1, prompt2, do_f)
{
	variable fold, fnew, e = 0;

	fold = cbrief_select_file(argc, argv, prompt1);
	if ( argc < 3 ) 
		fnew = read_mini(prompt2, "", fold);
	else
		fnew = argv[2];

	if ( strlen(fold) && (access(fold, R_OK) == 0) && strlen(strtrim(fnew)) ) {
		e = (@do_f)(fold, fnew);
		if ( e == 0 )
			vmess("Success");
		else
			uerrorf("Failed: %s", errno_string(errno));
		}
}

%% rename file
define cbrief_rename_file()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	cbrief_file_to(argc, argv, "Rename file:", "New file name:", &rename_file);
}

%% copy file
define cbrief_copy_file()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = _argc(argv);
	cbrief_file_to(argc, argv, "Copy file:", "Copy to:", &copy_file);
}

%% --- keystroke macros ---------------------------------------------------

private variable last_ksmacro = "";
private variable cur_ksmacro = "";
private variable paused_ksmacro = 0;

define cbrief_playback()
{
	if ( _has_set_last_macro )
		set_last_macro(last_ksmacro);
	call("execute_macro");
}

%%	Start macro recording.
%%	If recording is already in progress, stop recording.
define cbrief_remember ()
{
	if ( DEFINING_MACRO ) {
		call("end_macro");
		last_ksmacro = strcat(cur_ksmacro, get_last_macro());
		cur_ksmacro = "";
		}
   else ifnot ( EXECUTING_MACRO or DEFINING_MACRO ) {
		if ( paused_ksmacro )
			uerror("Macro already paused");
	   	else {
			last_ksmacro = "";
			cur_ksmacro = "";
			call("begin_macro");
			}
		}
}

%% pause recording macro
define cbrief_pause_ksmacro()
{
	if ( DEFINING_MACRO ) {
		call("end_macro");
		cur_ksmacro = get_last_macro();
		paused_ksmacro = 1;
		}
	else if ( paused_ksmacro ) {
		paused_ksmacro = 0;
		call("begin_macro");
		}
	else
		uerror("Not recording...");
}

%%	not the original save, but ...
define cbrief_save_ksmacro()
{
	variable file, fp;

	file = read_file_from_mini ("Keystroke macro file:");
	ifnot ( strlen(file) ) return;
	ifnot ( strlen(path_extname(file)) )
		file = strcat(file, ".km");

	fp = fopen(file, "wb+");
	ifnot ( fp == NULL ) {
		() = fwrite(last_ksmacro, fp);
		() = fclose(fp);
		}
	else
		uerror("Cannot create file.");
}

%%
define cbrief_load_ksmacro()
{
	variable file, fp, n;

	file = read_file_from_mini ("Keystroke macro file:");
	ifnot ( strlen(file) ) return;

	fp = fopen(file, "rb");
	ifnot ( fp == NULL ) {
		n = fseek (fp, 0, SEEK_END);
		() = fseek (fp, 0, SEEK_SET);
		() = fread(&last_ksmacro, String_Type, n, fp);
		() = fclose(fp);
		}
	else
		uerror("Cannot open file.");
}

%% --- lib ----------------------------------------------------------------

%%
%%	The original BRIEF's brace checking algorithm, I just rewrite it to slang.
%%	It is nice to see old bugs :P
%%
%%**              This macro is an attempt at a "locate the unmatched brace" utility.
%%**      Although it attempts to be fairly smart about things, it has an IQ of
%%**      4 or 5, so be careful before taking its word for something.
%%**              It DOES NOT WORK if there are braces inside quotes, apostrophes, or
%%**      comments.  The macro can, however, be modified to ignore everything
%%**      inside these structures (and check for the appropriate mismatches).
%%

%% part of brace()
define cbrief_char_search(backward)
{
	variable re = "[\{\}]";
	return ( backward ) ? re_bsearch(re) : re_fsearch(re);
}

%% locate the unmatched brace
define cbrief_brace()
{
	variable ch, pos, count, mismatch, backward;
	variable savepos = _get_spos();
	variable msgf = "Checking braces, %d unmatched '{'s.";
	
	backward = 0;
	mismatch = 0;
	count = 0;
	bob();

	while ( backward < 2 ) {
		while ( cbrief_char_search(backward) && mismatch == 0 ) {
			flush(sprintf(msgf, count));

			ch = what_char();
			if ( backward )	pos = ( ch == '}' ) ? 1 : 2;
			else 			pos = ( ch == '{' ) ? 1 : 2;

			if ( pos == 1 )		count ++;
			else if ( pos == 2 ) {
				if ( count )	count --;
				else {
					uerrorf("Mismatched %s brace.", (backward) ? "opening" : "closing");
					mismatch = 1; % found
					}
				}

			ifnot ( mismatch )	% next character
				call((backward) ? "previous_char_cmd" : "next_char_cmd");
			} % while int

		ifnot ( mismatch ) {
			if ( count ) { % missing '{', search backward
				eob();
				count = 0;
				backward = 1; % backward now
				msgf = "Locating mismatch, %d unmatched '}'s.";
				}
			else backward = 2; % exit
			}
		else backward = 2; % exit
		} % while -- change direction or exit
	
	ifnot ( mismatch ) {
		message("All braces match.");
		_set_spos(savepos);
		}
}

%% 
define cbrief_color_scheme()
{
	variable argv = (_NARGS) ? () : NULL;
	variable argc = length(argv);
	variable in;

	if ( argc < 3 ) {
		vmess("%s", _Jed_Color_Scheme);
		return;
		}
	
	in = argv[1];
	set_color_scheme(in);
}

%%
define cbrief_compile_it()
{
	variable s, err, ex;
	
	if ( path_extname(buffer_filename()) == ".sl" ) {
		save_buffer();
		s = sprintf("byte_compile_file(\"%s\", 0);", buffer_filename());

%		err = 0;
		eval(s);
%		try(ex) { eval(s); }
%		catch AnyError: { uerrorf("%s", ex.message); err = 1; }
%		ifnot ( err ) message("Compiled successful.");
		}
	else
		compile(Compile_Default_Compiler);
}

%%
define cbrief_build_it()
{
	compile("make");
}

%% wp mode, margins
define cbrief_margin()
{
	variable argv = (_NARGS) ? () : NULL;
	variable n, argc = _argc(argv);
	n = _inputv_int(argc, argv, "Enter margin:", WRAP);
	if ( n > 1 ) WRAP = n;
}

%% find a suitable xterm
define cbrief_find_xterm()
{
	if ( CBRIEF_XTERM == "" ) {
#ifdef UNIX
		variable xterm = getenv("TERMINAL");
		if ( xterm == NULL )
			xterm = "xterm";
		CBRIEF_XTERM = xterm;
#endif
		}
	return CBRIEF_XTERM;
}


%% create a new terminal window
define cbrief_new_term()
{
	if ( _jed_secure_mode ) {
		uerror("Shell is not available (jed-secure-mode)");
		return;
		}
#ifdef MSDOS OS2
	() = system("command.com");
#else
#ifdef VMS
	variable cfile = expand_jedlib_file ("vms_shell.com");
	ifnot ( strlen (cfile) )
		uerror("Unable to open vms_shell.com");
	else
		() = system(cfile);	
#else
#ifdef MSWINDOWS WIN32
	() = system("start cmd.exe");	
#else
	if ( is_xjed() || getenv("DISPLAY") != NULL ) % under X Windows
		() = system(cbrief_find_xterm() + " &");
	else % console
		() = system(getenv("SHELL"));
#endif % UNIX/Win
#endif % VMS
#endif % DOS
}

%%
define cbrief_dos()
{
	variable cline = (_NARGS) ? () : "";

	if ( cline == "" )
		cbrief_new_term();
	else {
#ifdef CBRIEF_PATCH_V5
		save_screen();
		() = system(cline);
		restore_screen();
#else
		() = system(cline);
#endif
		}
#ifdef CBRIEF_PATCH_V5
	redraw_screen();
#else
	update(0);
#endif
}

%% Alt+Z
define cbrief_az()
{
	if ( CBRIEF_OPTSF & 0x01 )
		suspend();
	else
		cbrief_new_term();
	update(0);
}

%%
define cbrief_load_macro()
{
	variable cline = (_NARGS) ? () : read_with_completion("Macro file:", "", getcwd(), 'f');
	ifnot ( strlen(cline) ) {
		if ( file_status(cline) == 1 )
			() = evalfile(cline);
		else
			uerror("Unable to load macro file.");
		}
}

%%
public define cbrief_cmd();
define cbrief_exec_macro()
{
	variable cline = (_NARGS) ? () : "";
	ifnot ( strlen(cline) )
		cbrief_cmd();
	else
		cbrief_cmd(cline);
}

%%
define cbrief_change_win()
{
	otherwindow();
}

%%
define cbrief_resize_win()
{
	enlargewin();
}

%%
define cbrief_create_win()
{
	splitwindow();
	otherwindow();
}

%%
define cbrief_delete_win()
{
	onewindow();
	% variable c = get_mini_response (strfit("Select window edge to delete (use cursor keys)."));
	% update(0);
	% switch ( c )
	% 	{ case Key_Up: }
	% 	{ case Key_Down: }
	% 	{ case Key_Left: }
	% 	{ case Key_Right: }
	% 	{ error(strfit("Edge does not have just two adjoining windows.")); }
}

%% --- command line -------------------------------------------------------

define cbrief_pwd()				{ vmess("%s", getcwd()); } % display current directory
#ifdef UNIX
define cbrief_man(p)			{ unix_man(p); }
#else
define cbrief_man(p)			{ uerror("man-pages are not supported."); }
#endif
define cbrief_menu_help()		{ eval("menu_select_menu(\"Global.&Help\")"); }
define cbrief_write_and_exit()	{ save_buffers(); exit_jed(); }

define cbrief_to_buf_rel(n)
{
	variable name, cbuf_list, curbuf = whatbuf();
	variable count = 0, idx = 0;
   
	if ( MINIBUFFER_ACTIVE ) return;

	cbuf_list = list_new();
	loop ( buffer_list() ) {
		name = ();
		if ( name[0] == ' ' ) continue;
		if ( name[0] == '*' ) continue;
		if ( strcmp(name, ".jedrecent") == 0 ) continue;
		list_append(cbuf_list, name);
		if ( strcmp(name, curbuf) == 0 )
			idx = count;
		count ++;
		}

	if ( count == 0 )
		message("No other buffers.");
	else if ( n > 0 ) {
		idx ++;
		if ( idx == count )	idx = 0;
		sw2buf(cbuf_list[idx]);
		}
	else {
		idx --;
		if ( idx < 0 )	idx = count - 1;
		sw2buf(cbuf_list[idx]);
		}
}

define cbrief_next_buf()		{ cbrief_to_buf_rel(1); }
define cbrief_prev_buf()		{ cbrief_to_buf_rel(0); }

%%
%%	show help about the keyword under the cursor
%% 
define cbrief_wordhelp()
{
	variable w, mode;

	push_spot();
	% jump to beginning of word
	if ( isalnum(what_char()) == 0 )
		bskip_non_word_chars();
	bskip_word_chars();
	push_mark();
	
	% copy word
	skip_word_chars();
	w = bufsubstr();

	% restore
%	pop_mark();
	pop_spot();

	% show help
	if ( strlen(w) ) {
		(mode,) = what_mode();
#ifdef UNIX
		if ( mode == "C" || mode == "SH" || mode == "CSH" || mode == "TCSH" )
			unix_man(w);
		else
			message(strcat("On-line help: No command for mode [", mode, "]"));
#endif
		}
}

define cbrief_eow()				{ goto_bottom_of_window(); eol(); }

private variable NO_ARG = 0;	% no parameters
private variable C_ARGV = 1;	% C-style argv
private variable C_LINE = 2;	% string
private variable S_LANG = 3;	% eval(this)
private variable S_CALL = 4;	% call(this)

private variable mac_list = {
%     name              function pointer        type
%
	{ "reset", &cbrief_reset, NO_ARG },

% bgd_compilation
%	Toggles whether or not all compilations should be performed
%	in the background.

	{ "backspace",		&cbrief_backspace,			NO_ARG },
% backspace
%	Backspaces and erases the character preceding the cursor

	{ "back_tab",		&cbrief_back_tab,			NO_ARG },
% back_tab
%	Moves the cursor to the previous tab stop without erasing tabs
%	or characters.

	{ "set_backup",		&cbrief_toggle_backup,		NO_ARG },
% set_backup
%	Turns automatic backup on or off from inside BRIEF.

	{ "beginning_of_line",	&bol,					NO_ARG },
% beginning_of_line
%	Places the cursor at column 1 of the current line.

	{ "block_search",	&cbrief_block_search,		NO_ARG },
% block_search
%	Toggles whether or not Search forward, Search back, and Search
%	again are restricted to blocks.

% Borders
%	Toggles whether or not window borders are displayed.

	{ "buf_list",		&cbrief_buf_list,			NO_ARG },
% buf_list
%	Displays the buffer list.

	{ "search_case",	&cbrief_search_case,		C_ARGV },
	{ "toggle_search_case",	&cbrief_search_case,		C_ARGV },
% search_case
%	Toggles upper and lower case sensitivity.

	{ "center",			"center_line",				S_CALL },
% center
%	Centers the text on a line between the first column and the
%	right margin.

	{ "center_line",	&brief_line_to_mow,			NO_ARG },
% center_line
%	Moves the current line, if possible, to the center (middle line)
%	of the current window. This only affects the display.

	{ "cd",				&cbrief_chdir,				C_ARGV },
% cd
%	Changes the current working directory.

	{ "output_file",	&cbrief_output_file,		C_ARGV },
% output_file
%	Changes the output file name for the current buffer. You cannot
%	enter an existing file name.

% change_window
%	Initiates a switch from one window to another.
	
% color
%	Resets the colors used for the background, foreground, titles,
%	and messages.

	{ "compile_it",		&cbrief_compile_it,			NO_ARG },
% compile_it
%	Compiles the file in the current buffer (and loads it if it's
%	a BRIEF macro file).

	{ "copy",			&cbrief_copy,			NO_ARG },
% copy
%	Copies the block of marked characters (selected by pressing A/t+M,
%	A/t+G, A/t+A, or A/t+L and highlighting the block with arrow keys
%	or commands) to the scrap, replacing the contents of the scrap
%	buffer and unmarking the block.

% assign_to_key
%	Adds a temporary key assignment to the current keyboard.

	{ "create_edge", &cbrief_create_win, NO_ARG },
% create_edge
%	Splits the current window in half either horizontally or vertically,
%	providing two views of the current buffer.

	{ "cut",			&cbrief_cut,			NO_ARG },
% cut
%	Copies the block of marked characters to the scrap, then deletes it,
%	replacing the previous contents of the scrap and unmarking the block.

	{ "delete_char",	&cbrief_delete,				NO_ARG },
% delete_char
%	Deletes the character at the cursor or, if a block is marked, deletes
%	(and unmarks) the marked block.

	{ "delete_curr_buffer",	&brief_delete_buffer,	NO_ARG },
% delete_curr_buffer
%	Deletes the current buffer and makes the next buffer in the buffer
%	list the current buffer.

	{ "del",			&cbrief_delete_file,		C_ARGV },
% del
%	Deletes a file from disk.

	{ "delete_line",	&delete_line,				NO_ARG },
% delete_line
%	Deletes the entire current line, regardless of the column position
%	of the cursor.

% delete_macro
%	Deletes the specified compiled macro file from memory.

	{ "delete_next_word",		"delete_word",		S_CALL },
% delete_next_word
%	Deletes from the cursor position to the start of the next word.

	{ "delete_previous_word",	"bdelete_word",		S_CALL },
	{ "delete_prev_word",		"bdelete_word",		S_CALL },	% non-brief
% delete_previous_word
% delete_prev_word
%	Deletes from the cursor position to the beginning of the previous
%	word.

	{ "delete_to_bol", 		&brief_delete_to_bol,	NO_ARG },
% delete_to_bol
%	Deletes all characters before the cursor to the beginning of the
%	line. If the cursor is beyond the end of the line, the entire line
%	is deleted, including the newline character.

	{ "delete_to_eol",	"kill_line",	S_CALL },
% delete_to_eol
%	Deletes all characters from the current position to the end
%	of the line.

	{ "delete_edge", &cbrief_delete_win, NO_ARG },
% delete_edge (param. the edge, 1..4 i think)
%	Allows you to delete a window by deleting the window's edge.

	{ "display_file_name", &cbrief_disp_file, NO_ARG },
% display_file_name
%	Displays the name of the file associated with the current buffer
%	on the status line.

	{ "version", &cbrief_disp_ver, NO_ARG },
% version
%	Displays BRIEF's version number and copyright notice on the
%	status line.

	{ "down",	&go_down_1, NO_ARG },
% down
%	Moves the cursor down one line, retaining the column position.

	{ "drop_bookmark", &cbrief_bkdrop, C_LINE },
% drop_bookmark
%	Drops a numbered bookmark at the current position.

	{ "edit_file",		&cbrief_edit_file,	C_ARGV },
% edit_file
%	Displays the specified file in the current window.

	{ "end_of_buffer",	&eob,				NO_ARG },
% end_of_buffer
%	Moves the cursor to the last character in the buffer, which is
%	always a newline character.

	{ "end_of_line",	&eol,				NO_ARG },
% end_of_line
%	Places the cursor at the last valid character of the current line.

	{ "end_of_window",	&cbrief_eow,  		NO_ARG },
% end_of_window
%	Places the cursor at the last valid character of the current line.

	{ "enter",			&cbrief_enter,		NO_ARG },
% enter
%	Depending on the mode being used (insert or overstrike), either
%	inserts a newline character at the current position, placing all
%	following characters onto a newly created next line, or moves the
%	cursor to the first column of the next line.

	{ "escape",			&cbrief_escape,		NO_ARG },
% escape
%	Lets you cancel a command from any prompt.

	{ "execute_macro", &cbrief_exec_macro, NO_ARG },
% execute_macro
%	Executes the specified command. This command is used to execute
%	any command without a key assignment, such as the Color command.

	{ "exit",			&cbrief_exit,		C_ARGV },
% exit
%	Exits from BRIEF to OS asking to write the modified buffers.
%	Note: exit (gets args, "w" = save all before)

	{ "quit",			&quit_jed,			NO_ARG },
% quit
%	Exits from BRIEF to OS without write the  buffers.

	{ "goto_line",		&cbrief_goto_line,	C_ARGV },
% goto_line
%	Moves the cursor to the specified line number.

% routines (^G)
%	Displays a window that lists the routines present in the current
%	file (if any).

	{ "halt",			&cbrief_escape,		NO_ARG },	% brief's key abort
% halt
%	Terminates the following commands: 'Search forward',
%	'Search backward', 'Translate', 'Playback', 'Execute command'.
	
	{ "help",			&help,				NO_ARG },
% help
%	Shows an information window with basic key-shortcuts.
	
	{ "long_help",		&cbrief_long_help,	NO_ARG },
% long_help
%	Displays the full help file in a new buffer.

% help
%	Either displays a general help menu or, if a command prompt is in
%	the message window, displays a pop-up window of information
%	pertaining to the command.

	{ "i_search",		&cbrief_i_search,	NO_ARG },
% i_search
%	Searches for the specified search pattern incrementally, that is,
%	as you type it.

	{ "slide_in",		&cbrief_slide_in,	NO_ARG },
% slide_in
%	When indenting is on and a block is marked, the Tab key indents all
%	the lines in the block to the next tab stop.

	{ "insert_mode",	&toggle_overwrite,	NO_ARG },
% insert_mode
%	Switches between insert mode and overstrike mode. Backspace, Enter,
%	and Tab behave differently in insert mode than in overstrike mode.

	{ "goto_bookmark", &cbrief_bkgoto,		C_LINE },
% goto_bookmark
%	Moves the cursor to the specified bookmark number.

	{ "left",		&go_left_1,				NO_ARG },
% left
%	Moves the cursor one column to the left, remaining on the same line.
%	When the cursor is moved into virtual space, it changes shape.

	{ "left_side",	"scroll_right",			S_CALL },
% left_side
%	Moves the cursor to the left side of the window.

	{ "to_bottom", &brief_line_to_eow,		NO_ARG },
% to_bottom
%	Scrolls the buffer, moving the current line, if possible, to the
%	bottom of the window.
	
	{ "to_top",		&brief_line_to_bow,		NO_ARG },
% to_top
%	Scrolls the buffer, moving the current line to the top of the
%	current window.

	{ "load_keystroke_macro", &cbrief_load_ksmacro, NO_ARG },
% load_keystroke_macro
%	Loads a keystroke macro into memory, if the specified file can be
%	found on the disk.

	{ "load_macro",	&cbrief_load_macro, C_LINE },
% load_macro
%	Loads a compiled macro file into memory, if the specified file can
%	be found on the disk.

	{ "tolower",	"cbrief_block_to('d')",		S_LANG },
% tolower
%	Converts the characters in a marked block or the current line to
%	lowercase.
	
	{ "margin",		&cbrief_margin,			C_ARGV },
% margin
%	Resets the right margin for word wrap, centering, and paragraph
%	reformatting. The preset margin is at the seventieth character.
	
	{ "mark",		&cbrief_mark,			C_LINE },
% mark
% 	'mark' or 'mark 0' remove mark.
% 	'mark 1' standard mark.
% 	'mark 2' Starts marking a rectangular block.
%	'mark 3' Starts marking a line at a time.
%	'mark 4' Equivalent to Mark 1, except that the marked area does not
%			include the character at the end of the block.
%
%	Marks a block in a buffer with no marked blocks. When a block of
%	text is marked, several BRIEF commands can act on the entire block:
%	Cut to scrap, Copy to scrap, Delete, Indent block (in files with
%	programming support), Lower case block Outdent block (in files with
%	programming support), Print Search forward, Search backward, and
%	Search again (optionally; see the Block search toggle command)
%	Translate forward, Translate back, and Translate again Uppercase
%	block, Write.
%	
%	When the Cut to scrap, Copy to scrap, Delete, Print, or Write
%	commands are executed on a block, the block becomes unmarked.

	{ "edit_next_buffer",	&cbrief_next_buf,	NO_ARG },
% edit_next_buffer
%	Moves the next buffer in the buffer list, if one exists, into the
%	current window, making it the current buffer. The last remembered
%	position becomes the current position.

	{ "next_char",		"next_char_cmd",	S_CALL },
% next_char
%	Moves the cursor to the next character in the buffer (if not at
%	the end of the buffer), treating tabs as single characters and
%	wrapping around line boundaries.

% next_error
%	Locates the next error in the current file, if an error exists.

	{ "next_word",		&cbrief_next_word,	NO_ARG },
% next_word
%	Moves the cursor to the first character of the next word.

	{ "open_line",		&brief_open_line,	NO_ARG },
% open_line
%	Inserts a blank line after the current line and places the cursor
%	on the first column of this new line. If the cursor is in the
%	middle of an existing line, the line is not split.

	{ "slide_out",		&cbrief_slide_out,	NO_ARG },
% slide_out
%	When indenting is on and a block is marked, the Tab key outdents
%	all the lines in the block to the next tab stop.

	{ "page_down",		&brief_pagedown,	NO_ARG },
% page_down
%	Moves the cursor down one page of text, where a page equals the
%	length of the current window.

	{ "page_up",		&brief_pageup,		NO_ARG },
% page_up
%	Moves the cursor up one page of text, where a page equals the
%	length of the current window.

	{ "paste",			&cbrief_paste,		NO_ARG },
% paste
%	Inserts (pastes) the current scrap buffer into the current buffer
%	immediately before the current position, taking the type of the
%	copied or cut block into account.

	{ "pause",		&cbrief_pause_ksmacro,	NO_ARG },
% ??? (s+f7)
%	Tells BRIEF to temporarily stop recording the current keystroke
%	sequence.

% pause_an_error
%	Tells BRIEF to pause when displaying run-time error messages.
%	Otherwise, the messages flash by at a rapid rate.

	{ "playback",		&cbrief_playback,	NO_ARG },
% playback
%	Plays back the last keystroke sequence recorded with the Remember
%	command.

% next_error 1
%	Displays a window of error messages and allows you to examine any
%	message or go to the line where an error occurred. This command
%	should be used after the current file has been compiled.

	{ "menu",	"select_menubar",	S_CALL },
% menu
%	Opens JED's menu bar. (non-brief)

% popup_menu
%	Displays a pop-up menu. If called using the mouse, the pop-up menu
%	is displayed centered under the mouse cursor. Otherwise, it is
%	displayed in the middle of the screen. The menu is in the file
%	'\brief\help\popup.mnu', and can be modified to add additional
%	features.

	{ "edit_prev_buffer",	&cbrief_prev_buf,	NO_ARG },
% edit_prev_buffer
%	Displays the previous buffer in the buffer list in the current
%	window.
	
	{ "prev_char",		"previous_char_cmd",	S_CALL },
% prev_char
%	Moves the cursor to the previous character in the buffer (if not at
%	the top of the buffer), treating tabs as single characters and
%	wrapping around line boundaries.

	{ "previous_word",	&cbrief_prev_word,	NO_ARG },
	{ "prev_word",		&cbrief_prev_word,	NO_ARG }, % non-brief
% previous_word
% prev_word
%	Moves the cursor to the first character of the previous word.

	{ "change_window", &cbrief_change_win, NO_ARG },
% change_window
%	Quickly changes windows when you choose the arrow key that points
%	to the window you want.

	{ "quote",		&cbrief_quote,		NO_ARG },
% quote
%	Causes the next keystroke to be interpreted literally, that is,
%	not as a command.

	{ "read_file",	&cbrief_read_file,	C_ARGV },
% read_file
%	Reads a copy of the specified file into the current buffer,
%	inserting it immediately before the current position.

	{ "redo",			"redo",			S_CALL },
% redo
%	Reverses the effect of commands that have been undone.
%	New edits to the buffer cause the undo information for commands
%	that were not redone to be purged.

	{ "reform",		"format_paragraph",	S_CALL },
% reform
%	Reformats a paragraph, adjusting it to the current right margin.
	
	{ "toggle_re",	  &cbrief_toggle_re,	NO_ARG },
	{ "toggle_regex", &cbrief_toggle_re,	NO_ARG },
% toggle_re
%	Toggles whether or not regular expressions are recognized
%	in patterns.
	
	{ "remember",	&cbrief_remember,	NO_ARG },
% remember
%	Causes BRIEF to remember a sequence of keystrokes.

% repeat (^R)
%	Repeats a command a specified number of times.

	{ "move_edge", &cbrief_resize_win, NO_ARG },
% move_edge
%	Changes the dimension of a window by moving the window's edge.

	{ "right",		&go_right_1,		NO_ARG },
% right
%	Moves the cursor one column to the right, remaining on the same
%	line. If the cursor is moved into virtual space, the cursor changes
%	shape.

	{ "right_side",	"scroll_left",		S_CALL },
% right_side
%	Moves the cursor to the right side of the window, regardless of the
%	length of the line.

	{ "save_keystroke_macro", &cbrief_save_ksmacro, NO_ARG },
% save_keystroke_macro
%	Save the current keystroke macro in the specified file. If no
%	extension is specified, .km is assumed.

	{ "screen_down", &scroll_down_in_place,	NO_ARG },
% screen_down
%	Moves the buffer, if possible, down one line in the window, keeping
%	the cursor on the same text line.

	{ "screen_up",	&scroll_up_in_place,	NO_ARG },
% screen_up
%	Moves the buffer, if possible, up one line in the window, keeping
%	the cursor on the same text line.

	{ "search_again",	&cbrief_search_again, NO_ARG },
% search_again
%	Searches either forward or backward for the last given pattern,
%	depending on the direction of the previous search.

	{ "search_back", 	&cbrief_search_back, NO_ARG },
% search_back
%	Searches backward from the current position to the beginning of the
%	current buffer for the given pattern.

	{ "search_fwd",		&cbrief_search_fwd, NO_ARG },
% search_fwd
%	Searches forward from the current position to the end of the
%	current buffer for the given pattern.

	{ "dos", &cbrief_dos, C_LINE },
	{ "sh", &cbrief_dos, C_LINE },
% dos
%	Gets parameter the command-line and pauses at exit,
%	or just runs the shell.
%	
%	Exits temporarily to the operating system.

	{ "swap_anchor", &exchange_point_and_mark,	NO_ARG },
% swap_anchor
%	Exchanges the current cursor position with the mark.

	{ "tabs",		&cbrief_tabs,		C_ARGV },
% tabs
%	Sets the tab stops for the current buffer.

	{ "top_of_buffer",	&bob,			NO_ARG },
% top_of_buffer
%	Moves the cursor to the first character of the buffer.

	{ "top_of_window",	&goto_top_of_window,	NO_ARG },
% top_of_window
%	Ctrl+Home moves the cursor to the top line of the current window,
%	retaining the column position. Home Home moves the cursor to the
%	top line and the first column of the current window.

	{ "translate_again",	&cbrief_translate_again,	NO_ARG },
% translate_again
%	Searches again for the specified pattern in the direction of the
%	previous Translate command, replacing it with the given string.

	{ "translate_back",		&cbrief_translate_back,		C_ARGV },
% translate_back
%	Searches for the specified pattern from the current position to the
%	beginning of the buffer, replacing it with the given string.

	{ "translate",			&cbrief_translate,			C_ARGV },
% translate
%	Searches for the specified pattern from the current position to the
%	end of the buffer, replacing it with the given string.

	{ "undo",			"undo",			S_CALL },
% undo
%	Reverses the effect of the last n commands (or as many as your
%	memory can hold). Any command that writes changes to disk (such as
%	Write) cannot be reversed.

	{ "up",				&go_up_1,		NO_ARG },
% up
%	Moves the cursor up one line, staying in the same column. When the
%	cursor is moved into virtual space, it changes shape.

	{ "toupper",	"cbrief_block_to('u')",	S_LANG },
% toupper
%	Converts the characters in a marked block to uppercase.

	{ "use_tab_char",	&cbrief_use_tab,	C_ARGV },
% use_tab_char
%	Determines whether spaces or tabs are inserted when the Tab key is
%	pressed to add filler space.

% warnings_only
%	Forces the Compile buffer command to check the output from the
%	compiler for messages. If any warning or error messages are	found,
%	the compile is considered to have failed.

	{ "write_buffer",	&cbrief_write,	NO_ARG },
% write_buffer
%	Writes the current buffer to disk or, if a block of text is marked,
%	prompts for a specific file name. BRIEF does not support writing
%	column blocks.

	{ "write_and_exit",	&cbrief_write_and_exit,		NO_ARG },
% write_and_exit
%	Writes all modified buffers, if any, and exits BRIEF without
%	prompting.

	{ "zoom_window",	&onewindow,					NO_ARG },
% zoom_window
%	If there is more than one window on the screen, Zoom window toggle
%	will enlarge the current window to a full screen window, and save
%	the previous window configuration.

	{ "whichkey",			&showkey,					NO_ARG },
% whichkey
%	Tells which command is invoked by a key. (brief, non-std)

	{ "showkey",			&showkey,					NO_ARG },
% showkey
%	Describes the key. (Jed)

	{ "ascii_code",			&cbrief_ascii_code,			C_LINE },
% ascii_code
%	Inserts character by ASCII code. (brief, non-std)

	{ "save_position",		&push_spot,					NO_ARG },
% save_position
%	Save cursor position into the stack.

	{ "restore_position",	&pop_spot,					NO_ARG },
% restore_position
%	Restores previous cursor position from stack.

	{ "insert",				&cbrief_insert,				C_LINE },
% insert
%	Inserts a string into the current position.

	{ "_home",				&brief_home,				NO_ARG },
% _home
%	BRIEF's home key.
%
%	[Home] = Beginning of Line.
%	[Home][Home] = Top of Window.
%	[Home][Home][Home] = Beginning of Buffer.
%	
%	There was 2 version of home macro, the _home and the new_home.
%	The only I remember is that the _home could	not stored in
%	KeyStroke Macros. The same for the _end.

	{ "_end",				&brief_end,					NO_ARG },
% _end
%	BRIEF's end key. se
%
%	[End] = End of Line.
%	[End][End] = Bottom of Window.
%	[End][End[End] = End of Buffer.

	{ "brace",				&cbrief_brace,				NO_ARG },
% brace
%	BRIEF's check braces macro (the buggy one).

	{ "comment_block",		&comment_region_or_line,	NO_ARG },
% comment_block
%	Comment block

	{ "uncomment_block",	&uncomment_region_or_line,	NO_ARG },
% uncomment_block
%	Uncomment block

	{ "bufed",				&bufed,						C_LINE },
% bufed
%	Jed's bufed macro (buffer manager).

	{ "cbufed",				&cbrief_bufed,				C_LINE },
% cbufed
%	CBRIEF's bufed macro (buffer manager).

	{ "dired",				&dired,						C_LINE },
% dired
%	Jed's dired macro (file manager).

	{ "build_it",			&cbrief_build_it,			NO_ARG },
	{ "make",				&cbrief_build_it,			NO_ARG },
% build_it
%	Runs make (non-brief)

	{ "tocapitalize",		"cbrief_block_to('c')",		S_LANG },
% tocapitalize
%	Jed's xform_region('c') (non-brief)

	{ "man",				&cbrief_man,				C_LINE },
% man
%	Shows a man page (non-brief)

	{ "pwd",				&cbrief_pwd,				NO_ARG },
% pwd
%	Displays the current working directory. (non-brief)

	{ "ren",				&cbrief_rename_file,		C_ARGV },
% ren
%	Rename file (non-brief)

	{ "cp",					&cbrief_copy_file,			C_ARGV },
% cp
%	Copy file. (non-brief)

	{ "occur",				&occur,						NO_ARG },
% occur
%	Jed's 'occur' macro. (non-brief, JED)

	{ "color_scheme",		&cbrief_color_scheme,		C_ARGV },
% color_scheme
%	Displays or selects a color scheme. ('^AiC' for UI)
%	(non-brief)

%	compile.sl module
%   compile_parse_errors                parse next error
%   compile_previous_error              parse previous error
%   compile_parse_buf                   parse current buffer as error messages
%   compile                             run program and parse it output
%   compile_select_compiler             set compiler for parsing error messages
%   compile_add_compiler                add a compiler to database
	{ "compile_parse_errors", &compile_parse_errors, NO_ARG },
	{ "compile_previous_error", &compile_previous_error, NO_ARG },
	{ "compile_parse_buf", &compile_parse_buf, NO_ARG },
	{ "compile_select_compiler", &compile_select_compiler, NO_ARG },
	{ "compile_add_compiler", &compile_add_compiler, NO_ARG },
	
%
	{ "xcopy",				&cbrief_xcopy,				NO_ARG },
% xcopy
%	Copies the selected block to system clipboard.
%	(non-brief)

	{ "xpaste",				&cbrief_xpaste,				NO_ARG },
% xpaste
%	Inserts the contents of system clipboard into the current bufffer.
%	(non-brief)

	{ "xcut",				&cbrief_xcut,				NO_ARG },
% xpaste
%	Copies the selected block to system clipboard and deletes
%	the selection.
%	(non-brief)
};
% v3.1 new macros
% ===============
% close_window
%	Collapses the current window.
% 
% inq_btn2_action
%	Returns the default action setting of mouse button 2.
%
% inq_ctrl_state
%	Returns the current state of mouse controls.
%	
% inq_mouse_action
%	Returns the name of the current mouse handler.
%	
% parse_filename
%	Parses a file name into its component parts.
%	
% set_btn2_action
% set_ctrl_state
% set_mouse_action
% set_mouse_type

%!%+
%\function{cbrief_in}
%\synopsis{Executes CBRIEF's macros}
%\usage{Integer cbrief_in(argv|NULL, ...)}
%\description
% Executes cbrief "bultins" macros.
%	
%\var{argv} = The list of the parameters.
% The first parameter is the name of the command to execute, and the
% rest are the command's parameters.
%
% If \var{argv} is NULL (omitted) then the following parameters will
% count as the elements of \var{argv}.
%
% Returns 0 if the command does not exists; otherwise 1 on success
% or -1 on error.
%!%-
private variable cin_index = Assoc_Type[List_Type];

private define cbrief_build_cindex()
{
	variable e;
	foreach e ( mac_list ) 
		cin_index[e[0]] = e;
}

define cbrief_in()
{
	variable i, l;
	variable e, f;

	ifnot ( length(cin_index) )
		cbrief_build_cindex();
	
	variable list;
	if ( _NARGS == 0 )	return 0;
	if ( _NARGS == 1 )	{ list = (); }
	else { e = (); list = __pop_list (_NARGS); }
	variable argv = list_to_array(list);
	variable argc = length(argv);
	
	variable cmd = argv[0];
	variable err;

	% find the command
	try(err) { e = cin_index[cmd]; }
	catch AnyError: { return 0; } % just not found
	
	%
	variable ctype = e[2];
	
	switch ( ctype )
		{ case C_ARGV: (@e[1])(argv); }
		{ case C_LINE: {
				variable cline = "";
				argc --;
				_for ( 1, argc, 1 )
					{ i = (); cline = strcat(cline, argv[i], " "); }
				cline = strtrim(cline);
				ifnot ( strlen(cline) )
					(@e[1])();
				else
					(@e[1])(cline);
				}
			}
		{ case S_LANG: eval(e[1]); }
		{ case S_CALL: call(e[1]); }
		{ case NO_ARG: (@e[1])(); }
		{ throw RunTimeError, "CBI-2: element in mac_list has undefined call-type";  }
	
	return 1; % everything ok, TODO: on error return < 0
}

%!%+
%\function{cbrief_split}
%\synopsis{Splits a string into substrings}
%\usage{List_Type cbrief_split(in, [delim], [flags])}
%\description
% Splits a string into substrings that are based on the characters
% in an array with support for escape sequences.
%
%\var{delim}
%	The array of delimiters (default = [' ', '\t'])
%	
%\var{flags} bit flags
%	0x01 = Keep quotes in strings, by default it removes them.
%	0x02 = Add code for backquotes (`).
%	0x04 = Activate escape sequences checking.
%	0x08 = Translate esc seq to actual value.
%	0x10 = Translate esc seq, except if it is inside single quotes.
%	0x20 = Translate esc seq, except if it is inside double quotes.
%	0x40 = Translate esc seq, except if it is inside back quotes.
%
%	TODO: \x \u \0 need testing
%
%Returns the list of the substrings.
%	
%\example
%	variable param_list = cbrief_split("cmd param1 \"param2 'still param2'\" `param 3`");
%!%-
define cbrief_split(in, delim, flags)
{
	variable c, s, i, j, len;
	variable dq, sq, bq;	% quote-flags
	variable oct, hex;
	variable found;
	variable result = {};

	if ( in    == NULL )	throw RunTimeError, "cbrief_split() the string to split is NULL";
	if ( delim == NULL )	delim = [' ', '\t'];
	if ( flags == NULL )	flags = 0;

	% flags
	variable keep_q = (flags & 0x01);	% do not remove quotes on '"' and '\''
	variable back_q = (flags & 0x02);	% support '`'
	variable slst_q = (flags & 0x04);	% check '\' before characters
	variable tran_q = (flags & 0x08);	% translate '\'
	variable tra_sq = (flags & 0x10);
	variable tra_dq = (flags & 0x20);
	variable tra_bq = (flags & 0x40);

	variable delim_count = length(delim);
	
	len = strlen(in);
	dq = 0; sq = 0; bq = 0;
	s = "";
	
	for ( i = 0; i < len; i ++ ) {
		
		c = in[i];

		if ( (flags & 0x7C) && (c == '\\') ) {	% we have escape sequence
			variable nc = 0; % next character
			
			if ( i < len - 1 ) {
				nc = in[i+1];
				
				if ( slst_q || (sq && tra_sq) || (dq && tra_dq) || (bq && tra_bq) ) {
					% store this seq
					s += (char)(c);
					s += (char)(nc);
					i ++;
					continue;
					}

				% translate characters
				switch ( nc )
				{ case 'e': s += '\033'; }
				{ case 't': s += '\t'; }
				{ case 'n': s += '\n'; }
				{ case 'r': s += '\r'; }
				{ case 'f': s += '\f'; }
				{ case 'b': s += '\b'; }
				{ case 'a': s += '\a'; }
				{ case 'v': s += '\v'; }
				{ case 'x':	% hex
					hex = 0;
					loop ( 2 )
						if ( i+2 < len - 1 )
							{ nc = in[i+2]; hex = (hex << 4) | _chex2dig(nc); i ++; }
					s += (char)(hex);
					}
				{ case 'u': % unicode
					hex = 0;
					loop ( 4 )
						if ( i+2 < len - 1 )
							{ nc = in[i+2]; hex = (hex << 4) | _chex2dig(nc); i ++; }
					s += (char)(hex);
					}
				{ nc >= '0' && nc <= '9': % octal
					oct = nc - '0';
					loop ( 2 )
						if ( i+2 < len - 1 )
							{ nc = in[i+2]; oct = (oct << 3) | (nc - '0'); i ++; }
					s += (char)(oct);
					}
				{ s += (char)(nc); }
				
				i ++; % the next is already processed
				continue;
				}
			else % no next char
				s += (char)(c);
			}

		% check quote characters
		if ( dq && c == '"' ) 					{ dq = not dq; if ( keep_q ) s += (char)(c); continue; }
		else if ( sq && c == '\'' ) 			{ sq = not sq; if ( keep_q ) s += (char)(c); continue; }
		else if ( back_q && bq && c == '`' )	{ bq = not bq; if ( keep_q ) s += (char)(c); continue; }
		else if ( c == '"' )					{ dq = not dq; if ( keep_q ) s += (char)(c); continue; }
		else if ( c == '\'' )					{ sq = not sq; if ( keep_q ) s += (char)(c); continue; }
		else if ( back_q && c == '`' )			{ bq = not bq; if ( keep_q ) s += (char)(c); continue; }

		if ( sq || dq || bq )	% if we are inside quotes
			s += (char)(c);		% just store 'c'
		else {					% ouside of quotes
			% check if it is delimiter
			found = 0;
			for ( j = 0; j < delim_count; j ++ ) {
				if ( c == delim[j] ) {
					found = 1;
					break;
					}
				}
			
			if ( found ) { % c is delimiter
				ifnot ( s == "" )
					list_append(result, s);
				s = "";
				}
			else % other character
				s += (char)(c);
			}
		}

	% if remains something in s, add it
	ifnot ( s == "" )
		list_append(result, s);

	return result;
}

%%
%%	Execute BRIEF's commands
%%
%%	f(..) = S-Lang syntax
%%	m x   = BRIEF syntax
%%
private variable cin_opts = "";
private variable cin_hist_file = jed_home + "/.hist_cmdline";

private define cbrief_build_opts()
{
	variable opts_a, opts_i, i, l;
	cin_opts = "";
	opts_a = assoc_get_keys(cin_index);
	opts_i = array_sort(opts_a);	
	l = length(opts_i);
	for ( i = 0; i < l; i ++ )
		cin_opts = strcat(cin_opts, (i==0)? "" : ",",  opts_a[opts_i[i]]);
}

%% add or remove 'space-bar' to mini
define cbrief_minimap(actsp)
{
	variable	m = "Mini_Map";
	undefinekey(" ", m);
	if ( actsp )
		definekey("self_insert_cmd", " ", m);
	else
		definekey("mini_complete", " ", m);
}

%% this is the '?' prefix of the command-line
public define cbrief_calc()
{
	variable x, s = "";
	
	loop ( _NARGS ) {
		x = ();
		if ( typeof(x) == String_Type )
			s += sprintf(" %s -", x);
		else		
			s += sprintf(" Int %d (0x%08X), Real %.3f (%e) -", (int)(x), (int)(x), double(x), double(x));
		}
	s = strfit(s, window_info('w'), 1);
	message(s);
}

%%
%%	Command line (F10)
%%	
public define cbrief_cmd()
{
	variable in, argv, argl, i, l, argc, cmd, err, e, fp;

	if ( cin_opts == "" )
		cbrief_build_opts();
	
	forever {
		if ( _NARGS )	in = ();
		else {
			cbrief_minimap(1);
			in = read_with_completion(cin_opts, "Command:", "", "", 's');
			cbrief_minimap(0);

			% store to histrory
%			fp = fopen(cin_hist_file, "a");
%			if ( fp != NULL ) {
%				in = strtrim(in);
%				if ( strlen(in) )
%					fputs(in, fp);
%				fclose(fp);
%			   }
			}
		
		err = 0;
		in = strtrim(in);
		ifnot ( strlen(in) ) break;

		if ( in[0] == '?' ) { % print/calc something
			in = strtrim(substr(in, 2, strlen(in) - 1));
			in = strcat("cbrief_calc(", in, ");");
			err = 1; % exit
			try(e) { eval(in); } catch AnyError: { err = -1; uerrorf("Error in expression: %s [%s]", e.message, in); }
			}
		else if ( in[0] == '$' ) {	% eval somthing
			in = substr(in, 2, strlen(in) - 1);
			err = 1; % exit
			try(e) { eval(in); } catch AnyError: { err = -1; uerrorf("%s [%s]", e.message, in); }
			}
		else if ( in[0] == '!' ) {	% run shell command, output in new buf
			in = substr(in, 2, strlen(in) - 1);
			err = 1; % exit
#ifdef CBRIEF_PATCH_V5
			save_screen();
#endif
			shell_perform_cmd(in, 0);
#ifdef CBRIEF_PATCH_V5
			restore_screen();
			redraw_screen();
#endif
			}
		else if ( in[0] == '&' ) {	% run shell command, in new term
#ifdef UNIX
			variable xterm;
			
			in = substr(in, 2, strlen(in) - 1);			
			if ( is_xjed() || getenv("DISPLAY") != NULL ) {
				xterm = cbrief_find_xterm();
				cmd = strcat(xterm + " -e ", in, " &");
				}
			else
				cmd = strcat(getenv("SHELL") + " -c '", in, "' &");
#ifdef CBRIEF_PATCH_V5
			save_screen();
#endif
			() = system(cmd);
#ifdef CBRIEF_PATCH_V5
			restore_screen();
			redraw_screen();
#endif
#else
			uerror("Not supported in this OS");
#endif
			err = 1; % exit
			}
		else if ( in[0] == '<' && in[1] == '!' ) {	% run shell command, output in this buf
			in = substr(in, 3, strlen(in) - 2);
			err = 1; % exit
#ifdef CBRIEF_PATCH_V5
			save_screen();
#endif
			run_shell_cmd(in);
#ifdef CBRIEF_PATCH_V5
			restore_screen();
			redraw_screen();
#endif
			}
		else if ( in[0] == '<' ) {	% insert the contents of a file to this location
			in = strtrim(substr(in, 2, strlen(in) - 1));
			err = 1; % exit
#ifdef CBRIEF_PATCH_V5
			save_screen();
#endif
			if ( strlen(in) )
				insert_file(in);
			else
				cbrief_read_file();
#ifdef CBRIEF_PATCH_V5
			restore_screen();
			redraw_screen();
#endif
			}
		else if ( in[0] == '~' ) {	% run shell command
#ifdef CBRIEF_PATCH_V5
			save_screen();
#endif
			() = system(in);
#ifdef CBRIEF_PATCH_V5
			restore_screen();
			redraw_screen();
#endif
			}
		else if ( strncmp(in, ">>", 2) == 0 ) { % append selected text of the whole buffer to output
			in = strtrim(substr(in, 3, strlen(in) - 2));
			if ( file_status(in) == 1 || file_status(in) == 0 ) {
				if ( is_visible_mark() )
					append_region_to_file(in);
				else {
					push_spot();
					bol(); push_mark(); eol();
					append_region_to_file(in);
					pop_mark(0);
					pop_spot();
					}
				}
			else
				uerrorf("Access denied. [%s]", in);
			err = 1; % exit
			}
		else if ( in[0] == '>' ) {	% write selected text of the whole buffer to output
			in = strtrim(substr(in, 2, strlen(in) - 1));
			if ( file_status(in) == 1 )
				delete_file(in);
			if ( file_status(in) == 0 ) {
				if ( is_visible_mark() )
					append_region_to_file(in);
				else {
					push_spot();
					bol(); push_mark(); eol();
					append_region_to_file(in);
					pop_mark(0);
					pop_spot();
					}
				}
			else
				uerrorf("Access denied. [%s]", in);
			err = 1; % exit
			}
		else if ( in[0] == '|' ) {	% write selected text of the whole buffer to output (throu pipe)
			in = strtrim(substr(in, 2, strlen(in) - 1));
			if ( file_status(in) == 0 ) {
#ifdef CBRIEF_PATCH_V5
				save_screen();
#endif
				if ( is_visible_mark() )
					pipe_region(in);
				else {
					push_spot();
					bol(); push_mark(); eol();
					pipe_region(in);
					pop_mark(0);
					pop_spot();
					}
#ifdef CBRIEF_PATCH_V5
				restore_screen();
				redraw_screen();
#endif
				}
			else
				uerrorf("Access denied. [%s]", in);
			err = 1; % exit		
			}
		else {
			% it is command line
			argl = cbrief_split(in,,0x05);
			argv = list_to_array(argl);
			argc = length(argv);
			err  = cbrief_in(argl);
			cmd  = argv[0];

			if ( err == 0 ) {	% command not found, it is not CBRIEF's build in
				variable f_int = is_internal(cmd);
				variable f_def = is_defined(cmd);
				
				if ( f_int || f_def ) {
					if ( argc == 1 ) {
						% it is only a word
						if ( f_int )
							call(cmd);
						else {
							cmd = strcat(argv[0], "();");
							try(e) { eval(cmd); } catch AnyError: { err = -1; uerrorf("CBC-2: %s", e.message); }
							}
						err = 1; % exit
						}
					else if ( f_int ) {
						% build for slang
						cmd = strcat(argv[0], "(");
						for ( i = 1; i < argc; i ++ ) {
							if ( argv[i][0] == '"' || argv[i][0] == '\'' )
								cmd = strcat(cmd, argv[i], ",");
							else
								cmd = strcat(cmd, "\"", argv[i], "\",");
							}
						if ( argc > 1 )
							cmd = substr(cmd, 1, strlen(cmd)-1);
						cmd = strcat(cmd, ")");
						try(e) { eval(cmd); } catch AnyError: { err = -1; uerrorf("CBC-3: %s", e.message); }
						err = 1; % exit
						}
					else { uerrorf("'%s' is internal, cannot have parameters.", argv[0]); err = -1; }
					}
				else { uerrorf("'%s' undefined.", argv[0]); err = -1; }
				}
			}
	
		if ( err < 0 )		break;		% if error, stop
		if ( _NARGS > 0 )	continue;	% if has more arguments, continue
		if ( err > 0 )		break;		% if success return
		}
}

%% --- menus --------------------------------------------------------------

%%
private define cbrief_load_popups_hook()
{
	variable m;

	m = "Global.&Edit";
	menu_append_separator(m);
%	menu_append_item(m, "Slide &in block",	"cbrief_slide_in");
%	menu_append_item(m, "Slide ou&t block",	"cbrief_slide_out");
	menu_append_item(m, "Co&mment block",	"comment_region_or_line");
	menu_append_item(m, "U&ncomment block",	"uncomment_region_or_line");

	m = "Global.&Search";
	menu_append_separator(m);
	menu_append_item(m, "&Search",				"cbrief_search_fwd");
	menu_append_item(m, "Re&verse Search",		"cbrief_search_back");
	menu_append_item(m, "Search &Again",			"cbrief_search_again");
	menu_append_item(m, "Reverse Search Agai&n",	"cbrief_search_again_r");
	menu_append_separator(m);
	menu_append_item(m, "Trans&late",	"cbrief_translate");
	menu_append_separator(m);
	menu_append_item(m, "Matching &Delimiter",	"cbrief_delim_match");

	m = "Global.&Buffers.&Toggle";
	menu_append_separator(m);
	menu_append_item(m, "Toggle Regular &Expr.",	"cbrief_toggle_re");
	menu_append_item(m, "Toggle Case &Sens.",	"cbrief_search_case");
	
	m = "Global.S&ystem";
	menu_append_separator(m);
	menu_append_item(m, "C&BRIEF Console", "cbrief_cmd");
	menu_append_item(m, "Sus&pend CBRIEF", "cbrief_dos");
	
	m = "Global.&Help";
	menu_append_separator(m);
	menu_append_item(m, "Describe &CBRIEF Mode", "cbrief_long_help");
}
add_to_hook("load_popup_hooks", &cbrief_load_popups_hook);

%% --- initialization -----------------------------------------------------

%% initialize
private define cbrief_init()
{
	variable m, tab_kmaps = ["C", "SLang", "TPas", "Lua", "make", "perl", "PHP", "python", "TCL", "Text" ];

	% default tabstops
	Tab_Stops = [0:19] * TAB_DEFAULT + 1;

	% reinstall tab and back-tab
	foreach m ( tab_kmaps ) {
		if ( keymap_p(m) ) {
			if ( cbrief_control_wins() ) {
%				undefinekey(Key_F1, m);
%				undefinekey(Key_F2, m);
%				undefinekey(Key_Alt_F2, m);
%				undefinekey(Key_F3, m);
%				undefinekey(Key_F4, m);
%				undefinekey("^Z", m);
				setkey("cbrief_change_win",			Key_F1);
				setkey("cbrief_resize_win",			Key_F2);
				setkey("one_window",				Key_Alt_F2);
				setkey("cbrief_create_win",			Key_F3);
				setkey("cbrief_delete_win",			Key_F4);
				setkey("one_window", "^Z");
				}
			if ( cbrief_control_tabs() ) {
				undefinekey("\t", m);	definekey("cbrief_slide_in(1)", "\t", m);
				undefinekey("\e\t", m);	definekey("cbrief_slide_out(1)", "\e\t", m);
				}
			if ( cbrief_control_indent() ) {
				undefinekey("{", m);	definekey("self_insert_cmd", "{", m);
				undefinekey("}", m);	definekey("self_insert_cmd", "}", m);
				undefinekey("(", m);	definekey("self_insert_cmd", "(", m);
				undefinekey(")", m);	definekey("self_insert_cmd", ")", m);
				undefinekey("[", m);	definekey("self_insert_cmd", "[", m);
				undefinekey("]", m);	definekey("self_insert_cmd", "]", m);
				undefinekey("\r", m);	definekey("cbrief_enter", "\r", m);
				}
			}
		}

	cbrief_dired_init("cbrief_dired");
}
append_to_hook("_jed_startup_hooks", &cbrief_init);

#ifdef UNIX
%% initialize display
private define cbrief_disp_init() {
	variable xterm = getenv("TERM");

	if ( xterm != NULL ) {
		if ( xterm == "linux" || xterm == "rxvt" || xterm == "rxvt-unicode" || xterm == "urxvt" )
			tt_send("\e=");  % set linux console to application mode keypad
		}
	}
append_to_hook("_jed_init_display_hook", &cbrief_disp_init);
#endif

%% --- keys ---------------------------------------------------------------

%%	BRIEF's keys (BRIEF v3.1, 1991)
static variable _keymap = {
	%% Basic keys 
	{ "cbrief_escape",			"\e\e\e" },			% Brief Manual: Escape. ESC somehow to abort (^Q is set to abort)
	{ "cbrief_backspace",		Key_BS },			% Brief Manual: Backspace
	{ "bdelete_word",			Key_Ctrl_BS },		% Brief Manual: Ctrl+Bksp. Delete Previous Word
	{ "delete_word",			Key_Alt_BS },		% Brief Manual: undefined, exists in KEYBOARD.H
	{ "cbrief_enter",			Key_Enter },		% Brief Manual: Enter
	{ "brief_open_line",		Key_Ctrl_Enter },	% Brief Manual: Ctrl-Enter. Open Line
	{ "cbrief_slide_in(1)",		Key_Tab },			% Brief Manual: Tab
	{ "cbrief_slide_out(1)",	Key_Shift_Tab },	% Brief Manual: Shift-Tab. Back Tab

	%%	Control keys
	{ "brief_line_to_eow",		"^B" },		 	% Brief Manual: Line to Bottom
	{ "brief_line_to_mow",		"^C" },		 	% Brief Manual: Center Line in Window. Here: Windows Copy
	{ "scroll_up_in_place", 	"^D" },		 	% Brief Manual: Scroll Buffer Down
	{ "@^AoF",					"^G" },		 	% Brief Manual: Go To Routine (popup list and select); JED/EMACS = abort
	{ "cbrief_slide_in(1)",		"^I" },		 	% tab
	{ "cbrief_slide_out(1)",	"\e^I" },	 	% backtab
	{ "brief_delete_to_bol",    "^K" },		 	% Brief Manual: Delete to beginning of line
	{ "redraw",					"^L" },		 	% undefined in Brief -- redraw, not a BRIEF key, but Unix one
	{ "cbrief_enter",			"^M" },		 	% enter
	{ "compile_parse_errors",	"^N" },		 	% Brief Manual: Next Error
	{ "compile_parse_buf",		"^P" },		 	% Brief Manual: Pop Up Error Window
	{ "brief_line_to_bow",		"^T" },		 	% Brief Manual: Line to Top
	{ "redo",					"^U" },		 	% Brief Manual: Redo
	{ "cbrief_toggle_backup",	"^W" },		 	% Brief Manual: Backup File Toggle
	{ "cbrief_write_and_exit",	"^X" },		 	% Brief Manual: Write Files and Exit, Windows Cut
	{ "one_window",				"^Z" },		 	% Brief Manual: Zoom Window
	{ "brief_delete_buffer",	"" },		 	% Brief Manual: Ctrl+Minus, Delete Curr. Buffer

	%%	Arrows and special keys
	{ "cbrief_paste",				Key_Ins },			% Brief Manual: Paste from Scrap
	{ "cbrief_delete",				Key_Del },			% Brief Manual: Delete
	{ "brief_home",					Key_Home },			% Brief Manual: Home BOL, Home Home = Top of Window, Home Home Home = Top of Buffer
	{ "brief_end",					Key_End  },			% Brief Manual: End  EOL, End  End  = End of Window, End  End  End  = End of Buffer
	{ "brief_pageup",				Key_PgUp },			% Brief Manual: Page Up
	{ "brief_pagedown",				Key_PgDn },			% Brief Manual: Page Down
	{ "scroll_right",				Key_Shift_Home },	% Brief Manual: Left side of Window
	{ "scroll_left",				Key_Shift_End },	% Brief Manual: Right side of Window
	{ "bob",						Key_Ctrl_PgUp },	% Brief Manual: Top of Buffer
	{ "eob",						Key_Ctrl_PgDn },	% Brief Manual: End of Buffer
	{ "goto_top_of_window",			Key_Ctrl_Home },	% Brief Manual: Top of Window
	{ "goto_bottom_of_window",		Key_Ctrl_End },		% Brief Manual: End of Window

	%%	KEYPAD (works on linux console and rxvt)
	{ "cbrief_copy",			Key_KP_Add },			% Brief Manual: Copy to Scrap
	{ "cbrief_cut",				Key_KP_Subtract },		% Brief Manual: Cut to Scrap
	{ "@\eu",					Key_KP_Multiply },		% Brief Manual: Undo
	{ "@^M",					Key_KP_Enter },			% enter
	{ "cbrief_paste",			Key_KP_0 },				% Brief Manual: Paste
	{ "cbrief_delete",			Key_KP_Delete },		% Brief Manual: Delete block or front character
	
	{ "brief_home",				Key_KP_7 },				% home
	{ "brief_end",				Key_KP_1 },				% end
	{ "brief_pageup",			Key_KP_9 },				% pgup
	{ "brief_pagedown",			Key_KP_3 },				% pgdn
	
	{ "previous_line_cmd",		Key_KP_8 },				% up
	{ "next_line_cmd",			Key_KP_2 },				% down
	{ "previous_char_cmd",		Key_KP_4 },				% left
	{ "next_char_cmd",			Key_KP_6 },				% right
	{ "brief_line_to_mow",		Key_KP_5 },				% undocumented, in my version was 'centered to window'

	%%	Brief's window keys
	%%
	%%	F1+arrow = Change Window, Alt+F1 = Toggle Borders
	%%	F2+arrow = Resize Window, Alt+F2 = Zoom Windows
	%%	F3+arrow = Create Window
	%%	F4+arrow = Delete Window
	%%
	%%  shift-arrow, alt-arrow = quick change window (Borland/KEYBOARD.H)
	%%
	{ "cbrief_change_win",			Key_F1 },		% Brief Manual: Change Window
	{ "cbrief_wordhelp",			Key_Ctrl_F1 },	% on-line help on word
	{ "cbrief_resize_win",			Key_F2 },		% Brief Manual: Resize Window
	{ "one_window",					Key_Alt_F2 },	% Brief Manual: Zoom
	{ "cbrief_create_win",			Key_F3 },		% Brief Manual: Create Window
	{ "cbrief_delete_win",			Key_F4 },		% Brief Manual: Delete Window (delete the other-window)

	%%	function keys
	{ "cbrief_search_fwd",			Key_F5 },		% Brief Manual: Search Forward
	{ "cbrief_search_back",			Key_Alt_F5 },	% Brief Manual: Search Backward
	{ "cbrief_search_again",		Key_Shift_F5 },	% Brief Manual: Search Again
	{ "cbrief_search_case",			Key_Ctrl_F5 },	% Brief Manual: Case Sens. Toggle
	
	{ "cbrief_translate",			Key_F6 },		% Brief Manual: Tanslate Forward
	{ "cbrief_translate_again",		Key_Shift_F6 },	% Brief Manual: Translate Again
	{ "cbrief_translate_back",		Key_Alt_F6 },	% Brief Manual: Translate Backward
	{ "cbrief_toggle_re",			Key_Ctrl_F6 },	% Brief Manual: Regular Expr. Toggle

	{ "cbrief_remember",			Key_F7 },		% Brief Manual: Remember (record macro)
	{ "cbrief_pause_ksmacro",		Key_Shift_F7 },	% Brief Manual: Pause Keystroke Macro
	{ "cbrief_load_ksmacro",		Key_Alt_F7 },	% Brief Manual: Load Keystroke Macro
	{ "cbrief_playback",			Key_F8 },		% Brief Manual: Playback
	{ "cbrief_save_ksmacro",		Key_Alt_F8 },	% Brief Manual: Save Keystroke Macro
	{ "macro_query",				Key_Shift_F8 },	% Macro Query: if not in the mini buffer and if during keyboard macro,
													%	allow user to enter different text each time macro is executed

	{ "cbrief_cmd",					Key_F10 },		% Brief Manual: Execute command (like M-x emacs but with parameters)
	{ "cbrief_cmd",					"\e=" },		% Alt = -- Alternative key for console, just in case...

	%%	Alt Keys
	{ "cbrief_noinc_mark",			"\ea" },		% Alt A -- Brief Manual: (3.1) Non-inclusive Mark; (BRIEF 2.1 = Drop BkMark)
	{ "cbrief_buf_list",			"\eb" },		% Alt B -- Brief Manual: Buffer List (buffer managment list)
	{ "cbrief_mark_column",   		"\ec" },		% Alt C -- Brief Manual: Column Mark; (BRIEF 2.1 = toggle case search)
	{ "delete_line",           		"\ed" },		% Alt D -- Brief Manual: Delete Line
	{ "cbrief_edit_file",			"\ee" },		% Alt E -- Brief Manual: Edit File (open file)
	{ "cbrief_disp_file",			"\ef" },		% Alt F -- Brief Manual: Display File Name
	{ "goto_line_cmd",         		"\eg" },		% Alt G -- Brief Manual: Go To Line
	{ "cbrief_help",				"\eh" },		% Alt H -- Brief Manual: Help
	{ "toggle_overwrite",			"\ei" },		% Alt I -- Brief Manual: Insert Mode Toggle 
	{ "cbrief_bkgoto",				"\ej" },		% Alt J -- Brief Manual: Jump to Bookmark
	{ "kill_line",             		"\ek" },		% Alt K -- Brief Manual: Delete to EOL
	{ "cbrief_line_mark",   		"\el" },		% Alt L -- Brief Manual: Line Mark
	{ "cbrief_stdmark"	,    		"\em" },		% Alt M -- Brief Manual: Mark
	{ "cbrief_next_buf",			"\en" },		% Alt N -- Brief Manual: Next Buffer
	{ "cbrief_output_file",			"\eo" },		% Alt O -- Brief Manual: Change Output File (renames but not save yet, close to 'save as')
	{ "cbrief_prev_buf", 			"\ep" },		% Alt P -- Brief Manual: Print Block -- Previous Buffer HERE
	{ "cbrief_quote",				"\eq" },		% Alt Q -- Brief Manual: Quote (Insert Keycode)
	{ "cbrief_read_file",			"\er" },		% Alt R -- Brief Manual: Read File into Buffer
	{ "cbrief_search_fwd",			"\es" },		% Alt S -- Brief Manual: Search Forward
	{ "cbrief_translate",			"\et" },		% Alt T -- Brief Manual: Translate (replace) Forward
	{ "undo",						"\eu" },		% Alt U -- Brief Manual: Undo
	{ "cbrief_disp_ver",			"\ev" },		% Alt V -- Brief Manual: Display Version ID
	{ "cbrief_write",           	"\ew" },		% Alt W -- Brief Manual: Write (save)
	{ "exit_jed",					"\ex" },		% Alt X -- Brief Manual: Exit (and/or save)
	{ "cbrief_az",					"\ez" },		% Alt Z -- Brief Manual: Suspend BRIEF
	{ "cbrief_prev_buf",		 	"\e-" },		% Alt - -- Brief Manual: Previous Buffer; (BRIEF 2.1, copy above line)
};

%% add keys to _keymap by code
private variable _build_keymap = 0;
private define cbrief_build_keymap()
{
	variable e, s;
	
	if ( _build_keymap ) {
		uerror("Keymap already builded!");
		return;
		}
	
	%% Brief Manual: Repeat
	_for (0, 9, 1) {
		e = ();
		list_append(_keymap, { "digit_arg", "^R" + string(e) } );
		}

	%% self-insert
	foreach e ( ["{", "}", "(", ")", "[", "]", "`", "'", "\"" ] )
		list_append( _keymap, { "self_insert_cmd", e } );

	%%	Alt 0..9 - Brief Manual: Drop Bookmark 1-10
	_for (0, 9, 1) {
		e = (); s = string(e);
		list_append( _keymap, { "cbrief_bkdrop(" + s + ")", "\e" + s });
		}

	if ( cbrief_readline_mode() ) {
		list_append( _keymap, { "brief_home",	"^A" } );
		list_append( _keymap, { "brief_end",	"^E" } );
		}
	else {
		% undefined in Brief, screen/tmux key, home in readline,
		%	menu key for using in macros (we need a ctrl key for menu) that has no problem with screen/tmux
		list_append( _keymap, { "select_menubar",			"^A" } );
		% Brief Manual: Scroll Buffer Up
		list_append( _keymap, { "scroll_down_in_place",		"^E" } );
		}

	ifnot ( cbrief_laptop_mode() ) {
		list_append( _keymap, { "cbrief_prev_word",			Key_Ctrl_Left } );	% Brief Manual: Previous Word
		list_append( _keymap, { "cbrief_next_word",			Key_Ctrl_Right } );	% Brief Manual: Next Word
		}
	else {
		list_append( _keymap, { "brief_home",			Key_Ctrl_Left } );
		list_append( _keymap, { "brief_end",			Key_Ctrl_Right } );
		list_append( _keymap, { "brief_pageup",			Key_Ctrl_Up } );
		list_append( _keymap, { "brief_pagedown",		Key_Ctrl_Down } );
		}

	%% --- NON-BRIEF KEYS ---

	%%	Windows Clipboard
	if ( cbrief_windows_keys() || cbrief_nopad_keys() ) {
		list_append(_keymap, { "cbrief_copy",	"^C" } );
		list_append(_keymap, { "cbrief_cut",	"^X" } );
		list_append(_keymap, { "cbrief_paste",	"^V" } );
		}

	%% more keys
	if  ( cbrief_nopad_keys() || cbrief_more_keys() ) {
		list_append(_keymap, { "cbrief_search_back", "^S" });	% search back, undefined in BRIEF
		list_append(_keymap, { "cbrief_find_prev",	 "^F" });	% search again backward, undefined in BRIEF
		list_append(_keymap, { "cbrief_find_next",	 "\ef" } );	% search again -- display filename in BRIEF
		}

	%% special keys for JED
	if ( Key_BS != "^H" && Key_BS != "" )
		list_append( _keymap, { "help_prefix", "^H" } );		% it is free for the JED's "help_prefix"
	if ( is_xjed() && getenv("DISPLAY") != NULL )
		list_append( _keymap, { "select_menubar", "[29~" } );	% windows menu key
	list_append( _keymap, { "cbrief_xcopy",		Key_Ctrl_Ins  });	% ctrl+ins
	list_append( _keymap, { "cbrief_xpaste",	Key_Shift_Ins });	% shift+ins
	list_append( _keymap, { "cbrief_xcopy",		"" });	% Ctrl+Alt+C
	list_append( _keymap, { "cbrief_xpaste",	"" });	% Ctrl+Alt+V
	list_append( _keymap, { "cbrief_xcut",		"" });	% Ctrl+Alt+V
	_build_keymap = 1;
}

%% remove any control and alt shortcut (at least the a-z)
private define cbrief_clear_keys()
{
	variable s, e, i;

	_for ( 0, 25, 1 ) {
		i = ();
		s = sprintf("^%c",  'A' + i);	unsetkey(s);
		s = sprintf("\e%c", 'a' + i);	unsetkey(s);
		}
	foreach e ( ["\t", "\e\t", "{", "}", "(", ")", "[", "]", "`", "'", "\"" ] )
		unsetkey(e);
}

%% setup keyboard shortcuts
define cbrief_keys()
{
	variable s, e, i;

	cbrief_clear_keys();

	foreach e ( _keymap ) 
		setkey(e[0], e[1]);

%	setkey("cbrief_halt",			Key_Ctrl_Break);		% Brief Manual: Halt (break macro)
%	setkey("brief_delete_buffer",	Key_Ctrl_KP_Subtract);	% Brief Manual: Delete Curr. Buffer (not sure if works with keypad)
%	setkey("brief_kill_region",		Key_Alt_KP_Subtract);	% Brief Manual: Previous Buffer (not sure if works with keypad)
%%
%%	F9 = [build and] run program in Borland, load macro file (evalfile) in Brief
%%	Ctrl+F9 = compile in Borland
%%	Shift+F9 = build in Borland, delete macro file in Brief
%%		
%	setkey("load macro",				Key_F9);		% Brief Manual: Load Macro File (slang file here)
%	setkey("delete macro",				Key_Shift_F9);	% Brief Manual: Delete Macro File (slang file here)
	setkey("cbrief_compile_it",			Key_Alt_F10); 	% Brief Manual: Compile Buffer,
	setkey("cbrief_build_it",			Key_Ctrl_F10); 	% make (non-brief)
	setkey("cbrief_quote",				Key_Shift_F10);	% Brief Manual: undefined, I found it in KEYBOARD.H of 3.1 and 2.1 (macro 'key' not the 'quote')
	setkey("compile_parse_errors",		"^P");
	setkey_reserved("compile_parse_errors", "'");
	setkey("compile_previous_error",	"^N");
	setkey_reserved ("compile_previous_error", ",");
%%	setkey ("ispell",					Key_F7);
	
	if ( cbrief_more_keys() ) {
		setkey("cbrief_build_it",		Key_F9);		% Borland: build and run
		setkey("cbrief_compile_it",		Key_Ctrl_F9);	% Borland: compile
		setkey("dired",		 			Key_F11);		% undefined
		setkey("select_menubar",		Key_F12);		% undefined
		}

	if ( cbrief_nopad_keys() ) {
%		setkey("brief_line_to_mow",		"\e^C");	% Alt+Ctrl C -- center to window
		setkey("cbrief_toggle_re",		"\e");	% Alt+Ctrl R -- toggle regexp search
		setkey("cbrief_search_back",  	"\e");	% Alt+Ctrl S -- search backward
		setkey("cbrief_search_case",	"\e");	% Alt+Ctrl A -- Case Sens. Toggle
		setkey("cbrief_find_prev",		"\e");	% Alt+Ctrl F -- find prev
		setkey("cbrief_translate_back",	"\e");	% Alt+Ctrl T -- replace backward
		}
	
	if ( cbrief_more_keys() ) {
		%
		%	Toggle keys and other options
		%
		%	This key is actually free for the user, re-assign as you wish
		%
		setkey("select_menubar",			"^Oa");
		setkey("cbrief_buf_list",			"^Ob");
		setkey("comment_region_or_line",	"^Oc");
		setkey("dired",						"^Od");
		setkey("@^AFR",						"^Oe");
		setkey("@^AoF",						"^Of");
		setkey("@^AEg",						"^Og");
		setkey("@^AHC",						"^Oh");
		setkey("toggle_overwrite",			"^Oi");
		setkey("@^ABS",						"^Ok");
		setkey("toggle_crmode",				"^Ol");
		setkey("unix_man",					"^Om");
		setkey("toggle_line_number_mode",	"^On");
		setkey("@^AiC",						"^Oo");
		setkey("@^AiC",						"^O^O");
		setkey("cbrief_quote",				"^Oq");
		setkey("cbrief_toggle_re",			"^Or");
		setkey("cbrief_search_case",		"^Os");
		setkey("uncomment_region_or_line",	"^Ou");
		setkey("@^Ait",						"^Ov");
		setkey("toggle_readonly",			"^Ow");
		setkey("exchange_point_and_mark",	"^Ox");
		setkey("@^AyW",						"^Oy");
		setkey("do_shell_cmd",				"^Oz");
			
%		setkey("cbrief_forward_delim",		"[");		% Alt [ -- go ahead to matching (, { or [ -- undefined in Brief, defined in Borland
%		setkey("cbrief_backward_delim",		"]");		% Alt ] -- go back to matching (, { or [ -- undefined in Brief, defined in Borland
		setkey("cbrief_delim_match",		"\e]");		% Alt ] -- matching delimiters, undefined in brief
		
%		setkey("cbrief_dabbrev",			"");		% Ctrl / -- adds or removes comments in Borland, undefined in Brief
%																 but it has the same code as the Ctrl+Minus 
		setkey("dabbrev",					"\e/");		% Alt / -- complete words, undefined in Brief 

		setkey("do_shell_cmd",				"\e!");		% Alt+! -- run shell command
		setkey("exchange_point_and_mark",	"\eX");		% Alt+X -- undefined in BRIEF, defined in BRIEF emulation of MS

		% no needed anymore, use tab/shift-tab 
		setkey("cbrief_slide_out",			"\e,");		% Alt , -- alternate outdent block, undefined in brief
		setkey("cbrief_slide_in",			"\e.");		% Alt . -- alternate indent block, undefined in brief
		%
		setkey("uncomment_region_or_line",	"\e<");		% ESC < -- removes comments, undefined in Brief
		setkey("comment_region_or_line",	"\e>");		% ESC > -- adds comments, undefined in Brief        
		}
}

%% reset keyboard... a mode take us the keys? again?
public define cbrief_reset()
{
	variable e, m = what_keymap();
		
	flush(sprintf("Resetting keymap [%s]...", m));
	TAB = 4;
	Tab_Stops = [0:19] * TAB + 1;
	TAB = 4;
	USE_TABS = 1;
	foreach e ( _keymap ) {
		undefinekey(e[1], m);
		definekey(e[0], e[1], m);
		}
	flush(sprintf("[%s] done...", m));
}

%% --- main -----------------------------------------------------------

#ifdef UNIX
enable_flow_control(0);  % turns off ^S/^Q processing (Unix only)
#endif
enable_top_status_line(0); % BRIEF's menus was through help
CASE_SEARCH = _search_case; % 1 = case sensitive

%set_abort_char(''); % Ctrl+G = the default, Routines macro in BRIEF (2.1/3.1)

% The original BRIEF's abort key wasnt the ESC but the Ctrl+Break (halt macro)
% Free control keys: Ctrl+Q, Ctrl+6, Ctrl+Y, Ctrl+], Ctrl+\ and Ctrl+H (but not suggested)
% Non-free but can be used: Ctrl+S, Ctrl+F, Ctrl+O
%
% In older BRIEFs, ^Q was a compination of keys to manipulate columns
% 
set_abort_char('');

% This key will be used by the modes (e.g. c_mode.sl) to bind additional functions to
%_Reserved_Key_Prefix = "";
_Reserved_Key_Prefix = ""; % this one is easiest to remember

menu_set_menu_bar_prefix("Global", " ");

#ifdef CBRIEF_PATCH_V1
% This is the default with field-widths
%set_status_line(" [ %b ] %5l:%03c %S - %m%a%n%o - %F - %t ", 1);

% try colors
private variable color_status = color_number("status");
private variable color_cursor_ins = color_number("cursor");
private variable color_cursor_ovr = color_number("cursorovr");
private variable color_menu_text = color_number("menu");

if ( CBRIEF_API <= 2 ) {
private variable _sb_colors = [ 
sprintf("%%+%d", color_status),
sprintf("%%+%d", color_cursor_ins),
sprintf("%%+%d", color_cursor_ovr),
sprintf("%%+%d", color_menu_text ) ];

set_status_line(
		sprintf(" %s %%b %s %s%%5l:%%03c %s %%S -%s %%m%%a%%n%%o %s- %%F - %s %%t %s ",
			_sb_colors[1],	_sb_colors[0],	% name
			_sb_colors[2],	_sb_colors[0],	% line/col
			_sb_colors[3],	_sb_colors[0],	% mode
			_sb_colors[3],	_sb_colors[0]	% time
			),
	1);
	}
else {
private variable _sb_colors = [ 
sprintf("%%%dC", color_status),
sprintf("%%%dC", color_cursor_ins),
sprintf("%%%dC", color_cursor_ovr),
sprintf("%%%dC", color_menu_text ) ];

	set_status_line(
		sprintf(" %s %%b %s %s%%5l:%%03c %s %%S -%s %%m%%a%%n%%o %s- %%F - %s %%t %s ",
			_sb_colors[1],	_sb_colors[0],	% name
			_sb_colors[2],	_sb_colors[0],	% line/col
			_sb_colors[3],	_sb_colors[0],	% mode
			_sb_colors[3],	_sb_colors[0]	% time
			),
	1);
}
#else
set_status_line(" [ %b ] %l:%c %S - %m%a%n%o - %F - %t ", 1);
#endif

% build tables
cbrief_build_cindex();
cbrief_build_opts();

% setup keys
cbrief_build_keymap();
cbrief_keys();

% run hooks
runhooks("keybindings_hook", _Jed_Emulation);


