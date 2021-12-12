% occur.sl
%
% $Id: occur.sl,v 1.5 2005/05/24 09:20:43 paul Exp $
% Keywords: matching
%
% Copyright (c) John Davis, Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
%
% Improved occur function:
% - can show occurrences with context
% - occur() has optional arguments for scripting
% - inherits from view-mode
% - propose to list occurrences of the word at point
% - in occur mode you can scroll the other window like in bufed or rmail
% - moccur: occur in multiple buffers
% - (SLang 2 only) highlight matches

provide ("occur");
require ("keydefs");
require ("view");
implements ("occur");
define get_buffer_name();

% default number of context lines
% unfortunately it's not possible to give a 0 prefix argument
custom_variable ("Occur_Context", 0);

$1 = "Occur";

%{{{ keymap

!if (keymap_p ($1))
  copy_keymap ($1, "view");
. "occur->occur_goto_line" "g"
. "occur->next" "n"
. "occur->prev" "p"
. "occur->scroll" " "
. "occur->scroll_up" Key_BS
. "occur->occur_pop_to_line" "\t"
loop(6) definekey($1);

%}}}

%{{{ static variables
variable buf = "*occur*",
  % The buffer that's searched
  obuf = Null_String,
  % How many lines of context to show
  % In occur mode, it should not be assumed that the entry really has
  % `nlines' lines of context, but if this is not 0 entries are separated by
  % "^-----"
  nlines = 0,
  % flag indicating that we're occurring in multiple buffers
  mbuffers=0,
  % were there any matches?
  matches_flag = 0;

  % Width of line number prefix without the colon.  Choose a width that's a
  % multiple of `tab-width' so that lines in *Occur* appear right.
  variable line_number_width=(4 / TAB_DEFAULT + 1) * TAB_DEFAULT - 1,
  line_number_format = sprintf("%%%dd:", line_number_width),
  empty =sprintf("%*s", line_number_width + 1, ":");

#ifexists _slang_utf8_ok
variable match_marker = sprintf("\e[%d]", color_number("keyword"));
#endif
%}}}

%{{{ occur mode
%{{{ moving around

static define next()
{
   if (nlines)
     ()=bol_fsearch("---");
   eol;
   () = re_fsearch ("^ *[0-9]");
   bol;
   if (nlines)
     recenter(nlines+2);
}

static define prev()
{
   if (nlines)
     ()=bol_bsearch("---");
   bol;
   () = re_bsearch ("^ *[0-9]");
   if (nlines)
     {
	if(bol_bsearch("---"))
	  {
	     () = re_fsearch ("^ *[0-9]");
	     recenter(nlines+2);
	  }
     }
}

%}}}
%{{{ jumping to the match

static define occur_goto_line()
{
   if (mbuffers)
     obuf = get_buffer_name();
   !if (bufferp (obuf))
     return vmessage("buffer: <%s> doesn't exist anymore", obuf);
   push_spot ();
   if (nlines)
     {
	% goto nearest of separator or matching line
	eol ();
	push_spot;
	!if (bol_bsearch ("---")) bob;
	push_mark; pop_spot;
	!if(re_bsearch ("^ *[0-9]+:")) bob;
	check_region(0);
	pop_mark_0;
     }
   bol;
   if (re_fsearch ("^ *\\([0-9]+\\):"))
     integer(regexp_nth_match(1));
   else
     return pop_spot;

.   pop_spot  obuf pop2buf  goto_line
}

static define occur_pop_to_line()
{
   occur_goto_line();
   pop2buf(buf);
}

%}}}
%{{{ scrolling the other window

static define scroll()
{
   !if (bufferp (obuf)) return;
   pop2buf (obuf);
   call("page_down");
   pop2buf (buf);
}

static define scroll_up()
{
   !if (bufferp (obuf)) return;
   pop2buf (obuf);
   call("page_up");
   pop2buf (buf);
}

%}}}
%{{{ syntax table
create_syntax_table($1);
#ifdef HAS_DFA_SYNTAX
dfa_enable_highlight_cache ("occur.dfa",$1);
dfa_define_highlight_rule("^Buffer", "keyword0", $1);
dfa_define_highlight_rule("^-+$", "keyword1", $1);
dfa_define_highlight_rule("^ *[0-9]+", "number", $1);
dfa_define_highlight_rule(":.*$", "normal", $1);
dfa_build_highlight_table($1);
enable_dfa_syntax_for_mode("occur");
#endif
%}}}

%!%+
%\function{occur_mode}
%\synopsis{mode of the *occur* buffer}
%\usage{occur_mode()}
%\description
%   Mode of the \var{*occur*} buffer.  The following keys are defined:
%   \var{RET}	go to the source buffer and visit the line
%               this entry points to
%   \var{TAB}	Visit this line, but stay in the \var{*occur*} buffer
%   \var{n}	Next entry
%   \var{p}	Previous entry
%   \var{SPC}	Scroll source buffer down
%   \var{DEL}	Scroll backward in the source buffer.
%\seealso{occur, moccur}
%!%-
public define occur_mode()
{
   use_keymap ("Occur");
   set_mode ("occur", 0);
   use_syntax_table("Occur");
#ifexists _slang_utf8_ok
   _set_buffer_flag(0x1000);
#endif
   set_buffer_hook ("newline_indent_hook", &occur_goto_line);
   set_help_message("RET:goto match  TAB:popup match  n:next  p:prev  SPC: scroll source buffer");
   run_mode_hooks ("occur_mode_hook");
}

%}}}

%{{{ search a buffer

% This is complicated, but it should always highlight the correct part of the line
% even when doing a case insensitive or anchored regexp search.
static define search_buffer(obuf, str)
{
   if (buf == obuf) return;
   if (andelse {mbuffers}{is_substr("* ", obuf[[0]])}) return;
   variable n, line;
   setbuf(obuf);
   push_spot_bob ();
   variable this_line, next_line, match_len;

   match_len = re_fsearch (str);
   !if (match_len) return pop_spot;
#ifexists _slang_utf8_ok
   push_spot;
#endif
   this_line = what_line();
   matches_flag=1;
   setbuf (buf);
   !if (bobp) newline;
   vinsert("Buffer: %s\n", obuf);
   if (nlines) insert ("------\n");
   setbuf (obuf);
   
   %%% get line and context
   variable c; % context
   variable sd = _stkdepth;
   variable beg, len;
   USER_BLOCK0 
     {
#ifexists _slang_utf8_ok
.	""
.	bol push_mark pop_spot
.	bufsubstr
.	push_mark
.	match_len 1 - go_right
.	match_marker
.	bufsubstr
.	"\e[0]"
.	push_mark_eol
.	bufsubstr
.	5 create_delimited_string
#else
.       line_as_string
#endif
     }
   while (this_line)
     {
	% before
	n = up (nlines);
	loop (n)
	  {
.	     empty  line_as_string  go_down_1
	  }
	% line
	sprintf(line_number_format, this_line); X_USER_BLOCK0; ++n;
	% if context overlaps with next line, merge
	forever
	  {
	     go_down_1;
	     match_len = re_fsearch (str);
	     !if (match_len)
	       {
		  next_line=0;
		  goto_line(this_line);
		  break;
	       }
#ifexists _slang_utf8_ok
	     push_spot;
#endif	  
	     next_line=what_line();
	     if (next_line - this_line > 2 * nlines)
	       {
		  goto_line(this_line);
		  break;
	       }
	     goto_line(this_line +1);
	     loop(next_line - this_line - 1)
	       { 
.		  empty  line_as_string    go_down_1 ++n
	       }
	     this_line = what_line();
	     sprintf(line_number_format, this_line); X_USER_BLOCK0; ++n;
	  }
	
		  
	% after
	loop (nlines)
	  {
	     !if(down_1) break;
.	     empty  line_as_string ++n
	  }


	_stk_reverse (_stkdepth-sd);
	
	%%% insert in the *occur* buffer
	setbuf (buf);

	loop (n)
	  {
	     insert ();
	     insert ();
	     newline ();
	  }

	if (nlines) insert ("------\n");

	setbuf (obuf);
	this_line=next_line;
	goto_line(this_line);
     }
   pop_spot ();
}

%}}}

%{{{ occur

%!%+
%\function{occur}
%\synopsis{occur}
%\usage{Void occur ([regexp, nlines]);}
%\description
%  This function may be used to search for all occurrences of a string in
%  the current buffer.  Without arguments, it prompts for a string to search
%  for, defaulting to the word at point.  It creates a separate buffer called
%  \var{*occur*} and associates a keymap called \var{Occur} with the new
%  buffer.  In this buffer, the \var{g} and \var{enter} key may be used to go
%  to the line described by the match.
%
%  Each line is displayed with \var{nlines} lines before and after.
%  \var{Nlines} defaults to \var{Occur_Context}.  Interactively it is the
%  prefix arg.
%\seealso{occur_mode, moccur}
%!%-
public define occur()
{
   variable str, n;

   (str, nlines) = push_defaults (, Occur_Context, _NARGS);
   if (str == NULL)
     {
	nlines = prefix_argument (nlines);
	str = read_mini ("Find All (Regexp):", get_word (), Null_String);
     }
   
   if (whatbuf() == buf)
     {
	if (mbuffers)
	  obuf = get_buffer_name();
	% else obuf = previous obuf
     }
   else obuf = whatbuf ();
   mbuffers=0;
   setbuf (buf);
   erase_buffer ();
   matches_flag=0;
   search_buffer(obuf, str);
   setbuf (buf);
   set_buffer_modified_flag (0);
   !if (matches_flag)
     {
	message ("no matches");
	return;
     }

   popup_buffer (buf);
   bob ();

   occur_mode();
}

%}}}

%{{{ moccur
static define get_buffer_name()
{
   push_spot();
   eol();
   !if (bol_bsearch("Buffer: "))
     error("What did you do with the header?!");
   ()=ffind_char(' ');
.  go_right_1  push_mark_eol  bufsubstr  pop_spot
}

%!%+
%\function{moccur}
%\synopsis{occur multiple buffers}
%\usage{moccur([regexp, nlines])}
%\description
%   This function may be used to search for all occurrences of a string in
%   all buffers except those whose names start with "*" or " ".  Otherwise
%   it works pretty much like \var{occur}
%\seealso{occur, occur_mode}
%!%-
public define moccur()
{
   variable str, n;

   (str, nlines) = push_defaults (, Occur_Context, _NARGS);
   if (str == NULL)
     {
	nlines = prefix_argument (nlines);
	str = read_mini ("Find All (Regexp):", get_word (), Null_String);
     }
   mbuffers=1;

   setbuf(buf);
   erase_buffer ();
   matches_flag=0;

   loop(buffer_list())
     search_buffer(str);
   setbuf (buf);
   set_buffer_modified_flag (0);
   !if (matches_flag)
     return message ("no matches");

   popup_buffer (buf);
   bob ();

   occur_mode();
}

%}}}
