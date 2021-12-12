%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	Jed BRIEF-mode configuration
%%	
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%

Info_Directory = "/usr/info";

Jed_Highlight_Cache_Dir = Jed_Home_Directory + "/.cache";
set_jed_library_path(sprintf("%s,%s,%s", Jed_Home_Directory, Jed_Highlight_Cache_Dir, get_jed_library_path()));
Jed_Highlight_Cache_Path = sprintf("%s,%s,%s", Jed_Home_Directory, Jed_Highlight_Cache_Dir, Jed_Highlight_Cache_Path);
Color_Scheme_Path = sprintf("%s/colors,%s", Jed_Home_Directory, Color_Scheme_Path);

%{{{ auto-compile
private variable local_files = listdir(strcat(Jed_Home_Directory, "/"));
foreach $0 ( local_files ) {
	if ( path_extname($0) ==  ".sl" ) {
		$1 = strcat(Jed_Home_Directory, "/", $0);
		$2 = strcat(Jed_Home_Directory, "/", $0, "c");
		if ( access($2, R_OK) != 0 )
			byte_compile_file($1, 1);
		else
			if ( 0 < file_time_compare($1, $2) )
				byte_compile_file($1, 1);
		}
	}
%}}}

%{{{ terminal characteristics/keys
private variable term_fixes = Jed_Home_Directory + "/terminal.sl";
ifnot ( BATCH ) {
	if ( file_status(term_fixes) == 1 )
		() = evalfile(term_fixes);
	}

%}}}

%% loading modules
require("sys/osl");
%% require("pcre");
require("cbrief");
require("hyperman");
require("recent");
require("compile");

% backup directory
require("sys/backup");

%% --- custom modes -------------------------------------------------------

%% ndc-keymap
autoload("kmap_mode", "syntax/kmap");
add_mode_for_extension("kmap_mode", "kmap");

%% ndc-csh
autoload("csh_mode", "syntax/csh");
autoload("tcsh_mode", "syntax/tcsh");
add_mode_for_extension("CSH", "csh");
add_mode_for_extension("CSH", "tcsh");

autoload("sh_mode", "syntax/shmode");
add_mode_for_extension("SH", "sh");

%% sql
autoload("sql_mode", "syntax/sql");
autoload("mysql_mode", "syntax/sql");
add_mode_for_extension("sql", "sql");

%% vim
autoload("vim_mode", "syntax/vim");
add_mode_for_extension("vim", "vim");

%%
add_mode_for_extension("latex", "tex");        % overrides tex_mode
add_mode_for_extension("latex", "sty");
add_mode_for_extension("latex", "cls");

%% hyperhelp
_autoload("help_for_help", "help",
		     "grep_definition", "help",
		     "grep_slang_sources", "help",
		     "context_help", "help",
		     "help_for_word_at_point", "help",
		     "set_variable", "help",
		     "help_search", "help",
		     7);
_add_completion("grep_definition", "set_variable", "help_search", 3);

define hyperhelp_load_popup_hook(menubar) {
	menu_insert_item("&Info Reader", "Global.&Help", "&Grep Definition", "grep_definition");
	menu_insert_item("&Info Reader", "Global.&Help", "&/ Search in Help Docs", "help_search");
	menu_insert_separator("&Info Reader", "Global.&Help");
	}
append_to_hook ("load_popup_hooks", &hyperhelp_load_popup_hook);

%%
autoload("awk_mode", "syntax/awk");
add_mode_for_extension("awk", "awk");

%% makefile
autoload("make_mode", "syntax/make");

%% --- special filenames --------------------------------------------------
private variable special_files = {
%	position is the priority too (the first wins)
%      mode-proc,                    filenames list,                             extensions list
	{ &text_mode, "README|INSTALL|CHANGES|CHANGELOG|ChangeLog|NEWS|TODO|NOTES", "txt|log|hlp|doc" },
	{ &make_mode, "Makefile|GNUmakefile|BSDmakefile", "mak" },
	{ &sh_mode,   ".profile|.bashrc|.kshrc|.mkshrc|.yashrc|.zshrc", "sh" },
	{ &csh_mode,  ".tcshrc|.cshrc|.login|.logout", "csh|tcsh" },
	{ &vim_mode,  ".vimrc|vimrc", "vim" },
	};

private define set_modes_hook(base, ext) {
	variable e;
	foreach e ( special_files ) {
		if ( osl_isset(e[1], base) || osl_isset(e[2], ext) ) {
			(@e[0])();
			return 1;
			}
		}
	return 0;
	}
list_append(Mode_Hook_Pointer_List, &set_modes_hook);

%% --- spell --------------------------------------------------------------
require("ispell");
Ispell_Program_Name = "aspell";

%% --- globals ------------------------------------------------------------

enable_top_status_line(0); % enable/disable menu bar

BLINK = 0;				% no blink parenthesis
TERM_BLINK_MODE = 0;	% use highlight
WRAP_DEFAULT = 132;		% max column on wrap-mode, it seems it is working everywhere
ADD_NEWLINE = 1;		% add newline to file when writing if one not present
USE_ANSI_COLORS = 1;	% use colors
TAB_DEFAULT	= 4;		% Tab size  (also try edit_tab_stops)
USE_TABS	= 1;		% Use tabs when generating whitespace.
LINENUMBERS = 1;		% A value of zero means do NOT display line number on status line line.
						% A value of 1, means to display the linenumber. A value greater than 1 will also display column number information.
DOLLAR_CHARACTER = '>'; % horizontal scroll character

%% Whitesmith style (ok it trying to be), I actually use Ratliff
require("cmode");
(C_INDENT, C_BRACE, C_BRA_NEWLINE, C_CONTINUED_OFFSET, C_Colon_Offset, C_Class_Offset) = (4,4,0,4,0,4);

% Ratliff mode by Jed
define c_set_style_hook (name) {
	if (name == "ratliff")  {
		% Customize
		C_INDENT = 4;
		C_BRACE = 2;
		C_BRA_NEWLINE = 1;
		C_CONTINUED_OFFSET = 4;
		C_Colon_Offset = 1;
		C_Class_Offset = 4;
		C_Namespace_Offset = 4;
		C_Macro_Indent = 4;
		C_Label_Offset = 0;
		C_Label_Indents_Relative = 0;
		C_Outer_Block_Offset = 0;
		}
	}

%% --- abbrev -------------------------------------------------------------
%% <F10>abbrev_mode

create_abbrev_table("Global", "_A-Za-z0-9");
define_abbrev("Global", "__ldq", "“");
define_abbrev("Global", "__rdq", "”");
define_abbrev("Global", "__lsq", "‘");
define_abbrev("Global", "__rsq", "’");
define_abbrev("Global", "__dag", "†");
define_abbrev("Global", "__ddag", "‡");
define_abbrev("Global", "__ss", "§");
define_abbrev("Global", "__laq", "‹");
define_abbrev("Global", "__raq", "›");
define_abbrev("Global", "__2", "²");
define_abbrev("Global", "__3", "³");
define_abbrev("Global", "__deg", "°");
define_abbrev("Global", "__OU", "Ȣ");
define_abbrev("Global", "__ou", "ȣ");
define_abbrev("Global", "__enter", "⏎");
define_abbrev("Global", "__00", "‰");
define_abbrev("Global", "__sq", "√");
define_abbrev("Global", "__inf", "∞");
define_abbrev("Global", "__aprox", "≈");
define_abbrev("Global", "__kk", "☭");
define_abbrev("Global", "__star", "★");
define_abbrev("Global", "__space", "␣");
set_abbrev_mode(1);

%% --- colors -------------------------------------------------------------
#ifdef XWINDOWS
set_color_scheme ("Xjed/atom-xjed");
#else
set_color_scheme ("cbrief-console");
if ( getenv("TERM") == "xterm" ) DISPLAY_EIGHT_BIT = 0;
#endif

%% --- finalize -----------------------------------------------------------

% key-bindings (not loaded for batch processes)
if ( BATCH == 0 ) {	() = evalfile("cbrief"); }

% sessions - last command always
require("sys/session");

