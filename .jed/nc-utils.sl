%%
%%	Jed Utilities
%%	
%%	Nicholas Christopoulos
%%	

provide("nc-utils");

%%
%%	Get terminal name
%%	
define getterm() {
	variable term = getenv("TERM");
	if ( term == NULL ) {
#ifdef MSDOS OS2
		term = "dos";
#elseif WIN32 MSWINDOWS
		term = "win";
#else
		term = "ansi";
#endif
		}
	else if ( term == "rxvt-unicode-256color" ) term = "rxvt-unicode";
	else if ( term == "rxvt-256color" ) term = "rxvt";
	return term;
	}

%%
%%	Returns true if we run xjed
%%	
private variable Is_Xjed = is_defined("x_server_vendor");
define isxjed() {
	return Is_Xjed;
	}

%%
%%	Returns user's home directory
%%	
define gethome()
{
	variable home = getenv("HOME");
	if ( home == NULL )
		home = "/tmp";
	return home;
}

%%
%%	Returns user's jed directory
%%	
define getjhome()
{
	variable jhome = getenv("JED_HOME");
	if ( jhome == NULL )
		strcat(gethome(), "/.jed");
	return jhome;
}

%%
%%	You may want to reserve a key to toggle between newline_and_indent and newline.
%%	
static variable newline_indents = 0;
define toggle_newline_and_indent ()
{
	if ( 0 == newline_indents ) {
		local_setkey ("newline_and_indent", "^M");
		newline_indents = 1;
		flush("RET indents");
		}
	else {
		local_setkey ("newline", "^M");
		newline_indents = 0;
		flush("RET does not indent");
		}
}

%%
%%	backup filenames on directory
%%
%%	Example:
%%	% keep backup files at this directory
%%	Backup_Directory = home + "/.backup/jed/";
%%	define make_backup_filename(dir, file) { return backup_dir_filename(dir, file); }
%%	
custom_variable("Backup_Directory", "");
define backup_dir_filename(dir, file)
{
	variable f = Backup_Directory;
	f = strcat(f, strtrans(dir, "/", "_"));
	f = strcat(f, "_");
	f = strcat(f, file);
	return f;
}

%%
%%	Terminals keycodes
%%	
%() = evalfile("termianl-keycodes");
