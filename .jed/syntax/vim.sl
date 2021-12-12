%
%	Syntax coloring for vimscript
%	Author: Nicholas Christopoulos
%
%	Installation:
%   * put the file in a directory on jed_library_path
%   * to your .jedrc add:
%       autoload ("vim_mode", "vim");
%       add_mode_for_extension ("vim, "vim");

require("keywords");

static define CreateSyntaxTable(mode) {
	create_syntax_table(mode);
%	define_syntax("^\"", "", '%', mode);
	define_syntax("/*", "*/", '%', mode);
%	define_syntax('"', '"', mode);
	define_syntax('\'', '\'', mode);
%	define_syntax ('\\', '#', mode);  % preprocessor
	define_syntax ("([{", ")]}", '(', mode);
	define_syntax ("0-9a-zA-Z_", 'w', mode);  % words
	define_syntax ("-+0-9.", '0', mode);      % Numbers
	define_syntax (",;.?", ',', mode);
	define_syntax ("%$()[]-+/*=<>^#", '+', mode);
	set_syntax_flags(mode, 0); % case sensitive
	}


static variable kwds_common =
	"for in endfor fu fun func function endf endfun endfunc endfunction while endwhile " +
	"break continue " +
	"if else elseif endif finish let set echo echom redraw exe exec execute silent " +
	"map nmap vmap imap nnoremap vnoremap inoremap call SID true false";

public define vim_mode () {
	!if (keywords->check_language("vim")) {
		variable K;
		CreateSyntaxTable("vim");
		K = keywords->new_keyword_list();
		keywords->add_keywords(K, kwds_common);
		keywords->sort_keywords(K);
		keywords->define_keywords(K, "vim", 0);
		keywords->add_language("vim");
		}

	set_mode("vim", 4);
	use_syntax_table("vim");
	}

