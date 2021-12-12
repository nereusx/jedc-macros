%%
%%	backup filenames on directory
%%
%%	Example:
%%	% keep backup files at this directory
%%	variable BACKUPDIR = getenv("HOME") + "/.jed/.backup";
%%	define make_backup_filename(dir, file) { return backup_dir_filename(dir, file); }
%%	

custom_variable("BACKUPDIR", "");

%% returns non-zero if the 'file' is a directory
private define is_directory(file) {
	variable st;
	st = stat_file(file);
	if (st == NULL) return 0;
	return stat_is("dir", st.st_mode);
	}

%%
public define nc_backup_getname(dir, file) {
	if ( strlen(BACKUPDIR) )
		return strcat(BACKUPDIR, strtrans(dir, "/", "_"), "_", file);
	return strcat(dir, "/", file, "~");
	}

%% install it
public define make_backup_filename(dir, file) {
	return nc_backup_getname(dir, file);
	}

%% init
if ( getenv("BACKUPDIR") != NULL )
	BACKUPDIR = getenv("BACKUPDIR") + "/text/";
else
	BACKUPDIR = getenv("HOME") + "/.backup/text/";

ifnot ( is_directory(BACKUPDIR) ) {
	if ( mkdir(BACKUPDIR) ) {
		if ( errno != EEXIST )
			throw IOError,
				sprintf ("mkdir %s failed: %s", BACKUPDIR, errno_string(errno));
		}
	}

