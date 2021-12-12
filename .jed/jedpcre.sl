% jedpcre.sl
% 
% $Id: jedpcre.sl,v 1.4 2008/10/21 18:48:25 paul Exp paul $
%
% Copyright (c) 2004-2008 Paul Boekholt.
% Released under the terms of the GNU GPL (version 2 or later).
% 
% This provides a pcre occur function.

provide("jedpcre");
require("pcre");
require("occur");  % this requires the occur from jedmodes.sf.net/mode/occur

%{{{ occur


public define pcre_occur()
{
   variable pat, str, tmp, n;
   if (_NARGS) pat = ();
   else
     pat = read_mini("Find All (Regexp):", LAST_SEARCH, Null_String);
   variable occur_re = pcre_compile(pat);
   tmp = "*occur*";
   occur->obuf = whatbuf();
   occur->nlines=0;
   occur->mbuffers=0;
   push_spot_bob;
   push_mark_eob;
   str = strchop(bufsubstr, '\n', 0);
   pop_spot;
   variable index = where(array_map(Integer_Type, &pcre_exec, occur_re, str));
   ifnot (length(index)) return message("no matches");
   pop2buf(tmp);
   erase_buffer();
   foreach n (index)
     {
	vinsert ("%*d: %s\n", occur->line_number_width, 1+n, str[n]);
     }
   bob(); set_buffer_modified_flag(0);
   occur_mode();
}


%}}}
