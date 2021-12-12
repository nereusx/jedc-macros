%%
%%	Green-black theme for XJed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/09/14 - created
%%

$1 = "#8f8"; % fg
$2 = "#333"; % bg
$3 = "#2a2"; % half light
$4 = "#88f"; % strings

private variable half_yellow = "#cc4";

private variable key0, key1, key2;

key0 = "#ff0";
key1 = "#ffffff";
key2 = half_yellow;

set_color("normal", $1, $2);
set_color("status", "black", $3);
set_color("operator", "#ffa", $2);      % +, -, etc..
set_color("number", "brightcyan", $2);    % 10, 2.71, etc..
set_color("comment", "#888", $2);% /* comment */
set_color("region", "black", "white"); % selected
set_color("string", $4, $2);    % "string" or 'char'
set_color("keyword",  key0, $2);    % if, while, unsigned, ...
set_color("keyword1", key1, $2);    % if, while, unsigned, ...
set_color("keyword2", key2, $2);
set_color("delimiter", "#aff", $2);     % {}[](),.;...
set_color("preprocess", "magenta", $2);
set_color("message", $3, $2);
set_color("error", "brightred", $2);
set_color("dollar", "brightred", $2);
set_color("...", "red", $2);			  % folding indicator

set_color ("menu_char", $1, $3);
set_color ("menu", "black", $3);
set_color ("menu_popup", "black", $3);
set_color ("menu_shadow", "blue", "black");
set_color ("menu_selection", $1, "black");
set_color ("menu_selection_char", "black", $3);

set_color ("cursor", "black", "green");
set_color ("cursorovr", "black", "red");

%% The following have been automatically generated:
set_color("linenum", "yellow", "blue");
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
