%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; c-style: ratliff; -*-
%%
%%	Copyright (c) 2016 Nicholas Christopoulos.
%%	Released under the terms of the GNU General Public License (ver. 3 or later)
%%
%%	This is a new version of the help().
%%	It is full compatible with the old one.
%%
%%	It arrange the text to the width of the window,
%%	and it supports columns and basic-colors.
%%
%%	2016-10-22 Nicholas Christopoulos
%%		Created.
%%

%%%!%+
%\variable{help_for_help_string}
%\synopsis{help_for_help_string}
%\description
% string to display at bottom of screen upon JED startup and when
% user executes the help function.
%%%!%-
%variable help_for_help_string;
%
%help_for_help_string =
%#ifdef VMS
%  "-> Help:H  Menu:?  Info:I  Apropos:A  Key:K  Where:W  Fnct:F  VMSHELP:M  Var:V";
%#elifdef IBMPC_SYSTEM
%"-> Help:H  Menu:?  Info:I  Apropos:A  Key:K  Where:W  Fnct:F  Var:V  Mem:M";
%#else
%"-> Help:H  Menu:?  Info:I  Apropos:A  Key:K  Where:W  Fnct:F  Var:V  Man:M";
%#endif

%%%!%+
%\variable{Help_File}
%\synopsis{Help_File}
%\description
% name of the file to load when the help function is called.
%%%!%-
%variable Help_File = "jed.hlp";   %% other modes will override this.

implements("chelp");

private variable _mode = "chelp-mode";
private variable _bufname = "*help*";
private variable prev_buf = "*scratch*";

%%
private define _to_char(v)
{
	variable l = strlen(strtrim(v));
	variable ch = ' ';

	if ( l ) {
		if ( isdigit(v[0]) )
			ch = atoi(v);
		else
			ch = v[0];
		}
	return ch;
}

%%
private define _jed_reform()
{
	call("format_paragraph");
}

%% CBRIEF's strfit()
private define _strfit(str, width, dir)
{
	variable len = strlen(str);
	if ( len < 2 )	return str;
	if ( width < 4 ) width = 4;
	if ( len > width ) 
		return ( dir > 0 ) ?
			strcat(substr(str, 1, width - 2), "..") : % >>
			strcat("..", substr(str, (len - width) + 3, width)); % <<
	return str;
}

%%
private define chelp_reform(lines)
{
	variable margin = WRAP;
	
	ifnot ( BATCH == 0 ) return;

	variable opts = Assoc_Type[Int_Type];
	opts["adv"] = '%';
	opts["cols"] = 40;
	opts["pars"] = '`';
	opts["cbeg"] = '+';
	opts["csep"] = '|';
	opts["wcbeg"] = '*';
	opts["ln1"] = '-';
	opts["ln2"] = '=';
	opts["ln3"] = '_';
	opts["right"] = '>';
	opts["center"] = '~';

	% now adjust spaces
	variable width = window_info('w');
	variable bftab = TAB, c;
	WRAP = width;
	variable i, j, cnt, l = length(lines), has_env = 0;
	if ( l <= 0 ) return;
	
	variable w = Integer_Type[l], s = Integer_Type[l];

	if ( lines[0][0] == opts["adv"] )
		has_env = 1;

	% old style help.. just insert the text file and return
	ifnot ( has_env ) {
		for ( i = 0; i < l; i ++ )
			insert(lines[i]);
		return;
		}

	% collect infos and remove '\n'
	for ( i = 0; i < l; i ++ ) {
		w[i] = strlen(lines[i]);
		s[i] = lines[i][0];

		% handle newline
		lines[i] = substr(lines[i], 1, w[i] - 1);
		w[i] = w[i] - 1;
		}

	% build the text
	variable env, e, ch, sch, sch3, v, args, name, val;
	
	for ( i = 0; i < l; i ++ ) {
		
		%% parse options
		if ( s[i] == opts["adv"] ) {
			env = strtrim(substr(lines[i], 2, w[0] - 1));
			ifnot ( strlen(env) )			continue;
			if    ( env[0] == opts["adv"] )	continue;
			ifnot ( is_substr(env, ";") )	continue;
			args = strchop(env, ';', 0);
			foreach e ( args ) {
				e = strtrim(e);
				ifnot ( strlen(e) ) continue;
				v = strchop(e, '=', 0);
				ifnot ( length(v) == 2 ) continue;
				name = strtrim(v[0]);
				val = strtrim(v[1]);
				ifnot ( strlen(name) && strlen(val) ) continue;
				if ( name == "cbeg" || name == "csep" || name == "wcbeg" )
					opts[name] = _to_char(val);
				else if ( strlen(name) )
					opts[name] = atoi(val);
				}
			continue;
			}
		%% columns
		else if ( s[i] == opts["cbeg"] || s[i] == opts["wcbeg"] ) { % column align
			if ( s[i] == opts["wcbeg"] && width <= 80 ) continue;
			args = strchop(substr(lines[i], 2, w[i] - 1), opts["csep"], 0);
			foreach e ( args ) {
				e = strtrim(e);
				c = what_column();
				while ( ((c-1) mod opts["cols"]) != 0 ) c ++;
				if ( c + strlen(e) > width ) {
					insert("\n");
					c = 1;
					}
				goto_column(c);
				vinsert("%s", e);
				}
			}
		%% lines
		else if ( s[i] == opts["ln1"] || s[i] == opts["ln2"] || s[i] == opts["ln3"] ) {
			ch = s[i];
			sch = string(char(ch));
			sch3 = sch + sch + sch;
			v = lines[i];
			if ( strncmp(v, sch3, 3) == 0 ) {
				variable vch = v[3];
				if ( _slang_utf8_ok() && ch == '-' ) { v = str_replace_all(v, sch, "─"); sch = "─"; }
				if ( _slang_utf8_ok() && ch == '=' ) { v = str_replace_all(v, sch, "═"); sch = "═"; }
				if ( vch == ' ' )
					vinsert("%s", v);
				for ( j = what_column(); j < width; j ++ )
					insert(sch);
				insert("\n");
				}
			else
				vinsert("%s\n", lines[i]);
			}
		%% other alignments
		else if ( s[i] == opts["right"] ) { % right align
			v = strtrim(substr(lines[i], 2, w[i] - 1));
			cnt = width - strlen(v);
			for ( j = 1; j < cnt; j ++ )	insert(" ");
			vinsert("%s", v);
			insert("\n");
			}
		else if ( s[i] == opts["center"] ) { % center
			vinsert("%s", strtrim(substr(lines[i], 2, w[i] - 1)));
			cnt = width / 2 - strlen(v) / 2;
			for ( j = 1; j < cnt; j ++ )	insert(" ");
			vinsert("%s", v);
			insert("\n");
			}
		%% paragraph
		else if ( s[i] == opts["pars"] ) {
			push_mark(0);
			v = substr(lines[i], 2, w[i] - 1);
			while ( (i+1) < l && s[i+1] == opts["pars"] ) {
				i ++;
				v += substr(lines[i], 2, w[i] - 1);
				}
			v = strcompress(v, " \t");
			insert("\t");
			insert(v);
			insert("\n");
			narrow_to_region();
			bob();
			_jed_reform();
			widen_region ();
			pop_mark();
			eob();
			}
		else
			vinsert("%s\n", lines[i]);
		}

	% restore
	WRAP = margin;
	TAB = bftab;
}

%%
private define chelp_buf_switch_buffer_hook (prev_buffer)
{
	if ( whatbuf() == _bufname ) {
		message(_strfit("(E)dit, (Q)uit, "+
						"(M)an, (I)nfo, (A)propos, (W)here, (K)ey, "+
						"(F)unction, (V)ariable, (?) Menu", window_info('w'), 1));
		}
}
add_to_hook ("_jed_switch_active_buffer_hooks", &chelp_buf_switch_buffer_hook);

%%
public define chelp_events(ch)
{
	variable name, file;

	switch ( ch )
		{ case 'q':
			otherwindow();
			onewindow();
			delbuf(_bufname); }
		{ case 'e':
			file = get_blocal_var("help_file");
			name = path_basename(file);
			if ( bufferp(name) )
				pop2buf(name);
			else
				() = find_file(file);
			}
		{ case 'a' or case 'A': apropos (); }
		{ case 'b' or case 'B': describe_bindings (); }
		{ case 'i' or case 'I': info_reader (); }
		{ case '?': call ("select_menubar"); }
		{ case 'f' or case 'F': describe_function (); }
		{ case 'v' or case 'V': describe_variable (); }
		{ case 'w' or case 'W': where_is (); }
		{ case 'c' or case 'C' or case 'k' or case 'K': showkey (); }
		{ case 'm' or case 'M':
#ifdef UNIX OS2
        unix_man();
#else
#ifdef VMS
        vms_help ();
#endif
#endif
#ifdef MSDOS MSWINDOWS
        call("coreleft");
#endif
    	}
}

%% create syntax table
%% how the heck I can get if exist or not?
private define chelp_syntax()
{
	create_syntax_table(_mode);
	define_syntax("#", "", '%', _mode);
	define_syntax("(", ")", '(', _mode);
	define_syntax("0-9a-zA-Z_", 'w', _mode);
	define_syntax("[]", '<', _mode);
	set_syntax_flags (_mode, 0);
}
chelp_syntax(); % build syntax table

%%
private define chelp_mode()
{
	variable e;

	ifnot ( keymap_p(_mode) ) {
        make_keymap(_mode);
		foreach e ( ["q", "Q", "\eq", "^Q", "\e\e\e" ] )
	        definekey("chelp_events('q')", e, _mode);
		foreach e ( ["e", "E", "\ee" ] )
			definekey("chelp_events('e')", e, _mode);
		foreach e ( ["a", "A", "b", "B", "f", "F", "w", "W", "c", "C", "m", "M", "i", "I", "k", "K", "v", "V", "?" ] )
			definekey("chelp_events('" + e + "')", e, _mode);
		}
	set_mode(_mode, 0);
	use_syntax_table(_mode);
	use_keymap(_mode);
}

%!%+
%\function{chelp}
%\synopsis{Width based formated Help window}
%\usage{void chelp([String_Type help_file][, flags])}
%\description
% This function pops up a window containing the specified help file.  If the
% function was called with no arguments, the the file given by the \var{Help_File}
% variable will be used.
%
% If the text begins with '%', then the chelp goes to advanced mode.
% The advanced mode offers columns and paragraphs based on the width
% of the window.
%
% \var{flags}: bit flags
% 	0x00 = Small window to fit the text.
% 	0x01 = Use one window zoomed.
%
% Advanced mode, if line begins with:
% '%' the rest of line has environment parameters or it is a comment if it continues with '%'; (option adv)
% '`' then the line it is part of paragraph and so will reformated. (options pars)
% '+' then the line will be shown in the next column. (option cbeg)
% '*' then the line will be shown in the next column if width of window > 80 characters; otherwise will be ignored. (option wcbeg)
% '>' right align.  (option right)
% '~' center align. (option center)
%
% for characters '-', '=' and '_': (options ln1,ln2 and ln3)
% "--- " then the line is part of title, '-' will be added to the end to much the width.
% "---" fill line with '-'.
%
% Enviroment parameters:
% adv=n; defines the advanced environent control character (default: '%').
% cols=n; defines the size of the columns.
% cbeg=c; defines the begin character of the column (default: '+').
% wcbeg=c; defines the begin character of the column on wide windows (width > 80, default: '*').
% csep=c; defines the column separator (default: '|'), value can be ASCII or the character.
% ln1=c; defines line character ('-').
% ln2=c; defines line character ('=').
% ln3=c; defines line character ('_').
% right=c; defines right align character ('>').
% center=c; defines center align character ('~').
% 
% Values can be ASCII or the characters
% 
%v+
%+this is line has columns | this goes to the second column
%v-
%
% There is a syntax table for advanced mode, mostly to colorize the key shortcuts.
% Everything inside [ and ] shown as definition.
% Starting with '#' shown as comment. (good for TODOs or Notes)
%!%-
public define chelp()
{
	variable help_file = Help_File;
	variable win_refresh_f, lines;
	variable rows, buf = whatbuf();
	variable fp, flags = 0;

	if ( _NARGS > 1 )
		flags = ();
	if ( _NARGS )				help_file = ();
	if ( help_file == NULL )	help_file = "";
	ifnot ( strlen(help_file) ) help_file = "generic.hlp";
	
	help_file = expand_jedlib_file(help_file);

	win_refresh_f = 0;
	if ( bufferp(_bufname) ) {
		setbuf(_bufname);
		if ( blocal_var_exists("help_file") ) {
			if ( get_blocal_var("help_file") != help_file )
				win_refresh_f = 1;
			}
		setbuf(buf);
		}

	ifnot ( win_refresh_f || buffer_visible(_bufname) ) {
		onewindow();

		setbuf(_bufname);
		set_readonly(0);
		ifnot ( blocal_var_exists("help_file") ) 
			create_blocal_var("help_file");
		set_blocal_var(help_file, "help_file");
		chelp_mode();
		
		erase_buffer();

		% () = insert_file(help_file);
		fp = fopen(help_file, "r");
		lines = fgetslines (fp);
		fclose(fp);

		% transform...
		chelp_reform(lines);

		if ( flags & 0x01 ) { % in whole window
			bob();
			set_buffer_modified_flag(0);
			set_readonly(1);
			sw2buf(_bufname);
			}
		else { % in small window
			pop2buf(_bufname);
			eob(); bskip_chars("\n");
			rows = window_info('r') - what_line();
			bob();
			set_buffer_modified_flag(0);
			set_readonly(1);
			pop2buf(buf);
			loop ( rows )
				enlargewin();
			}
		}

	if ( flags & 0x01 ) % in whole window
		message(help_for_help_string);
	else
		message("Press F1 to change windows, F4 to close it, Ctrl+H for Jed's help_prefix");
}

%!%+
%\function{help}
%\synopsis{help replacement}
%\usage{void help([String_Type help_file])}
%\description
% help() replacement. help() is defined in site.sl.
% This function will call the new chelp().
%!%-
public define help()
{
	variable help_file;
	
	if ( _NARGS ) {
		help_file = ();
		chelp(help_file);
		}
	else
		chelp();
}

