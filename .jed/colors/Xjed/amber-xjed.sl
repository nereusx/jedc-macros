%%
%%	amber-black theme for Jed
%%
%%	Nicholas Christopoulos (nereus@freemail.gr)
%%
%%		2016/09/14 - created
%%

%% yellow = #FFFF00
private variable yellow = "#FFEE00";
private variable brown  = "#DDAA22";

%% colors
private variable G = "brightgreen";
private variable g = "green";
private variable Y = yellow;
private variable y = brown;
private variable W = "white";
private variable w = "lightgray";
private variable R = "brightred";
private variable r = "red";
private variable B = "brightblue";
private variable b = "blue";
private variable C = "brightcyan";
private variable c = "cyan";
private variable Z = "gray";
private variable z = "black";
private variable M = "brightmagenta";
private variable m = "magenta";

%% video modes high,low,black
private variable hi = Y;
private variable lo = y;
private variable zz = z;

%% default foreground, background
$1 = lo;
$2 = "black";

%%
set_color("normal",   	$1, $2);
set_color("number",		G, $2);		% 10, 2.71, etc..
set_color("comment",	Z, $2);		% comment
set_color("string",  	G, $2);		% "string" or 'char'
set_color("keyword",	Y, $2);		% if, while, unsigned, ...
set_color("keyword1",	G, $2);		% if, while, unsigned, ...
set_color("keyword2",	y, $2);		% if, while, unsigned, ...
set_color("operator",	w, $2);     % +, -, etc..
set_color("delimiter",	W, $2);		% {}[](),.;...
set_color("preprocess", m, $2);
set_color("message",	g, $2);
set_color("error",		R, $2);
set_color("dollar",		R, $2);
set_color("...",		r, $2);			  % folding indicator

set_color("status",					zz, lo);	% status line
set_color("region",					zz, lo);	% selection

set_color("menu_char",				hi, lo);
set_color("menu",					zz, lo);
set_color("menu_popup",				zz, lo);
set_color("menu_selection", 		hi, zz);
set_color("menu_selection_char", 	lo, zz);
set_color("menu_shadow",			b,  z);

set_color ("cursor",	z, G);
set_color ("cursorovr",	z, R);

%% The following have been automatically generated:
set_color("linenum",	G, g);
set_color("trailing_whitespace", "black", "brightcyan");
set_color("tab", "black", "brightcyan");
set_color("url", 		B, $2);

set_color("bold",		G, $2);
set_color("italic",		y, $2);
set_color("underline",	c, $2);

set_color("html", "brightred", $2);
set_color("keyword2", $1, $2);
set_color("keyword3", $1, $2);
set_color("keyword4", $1, $2);
set_color("keyword5", $1, $2);
set_color("keyword6", $1, $2);
set_color("keyword7", $1, $2);
set_color("keyword8", $1, $2);
set_color("keyword9", $1, $2);
