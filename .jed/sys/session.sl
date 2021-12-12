% jed session save/restore
%
% NDC version
% 
%    require ("nc-session");
%

require("nc-utils");

provide("nc-session");

static variable session_file = getjhome() + "/.jedsession-nc";

%
%
%
public define nc_save_session ()
{
	variable files = {}, lines = {}, columns = {}, flags = {};
	
	loop ( buffer_list )	{
		variable b = ();
		variable file = buffer_filename(b);

		if ( (file == "") || (b[0] == ' ') || (b[0] == '*') )
			continue;

		setbuf(b);
		push_narrow ();
		widen_buffer();

		variable f; (,,,f) = getbuf_info ();
		list_append(flags, f);
		list_append(files, file);
		list_append(lines, what_line());
		list_append(columns, what_column());
		pop_narrow ();
		}

	variable fp = fopen (session_file, "w");
	if ( fp == NULL ) return;

	_for ( 0, length(files)-1, 1 ) {
		variable i = ();
		() = fprintf (fp, "%s|%d|%d|%#lx\n", files[i], lines[i], columns[i], flags[i]);
		}
	() = fclose (fp);
	() = chmod(session_file, 0600);
}

%
%
%
public define nc_load_session ()
{
	variable fp = fopen(session_file, "r");
	if ( fp == NULL )	return;

	% Preserve the following flags:
	%   read-only (1<<3), overwrite (1<<4), crflag (1<<10)
	variable mask = (1<<3)|(1<<4)|(1<<10);
	variable str;
	
	while ( -1 != fgets (&str, fp) ) {
		if ( str[0] == '%')
			continue;

		variable fields = strchop (str, '|', 0);
		variable file, line, col, flags;
		if ( (length (fields) != 4 )
		    || (1 != sscanf(fields[1], "%d", &line))
		    || (1 != sscanf(fields[2], "%d", &col))
			|| (1 != sscanf(fields[3], "0x%x", &flags)))
			continue;

		file = fields[0];

		if ( NULL == stat_file(file) )
			continue;

		() = find_file(file); % huh?
		if ( bobp() ) {
			goto_line (line);
			goto_column_best_try(col);
			}

		_set_buffer_flag (flags&mask);
		}

	() = fclose (fp);
}

%
%
%
static define exit_save_session_hook ()
{
	if ( BATCH == 0 )
		nc_save_session();
	return 1;
}
add_to_hook ("_jed_exit_hooks", &exit_save_session_hook);

static define startup_load_session_hook ()
{
	if ( BATCH == 0 ) {
		if ( whatbuf () != "*scratch*" )
			return;
		nc_load_session ();
		}
}
add_to_hook ("_jed_startup_hooks", &startup_load_session_hook);
