% txtutils.sl: % Tools for text processing (marking, picking, formatting)
%
% Copyright (c) 2005 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% VERSIONS
%  2.0              * get_word(), bget_word() now "region aware"
%                   * new functions mark_line(), get_line(), autoinsert()
%                   * bugfix for indent_region_or_line() (used to leave stuff
%                     on stack)
%  2.1       	    * mark_word(), bmark_word() test for buffer local variable
%                    "Word_Chars" (using get_blocal from sl_utils.sl)
%  2.2   2003-11    * removed indent_region_or_line() (now in cuamisc.sl)
%                   * changed mark_/get_word: added 2nd opt arg skip
%                               -1 skip backward, if not in a word
%                                0 don't skip
%                                1 skip forward, if not in a word
%                    Attention: get_word now returns last word, if the point is
%                    just behind a word (that is the normal way jed treats
%                    word boundaries)
%  2.3   2004-11-24 * New function insert_markup(beg_tag, end_tag)
%  2.3.1 2005-05-26  bugfix: missing autoload (report PB)
%  2.3.2 2005-06-09 * reintroduced indent_region_or_line()
%  	 	      jed99-17's cuamisc.sl doesnot have it
%  2.3.3 2005-10-14 * added documentation
%  2.3.3 2005-11-21 * removed "public" from definitions of functions
%                     returning a value
%  2.4   2005-11-24 * new function local_word_chars() that also probes
%  	 	      mode_get_mode_info("word_chars")
%  	 	      new (optional) arg 'lines' for get_buffer()
%  2.5   2006-01-19 New functions mark_paragraph(),
%  	 	    mark_paragraph_from_point(), format_paragraph_from_point()
%  2.6   2006-09-14 New function newline_indent() (fix pasting in x-terminal)
%  2.6.1 2006-10-04 fix spurious spot in indent_region_or_line()
%  2.6.2 2006-11-10 indent_region_or_line() did not indent a regions last line
%  2.6.3 2007-05-14 * documentation update
%  	 	    * insert_block_markup() inserts newline if region|word
%  	 	      doesnot start at bol
%  2.7   2007-12-11 * new function re_replace()
%  2.7.1 2008-02-25 * update help for newline_indent()
%  2.7.2 2009-01-26 * documentation example for re_replace() (M. Mahnič)

provide("txtutils");

% Requirements
% ------------

autoload("get_blocal", "sl_utils");
autoload("push_defaults", "sl_utils");

% Marking and Regions
% -------------------

%!%+
%\function{local_word_chars}
%\synopsis{Return the locally valid set of word chars}
%\usage{String local_word_chars()}
%\description
%  Returns the currently defined set of characters that constitute a word in
%  the local context: (in order of preference)
%
%    * the buffer local variable "Word_Chars"
%    * the mode-info field "word_chars" (with \sfun{mode_get_mode_info})
%    * the global definition (with \sfun{get_word_chars}).
%\example
%  Define a global set of word_chars with e.g.
%#v+
%  define_word("a-zA-Z")
%#v-
%  Define a mode-specific set of word_chars with e.g.
%#v+
%  mode_set_mode_info("word_chars", "a-zA-Z")
%#v-
%  Define a buffer-specific set of word_chars with e.g.
%#v+
%  define_blocal_var("word_chars", "a-zA-Z")
%#v-
%\seealso{}
%!%-
define local_word_chars()
{
   variable word_chars = get_blocal("Word_Chars");
   if (word_chars != NULL)
     return word_chars;
   word_chars = mode_get_mode_info("word_chars");
   if (word_chars != NULL)
     return word_chars;
   return get_word_chars();
}

%!%+
%\function{mark_word}
%\synopsis{Mark a word}
%\usage{ mark_word(word_chars=local_word_chars(), skip=0)}
%\description
% Mark a word as visible region.  Get the idea of the characters
% a word is made of from the optional argument \var{word_chars}
% or  \var{local_word_chars}.  The optional argument \var{skip} tells how to
% skip non-word characters:
%
%   -1 skip backward
%    0 don't skip (default)
%    1 skip forward
%
%\seealso{mark_line, get_word, define_word, define_blocal_var, push_visible_mark}
%!%-
public define mark_word() % (word_chars=local_word_chars(), skip=0)
{
   variable word_chars, skip;
   (word_chars, skip) = push_defaults( , 0, _NARGS);
   if (word_chars == NULL)
     word_chars = local_word_chars();
   switch (skip)
     { case -1: 
	   skip_chars(word_chars);
	   bskip_chars("^"+word_chars);
     }
     { case  1: 
	skip_chars("^"+word_chars);
	if(eolp()) {
	   push_visible_mark();
	   return;
	}
     }
   % Find word boundaries
   bskip_chars(word_chars);
   push_visible_mark();
   skip_chars(word_chars);
}

% % mark a word (skip forward if between two words)
% public define fmark_word() % fmark_word(word_chars=local_word_chars())
% {
%    variable args = __pop_args (_NARGS);
%    mark_word(__push_args(args), 1);
% }

% % mark a word (skip backward if not in a word)
% public define bmark_word () % (word_chars=local_word_chars())
% {
%    variable args = __pop_args (_NARGS);
%    mark_word(__push_args(args), -1);
% }

%!%+
%\function{get_word}
%\synopsis{Return the word at point as string}
%\usage{String get_word(word_chars=local_word_chars(), skip=0)}
%\description
%  Return the word at point (or a visible region) as string.
%
%  See \sfun{mark_word} for the "word finding algorithm"
%  and meaning of the optional arguments.
%\seealso{bget_word, mark_word, define_word, push_visible_mark}
%!%-
define get_word() % (word_chars=local_word_chars(), skip=0)
{
   % pass on optional arguments
   variable args = __pop_args(_NARGS);
   push_spot;
   !if (is_visible_mark)
     mark_word (__push_args(args));
   bufsubstr();
   pop_spot();
}

% % return the word at point as string (skip forward if between two words)
% public define fget_word() %  (word_chars=local_word_chars())
% {
%    variable word_chars = push_defaults( , _NARGS);
%    get_word(word_chars(args), 1);
% }

%!%+
%\function{bget_word}
%\synopsis{Return the word at point as string, skip back if not in a word}
%\usage{String get_word([String word_chars], skip=0)}
%\description
%  Return the word at point (or a visible region) as string.
%  Skip back over non-word characters when not in a word.
%  This is a shorthand for get_word(-1).
%  See \sfun{mark_word} for the "word finding algorithm"
%\seealso{get_word, mark_word, define_word}
%!%-
define bget_word() % (word_chars=local_word_chars())
{
   variable word_chars = push_defaults( , _NARGS);
   get_word(word_chars, -1);
}

%!%+
%\function{mark_line}
%\synopsis{Mark the current line}
%\usage{mark_line()}
%\description
%  Mark the current line as an invisible region
%\seealso{push_mark_eol}
%!%-
public define mark_line()
{
   bol();
   push_mark_eol();
}

%!%+
%\function{get_line}
%\synopsis{Return the current line as string}
%\usage{String get_line()}
%\description
%  Return the current line as string. In contrast to the standard
%  \sfun{line_as_string}, this keeps the point at place.
%\seealso{line_as_string, mark_line, bufsubstr}
%!%-
define get_line()
{
   push_spot();
   line_as_string();  % leave return value on stack
   pop_spot();
}

define mark_paragraph_from_point()
{
   push_visible_mark();
   forward_paragraph();
}

define mark_paragraph()
{
   backward_paragraph();
   mark_paragraph_from_point();
}

define format_paragraph_from_point()
{
   mark_paragraph_from_point();
   exchange_point_and_mark();
   narrow ();
   call ("format_paragraph");
   widen ();
}

%!%+
%\function{get_buffer}
%\synopsis{Return buffer as string}
%\usage{String get_buffer(kill=0, lines=0)}
%\description
%  Return buffer as string.
%  If a visible region is defined, return it instead.
%  If \var{kill} is not zero, the buffer/region will be deleted in the process.
%  If \var{lines} is not zero, whole lines will be returned
%\seealso{bufsubstr, push_visible_mark}
%!%-
define get_buffer() % (kill=0, lines=0)
{
   variable  str, kill, lines;
   (kill, lines) = push_defaults(0, 0, _NARGS);

   push_spot();
   !if(is_visible_mark())
     mark_buffer();
   else if (lines)
     {
	check_region(0);
	eol();
	go_right_1();
	exchange_point_and_mark();
	bol();
     }

   if (kill)
     str = bufsubstr_delete();
   else
     str = bufsubstr();
   pop_spot();
   return(str);
}

% Formatting
% ----------

%!%+
%\function{indent_region_or_line}
%\synopsis{Indent the current line or (if visible) the region}
%\usage{Void indent_region_or_line ()}
%\description
%   Call the indent_line_hook for every line in a region.
%   If no region is defined, call it for the current line.
%\seealso{indent_line, set_buffer_hook, is_visible_mark}
%!%-
public define indent_region_or_line()
{
   !if(is_visible_mark())
     {
	indent_line();
	return;
     }
   % narrow() doesnot work, as indent_line() needs the context!
   check_region(0);                  % make sure the mark comes first
   variable end_line = what_line();
   pop_mark_1(); % go there
   loop (end_line - what_line() + 1)
     {
	indent_line();
	go_down_1();
     }
}

%!%+
%\function{indent_buffer}
%\synopsis{Format a buffer with \sfun{indent_line}}
%\usage{indent_buffer()}
%\description
%  Call \sfun{indent_line} for all lines of a buffer.
%\seealso{indent_line, indent_region_or_line}
%!%-
public define indent_buffer()
{
   push_spot;
   bob;
   do
     indent_line;
   while (down_1);
   pop_spot;
}

%!%+
%\function{newline_indent}
%\synopsis{Correct mouse-pasting problem for for Jed in an x-terminal}
%\usage{newline_indent()}
%\description
%  Jed's default binding for the Return key is \sfun{newline_and_indent}. In
%  an x-terminal, this can result in a staircase effect when mulitple lines
%  are pasted with the mouse, as indentation is doubled.
%
%  As workaround, \sfun{newline_indent} guesses, whether the input comes from
%  the keyboard or the mouse and only indents in the first case.
%
%\example
%  Many editing modes (c_mode, slang_mode, perl_mode, php_mode, to name but a
%  few) bind the return key to newline_and_indent() in their local keymap.
%  Therefore you will need to change this binding in the global_mode_hook.
%
%  In your jed.rc, write e.g.
%#v+
%     #ifndef XWINDOWS IBMPC_SYSTEM
%     % Fix staircase effect with mouse-pasting in an x-terminal
%     setkey("newline_indent", "^M");
%     % Some modes overwrite the Key_Return binding. Restore it:
%     define global_mode_hook (hook)
%     {
%        if (wherefirst(what_keymap() == ["C", "DCL", "IDL", "perl", "PHP"])
%            != NULL)
%           local_setkey("newline_indent", "^M");
%     }
%     #endif
%#v-
%  or add the setkey() line to an already existing global_mode_hook()
%  definition.
%
%\notes
%  Jed receives its input as a sequence of characters and cannot easily tell
%  whether this input is generated by keypesses, pasting from the mouse or a
%  remote application.
%
%  \sfun{newline_indent} uses \sfun{input_pending} for the guessing:
%
%  In normal typing, jed can process a newline faster than the next char is
%  pressed. When pasting from the mouse, the pasted string goes to the
%  input buffer and is processed one character a time, thus pending input
%  indicates a paste operation.
%\seealso{newline, newline_and_indent, Help>Browse_Doc>hooks.txt}
%!%-
public define newline_indent()
{
  if (input_pending(0))
     newline();
  else
     call("newline_and_indent");
}

%!%+
%\function{number_lines}
%\synopsis{Insert line numbers}
%\usage{number_lines()}
%\description
%  Precede all lines in the buffer (or a visible region) with line numbers
%
%  The numbers are not just shown, but actually inserted into the buffer.
%\notes
%  Use \var{toggle_line_number_mode} (Buffers>Toggle>Line_Numbers) to show
%  line numbers without inserting them in the buffer.
%\seealso{set_line_number_mode, toggle_line_number_mode}
%!%-
define number_lines()
{
   variable visible_mark = is_visible_mark();
   push_spot;
   if(visible_mark)
     narrow;
   eob;
   variable i = 1,
     digits = strlen(string(what_line())),
     format = sprintf("%%%dd ", digits);
   bob;
   do
     { bol;
        insert(sprintf(format, i));
	i++;
     }
   while (down_1);
   if (visible_mark)
     widen;
   pop_spot;
}

%!%+
%\function{autoinsert}
%\synopsis{Auto insert text in a rectangle}
%\usage{autoinsert()}
%\description
% Insert the content of the first line into a rectangle defined by
% point and mark. This is somewhat similar to \sfun{open_rect} but for
% arbitrary content.
%
% If you have to fill out collumns with identical content, write the content
% in the first line, then mark the collumn and call \sfun{autoinsert}.
%\seealso{open_rect}
%!%-
public define autoinsert()
{
   () = dupmark();
   narrow;
   % get string to insert
   check_region(0);
   variable end_col = what_column();
   bob();
   goto_column(end_col);
   variable str = bufsubstr();
   variable beg_col = end_col - strlen(str);
   while (down_1)
     {
	goto_column(beg_col);
        insert(str);
     }
   widen;
}

%!%+
%\function{insert_markup}
%\synopsis{Insert markup around region or word}
%\usage{Void insert_markup(Str beg_tag, Str end_tag)}
%\description
%   Inserts beg_tag and end_tag around the region or current word.
%\example
%  Marking a region and
%#v+
%   insert_markup("<b>", "</b>");
%#v-
%  will highlight it as bold in html, while
%#v+
%   insert_markup("{\textbf{", "}");
%#v-
%  will do the same for LaTeX.
%\seealso{mark_word}
%!%-
define insert_markup(beg_tag, end_tag)
{
   !if (is_visible_mark)
     mark_word();
   variable region = bufsubstr_delete();
   insert(beg_tag + region + end_tag);
   % put cursor in the markup tags if the region is void
   if (region == "")
     go_left(strlen(end_tag));
}

%!%+
%\function{insert_block_markup}
%\synopsis{Insert markup around region and (re) indent}
%\usage{insert_block_markup(beg_tag, end_tag)}
%\description
%   Insert beg_tag and end_tag around the region or current word.
%   Insert a newline before the region|word if it is not the first non-white
%   token of the line.
%   Indent region or line (according to the mode's syntax rules).
%\seealso{insert_markup}
%!%-
define insert_block_markup(beg_tag, end_tag)
{
   !if (is_visible_mark)
     mark_word();
   () = dupmark();
   variable region = bufsubstr_delete();

   insert(beg_tag + region + end_tag);

   % insert newline if there is something except whitespace before the start
   % of the region
   exchange_point_and_mark();
   bskip_white();
   !if (bolp)
     newline();
   exchange_point_and_mark();
   indent_region_or_line();
   % put cursor inside the markup tags if the region is void
   if (region == "")
     go_left(strlen(end_tag));
}

%!%+
%\function{re_replace}
%\synopsis{Replace all occurences of regexp \var{pattern} with \var{rep}}
%\usage{re_replace(pattern, rep)}
%\description
%  Regexp equivalent to \sfun{replace}.
%  Replaces all occurences of of regexp \var{pattern} with \var{rep}
%  from current editing point to the end of the buffer. 
%  The editing point is returned to the initial location.
%  The regexp syntax is the same as in \sfun{re_fsearch}
%  (currently S-Lang regular expressions).
%\example
%  before: ad e cf
%#v+
%     re_replace ("\([abc]\)\([def]\)"R, "\0:\2\1"R)
%#v-
%  after: ad:da e cf:fc
%\seealso{replace, re_search_forward, str_re_replace, query_replace_match}
%!%-
define re_replace(pattern, rep)
{
   push_spot();
   while (re_fsearch(pattern)) {
      !if (replace_match(rep, 0))
	 error ("replace_match failed.");
   }
   pop_spot();
}
