% keywords.sl
% 
% @author: Marko Mahnic  <marko.mahnic@...si>
% @version: 1.0
% @created: 2004-07-29
% 
% A set of macros to make lists of keywords for language modes more manageable.
% 
% Create keyword lists to be used in define_keywords_n.
% You can add keywords to the keyword lists in multiple
% steps. Keywords are separated by whitespace.
% You can mix words of different sizes. The sort order of
% keywords is not important.
%
% Very helpful when you define syntaxes for similar languages or language variants.
% (SQL: sql92, postgresql, mysql, oracle, mssql; some keywords are
% the same in all variants, but some are dbms-specific)
% 
% Remark:
%   Use of this system is slower than use of define_keywords_n calls,
%   but the difference might be noticeable only when first using a
%   mode in a session.
%   You can also use write_keywords to prepare a list of define_keywords_n
%   call.
%   
% Installation:
%   Put the file somewhere on your jed_library_path. 
%   See keywords_sl.html
% 
  
implements("keywords");

static variable languages = ".";

% Check if keywords for a language have already been defined
define check_language (langId)
{
   variable lng = "." + langId + ".";
   !if (is_substr (languages, lng)) return 0;
   return 1;
}

define add_language (langId)
{
   languages = languages + langId + ".";
}

% Extend the array A to a minimum of minsize elements
% If the array is extended, its size is a multiple of 8.
static define extend_array (A, minsize)
{
   variable round = 8;
   % if (_NARGS == 3) round = int( () );
   % if (round < 2) round = 2;
   
   variable asize = ((int(minsize) / round) + 1) * round;
   if (length(A) < asize)
   {
      variable B, i;
      B = @Array_Type(_typeof(A), asize);
      
      for (i = length(A) - 1; i >= 0; i--) B[i] = A[i];
      for (i = length(A); i < asize ; i++) B[i] = "";
      
      return B;
   }
   
   return A;
}

typedef struct
{
   keywords
} _KeywordList_Type;

% Create a new structure to hold the keywords.
% The structure is an array of strings. Each string is a list of 
% space delimited keywords of the same length.
define new_keyword_list ()
{
   variable i, a;
   a = @_KeywordList_Type;
   a.keywords = @Array_Type(String_Type, 1);

   a.keywords[0] = "";
   
   return a;
}

% Add new keywords to the corresponding lists.
% The lists are not sorted.
define add_keywords (kwdlst, strKeywords)
{
   variable akwd = strtok(strKeywords);
   variable n, i, s;
   
   n = length(akwd);
   for (i = 0; i < n; i++)
   {
      s = strlen(akwd[i]);
      if (s < 1) continue;
      if (s >= length(kwdlst.keywords))
         kwdlst.keywords = extend_array(kwdlst.keywords, s);

      kwdlst.keywords[s-1] = kwdlst.keywords[s-1] + " " + akwd[i];
   }
}

% Sort all keyword lists.
define sort_keywords (kwdlst)
{
   variable i;
   for (i = length(kwdlst.keywords) - 1; i >= 0; i--)
   {
      if (kwdlst.keywords[i] != "")
      {
         variable akwd = strtok(kwdlst.keywords[i]);
         variable II = array_sort(akwd);
         akwd = akwd[II];
      
         kwdlst.keywords[i] = strjoin(akwd, " ");
      }
   }
}

% Convert all keywords to lower case - for case insensitive syntaxes
define strlow_keywords (kwdlst)
{
   variable i;
   for (i = length(kwdlst.keywords) - 1; i >= 0; i--)
   {
      if (kwdlst.keywords[i] != "")
      {
         kwdlst.keywords[i] = strlow(kwdlst.keywords[i]);
      }
   }
}


% Merge two structures into a third one and return it.
define merge_keywords (akwd, bkwd)
{
   variable i, mrg;
   if (length(akwd.keywords) > length(bkwd.keywords))
   {
      mrg = akwd;
      for (i = length(bkwd.keywords) - 1; i >= 0; i--)
         add_keywords(mrg, bkwd.keywords[i]);
   }
   else
   {
      mrg = bkwd;
      for (i = length(akwd.keywords) - 1; i >= 0; i--)
         add_keywords(mrg, akwd.keywords[i]);
   }
    
   return mrg;
}

% Call define_keywords_n for each list in the structure.
define define_keywords (kwdlst, strTable, colorN)
{
   variable i;
   for (i = length(kwdlst.keywords) - 1; i >= 0 ; i--)
   {
      variable wrds = str_delete_chars(kwdlst.keywords[i], " ");
      if (wrds == "") continue;
      () = define_keywords_n (strTable, wrds, i + 1, colorN);
   }
}

% insert define_keywords_n calls into buffer buf.
define write_keywords (kwdlst, strTable, colorN, buf)
{
   if (buf != NULL) setbuf(buf);
   !if (bolp())
   {
      eol();
      insert("\n");
   }
   
   variable i;
   for (i = 0; i < length(kwdlst.keywords); i++)
   {
      variable wrds = str_delete_chars(kwdlst.keywords[i], " ");
      if (wrds == "") continue;
      vinsert("() = define_keywords_n (\"%s\", ", strTable);
      vinsert("\"%s\"", wrds);
      vinsert(", %d, %d);\n", i + 1, colorN);
   }
}

provide("keywords");
