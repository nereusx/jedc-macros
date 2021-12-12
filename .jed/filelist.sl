% filelist.sl
% A special mode for file listings (ls, ls -a, locate)
% -> replace/extend dired mode
%
% Copyright (c) 2005 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Changelog
% ---------
%
%           0.9   * initial version (beta)
%           0.9.1 (based on report by Paul Boekholt)
%                 * added USAGE documentation (including ...find_file_hook)
%                 * filelist_list_dir:
%                   + directories end in "/" ("\" with DOS-like OS-es)
%                     when listing with listdir
%                   + If no dir argument given, ask in minibuffer
%                 * filelist_open_file:
%                   use filelist_list_dir, if filename is a directory,
%                   goto line of child-dir if stepping up with ".."
%                 * bugfixes (and maybe new bugs =:-( )
% 	    	  * color syntax (DFA: mark directories)
% 	    	  * Mode directory
% 	    	  * dired-bindings (Paul Boekholt)
% 	      	  * works with PB-s tar_mode: a tar file is opened in tar-mode
% 2003-08-18  0.9.2 * bugfix to filelist_list_dir
% 2003-12-19  0.9.3   several fixes by Paul Boekholt, including
%                 * new functions for regexp-rename, tar and grep bindings
% 2004-02-19  0.9.4 * bugfix: filelist_delete_file now deletes also
%                     (empty) directories. (PB)
% 2004-07-07  1.0   if a file ends in .gz, check for another extension
% 2004-10-11  1.1   bugfix in filelist_list_base_dir()
% 2004-11-22  1.2   FileList_Trash_Bin now defaults to "" (delete files)
% 2005-03-18  1.2.1 added definition of filelist_find_file_hook() (was in doc)
% 2005-04-28  1.3   moved definition and call of filelist_find_file_hook() to
% 	      	    INITALIZATION block, i.e. with make_ini and home-lib
% 	      	    modes you will have this hook as default.
% 	      	    bugfix: extract_line_no gave error with filenames like
% 	      	    	    00debian.sl.
% 2005-05-13  1.3.1 filelist_open_file_with() now checks whether the file is
%                   a directory and calls filelist_list_dir in this case.
%                   Thus, a directory ".lyx" will not be opened as a lyx file
% 2005-06-01  1.4   extract_filename() now uses whitespace as default delimiter
% 2005-11-08  1.4.1 changed _implements() to implements()
% 2005-11-23  1.5   added documentation for public functions and custom vars
%                   new function filelist_open_tagged() (initiated by T. Koeckritz)
%                   removed dependency on grep.sl (now recommandation)
% 2005-11-25  1.5.1 bugfix: mark directories and cleanup again
% 	      	    code cleanup regarding FileList_Cleanup
% 2006-02-16  1.5.2 added fit_window() to autoloads (report Mirko Rzehak)
% 2006-03-13  1.5.3 USAGE docu fix
% 2006-05-23  1.6   Copy and delete instead of rename if the destination is
%                   on a different filesystem.
% 2007-04-16  1.7   Changed the keybinding for (i)search from '^S' to 's'
% 	      	    (match the one in tokenlist and keep the original '^S')
% 2007-04-18  1.7.1 * filelist_open_file() improvements
% 	      	      - close the calling buffer before opening new
% 	      	        (keeps the right order for navigate_back())
% 	      	      - "smart" fit_window() for files openend from filelist
% 	      	      - localise `FileList_Cleanup' with blocal var
% 	      	        and optional argument `close'
% 	      	      - return to the filelist, if a buffer
% 	      	        opened from there is closed with close_buffer()
% 	      	    * filelist_open_in_otherwindow() (request by Lechee Lai)
% 	      	      open file, return focus to filelist
% 	      	    * highlight rule for directories listed with `ls -l`
% 	      	    * locate(): dont't close list if going to a directory
% 2007-04-23  1.7.2 * filelist_view_file(): never close calling filelist
% 2007-05-02  1.7.3 * documentation update
% 2007-05-25  1.7.4 * bugfix in filelist_open_file(): went to wrong buffer if
% 		      file with same basename already open
% 2007-10-01  1.7.5 * optional extensions with #if ( )
% 2007-10-04  1.7.6 * no DFA highlight in UTF-8 mode (it's broken)
% 2007-10-23  1.7.7 * no DFA highlight caching
% 2008-01-21  1.7.8 * fix stack leftovers in filelist_open_file()
% 	      	    * add Jörg Sommer's fix for DFA highlight under UTF-8
% 2008-05-05  1.7.9 * filelist_list_dir(): do not sort empty array
% 	      	    * filelist_open_with() bugfix: do not set a default when asking
% 	      	      for cmd to open, as this prevents opening in Jed.
% 	      	    * separate function filelist->get_default_cmd(String filename)
% 2008-06-18  1.7.10  use call_function() instead of runhooks()
% 2008-12-16  1.8   * use `trash` cli for deleting (if available and set)
% 2009-10-05  1.8.1 * bugfix: pass name of calling buffer to _open_file()
% 	      	      as it may be already closed.
% 2009-12-08  1.8.1 * adapt to new require() syntax in Jed 0.99.19


% TODO
% ----
% 	* write a trash.sl mode (based on the `trash` Python utility
% 	  and the FreeDesktop.org Trash Specification e.g. at
%	  http://www.ramendik.ru/docs/trashspec.html)
%
% 	* more bindings of actions: filelist_cua_bindings
%       * copy from filelist to filelist ...
%         ^C copy : cua_copy_region und copy_tagged (in separaten buffer)
%         ^X kill:  yp_kill_region und kill_tagged    ""   ""        ""
%         ^V filelist_insert (im filelist modus)
%         bzw die bindungen abfragen.
% 	* detailed directory listing (ls -l)
%       * custom_variable("dir_ls_cmd", "ls -la --quoting-style=shell")
% 	* quoting of special file names
% 	* give error reason with errno/errno_string (if not automatically done)
%       * use MIME_types and mailcap (view and edit commands) for
%         FileList_Default_Commands
%         hint: `mimedb -a` returns default app for a file
%               `xdg-open` opens an URL with default app (opendesktop.org)

%
% Usage
% -----
%
% * Place filelist.sl and required files in your library path.
%
% * Use filelist_list_dir() to open a directory in the "jed-file-manager"
%
% * To make file finding functions list the directory contents
%   if called with a directory path as argument (instead of reporting an
%   error), copy the content of the INITALIZATION block below
%   (without the preprocessor #<INITALIZATION> lines) into your
%   .jedrc (or jed.rc) (or use the "make_ini" and "home-lib" modes from
%   jedmodes.sf.net)

#<INITIALIZATION>
"filelist_list_dir", "filelist.sl";
"filelist_mode", "filelist.sl";
"locate", "filelist.sl";
_autoload(3);
_add_completion("locate", "filelist_mode", 2);

define filelist_find_file_hook(filename)
{
   if (file_status(filename) == 2)
     {
	filelist_list_dir(filename);
	return 1; % abort hook chain, do not use the function actually called
     }
   return 0;  % try other hooks or use opening function
}
append_to_hook("_jed_find_file_before_hooks", &filelist_find_file_hook);
#</INITIALIZATION>

% Requirements
% ------------
% extensions from http://jedmodes.sf.net/
#if (_jed_version > 9918)
require("listing", "Global"); % depends on datutils, view, bufutils
require("bufutils", "Global");
require("sl_utils", "Global");
#else
require("listing");  % the listing widget, depends on datutils, view, bufutils
require("bufutils");
require("sl_utils");
#endif
autoload("string_get_match", "strutils");
% optional extensions
#if (expand_jedlib_file("filelistmsc") != "")
autoload("filelist_do_rename_regexp", "filelistmsc");
#endif

% Recommended for Trash-can compliance: http://www.andreafrancia.it/trash/
%   An interface to the FreeDesktop.org Trash Specification (used by
%   KDE and XFCE) provided via the `trash` CLI
%   (used if found on the system PATH).



% Name and namespace
% ------------------
provide("filelist");
implements("filelist");
variable mode = "filelist";

% Custom Variables 
% ----------------

%!%+
%\variable{FileList_Action_Scope}
%\synopsis{What files should filelist actions be applied to}
%\usage{Int_Type FileList_Action_Scope = 1}
%\description
% What files should actions like move, delete, open_with be applied to
%     0 current line                                        (MC-macro "%f")
%     1 tagged lines or current line, if no line is tagged. (MC-macro "%s")
%     2 tagged lines 		      	    	    	    (MC-macro "%t")
%\seealso{filelist_mode, filelist_open_tagged, filelist_rename_tagged, filelist_delete_tagged}
%!%-
custom_variable("FileList_Action_Scope", 1);

%!%+
%\variable{FileList_KeyBindings}
%\synopsis{Keybinding set for the filelist mode}
%\usage{String_Type FileList_KeyBindings = "mc"}
%\description
%  Which set of keybindings should the filelist mode emulate?
%  ("mc" or "dired")
%\seealso{filelist_mode}
%!%-
custom_variable("FileList_KeyBindings", "mc");

%!%+
%\variable{FileList_Cleanup}
%\synopsis{Close a filelist when leaving?}
%\usage{Int_Type FileList_Cleanup = 1}
%\description
%  Close the directory listing when opening a file/dir from it?
%    0 keep open,
%    1 close when going to a new directory,
%    2 always close
%\notes
%  The global default will be overridden by a buffer local variable of
%  the same name.
%\seealso{filelist_mode}
%!%-
custom_variable("FileList_Cleanup", 1);

%!%+
%\variable{FileList_max_window_size}
%\synopsis{}
%\usage{FileList_max_window_size = 1.0}
%\description
%  How big shall the filelist window be maximal
%    Integer: no. of rows,
%             0 do not fit to content size
%    Float:   screen-fraction,
%             1.0 no limit
%\seealso{filelist_mode, fit_window}
%!%-
custom_variable("FileList_max_window_size", 1.0);  % my default is full screen

%!%+
%\variable{FileList_Trash_Bin}
%\synopsis{Trash bin for files deleted in \sfun{filelist_mode}}
%\usage{String_Type FileList_Trash_Bin = "trash-cli"}
%\description
% Directory, where deleted files are moved to or the special string
% "trash-cli" (to call the `trash` command line utility).
% The empty string "" means real deleting.
% \notes
%  Desktop users might want to set this to "trash-cli" or
%  "~/local/share/Trash/files" (see the Desktop Trash Can Specification
%  http://freedesktop.org/wiki/Standards_2ftrash_2dspec).
%
%  A path value will be expanded with \sfun{expand_filename}.
%  It is checked for existence in \sfun{filelist_delete_tagged}.
%\seealso{filelist_mode, filelist_delete_tagged}
%!%-
custom_variable("FileList_Trash_Bin", "~/local/share/Trash/files");

% Check and expand:
if (andelse{FileList_Trash_Bin == "trash-cli"}
      {search_path_for_file(getenv("PATH"), "trash", ':') == NULL})
   % trash CLI not available, try Trash dir:
   FileList_Trash_Bin = "~/.local/share/Trash/files";

if (wherefirst(FileList_Trash_Bin == ["", "trash-cli"]) == NULL)
   FileList_Trash_Bin = expand_filename(FileList_Trash_Bin);

% --- Static Variables ----------------------------------------------------
% Add to/Change in the filelist_mode_hook

% Default values for command opening a file with a certain extension
% The command is called via system(command + file + "&")
static variable FileList_Default_Commands = Assoc_Type[String_Type, ""];

% under xjed and jed in xterm use X programs
if (getenv("DISPLAY") != NULL) % assume X-Windows running
{
   FileList_Default_Commands[".dia"]     = "dia";
   FileList_Default_Commands[".doc"]     = "abiword";
   FileList_Default_Commands[".dvi"]     = "xdvi";
   FileList_Default_Commands[".dvi.gz"]  = "xdvi";
   FileList_Default_Commands[".eps"]     = "gv";
   FileList_Default_Commands[".gnumeric"]     = "gnumeric";
   FileList_Default_Commands[".gif"]     = "display";
   % FileList_Default_Commands[".gnuplot"] = "gnuplot -persist";
   FileList_Default_Commands[".html"]    = "firefox";
   FileList_Default_Commands[".xhtml"]   = "firefox";
   FileList_Default_Commands[".htm"]     = "firefox";
   FileList_Default_Commands[".ico"]     = "display";
   FileList_Default_Commands[".jpg"]     = "display";
   FileList_Default_Commands[".jpeg"]    = "display";
   FileList_Default_Commands[".lyx"]     = "lyx-remote";
   FileList_Default_Commands[".odt"]     = "ooffice";
   FileList_Default_Commands[".png"]     = "display";
   FileList_Default_Commands[".pdf"]     = "xpdf";
   FileList_Default_Commands[".pdf.gz"]  = "zxpdf";
   FileList_Default_Commands[".ps"]      = "gv";
   FileList_Default_Commands[".ps.gz"]   = "gv";
   FileList_Default_Commands[".sk"]      = "sketch";
   FileList_Default_Commands[".svg"]     = "inkscape";
   FileList_Default_Commands[".xpm"]     = "display";
}

static variable listing = "listing";
static variable FileListBuffer = "*file-listing*";

static variable LAST_LOCATE = "";
static variable Dir_Sep = path_concat("a", "")[[1:]];  % path separator

% ------ Function definitions -------------------------------------------

public define filelist_mode(); % forward definition

% truncate a string to the n last characters (prepending "..." if n >= 4)
static define strtail(str, n)
{
   if (strlen(str) <= n)
     return str;

   if (n >= 4)
     return "..." +  str[[-(n-3):]];
   return str[[-n:]];
}

% Extract the filename out of a string (with position given as blocal-var)
% Str = extract_filename(Str line)
static define extract_filename(line)
{
   % some listings refer to only one file, omitting it in the list
   variable filename = get_blocal("filename", "");

   !if (strlen(filename))
     {
	variable position = get_blocal("filename_position", 0);
	variable del = get_blocal("delimiter");
	if (del == NULL) % use any whitespace
	   filename = strtok(line)[position];
	else
	  filename = extract_element(line, position, del);
     }
   % remove trailing path-separator
   return strtrim_end(filename, Dir_Sep);
}

% Return array of tagged filenames
static define get_tagged_files() % (scope, untag)
{
   variable args = __pop_args(_NARGS);
   variable lines = listing_list_tags(__push_args(args));
   return array_map(String_Type, &extract_filename, lines);
}

% Return the filenames of the tagged lines as a space separated string
static define list_tagged_files() % (scope, untag)
{
   variable args = __pop_args(_NARGS);
   return strjoin(get_tagged_files(__push_args(args)), " ");
}

% Extract the line number out of a string (with position given as blocal-var)
static define extract_line_no(str)
{
   variable np = get_blocal("line_no_position", -1);
   variable nr_str = extract_element(str, np, get_blocal("delimiter", ' '));
   if (nr_str == NULL)
     return 0;
   ERROR_BLOCK
     {
	_clear_error();
	return 0;
     }
   return integer(nr_str);
}

% Move file/files
static define filelist_rename_file(line, dest)
{
   variable result, file = extract_filename(line);
   file = expand_filename(file);
   if (file_status(dest) == 2) % directory
     dest = path_concat(dest, path_basename(file));
   % vshow("moving %s to %s", file, dest);
   if (andelse{file_status(dest) > 0}
       {listing->get_confirmation(sprintf("'%s' exists, overwrite",
                                          strtail(dest, 30))) != 1})
     return 0;

   result = rename_file(file, dest);

   if (result == 0) % success
     return 2;

   % if dest is on a different filesystem, copy and delete
   % show("rename_file failed, try copy and delete", errno_string (errno));

   result = copy_file(file, dest); % -1 -> failure

   if (result != 0)
     verror ("copy '%s' to '%s' failed: %s",
        strtail(file, 10), strtail(dest, 20), errno_string (errno));

   result = delete_file(file); % 0 -> failure

   if (result != 0)
     return 2;

   if (get_y_or_n(sprintf("Delete %s failed (%s), remove copy? ",
                           file, errno_string(errno))) == 1)
     result = delete_file(dest);

   % verror ("cannot delete '%s': %s", strtail(file, 10), errno_string (errno));
   return 1;
}

%!%+
%\function{filelist_rename_tagged}
%\synopsis{Rename/Move tagged files}
%\usage{filelist_rename_tagged()}
%\description
%  Move/Rename current or tagged files.
%  Ask in the minibuffer for the destination
%\seealso{filelist_mode, FileList_Action_Scope}
%!%-
public define filelist_rename_tagged()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Move/Rename file(s) to:", "", "", 'f');
   listing_map(FileList_Action_Scope, &filelist_rename_file, dest);
   help_message();
}

% Copy file/files
static define filelist_copy_file(line, dest)
{
   variable result, file = extract_filename(line);
   if (file_status(dest) == 2) % directory
     dest = path_concat(dest, path_basename(file));
   if (andelse{file_status(dest) > 0}
       {listing->get_confirmation(sprintf("'%s' exists, overwrite",
                                          strtail(dest, 30))) != 1})
     return 0;
   % show("copying", file, "to", dest);
   result = copy_file(extract_filename(line), dest);

   if(result == 0) % success
     return 1;

   if (get_y_or_n(sprintf("Copy failed %s, continue? ",
                           errno_string(errno))) != 1)
     verror("copy failed: %s", errno_string(errno));
   return 0;
}

%!%+
%\function{filelist_copy_tagged}
%\synopsis{Copy tagged files}
%\usage{filelist_copy_tagged()}
%\description
%  Copy current or tagged files.
%  Ask in the minibuffer for the destination
%\seealso{filelist_mode, FileList_Action_Scope}
%!%-
public define filelist_copy_tagged()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Copy file(s) to:", "", "", 'f');
   listing_map(FileList_Action_Scope, &filelist_copy_file, dest);
   help_message();
}

%!%+
%\function{filelist_make_directory}
%\synopsis{Create a new directory}
%\usage{  filelist_make_directory()}
%\description
%  Create a new directory.
%  Ask the user for the name.
%\seealso{filelist_mode}
%!%-
public define filelist_make_directory()
{
   () = chdir(buffer_dirname());
   variable dest = read_with_completion("Create the directory:", "", "", 'f');
   if (mkdir(dest, 0777))
          verror ("mkdir failed: %s", errno_string (errno));
   help_message();
}

% Delete file whose path is given on `line'
%
% Depending on the value of FileList_Trash_Bin, the file or dir is either
%  a) put to the trash bin via `trash`
%  b) copied to the trash folder
%  c) deleted immediately
% The user is asked for confirmation first.
static define filelist_delete_file(line)
{
   variable file = extract_filename(line);
   if (listing->get_confirmation("Delete " + file) != 1)
     return 0;

   % a) use the `trash` cli:
   if (FileList_Trash_Bin == "trash-cli") {
      if (system("trash " + file) == 0) % success
	 return 2; % (deleted)
   }
   % b) copy to Trash Bin:
   else if (strlen(FileList_Trash_Bin)) {
      try {
	 return filelist_rename_file(line, FileList_Trash_Bin);
      }
      catch RunTimeError: {
	 % Check Trash Bin directory for existence and offer re-setting
	 if (file_status(FileList_Trash_Bin)!=2)
	    FileList_Trash_Bin =
	    read_with_completion("Trash Bin (leave empty for real delete)",
				 "", FileList_Trash_Bin, 'f');
      }
   }
   % c) delete immediately
   % delete directory
   else if (file_status(file) == 2) {
      if (rmdir(file) == 0) % successfully removed dir
	 return 2;
      % delete normal file
      if (delete_file(file) != 0) % success
	 return 2;
      if (get_y_or_n(sprintf("Delete failed %s, continue? ",
			     errno_string(errno))) != 1)
	 verror("Delete failed %s", errno_string(errno));
   }
   return 1; % (not deleted)
}

%!%+
%\function{filelist_delete_tagged}
%\synopsis{Rename/Move tagged files}
%\usage{filelist_delete_tagged()}
%\description
%  Delete (or move to Trash_Bin) current or tagged files.
%\notes
%  If \var{FileList_Trash_Bin} is "" (default), directories can only be
%  deleted if they are empty.
%\seealso{filelist_mode, filelist_rename_tagged, FileList_Action_Scope}
%!%-
public define filelist_delete_tagged()
{
   () = chdir(buffer_dirname());
   listing_map(FileList_Action_Scope, &filelist_delete_file);
   help_message();
}


%!%+
%\function{filelist_do_tar}
%\synopsis{Make a tgz of the tagged files}
%\usage{filelist_do_tar()}
%\description
%  Pack the tagged files in a gzipped tar archive.
%\notes
%  Needs the `tar` system command.
%\seealso{filelist_mode}
%!%-
public define filelist_do_tar()
{
   variable tar = read_with_completion("Name of tgz to create", "", "", 'f');
   switch (file_status(tar))
     {case 2: error ("this is a directory");}
     {case 1: !if (get_y_or_n("file exists, overwrite")) return;}
     {case 0: ;}
     {error("can't stat this");}
   shell_perform_cmd(strcat("tar -czvf ", tar, " ", list_tagged_files()), 0);
}


%!%+
%\function{filelist_reread}
%\synopsis{Re-read the current file listing}
%\usage{filelist_reread()}
%\description
%  Re run the function that generated the current file list to
%  update the view.
%\seealso{filelist_mode}
%!%-
public define filelist_reread()
{
   variable line = what_line();
   () = run_function(push_array(get_blocal("generating_function")));
   goto_line(line);
}

%!%+
%\function{filelist_list_dir}
%\synopsis{List all files in \var{dir}}
%\usage{filelist_list_dir([dir], ls_cmd="listdir")}
%\description
%  List all files in the current (or given) directory and set the buffer to
%  \sfun{filelist_mode}.
%\notes
%  With the filelist_find_file_hook() as proposed in the INITIALIZATION
%  block of filelist.sl, Jed will open directories as a file listing instead
%  of issuing an error.
%\seealso{filelist_mode, FileList_Cleanup, listdir}
%!%-
public define filelist_list_dir() % ([dir], ls_cmd="listdir")
{
   % get arguments
   variable dir, ls_cmd;
   (dir, ls_cmd) = push_defaults( , "listdir", _NARGS);
   if (dir == NULL)
     dir = read_with_completion("Open directory:", "", "", 'f');
   % make sure there is a trailing directory separator
   dir = path_concat(dir, "");
   % expand relative paths
   dir = expand_filename(path_concat(buffer_dirname(), dir));
   if (file_status(dir) != 2)
     error(dir + " is not a directory");

   % create (or reuse) the buffer
   popup_buffer(dir, FileList_max_window_size);
   setbuf_info("", dir, dir, 0);
   erase_buffer();

   % show(ls_cmd);
   if (ls_cmd == "listdir")
     {
	variable files = listdir(dir);
	if (length(files)) {
	   files = files[array_sort(files)];
	   % quote spaces and stars
	   % files = array_map(String_Type, &str_quote_string, files, "* ", '\\');
	}
	insert(strjoin(["..", files], "\n"));
	do
	  if (file_status(dir + line_as_string()) == 2)
	      insert(Dir_Sep);
	while (up_1());
     }
   else
     {
	shell_perform_cmd(ls_cmd,1);
	% write_table([[8,[0:7],[9:length($1)-1]],*])
     }
   bob;

   define_blocal_var("generating_function", [_function_name, dir]);
   fit_window(get_blocal("is_popup", 0));
   filelist_mode();
}

%!%+
%\function{filelist_list_base_dir}
%\synopsis{List the directory of the current file}
%\usage{filelist_list_base_dir()}
%\description
%  List the base directory of the current file. This is usefull e.g. in
%  \sfun{locate} or \sfun{grep} listings, where the files come from different
%  directories.
%\seealso{filelist_mode}
%!%-
public define filelist_list_base_dir()
{
   variable filename = extract_filename(line_as_string());
   filelist_list_dir(path_dirname(filename));
}

% return to the filelist, if a buffer opened from there is closed with
% close_buffer()
static define filelist_close_buffer_hook(buf)
{
   !if (buffer_visible(buf))
     return;

   variable calling_buf = get_blocal("calling_buf", "");

   if (bufferp(calling_buf))
     {
	go2buf(calling_buf);
	fit_window(get_blocal("is_popup", 0)); % resize popup window
     }
}


% open file|directory|tar-archive, goto line number
% return success
private define _open_file(filename, line_no, calling_buf)
{
   variable newbuf, fit = (get_blocal("is_popup", 0) != 0);

   try {
      % directory
      if (file_status(filename) == 2) {
	 filelist_list_dir(filename);
	 % set point to the previous directory (when going up)
	 variable last_dir = path_basename(strtrim_end(calling_buf, Dir_Sep));
	 () = fsearch(last_dir + Dir_Sep);
      }
      % tar archive
#ifexists check_for_tar
      else if (check_for_tar(filename))
	 tar(filename, 0);               % open in tar-mode, read-write
#endif
      % normal file
      else {
	 % open file in second window
	 () = find_file(filename);
	 newbuf = whatbuf();
	 % save return data in blocal variables
	 define_blocal_var("close_buffer_hook", &filelist_close_buffer_hook);
	 define_blocal_var("calling_buf", calling_buf);
	 % fit window (eventually closing the filelists window)
	 if (fit)
	   {
	      fit_window(FileList_max_window_size);
	      % Shrink the filelist buffer, if there is excess space
	      if (nwindows > 1)
		{
		   pop2buf(calling_buf);
		   fit_window(window_info('r'));
		   pop2buf(newbuf);
		}
	   }
      }
      if (line_no)                      % line_no == 0 means don't goto line
	 goto_line(line_no);
      return 1;
   }
   catch AnyError: return 0;
}

%!%+
%\function{filelist_open_file}
%\synopsis{Open current file}
%\usage{filelist_open_file(scope=0)}
%\description
% Open the file (or directory) in the current line in a buffer.
% If scope != 0, open tagged files (see \var{FileList_Action_Scope})
%\notes
% If the filename is not the first whitespace delimited token in the line,
% the function generating the list must set the blocal variables
%   "filename_position" (counting from 0) and
%   "delimiter"         (Char_Type, default == NULL, meaning 'whitespace')
%\seealso{filelist_mode, FileList_Cleanup}
%!%-
public define filelist_open_file() % (scope=0, close=FileList_Cleanup)
{
   variable scope, close;
   (scope, close) = push_defaults(0,
      	   	    get_blocal("FileList_Cleanup", FileList_Cleanup), _NARGS);

   variable buf = whatbuf(), bufdir = buffer_dirname();
   variable lines = listing_list_tags(scope, 1); % get and untag
   variable filenames = array_map(String_Type, &extract_filename, lines);
   filenames = array_map(String_Type, &path_concat, bufdir, filenames);
   filenames = array_map(String_Type, &expand_filename, filenames);
   variable file_states = array_map(Int_Type, &file_status, filenames);
   variable line_numbers = array_map(Int_Type, &extract_line_no, lines);

   % close the calling buffer (see also FileList_Cleanup)
   % (Do this before opening the new one to keep Navigation_List in
   % correct order).
   switch (close)
     % case 0: do not close calling buffer
     { case 1:
	if (wherefirst(file_states == 2) != NULL)
	  close_buffer(buf);
     }
     { case 2: close_buffer(buf);}
   
   () = array_map(Int_Type, &_open_file, filenames, line_numbers, buf);
}

public define filelist_open_in_otherwindow()
{
   % open file on current line, don't close current buffer
   filelist_open_file(0, 0);
   % go back to calling buffer, splitting window in 2
   popup_buffer(get_blocal_var("calling_buf"));
}

%!%+
%\function{filelist_open_tagged}
%\synopsis{Open all tagged files in jed}
%\usage{filelist_open_tagged()}
%\description
%  This function calls \sfun{filelist_open_file} with
%  the \var{FileList_Action_Scope} argument to open
%  the set of tagged files (or the current)
%  in JED.
%\seealso{filelist_mode}
%!%-
public define filelist_open_tagged()
{
   filelist_open_file(FileList_Action_Scope);
}

%!%+
%\function{filelist_view_file}
%\synopsis{Open the file in view mode}
%\usage{  filelist_view_file()}
%\description
%  Open the file in \sfun{view_mode} (readonly).
%\seealso{filelist_mode, view_mode}
%!%-
public define filelist_view_file()
{
   filelist_open_file(FileList_Action_Scope, 0);
   set_readonly(1);
   view_mode();
}

static define get_default_cmd(filename)
{
   variable extension = path_extname(filename);
   % double extensions:
   if (extension == ".gz") % some programs can handle gzipped files
     extension = path_extname(path_sans_extname(filename)) + extension;

   return FileList_Default_Commands[extension];
}

%!%+
%\function{filelist_open_file_with}
%\synopsis{Open the current file with a shell command}
%\usage{filelist_open_file_with(ask = 1)}
%\description
% Open the file with a shell command in a background process.
% The command is taken from \var{FileList_Default_Commands} or asked
% for in the minibuffer.
% If \var{ask} = 0, use default without asking.
%\seealso{filelist_mode, filelist_open_file, system, run_program}
%!%-
public define filelist_open_file_with() % (ask=1)
{
   variable ask = push_defaults(1, _NARGS);

   variable filename = extract_filename(listing_list_tags(0)[0]);
   variable cmd = get_default_cmd(filename);

   if (ask)
     cmd = read_mini(sprintf("Open %s with (Leave empty to open in jed):",
			     filename), "", cmd);

   if (cmd == "")
      return filelist_open_file();

   () = chdir(buffer_dirname());
   if (getenv("DISPLAY") != NULL) % assume X-Windows running
      () = system(cmd + " " + filename + " &");
   else
      () = run_program(cmd + " " + filename);
}


#ifexists ffap
public define ffap_with() % (ask=1)
{
   variable ask = push_defaults(1, _NARGS);

   % Simple scheme to separate a path or URL from context
   % will not work for filenames|URLs with spaces or "strange" characters.
   variable filename = get_word("-a-zA-z_.0-9~/+:?=&\\");
   filename = strtrim_end(filename, ".+:?");
   if (filename == "")
      return;
   
   variable cmd = get_default_cmd(filename);

   if (ask)
     cmd = read_mini(sprintf("Open %s with (Leave empty to open in jed):",
			     filename), "", cmd);
   
   if (cmd == "")
      return ffap();
   
   () = chdir(buffer_dirname());
   if (getenv("DISPLAY") != NULL) % assume X-Windows running
      () = system(cmd + " " + filename + " &");
   else
      () = run_program(cmd + " " + filename);
}
#endif

#ifexists grep
%!%+
%\function{filelist_do_grep}
%\synopsis{Grep for a string in tagged files}
%\usage{  filelist_do_grep()}
%\description
%  Grep for a string in the tagged files.
%  Prompts for the pattern in the minibuffer.
%\notes
%  This function is only available, when \sfun{grep} is defined at
%  the time of evaluation or preparsing of filelist.sl
%\seealso{grep, filelist_mode}
%!%-
public define filelist_do_grep()
{
   grep( , list_tagged_files(FileList_Action_Scope, 1));
}
#endif

% --- The filelist mode -----------------------------------------

#ifdef HAS_DFA_SYNTAX
create_syntax_table(mode);
% set_syntax_flags (mode, 0);
% define_syntax ("-+0-9.", '0', mode);            % Numbers

% directories
dfa_define_highlight_rule(".*" + Dir_Sep + "$", "keyword", mode);
dfa_define_highlight_rule("^d[\\-r][\\-w]x.*$", "keyword", mode); % with "ls -l"
% backup copies
dfa_define_highlight_rule(".*~$", "comment", mode);
% Bugfix for high-bit chars in UTF-8
% render every char outside the range of printable ASCII chars as normal
dfa_define_highlight_rule("[^ -~]+", "normal", mode);

dfa_build_highlight_table(mode);

enable_dfa_syntax_for_mode(mode);
#endif

static define mc_bindings()
{
   definekey("menu_select_menu(\"Global.M&ode\")", Key_F2,  mode); % Menu
   definekey("filelist_view_file",           Key_F3,  mode); % View
   definekey("filelist_open_file",           Key_F4,  mode); % Edit
   definekey("filelist_copy_tagged",         Key_F5,  mode); % Copy
   definekey("filelist_rename_tagged",       Key_F6,  mode); % Ren/Move
   definekey("filelist_make_directory",      Key_F7,  mode); % Mkdir
   definekey("filelist_delete_tagged",       Key_F8,  mode); % Delete
   definekey("select_menubar",       	     Key_F9,  mode); % PullDn
   definekey("close_buffer",                 Key_F10, mode); % Quit
   definekey("filelist_open_file_with(0)",   "^M",    mode); % Return
   definekey("filelist_open_in_otherwindow", "o",     mode);
   % show("call set_help_message", "1Help...", mode);
   set_help_message(
     "1Help 2Menu 3View 4Edit 5Copy 6RenMov 7Mkdir 8Delete 9PullDn 10Quit",
		    mode);
}

static define dired_bindings()
{
   definekey("filelist_copy_tagged",		"C",  mode); % Copy
   definekey("filelist_delete_tagged",		"x",  mode); % Delete
   definekey("filelist_make_directory",		"+",  mode); % Mkdir
   definekey("filelist_open_file",		"e",  mode); % Edit
   definekey("filelist_open_file",		"^M", mode); % Return
   definekey("filelist_open_file_with(0)",	"X",  mode); % shell cmd
   definekey("filelist_rename_tagged",		"R",  mode); % Ren/Move
   definekey("filelist_do_rename_regexp",	"%r", mode); % rename regexp
   definekey("filelist_reread",			"g",  mode); % reread
   definekey("filelist_view_file",		"v",  mode); % View
   definekey("listing->tag_matching(1)",	"%d", mode); % tag regexp
   definekey("filelist_open_in_otherwindow",	" ",  mode);
   definekey("listing->tag(0); go_up_1",	_Backspace_Key,  mode);
   set_help_message(
     "Enter:Open t/Ins:Tag +/-:Tag-Matching s:search ^R:Reread q:Quit",
		    mode);
}

% Create the keymap
!if (keymap_p(mode)) {
   copy_keymap(mode, listing);
   undefinekey("^R", 			      	    mode);
   definekey ("filelist_reread", 	    "^R",   mode);
   call_function(FileList_KeyBindings + "_bindings");
}

% --- the mode dependend menu
static define filelist_menu(menu)
{
   % Re-use the listing mode menu
   listing->listing_menu(menu);
   % Insert extensions before the "Edit Listing" entry
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item("&Edit Listing", menu, "&Open", "filelist_open_file");
   menu_insert_item("&Edit Listing", menu, "Open &With", "filelist_open_file_with(1)");
   menu_insert_item("&Edit Listing", menu, "Open in other window", "filelist_open_in_otherwindow");
   menu_insert_item("&Edit Listing", menu, "&View (read-only)", "filelist_view_file");
   menu_insert_item("&Edit Listing", menu, "Open &Directory", "filelist_list_base_dir");
   menu_insert_item("&Edit Listing", menu, "Open Tagged &Files", "filelist_open_tagged");
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item("&Edit Listing", menu, "&Copy", "filelist_copy_tagged");
   menu_insert_item("&Edit Listing", menu, "Rename/&Move", "filelist_rename_tagged");
   menu_insert_item("&Edit Listing", menu, "&Rename/ regexp", "filelist_do_rename_regexp");
   menu_insert_item("&Edit Listing", menu, "Make Di&rectory", "filelist_make_directory");
   menu_insert_item("&Edit Listing", menu, "Delete", "filelist_delete_tagged");
   menu_insert_separator("&Edit Listing", menu);
   menu_insert_item("&Edit Listing", menu, "&Grep", "filelist_do_grep");
   menu_insert_item("&Edit Listing", menu, "Tar", "filelist_do_tar");
   menu_insert_separator("&Edit Listing", menu);
}

static define filelist_mouse_2click_hook (line, col, but, shift)
{
   filelist_open_file();
   return 1;  % stay in window
}

%!%+
%\function{filelist_mode}
%\synopsis{Interactive mode for file listings}
%\usage{filelist_mode()}
%\description
%  This mode transforms JED into a file manager (somewhat similar to
%  the  Midnight commander, MC). It can be used as a \sfun{dired} replacement
%  and gives (IMHO) a superiour look and feel. It works for directory listings
%  as well as the result of \sfun{locate}, \sfun{grep} or \sfun{find} actions.
%  Files can be listed, tagged, copied, moved, deleted, viewed, and opened
%  with ease.
%\seealso{filelist_list_dir, filelist_open_tagged}
%\seealso{FileList_KeyBindings, FileList_Action_Scope, FileList_max_window_size}
%!%-
public define filelist_mode()
{
   listing_mode();
   set_mode(mode, 0);
   use_syntax_table(mode);
   use_keymap(mode);
   mode_set_mode_info(mode, "init_mode_menu", &filelist_menu);
   set_buffer_hook("mouse_2click", &filelist_mouse_2click_hook);
   run_mode_hooks("filelist_mode_hook");
   help_message();
}

% ---------------------------------------------------------------------------

%!%+
%\function{locate}
%\synopsis{Search for a file with the `locate` command}
%\usage{ locate(what=<Ask>)}
%\description
%  The `locate` command performs a fast file lookup using a database.
%  This function is a backend to `locate` that presents the result
%  in a filelist buffer for easy browsing.
%\seealso{filelist_mode, grep}
%!%-
public define locate() % (what=<Ask>)
{
   % read pattern from minibuffer if not given as optional argument
   variable what = push_defaults("", _NARGS);
   if (what == "")
     {
	what = read_mini("Locate: ", "", LAST_LOCATE);
	!if ( strlen(what) )
	  return;
	LAST_LOCATE = what;
     }

   popup_buffer("*locate*", FileList_max_window_size);
   set_readonly(0);
   erase_buffer();

   set_prefix_argument(1);     % insert result in current buffer
   do_shell_cmd("locate " + what);
   if (bobp and eobp)
     {
	set_buffer_modified_flag(0);
	delbuf(whatbuf);
	return message("Locate: No results");
     }
   fit_window(get_blocal("is_popup", 0));
   filelist_mode();
   set_status_line("locate:" + what + " (%p)", 0);
   define_blocal_var("generating_function", [_function_name, what]);
   define_blocal_var("FileList_Cleanup", 0);
   bob();
}
