%%
%%	Atom like blackish theme for XJed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/09/14 ndc: created
%%		2016/10/28 ndc: changed menu and status bg, lighter and a bit lighter
%%

%implements("atom-colors");

$0 = "#000000";	% black always
$9 = "#ffffff";	% white always
$1 = "#cccccc"; % fg
$2 = "#2c2c2c"; % bg
$3 = "#444444";	% default menu/status background
$4 = "#bb0000"; % menu - red

private variable red      = "#ff4444";
private variable redx     = "#ff8888";
private variable green    = "#88ff88";
private variable blue     = "#8888ff";
private variable cyan     = "#88ffff";
private variable magen    = "#ff44ff";
private variable orange   = "#ffbb44";
private variable yellow   = "#ffff44";
private variable yellow_2 = "#cccc44";

private variable comments = "#808080";
private variable strings  = green;
private variable key0, key1, key2;
private variable menu_bg  = "#bbbbbb";
private variable stat_bg  = "#666666";

#ifdef NONE
% example
private variable show_int = 0x1234 + 033 - (125/4);
#endif

key0 = orange;
key1 = yellow;
key2 = $9;

set_color("normal",		$1, $2);
set_color("region",		$9, comments); % selected
set_color("status",		$0, stat_bg);
set_color("operator",	redx, $2);      % +, -, etc..
set_color("number", 	cyan, $2);    % 10, 2.71, etc..
set_color("comment",	comments, $2);		% /* comment */
set_color("string",		strings,  $2);    % "string" or 'char'
set_color("keyword",	key0, $2);    % if, while, unsigned, ...
set_color("keyword1",	key1, $2);    % if, while, unsigned, ...
set_color("keyword2",	key2, $2);
set_color("delimiter",	magen, $2);     % {}[](),.;...
set_color("preprocess", red, $2);
set_color("message",	$1, $2);
set_color("error", "brightred", $2);
set_color("dollar", "brightred", $2);
set_color("...", "red", $2);			  % folding indicator

set_color("menu_char",		$4, menu_bg);
set_color("menu",			$0, menu_bg);
set_color("menu_popup",		$0, menu_bg);
set_color("menu_selection", $1, $2);
set_color("menu_selection_char", $4, $2);
set_color("menu_shadow",	$2, "black");

set_color("cursor",		"black",		"green");
set_color("cursorovr",	"brightgreen",	stat_bg);

%% The following have been automatically generated:
set_color("linenum", comments, $2);
set_color("trailing_whitespace", "black", "brightcyan");
set_color("tab", "black", "brightcyan");
set_color("url", "brightblue", $2);
set_color("italic", $1, $2);
set_color("underline", "yellow", $2);
set_color("bold", "brightred", $2);
set_color("html", "brightred", $2);
set_color("keyword3", $9, $2);
set_color("keyword4", $9, $2);
set_color("keyword5", $9, $2);
set_color("keyword6", $9, $2);
set_color("keyword7", $9, $2);
set_color("keyword8", $9, $2);
set_color("keyword9", $9, $2);

