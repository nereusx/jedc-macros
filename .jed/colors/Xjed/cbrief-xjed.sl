%%
%%	CBRIEF's colors for Jed and XJed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/10/04 - created
%%

$1 = "#fff";		% fg
$2 = "blue";
$3 = "#bbb";	% "lightgray";	% half light
$4 = "brightcyan";	% strings
$5 = "brightmagenta";	 	% delims/oprs
$8 = "#b00";	% menu-red

private variable key0, key1, key2;

#ifdef NONE
% example
int x = 1/2 * sin(pi/4);
#endif

key0 = "#ffff00";
key1 = "#00ff00";
key2 = "#ffcc00";

set_color("normal",   $1, $2);				% default
set_color("status",   "#000000", $3);		% status line
set_color("operator", "#ffbb00", $2);		% +, -, etc..
set_color("delimiter","#ff00ff", $2);		% {}[](),.;...
set_color("number",   "#00ff00", $2);		% 10, 2.71, etc..
set_color("comment",  "#999999", $2);		% /* comment */
set_color("region",   "#000000", $3);		% selected
set_color("string",   "#00ffff", $2);		% "string" or 'char'
set_color("keyword",  key0, $2);	    % if, while, unsigned, ...
set_color("keyword1", key1, $2);	    % if, while, unsigned, ...
set_color("keyword2", key2, $2);
set_color("preprocess", "brightred", $2);
set_color("message",  "#ffff00", $2);
set_color("error",	"brightred", $2);
set_color("dollar", "brightred", $2);
set_color("...", "red", $2);			  % folding indicator

set_color("menu_char", $8, $3);
set_color("menu", "black", $3);
set_color("menu_popup", "black", $3);
set_color("menu_selection", $1, $2);
set_color("menu_selection_char", $8, $2);
set_color("menu_shadow", "brightblue", "black");

set_color ("cursor",    "black", "green");
set_color ("cursorovr", "black", "red");

%% The following have been automatically generated:
set_color("linenum", $3, $2);
set_color("trailing_whitespace", "black", "cyan");
set_color("tab", "black", "cyan");
set_color("url", "brightblue", $2);
set_color("italic", $1, $2);
set_color("underline", "yellow", $2);
set_color("bold", "brightred", $2);
set_color("html", "brightred", $2);
set_color("keyword3", $1, $2);
set_color("keyword4", $1, $2);
set_color("keyword5", $1, $2);
set_color("keyword6", $1, $2);
set_color("keyword7", $1, $2);
set_color("keyword8", $1, $2);
set_color("keyword9", $1, $2);
