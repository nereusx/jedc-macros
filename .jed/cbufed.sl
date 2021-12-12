%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	Copyright (c) 2016 Nicholas Christopoulos.
%%	Released under the terms of the GNU General Public License (ver. 3 or later)
%%
%%	This is a bufed version for cbrief
%%
%%	2016-10-22 Nicholas Christopoulos
%%		Created.
%% 

require("chelp");

provide("cbufed");
private variable _help_file  = "cbufed.hlp";
private variable cbufed_buf  = "* Buffer List *";
private variable scrap_buf   = "*scratch*";
private variable help_buf    = "*help*";
private variable ignore_list = [ cbufed_buf, ".jedrecent", scrap_buf, help_buf, "*Completions*" ];

private variable prev_buf    = scrap_buf;
private variable cbuf_hide   = 1;
private variable cbuf_list   = {};
private variable short_help  = "ENTER/(E)dit, (D)elete, (W)rite, (R)eload, (Q)uit | (H)elp, Re(N)name, (A)ttributes, (U)nhide Buffers ?:This";

% get the buffer-name by using the current screen line
private define _getcurbuf()
{
	variable e, line = what_line();

	foreach e ( cbuf_list ) {
		if ( e[0] <= line && e[1] >= line  )
			return e[2]; % name
		}
	
	message("No buffers in the list; only *scratch*");
	return scrap_buf;
}

% get the list-record by using the current screen line
private define _getcurrec()
{
	variable e, line = what_line();

	foreach e ( cbuf_list ) {
		if ( e[0] <= line && e[1] >= line  )
			return e; % name
		}
	
	message("No buffers in the list; only *scratch*");
	return scrap_buf;
}

% build the list of the buffers
private define _build_list()
{
	variable file, dir, name, flags, s, found;
	variable st, mode, size, buf = whatbuf();
	
	cbuf_list = list_new();
	loop ( buffer_list() ) {
		name = ();
		if ( name[0] == ' ' )	continue;

		if ( cbuf_hide ) {
			found = 0;
			foreach s ( ignore_list )
				if ( strcmp(name, s) == 0 )
					{ found = 1; break; }
			if ( found ) continue;
			}
		
		setbuf(name);
		(file, dir, name, flags) = getbuf_info();
		
		st = stat_file(dircat(dir, file));
		if ( st == NULL ) {
			mode = set_buffer_umask(-1);
			size = 0;
			}
		else {
			mode = st.st_mode & 0777;
			size = st.st_size;
			}
			
		list_append(cbuf_list, { 0, 0, name, flags, dircat(dir, file), mode, size } );
		}
	setbuf(buf);
}

%% normal help
define cbufed_help()
{
	if ( bufferp(help_buf) )
		delbuf(help_buf);
	chelp(_help_file);
}

%% display short help message
define cbufed_short_help()
{
	message(short_help);
%	set_status_line(short_help, 0);
}

%
private variable bufed_minl;
private variable bufed_maxl;
private variable curr_lines = Mark_Type[2];

%
private define update_bufed_hook ()
{
	variable e, n, line = what_line();
	
	if ( line < bufed_minl ) {
		goto_line(bufed_minl);
		return;
		}
	if ( line > bufed_maxl ) {
		goto_line(bufed_maxl);
		return;
		}

	n = 0;
	foreach e ( cbuf_list ) {
		if ( e[0] <= line && e[1] >= line  ) {
			goto_line(e[0]);
			curr_lines[n] = create_line_mark(color_number("region"));
			n ++;
			go_down_1();
			curr_lines[n] = create_line_mark(color_number("region"));
			n ++;
			go_up_1();
			break;
			}
		}
%	goto_line(line);
}

%
define cbufed_show ()
{
	variable mod_f, chg_f, rdo_f, bin_f, crm_f; % flags
	variable e, name, flags, file, mode, size;
	variable count, flags_col = 45;

	setbuf(cbufed_buf);
	check_buffers();
	_build_list();
	set_readonly(0);
	erase_buffer();
	bob();

	foreach e ( cbuf_list ) {
		name  = e[2];
		if ( strlen(name) + 8 > flags_col )
			flags_col = strlen(name) + 8;
		}
	
	bufed_minl = what_line(); % mark starting line
	count = 1;
	foreach e ( cbuf_list ) {
		e[0]  = what_line(); % update the list record
		name  = e[2];
		flags = e[3];
		file  = e[4];
		mode  = e[5];
		size  = e[6];
		
		mod_f = flags & 0x0001; % modified
		chg_f = flags & 0x0004; % modified in disk (from someone else)
		rdo_f = flags & 0x0008; % readonly
		bin_f = flags & 0x0200; % binary
		crm_f = flags & 0x0400; % CR mode
		
		bol();
		vinsert("%2d) \"%s\"%c", count, name,
				(mod_f) ? '*' : ((chg_f) ? '!' : ' ') );
		count ++;

		goto_column(flags_col-1);
		if ( mod_f ) insert(" Modified");
		if ( chg_f ) insert(" UPDATED");
		if ( bin_f ) insert(" Binary");
		if ( rdo_f ) insert(" ReadOnly");
		if ( crm_f ) insert(" CR/LF");
		vinsert(" Mode %03o", mode);
		vinsert(" Size %3.f KB", round(size/1024.0));

		newline();

		goto_column(7);
		insert(file);
		e[1] = what_line(); % update the list record
		newline();
		}
	bufed_maxl = what_line() - 1; % last line

	% show this
	bob();
	set_buffer_modified_flag(0);
	set_buffer_hook ("update_hook", &update_bufed_hook);
	set_readonly (1);
	sw2buf(cbufed_buf);
}

%
define cbufed_save()
{
	variable buf = _getcurbuf();
	variable line = what_line();
	
	if ( (buf[0] == ' ') or (buf[0] == '*') )
		return;	% internal buffer or special

	setbuf(buf);
	save_buffer();
	setbuf(cbufed_buf);
	cbufed_show();
	goto_line(line);
}

% kill a buffer, if it has been modified then pop to it so it's obvious
define cbufed_delete ()
{
	variable file, dir, flags, buf = _getcurbuf();
	variable line = what_line(), ch;

	if ( strcmp(buf, cbufed_buf) == 0 )
		return;
	
	(file,dir,,flags) = getbuf_info(buf);
	if ( flags & 0x01 ) {
		forever {
			ch = get_mini_response("This buffer has NOT been saved. Delete [ynw]?");
			switch ( ch )
				{ case 'w' or case 'W':
					setbuf(buf);
					save_buffer();
					setbuf(cbufed_buf);
					break;
					}
				{ case 'y' or case 'Y': break; }
				{ case 'n' or case 'N': message("Canceled."); return; }
			}
		}
	
	delbuf(buf);
	setbuf(cbufed_buf);
	cbufed_show();
	if ( line < bufed_maxl )
		goto_line(line);
	else
		goto_line(bufed_maxl - 1);
}

%%
define cbufed_change_attr()
{
	variable e = _getcurrec();
	variable v, s;

	setbuf(e[2]);
	ifnot ( access(e[4], F_OK)	== 0 ) { % newfile
		s = sprintf("0%o", e[5]);
		s = read_mini("Enter umask:", s, "");
		if ( strlen(s) ) {
			v = integer(s);
			set_buffer_umask(v);
			cbufed_show();
			vmessage("The new buffer umask is %03o.", set_buffer_umask(-1));
			}
		}
	else {
		s = sprintf("0%o", e[5]);
		s = read_mini("Enter mode:", s, "");
		if ( strlen(s) ) {
			v = integer(s);
			if ( v != e[5] ) {
				if ( chmod(e[4], v) == 0 ) {
					set_buffer_modified_flag(1);
					cbufed_show();
					vmessage("The new buffer mode is %03o.", v);
					}
				else
					vmessage("%s", errno_string());
				}
			else
				message("Nothing changed.");
			}
		}
	setbuf(cbufed_buf);
}

%%
define cbufed_reload()
{
	variable file, dir, flags, buf = _getcurbuf();
	variable line = what_line(), ch;

	if ( strcmp(buf, cbufed_buf) == 0 )
		return;
	
	(file,dir,,flags) = getbuf_info(buf);
	if ( flags & 0x01 ) {
		forever {
			ch = get_mini_response("This buffer has NOT been saved. Reload [ynw]?");
			switch ( ch )
				{ case 'w' or case 'W':
					setbuf(buf);
					save_buffer_as();
					setbuf(cbufed_buf);
					break;
					}
				{ case 'y' or case 'Y': break; }
				{ case 'n' or case 'N': message("Canceled."); return; }
			}
		}
	
	setbuf(buf);
	(file, dir,,flags) = getbuf_info();
	erase_buffer(buf);
	() = insert_file(path_concat(dir, file));
	setbuf_info(file, dir, buf, flags & ~0x004); % reset the changed-on-disk flag
	setbuf(cbufed_buf);
	cbufed_show();
	goto_line(line);
}

%%
define cbufed_rename()
{
	variable e = _getcurrec();
	variable v, s;

	setbuf(e[2]);
	s = read_mini("Enter new file name:", e[4], "");
	if ( s != e[4] ) {
		variable file, dir, name, flags;		

		(file, dir, name, flags) = getbuf_info();
		if ( path_is_absolute(s) ) 
			dir = path_dirname(s);
		file = path_basename(s);
		name = path_basename(s);
		flags |= 1;
		setbuf_info(file, dir, name, flags);
		cbufed_show();
		}
	setbuf(cbufed_buf);
}

%%
define cbufed_toggle_hide()
{
	setbuf(cbufed_buf);
	cbuf_hide = not cbuf_hide;
	cbufed_show();
}

%%
define cbufed_move_sel(dir)
{
	if ( dir < 0 )
		() = up(2);
	else
		() = down(2);
}

%%
define cbufed_select()	{ sw2buf(_getcurbuf()); }
define cbufed_exit()	{ sw2buf(prev_buf); delbuf(cbufed_buf); }

private define cbuild_keymap(km)
{
	variable e;
	
	if ( keymap_p(km) )	return;
	
	make_keymap (km);

	definekey("cbufed_move_sel(-1)", Key_Up, km);
	definekey("cbufed_move_sel(1)", Key_Down, km);

	% select 
	foreach e ( ["\r", "e", "E", "\ee", "\t", " "] )
		definekey("cbufed_select", e, km);

	% delete (remove from buffers)
	foreach e ( ["d", "D", "\ed", Key_Del, Key_KP_Subtract] )
		definekey("cbufed_delete", e, km);
	
	% write (save)
	foreach e ( ["w", "W", "\ew"] )
		definekey("cbufed_save", e, km);

	% reload an updated file
	foreach e ( ["r", "R"] )
		definekey("cbufed_reload", e, km);

	% refresh
	foreach e ( ["^L"] )
		definekey("cbufed_show", e, km);

	% file attributes
	foreach e ( ["a", "A"] )
		definekey("cbufed_change_attr", e, km);

	% change filename (does not write it)
	foreach e ( ["n", "N"] )
		definekey("cbufed_rename", e, km);

	% help
	foreach e ( ["u", "U"] )
		definekey("cbufed_toggle_hide", e, km);

	% help
	foreach e ( ["h", "H", "h", ""] )
		definekey("cbufed_help", e, km);
	
	foreach e ( ["?"] )
		definekey("cbufed_short_help", e, km);
	
	% quit
	foreach e ( ["\e\e\e", "`",  "^Q", "q", "Q", "q"] )
		definekey("cbufed_exit", e, km);
}

%%
define cbrief_bufed ()
{
	variable mode = "cbrief-bufed";
	variable callers_buf;

	prev_buf = whatbuf();
	callers_buf = sprintf("\"%s\"", prev_buf);

	cbuild_keymap(mode);
	cbufed_show();

	sw2buf(cbufed_buf);
	() = fsearch(callers_buf);

	use_keymap(mode);
	set_mode(mode, 0);
	cbufed_short_help();
}

#ifdef CBRIEF_PATCH_V5
%
private variable table;

%
define cbrief_bufpu_hook(item, code, key)
{	
	variable i, count, buf, pbuf, s;
	
	if ( code == 'd' ) { % delete item
		buf = table[item];
		count = length(table);
		for ( i = item; i < count - 1; i ++ )
			table[i] = table[i+1];
		delbuf(buf);
		}
%	else if ( code == 's' ) % select item
%		sw2buf(table[item]);
	else if ( code == 'k' ) { % unhandled key
		if ( key == 'w' || key == 'W' ) {
			pbuf = whatbuf();
			buf = table[item];
			setbuf(buf);
			save_buffer();
			setbuf(pbuf);
			return -2; % redraw
			}
		else if ( key == 0x168 ) { % Alt+H
			s = "\
ENTER   : Select buffer\n\
ESC,q,Q : Close window\n\
w,W     : Write buffer\n\
DEL,d,D : Delete buffer\n\
";
			msgbox(" Help ", s, 0);
			}
		else if ( key > 0x100 || key < 0 )
			msgbox(" Key ", sprintf("Key: 0x%X", key), 0);
		}
	return 0;
}

% using popup menu to change buffer
define cbrief_bufpu()
{
	variable s, i, n, ml, count, found;
	variable list, e, fs;
	variable file, dir, name, flags;
	
	prev_buf = whatbuf();

	do {
		% get the list of buffers
		count = buffer_list();
		if ( count == 0 ) return;
		list  = __pop_list(count);
		
		% remove hidden buffers
		if ( cbuf_hide ) {
			found = 0;
			do {
				for ( i = 0; i < count; i ++ ) {
					found = 0;
					if ( list[i][0] == ' ' ) {
						list_delete(list, i);
						count --;
						found = 1;
						break;
						}
					foreach s ( ignore_list )
						if ( strcmp(list[i], s) == 0 ) {
							list_delete(list, i);
							count --;
							found = 1;
							break;
							}
					if ( found ) break;
					}		
				} while ( found );
			}
		if ( count == 0 ) return;
	
		% convert to table and sort it
		table = list_to_array(list);
		table = table[array_sort(table, &strcmp)];
	
		% for each buffer
		n  = 0;
		ml = 0;
		for ( i = 0; i < count; i ++ ) {
			% default selected file
			if ( n == 0 && strcmp(table[i], prev_buf) == 0 )	n = i;
			% calculate the maximum width of buffer's name
			if ( strlen(table[i]) > ml )		ml = strlen(table[i]);
			}
	
		% build options string
		s = "";
		for ( i = 0; i < count; i ++ ) {
			setbuf(table[i]);
			(file, dir, name, flags) = getbuf_info();
			fs = "-";
			if ( flags & 1 ) fs = "*";
			if ( flags & 8 ) fs = "R"; % read-only
			if ( flags & 4 ) fs = "!"; % modified in disk
			s = sprintf("%s%-*s %s %s\n", s, ml, table[i], fs, path_concat(dir, file));
			}
		setbuf(prev_buf);
		
		% call popup menu
		n = popup_menu5(1, s, n, " buffer list ", " alt-h: help ", "cbrief_bufpu_hook");
		if ( n >= 0 ) % if !cancel switch to buffer
			sw2buf(table[n]);
		} while ( n < -1 );
	
	redraw_screen();
}
#endif
