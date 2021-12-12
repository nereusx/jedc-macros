%
%	This is a simple kernel keymap mode.
%	
% 	Nicholas Christopoulos (nereus@freemail.gr)
% 	
% 	2016/10/04
% 	

require("keywords");

private variable table = "KMAP";

static define syntax_table()
{
	create_syntax_table(table);
	define_syntax("#", "", 			'%', table);	% comments
	define_syntax("!", "", 			'%', table);	% commants
	define_syntax("([{", ")]}",		'(', table);
	define_syntax('"',				'"', table);
	define_syntax('\'',				'\'', table);
	define_syntax('\\',				'\\', table);

	define_syntax("0-9a-zA-Z_",		'w', table);	% words
	define_syntax("-+0-9",			'0', table);	% Numbers
	define_syntax("0x1-9a-f",		'0', table);	% Numbers hex
%	define_syntax(",;:",			',', table);	% Separators
	define_syntax("-+=",			'+', table);	% Operators
	
	set_syntax_flags(table, 0x01 | 0x20); % case insensitive
}

static variable hard = "keycode keymaps string ";
static variable mods = "alt altgr altl altr control ctrll ctrlr shift shiftl shiftr ";
static variable defs = "charset compose include keymaps strings as usual ";

public define kmap_mode()
{
	ifnot ( keywords->check_language(table) ) {
		variable k;

		syntax_table();
		
		k = keywords->new_keyword_list();
		keywords->add_keywords(k, hard + defs);
		keywords->sort_keywords(k);
		keywords->define_keywords(k, table, 0);
		
		k = keywords->new_keyword_list();
		keywords->add_keywords(k, mods);
		keywords->sort_keywords(k);
		keywords->define_keywords(k, table, 1);

		keywords->add_language(table);
		}

	set_mode(table, 4);
	use_syntax_table(table);
}


