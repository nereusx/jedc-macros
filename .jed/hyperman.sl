% hyperman.sl
%
% $Id: hyperman.sl,v 1.34 2009/03/07 17:22:17 paul Exp paul $
% Keywords: help, hypermedia, unix
%
% Copyright (c) 2000-2008 JED, Paul Boekholt, Günter Milde
% Released under the terms of the GNU GPL (version 2 or later).
% hypertextish man pager

provide ("hyperman");
provide ("man");
require("pcre");
require("bufutils");
require("view");
implements("man");
%{{{ customvariables

%!%+
%\variable{Man_Clean_Headers}
%\synopsis{Set whether or not manpage headers are cleaned up}
%\usage{Int_Type Man_Clean_Headers = 0}
%\description
%   Set Man_Clean_Headers to 1, if you have an old man that gives you headers,
%   footers, and blank lines
%\seealso{unix_man}
%!%-
custom_variable("Man_Clean_Headers", 0);

%!%+
%\variable{Man_Use_Extensions}
%\synopsis{Set whether or not unix_man looks for extended section numbers}
%\usage{Int_Type Man_Use_Extensions = 1}
%\description
%   If a link looks like Tk::TList (3pm) we can try man -e pm Tk::Tlist
%   instead of man 3 Tk::Tklist, that may be more reliable.  This differs
%   from Emacs, where man xvidtune(1x) is translated to man 1x xvidtune,
%   but the latter means "man 1x and xvidtune" to my man.
%\seealso{unix_man}
%!%-
custom_variable("Man_Use_Extensions", 1);

%!%+
%\variable{Man_Complete_Whatis}
%\synopsis{Set whether or not unix_man should build a list of completions}
%\usage{Int_Type Man_Complete_Whatis = 1}
%\description
%   Set whether or not to complete in the man prompt.  The list of completions
%   is read in from the file \var{man_completions} in the \var{Jed_Home_Directory}.
%   If the file does not exist, it is generated from the output of "man -w '*'".
%\seealso{unix_man}
%!%-
custom_variable("Man_Complete_Whatis", 1);

%}}}


static variable mode = "man",
  man_word_chars = "-A-Za-z0-9_.:+()\e[]";

% pcre patterns
variable  page_pattern = "([-A-Za-z0-9_\e\[\]][-A-Za-z0-9_.:+\e\[\]]*)"R,
  sec_pattern = "\(([0-9no\e\[\]]|-k)([a-zA-Z+\e\[\]]*)\)"R,
  man_pattern = sprintf("%s ?%s", page_pattern, sec_pattern);

variable man_re = pcre_compile(man_pattern);

% slang patterns
page_pattern = "\\([-A-Za-z0-9_\e\\[\\]][-A-Za-z0-9_.:+\e\\[\\]]*\\)";
sec_pattern = "(\\([0-9no\e\\[\\]]\\)\\([a-zA-Z+\e\\[\\]]*\\))";
man_pattern = sprintf("%s ?%s", page_pattern, sec_pattern);


static variable Man_History = String_Type[16],
  keep_history = 1,
  this_manpage;
% ---- Functions -----------------------------------------------------------

%{{{ escape sequences
variable escape_re=pcre_compile("\e\\[[0-9]+\\]");
define purge_escapes(str);
define purge_escapes(str)
{
   if(pcre_exec(escape_re, str))
     {
	variable m = pcre_nth_match(escape_re, 0);
	str = str[[0:m[0]-1]] + purge_escapes(str[[m[1]:]]);
     }
   return str;
}

variable bold_marker = sprintf("\e[%d]", color_number("keyword")),
italic_marker = sprintf("\e[%d]", color_number("keyword1"));
%}}}

%{{{ parsing references

static define parse_ref(word)
{
   if (pcre_exec(man_re, word))   % e.g. man(5)
     {
        variable sec, page, ext;
        page = pcre_nth_substr(man_re, word, 1);
        sec  = pcre_nth_substr(man_re, word, 2);
        ext  = pcre_nth_substr(man_re, word, 3);

        if (strlen(ext) && Man_Use_Extensions)
          sec = "-e " + ext;

        word = sec + " " + page;
     }
   else
     word = strcompress(word, " ");
   return word;  % "5 man", "-e tcl list",
}

% transform:  "5 man"       to "man(5)"
%               "-e tcl exit" to "exit(3tcl)"
%               "man"         to "man"
static define make_ref(subj)
{
   if (pcre_exec(man_re, subj))
     return subj;
   subj = strtok(subj, " "); % ["5", "man"] , ["-e", "tcl", "exit"]
   switch (length(subj))
     { case 2: return  sprintf("%s(%s)",subj[1], subj[0]);}
     { case 3 && (subj[0] == "-e "):
        return  sprintf("%s(%s)",subj[2], subj[1]);
     }
     { return subj[-1];}
}
%}}}

%{{{ read a subject
% see below for initialization of this variable
variable man_completions="";

% Read a subject from the minibuffer.
% Can be in the n exit or exit(n) or exit(3tcl) format.
static define man_read_subject()
{
   variable word= purge_escapes(get_word(man_word_chars));
   if (is_substr(word, "(") && not pcre_exec(man_re, word))  % maybe it's a C function
     {
	  word = strchop(word, '(', 0)[0];
     }
   if (Man_Complete_Whatis)
     word= read_string_with_completion ("man", word, man_completions);
   else
     word = read_mini("man", word, "");
   return word;
}
%}}}

%{{{ clean the page
static define man_mode();
static define man_push_position();

static define man_clean_manpage ()
{
   variable clean = "Cleaning man page...";
   variable section_alist=String_Type[25, 2], sections = 0, line;
   bob ();
   flush (clean);
   % fix hyphens if in utf-8 mode
   if (_slang_utf8_ok)
     {
	while(fsearch_char(173))
	  {
	     del;
	     insert_char(173);
	  }
	bob();
     }
   variable ch;
   while(re_fsearch("[^_]\010"))
     {
	% This is needed for multibyte characters such as \u{2018} 
	% in the sed manpage
	if (_slang_utf8_ok)
	  ()=left(right(1));
	insert(bold_marker);
	ch = what_char();
	right(1);
	while(looking_at(sprintf("\010%c", ch)))
	  {
	     deln(2);
	     ch = what_char();
	     right;
	  }
	()=left;
	insert("\e[0]");
     }
   bob;
   while(fsearch("_\010"))
     {
	insert(italic_marker);
	1;
	while(looking_at("_\010"))
	  {
	     deln(2);
	     right;
	  }
	pop;
	insert("\e[0]");
     }

   if (Man_Clean_Headers)
     {
	variable header;
	% remove headers
	bob ();
	skip_chars ("\n");
	header = line_as_string ();
	go_down_1 ();
	bol ();
	while (bol_fsearch (header))
	  delete_line ();
	% remove footers
	eob ();
	bskip_chars ("\n");
	bol ();
	push_mark_eol ();
	bskip_chars ("1234567890");
	header = bufsubstr ();
	% get rid of spurious empty lines around headers and footers
	bol ();
	while (bol_bsearch (header))
	  {
	     delete_line ();
	     go_up (3);
	     loop (10)
	       {
		  bol();
		  ifnot (eolp()) break;
		  delete_line ();
	       }
	  }
     }
   % remove multiple blank lines
   trim_buffer ();
   % build the sections-list
   bob();
   variable alist_index;
   while (sections <  25)
     {
	ifnot (re_fsearch ("^[\e0-9\\[\\]]*[A-Z]")) break;
	line = line_as_string;
	if (strlen(line) > 50) continue;   %  header or footer
	section_alist[sections, 0] = purge_escapes(line);
	section_alist[sections, 1] = string(what_line());
	sections++;
     }
   define_blocal_var("section_list", section_alist);
   define_blocal_var("sections", sections -1);
   bob();
   sw2buf(whatbuf());
   set_buffer_modified_flag (0);
   man_mode;
   man_push_position(this_manpage);
   define_blocal_var("generating_function",
		     ["unix_man", this_manpage]);
   flush (strcat (clean, "done"));
   update (1);
}

%}}}

%{{{ move in the page

public define man_next_section ()
{
   go_down_1 ();
   () = re_fsearch ("^[\e0-9\\[\\]]*[A-Z]");
   recenter (1);
}

public define man_previous_section ()
{
   () = re_bsearch ("^[\e0-9\\[\\]]*[A-Z]");
   recenter (1);
}

% Go to a section.  In Emacs this is on 'g' but I use that key for
% going to another page like in lynx, so it's on 's'
public define man_goto_section ()
{
   variable section_list = get_blocal_var("section_list"),
   sections = get_blocal_var("sections");
   section_list = section_list[[:sections],*];
   variable names = section_list[*,0], lines = section_list[*,1];
   variable section = read_with_completion
     (strjoin(names, ","), "Go to section", "SEE ALSO", "", 's');
   variable n = wherefirst(section == names);
   if (n != NULL)
     {
	goto_line(atoi(lines[n]));
	recenter(1);
     }
}

public define man_next_reference ()
{
   skip_chars (man_word_chars);
   go_right_1; % weirdness in searching w/ escape sequences
   () = re_fsearch (man_pattern);
}

public define man_previous_reference ()
{
   bskip_chars (man_word_chars);
   if (re_bsearch (man_pattern))
     {
	bskip_chars("\e[]0-9");
	bskip_chars("-a-zA-Z0-9");
     }
}
%}}}

%{{{ Close all man-Buffers
public define man_cleanup()
{
   variable buf;
   loop (buffer_list ())
     {
	buf = ();
	if (is_substr(buf, "*Man"))
	  delbuf(buf);
     }
}
%}}}

%{{{ get the page

static variable man_stack_depth = -1, this_manpage;


static define man(subj)
{
   subj = parse_ref(subj);              % ["man(3)"|"3 man"] -> "3 man"
   this_manpage = subj;
   variable buf = "*Man " + subj + "*";
   if (bufferp (buf))
     return sw2buf (buf);
   % get the manpage
   setbuf (buf);
   set_readonly (0);
   erase_buffer ();
   flush ("Getting man page "+ subj);
   variable man_cmd;
#ifdef OS2
   man_cmd = sprintf("man %s 2> nul", subj);
#else
% man-db
%   man_cmd = sprintf("MAN_KEEP_FORMATTING=1 MANWIDTH=%d man %s 2> /dev/null", SCREEN_WIDTH, subj);
% mandoc
%   man_cmd = sprintf("MAN_KEEP_FORMATTING=1 man -O width=%d %s 2> /dev/null", SCREEN_WIDTH - 6, subj);
% both
   man_cmd = sprintf("MAN_KEEP_FORMATTING=1 MANWIDTH=%d man -O width=%d %s 2> /dev/null", SCREEN_WIDTH, SCREEN_WIDTH-6, subj);
#endif
   variable return_status = run_shell_cmd (man_cmd);
   if (return_status && bobp() && eobp())
     {
	delbuf(whatbuf);
	if (16 == return_status)
	  throw RunTimeError, "manpage $subj not found"$;
	else
	  throw RunTimeError, "man returned an error (return status $return_status)"$;
     }
   man_clean_manpage;

}
%}}}

%{{{ jump to another page

%{{{ history stack

variable man_history_rotator = [[1:15],0],
  forward_stack_depth = 0;

static define man_push_position(subj)
{
   ifnot (keep_history)
     return;

   ++man_stack_depth;
   if (man_stack_depth == 16)
     {
        --man_stack_depth;
	Man_History  = Man_History [man_history_rotator];
     }

   Man_History [man_stack_depth] = make_ref(subj);

   forward_stack_depth = 0;
}

public define man_go_back ()
{
   ifnot (man_stack_depth) return message("Can't go back");
   --man_stack_depth;
   ++forward_stack_depth;
   keep_history = 0;
   man(Man_History[man_stack_depth]);
}

public define man_go_forward()
{
   ifnot (forward_stack_depth) return message("Can't go forward");
   ++man_stack_depth;
   --forward_stack_depth;
   keep_history = 0;
   man(Man_History[man_stack_depth]);
}

%}}}

% get: page(sec) or page (sec)
static define man_get_ref ()
{
   variable word = "";

   % get word under cursor and neighbours too (to catch page (sec))
   push_spot ();
   push_mark();
   bskip_chars(man_word_chars);
   go_left_1; % maybe this is a " "
   bskip_chars(man_word_chars);
   % get beginning of hyphenated link
   push_spot;
   bskip_white;
   if (bolp)
     {
	go_left(2);
	if(looking_at_char(']')) {bskip_chars("\e[]0-9"); go_left_1;}
	if (looking_at_char('­'))
	  {
	     push_mark;
	     bskip_chars(man_word_chars);
	     word = bufsubstr;
	  }
     }
   pop_spot;
   exchange_point_and_mark();
   skip_chars(man_word_chars);
   go_right_1; % maybe this is a " "
   skip_chars(man_word_chars);
   word += strtrim (bufsubstr());
   pop_spot ();

   ifnot (string_match(word, man_pattern, 1))
     {
	message (word + " is not a man-page");
	return "";
     }
   return parse_ref(purge_escapes(word)); % extract and normalize reference
}

public define man_follow()
{
   variable ref = man_get_ref();
   if (ref == "") return;
   keep_history = 1;
   man(ref);
}

%}}}

%{{{ start reading manpages

%!%+
%\function{unix_man}
%\synopsis{Display a man page entry}
%\usage{unix_man([subject])}
%\description
%  Retrieve a man page entry, use clean_manpage to clean it up and
%  display in a buffer in man_mode.  
%  
%\seealso{man_mode, unix_apropos, Man_Clean_Headers, Man_Use_Extensions, Man_Complete_Whatis}
%
%!%-
public define unix_man ()
{
   variable subj;
   if (_NARGS)
     subj = ();
   else
     subj = man_read_subject();
   ifnot (strlen (subj))
     return;
   keep_history = 1;
   man (subj);
}

%}}}

%{{{ apropos, whatis

%!%+
%\function{unix_apropos}
%\synopsis{search the manual page names and descriptions}
%\usage{unix_apropos([subject])}
%\description
%   Runs "man -k" to get a list of manpages whose names match \var{subject}
%   and display the result in a buffer in \sfun{man_mode}
%\seealso{unix_man}
%!%-
public define unix_apropos()
{
   variable subj;
   if (1 == _NARGS)
     subj = ();
   else
     subj = read_mini ("apropos", "", "");
   subj = "-k " + subj;
   keep_history = 1;
   man (subj);
}

public define unix_whatis()
{
   push_spot;
   variable ro = is_readonly(), mo = buffer_modified(),
   word = purge_escapes(get_word("-A-Za-z0-9_.:\e[]0-9"));
   eol;
   set_readonly(0);
   push_visible_mark;
   newline;
   word = strtrim_beg(word, "-"); % strip '-' from options
   () = run_shell_cmd(strcat("whatis ", word));
   message("hit any key to continue");
   update_sans_update_hook(0);
   % wait for any key and discard the key sequence
   ( , ) = get_key_binding();
   del_region;
   set_readonly(ro);
   set_buffer_modified_flag(mo);
   pop_spot;
}

%}}}

%{{{ keybindings & menu

ifnot (keymap_p (mode))
{
   copy_keymap (mode, "view");
   definekey ("man_follow", "^M", mode);
   definekey ("man_go_back", "l", mode);
   definekey ("man_go_forward", ";", mode);
   definekey ("unix_man", "g", mode);
   definekey ("unix_man", "m", mode);
   definekey ("unix_man", "u", mode);
   definekey ("unix_apropos", "i", mode);
   definekey ("unix_apropos", "a", mode);
   definekey ("unix_whatis", "w", mode);

   definekey ("man_next_section", "n", mode);
   definekey ("man_previous_section", "p", mode);
   definekey ("man_next_reference", "\t", mode);
   definekey ("man_previous_reference", Key_Shift_Tab, mode);
   definekey ("man_next_reference", "f", mode);
   definekey ("man_previous_reference", "b", mode);
   definekey ("man_goto_section", "s", mode);
}

set_help_message("(M)anpage, (A)propos, (W)hatis, (L)ast page, (N)ext section, (P)revious section",
		 "man");

static variable numbers = "123456789abcdefghijklmnop";

static define man_jump_callback(popup)
{
   variable section_list= get_blocal_var("section_list"),
   sections = get_blocal_var("sections"), number;
   _for number (0, sections, 1)
     {
	menu_append_item
	  (popup, strlow
	   (sprintf("&%c %s", numbers[number], section_list[number,0])),
	   &goto_line, atoi(section_list[number,1]));
     }
   pop_spot();
}

static define man_page_callback(popup)
{
   variable buf;
   loop (buffer_list ())
     {
	buf = ();
	if (is_substr(buf, "*Man"))
	  menu_append_item(popup, buf[[5:-2]], &sw2buf, buf);
     }
}

static define man_menu(menu)
{
   menu_append_popup (menu, "man pages");
   menu_set_select_popup_callback (menu + ".man pages", &man_page_callback);
   menu_append_popup (menu, "&section");
   menu_set_select_popup_callback(menu+".&section", &man_jump_callback);
   menu_append_item (menu, "&go to page", "unix_man");
   menu_append_item (menu, "&apropos", "unix_apropos");
   menu_append_item (menu, "&what is", "unix_whatis");
   menu_append_item (menu, "&close man buffers", "man_cleanup");
}

%}}}

%{{{ mouse support

static define man_mouse(line, col, but, shift)
{
   switch (but)
     { case 1:
	if (re_looking_at (man_pattern)) man_follow;
     }
     { case 4: unix_whatis; }
     { return -1; } % pass wheel scrolling events to the default hook
   1;
}

%}}}

%!%+
%\function{man_mode}
%\synopsis{Mode for reading man pages}
%\usage{man->man_mode()}
%\description
%  The following man commands are available in the buffer.
%  \var{TAB}     move to next manpage reference
%  \var{ENTER}   follow a manpage reference
%  \var{g}       Prompt to retrieve a new manpage.
%  \var{l}       Go back to last visited manpage in history.
%  \var{;}       Go forward in history.
%  \var{p}       Jump to previous manpage section.
%  \var{n}       Jump to next manpage section.
%  \var{s}       Go to a manpage section.
%  \var{w}       Run \sfun{whatis} on the word at point
%  \var{a}       Call \sfun{unix_apropos}
%  \var{q}       Deletes the manpage window, kill its buffer.
%  \var{h}       Give help for man_mode
%\seealso{unix_man}
%!%-
static define man_mode()
{
   view_mode ();
   use_keymap (mode);
   _set_buffer_flag(0x1000);
   set_mode(mode, 0);
   set_buffer_hook("mouse_up", &man_mouse);
   mode_set_mode_info(mode, "init_mode_menu", &man_menu);
   run_mode_hooks("man_mode_hook");
}

%{{{ completions initialisation

static define man_read_completions()
{
   variable fp = fopen(dircat(Jed_Home_Directory, "man_completions"), "r");
   if (fp == NULL) return;
   () = fread_bytes(&man_completions, 1000000, fp);
   () = fclose(fp);
}

public define man_make_completions()
{
   flush("initializing completions");
   variable fp = popen
     ("(whatis -w '*' | sed -e 's/).*/),/' | tr -d '\n') 2> /dev/null", "r");
   if (fp == NULL) return;
   () = fread_bytes(&man_completions, 1000000, fp);
   () = pclose(fp);
%   fp = fopen(dircat(Jed_Home_Directory, "man_completions"), "w");
%   if (fp == NULL) return;
%   ()=fputs(man_completions, fp);
%   () = fclose(fp);
}

runhooks("man_init_hook");
if(Man_Complete_Whatis)
{
   if(1 != file_status (dircat(Jed_Home_Directory, "man_completions")))
     man_make_completions();
   else
     man_read_completions();
}

%}}}
