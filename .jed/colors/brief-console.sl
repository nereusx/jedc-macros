%%
%%	BRIEF's (TC) colors for Jed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/10/04 - created
%%

$0 = "black";
$9 = "white";
$1 = "brightgreen";	% fg
$2 = "blue";		% bg
$3 = "lightgray";	% half light

private variable key0, key1, key2;

key0 = "white";
key1 = "yellow";
key2 = "brown";

set_color("normal",		$1, $2);		% default
set_color("status",		$0, $9);		% status line
set_color("operator",	"yellow", $2);% +, -, etc..
set_color("number",		"lightgray", $2); % 10, 2.71, etc..
set_color("comment", 	"cyan", $2);	% /* comment */
set_color("region", 	$0, $9);	% selected
set_color("string", 	"brightred", $2);			% "string" or 'char'
set_color("keyword",  	key0, $2);	    % if, while, unsigned, ...
set_color("keyword1",	key1, $2);	    % if, while, unsigned, ...
set_color("keyword2",	key2, $2);
set_color("delimiter",	"yellow", $2);% {}[](),.;...
set_color("preprocess", "blue", "cyan");
set_color("message",	"yellow", $2);
set_color("error",		"brightred", $2);
set_color("dollar",		"red", $2);
set_color("...",		"red", $2);			  % folding indicator

set_color("menu_char",	"red", $3);
set_color("menu", 		$0,    $3);
set_color("menu_popup", $0,    $3);
set_color("menu_selection", $0, "green");
set_color("menu_selection_char", "red", "green");
set_color("menu_shadow", "gray", "black");

set_color("cursor", "black", "green");
set_color("cursorovr", "black", "red");

%% The following have been automatically generated:
set_color("linenum", "cyan", $2);
set_color("trailing_whitespace", "black", "brightcyan");
set_color("tab", "black", "brightcyan");
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

