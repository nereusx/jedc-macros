%%
%%	BRIEF's colors (TC++) for Jed and XJed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/10/04 - created
%%

$1 = "#4f4";	% fg
$2 = "#00b";	% bg
$3 = "#bbb";	% "lightgray";	% half light
%$4 = "#b00"; 	% strings - red low
$4 = "#f00"; 	% strings - red (low or bright depended of TC version)
$5 = "#0bb"; 	% comment - cyan
$6 = "#b00";	% menu-red
$7 = "#0b0";	% menu-green (selection background)

private variable key0, key1, key2;

key0 = "#ffffff";
key2 = "#cccc44";
key1 = "yellow";
set_color("normal",		$1, $2);			% default
set_color("status",		"black", $3);		% status line
set_color("operator", "yellow", $2);% +, -, etc..
set_color("number", "lightgray", $2); % 10, 2.71, etc..
set_color("comment", $5, $2);	% /* comment */
set_color("region", "black", $3);	% selected
set_color("string", $4, $2);			% "string" or 'char'
set_color("keyword",  key0, $2);	    % if, while, unsigned, ...
set_color("keyword1", key1, $2);	    % if, while, unsigned, ...
set_color("keyword2", key2, $2);
set_color("delimiter", "yellow", $2);% {}[](),.;...
set_color("preprocess", $2, $5); % blue/cyan
%set_color("preprocess", "brightred", $2); % this is better
set_color("message", "yellow", $2);
set_color("error", "brightred", $2);
set_color("dollar", "brightred", $2);
set_color("...", "yellow", $2);			  % folding indicator

set_color("menu_char", $6, $3);
set_color("menu", "black", $3);
set_color("menu_popup", "black", $3);
set_color("menu_shadow", "blue", "black");
set_color("menu_selection", "black", $7);
set_color("menu_selection_char", $6, $7);

set_color("cursor", "black", "green");
set_color("cursorovr", "black", "red");

%% The following have been automatically generated:
set_color("linenum", $5, $2);
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

