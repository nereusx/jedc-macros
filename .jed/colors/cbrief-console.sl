%%
%%	CBRIEF's colors for Jed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/10/04 - created
%%

$1 = "white";		% fg
$2 = "blue";		% bg
$3 = "lightgray";	% half light
$4 = "brightcyan";	% strings
$5 = "brightmagenta";	 	% delims/oprs

private variable key0, key1, key2;

key0 = "yellow";
key1 = "brightgreen";
key2 = "brown";

set_color("normal",   $1, $2);				% default
set_color("status",   "black", $3);			% status line
set_color("operator", $5, $2);% +, -, etc..
set_color("number",   "brightgreen", $2); % 10, 2.71, etc..
set_color("comment",  $3, $2);	% /* comment */
set_color("region",   "black", $3);	% selected
set_color("string",   $4, $2);			% "string" or 'char'
set_color("keyword",  key0, $2);	    % if, while, unsigned, ...
set_color("keyword1", key1, $2);	    % if, while, unsigned, ...
set_color("keyword2", key2, $2);
set_color("delimiter", $5, $2);% {}[](),.;...
set_color("preprocess", "brightred", $2);
set_color("message", "yellow", $2);
set_color("error", "brightred", $2);
set_color("dollar", "brightred", $2);
set_color("...", "red", $2);			  % folding indicator

set_color("menu_char", "red", $3);
set_color("menu", "black", $3);
set_color("menu_popup", "black", $3);
set_color("menu_selection", $1, $2);
set_color("menu_selection_char", "cyan", $2);
set_color("menu_shadow", "brightblue", "black");

set_color ("cursor", "black", "green");
set_color ("cursorovr", "black", "red");

%% The following have been automatically generated:
set_color("linenum", "lightgray", "blue");
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
