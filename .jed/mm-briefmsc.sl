% utility functions used mostly in BRIEF mode
%
% 2007-02-11 Marko Mahnic
%   - moved all functions from brief.sl to briefmsc.sl
%
%	2016-10-13 Nicholas Christopoulos
%		+ on paste lines, cursor must be bellow the lines
%

provide("mm-briefmsc");

private variable Brief_HomeEnd_Count = 0;

% Move the cursor based on the count of succesive function invocation:
%   1: move to beginning of line
%   2: move to beginning of window
%   3: move to beginning of buffer
define brief_home ()
{
   if (LAST_KBD_COMMAND != "brief_home") {
      Brief_HomeEnd_Count = 0;
      bol ();
   }
   else {
      Brief_HomeEnd_Count++;
      
      switch (Brief_HomeEnd_Count)
	{case 1: goto_top_of_window (); }
	{case 2: bob (); }
	{bol (); }
   }
}

% Move the cursor based on the count of succesive function invocation:
%   1: move to end of line
%   2: move to end of window
%   3: move to end of buffer
define brief_end ()
{
   if (LAST_KBD_COMMAND != "brief_end") {
      Brief_HomeEnd_Count = 0;
      eol ();
   }
   else {
      Brief_HomeEnd_Count++;
      
      switch (Brief_HomeEnd_Count)
	{case 1: goto_bottom_of_window (); eol (); }
	{case 2: eob (); }
	{eol (); }
   }   
}

% Scroll current line to end of window
define brief_line_to_eow ()
{
   recenter (window_info ('r'));
}

% Scroll current line to beginning of window
define brief_line_to_bow ()
{
   recenter (1);
}

% Scroll current line to center of window
define brief_line_to_mow ()
{
   recenter (window_info ('r') / 2);
}

% Set bookmark number n
define brief_set_bkmrk_cmd (n)
{
   ungetkey (n + '0');
   bkmrk_set_mark ();
}

% Delete from current position to end of line
define brief_delete_to_bol ()
{
   push_mark ();
   bol();
   del_region ();
}

% Open  a blank  line below the current line 
define brief_open_line ()
{
   eol ();
   newline ();
   indent_line ();
}

private define onoff(val)
{ 
   if (val) return "on"; 
   else return "off";
}

% Toggle the case-sensitive search mode
define brief_toggle_case_search ()
{
   CASE_SEARCH = not (CASE_SEARCH);
   vmessage ("Case sensitive search is %s.", onoff(CASE_SEARCH));
}

variable Brief_Regexp_Search = 0;

% Toggle regular expression search
define brief_toggle_regexp ()
{
   Brief_Regexp_Search = not (Brief_Regexp_Search);
   vmessage ("Regular expression search is %s.", onoff(Brief_Regexp_Search));
}

variable Brief_Search_Forward = 1;

% The main search function
define brief_search_cmd ()
{
   if (Brief_Search_Forward) {
      if (Brief_Regexp_Search) re_search_forward ();
      else search_forward ();
   }
   else {
      if (Brief_Regexp_Search) re_search_backward ();
      else search_backward ();
   }
}

% Reverse the search direction and start the search
define brief_reverse_search ()
{
   Brief_Search_Forward = not (Brief_Search_Forward);
   brief_search_cmd ();
}

% The main replace function.
% When a region is marked the buffer is narrowed to the region
% before search/replace and widened afterwards.
define brief_replace_cmd()
{
   variable bWiden = 0;
   if (markp()) {
      push_spot ();
      narrow_to_region();
      bob();
      bWiden = 1;
   }
   if (Brief_Regexp_Search) query_replace_match ();
   else replace_cmd();
   
   if (bWiden) {
      widen_region ();
      pop_spot();
   }
}

%%  0 - No mark
%%  1 - Normal    3 - Line
%%  2 - Column    4 - Noninclusive
variable Brief_Mark_Type = 0;

#ifdef HAS_BLOCAL_VAR

private variable Brief_Scrap_Type = "Brief_Scrap_Type";
private define brief_get_scrap_type(scbuf)
{
   variable b, v = 1;
   !if (bufferp(scbuf)) return 1;
   b = whatbuf();
   setbuf(scbuf);
   if (blocal_var_exists(Brief_Scrap_Type))
      v = get_blocal_var(Brief_Scrap_Type);
   setbuf(b);
   return v;
}

private define brief_set_scrap_type(scbuf, sctype)
{
   variable b;
   !if (bufferp(scbuf)) return;
   b = whatbuf();
   setbuf(scbuf);
   create_blocal_var(Brief_Scrap_Type);
   set_blocal_var(sctype, Brief_Scrap_Type);
   setbuf(b);
}

#else

private variable Brief_Scrap_Type = 0;
private define brief_get_scrap_type(scbuf)
{
   return Brief_Scrap_Type;
}

private define brief_set_scrap_type(scbuf, sctype)
{
   Brief_Scrap_Type = sctype;
}

#endif %% HAS_BLOCAL_VAR

private variable Brief_Scrap_Buf_Format = " <scrap-%s>";
private define brief_get_scrap_name ()
{
   variable b, scrps;
   scrps = "";
   loop (buffer_list ())
   {
      b = ();
      if (1 == is_substr(b, " <scrap-"))
      {
         b = strtrim(b[[8:]], ">");
         if (scrps == "") scrps = b;
         else scrps = scrps + "," + b;
      }
   }
   variable name = read_with_completion (scrps, "Scrap name:", "", "", 's');
   name = strtrim (name);
   if (name == "") name = NULL;
   return name;
}

% Yanking whole lines from the pastebuffer
define brief_yank_lines ()
{
%   call ("mark_spot");
   bol (); 
   call ("yank"); 
%   pop_spot ();
}

% Select the yank mode based on the type of data stored
% in the pastebuffer.
define brief_yank ()
{
   switch (brief_get_scrap_type(" <paste>"))
     { case 2: insert_rect (); message ("Columns inserted."); }
     { case 3: brief_yank_lines (); message ("Lines inserted."); }
     { call ("yank"); message ("Scrap inserted.");}
}

% Select the yank mode based on the type of data stored
% in the named buffer.
define brief_yank_named ()
{
   variable sctype, scbuf, b;
   variable scrapname = brief_get_scrap_name();
   
   if (scrapname == NULL) return;
   scbuf = sprintf(Brief_Scrap_Buf_Format, scrapname);
   !if (bufferp(scbuf))
   {
      message ("No such scrap.");
      return;
   }
   b = whatbuf();
   
   sctype = brief_get_scrap_type(scbuf);
   if (sctype == 2) setbuf(" <rect>");
   else setbuf(" <paste>");
   erase_buffer();
   insbuf(scbuf);
   setbuf(b);

   switch (sctype)
     { case 2: insert_rect (); vmessage ("Columns from scrap '%s' inserted.", scrapname); }
     { case 3: brief_yank_lines (); vmessage ("Lines from scrap '%s' inserted.", scrapname);}
     { call ("yank"); vmessage ("Scrap '%s' inserted.", scrapname);}
}

% Prototype: brief_complete_line_region ()
% Makes a line region complete including whole first line
% and whole last line (with newline character).
define brief_complete_line_region ()
{
   check_region (0);           %% region is canonical
   exchange_point_and_mark (); %% mark entire first line
   bol ();
   check_region (0);
   eol();
   !if (eobp ()) {
      go_down_1 (); 
      bol ();
   }
}

% Check if a marked region exists. If it does not, mark the current line.
% Returns 1 if the region was automarked, 0 otherwise.
define brief_check_marked_automark ()
{
   if (markp() == 0) {                % not marked --> copy line
      if (eobp() and bolp()) return (0);
      set_mark_cmd ();
      Brief_Mark_Type = 3;
      return (1);
   }
   else if (Brief_Mark_Type == 0) {   % marked, but wrong type --> copy region
      Brief_Mark_Type = 1;
   }
   
   return (0);
}

private define brief_region_to_scrap(opinfo, macro, rectmacro, namedscrap)
{
   variable b, what = NULL;   

   if (brief_check_marked_automark()) what = "Line";
   
   if (Brief_Mark_Type == 2) {
      if (is_internal(rectmacro)) call (rectmacro);
      else eval(rectmacro);
      what = "Columns";
   }
   else if (Brief_Mark_Type == 3) {
      push_spot ();
      brief_complete_line_region ();
      if (is_internal(macro)) call (macro);
      else eval(macro);
      pop_spot ();
      if (what == NULL) what = "Lines";
   }
   else {
      if (is_internal(macro)) call (macro);
      else eval(macro);
      what = "Region";
   }
   
   if (namedscrap == NULL or namedscrap == "")
   {
      vmessage ("%s %s to scrap.", what, opinfo);
      brief_set_scrap_type(" <paste>", Brief_Mark_Type);
   }
   else
   {
      vmessage ("%s %s to scrap '%s'.", what, opinfo, namedscrap);
      
      b = whatbuf();
      what = sprintf(Brief_Scrap_Buf_Format, namedscrap);
      setbuf(what);
      erase_buffer();
      if (Brief_Mark_Type == 2) insbuf(" <rect>");
      else insbuf(" <paste>");
      brief_set_scrap_type(what, Brief_Mark_Type);
      setbuf(b);
   }
   
   Brief_Mark_Type = 0;
}

% Copy the region to pastebuffer based on current mark type (normal, lines, columns)
define brief_copy_region ()
{
   brief_region_to_scrap("copied", "copy_region", "copy_rect", NULL);
}

% Cut the region to pastebuffer based on current mark type (normal, lines, columns)
define brief_kill_region ()
{
   brief_region_to_scrap("cut", "kill_region", "kill_rect", NULL);
}

% Copy the region to a named buffer based on current mark type (normal, lines, columns)
define brief_copy_region_named ()
{
   variable name = brief_get_scrap_name();
   if (name != NULL)
      brief_region_to_scrap("copied", "copy_region", "copy_rect", name);
}

% Cut the region to a named buffer based on current mark type (normal, lines, columns)
define brief_kill_region_named ()
{
   variable name = brief_get_scrap_name();
   if (name != NULL)
      brief_region_to_scrap("cut", "kill_region", "kill_rect", name);
}

% Delete the next charactre.
% If a region is marked, delete it based on current mark type (normal, lines, columns)
define brief_delete ()
{
   if (markp ()) {
      if (Brief_Mark_Type == 2)  {
	 kill_rect ();
      } 
      else if (Brief_Mark_Type == 3) {
	 brief_complete_line_region ();
	 del_region ();
      }
      else {
	 del_region ();
      }
      Brief_Mark_Type = 0;
      return;
   }
   del ();
   Brief_Mark_Type = 0;
}

% int brief_unmark (int MarkType)
% If a region is marked and it is of type MarkType,
% the region is unmarked, 1 is returned. It returns
% 0 otherwise.
define brief_unmark (n)
{
   if (markp ()) {
      if (Brief_Mark_Type == n) {
	 smart_set_mark_cmd ();
	 message ("Mark unset");
	 Brief_Mark_Type = 0;
	 return (1);
      }
   }
   
   return (0);
}

% Start marking a region and set region type to Lines.
% If a region is already marked and is not of type Lines,
% change region type to Lines.
define brief_line_mark ()
{
   !if (brief_unmark (3)) {
      Brief_Mark_Type = 3;
      push_spot ();
      eol (); goto_column (what_column () / 2);
      set_mark_cmd ();
      pop_spot ();
      message ("Line mark set.");
   }
}

% void brief_set_mark_cmd (int MarkType)
define brief_set_mark_cmd (n)
{
   !if (brief_unmark (n)) {
      Brief_Mark_Type = n;
      if (Brief_Mark_Type == 1) {
	 set_mark_cmd ();
      }
      else {
	 smart_set_mark_cmd ();
      }
   }
}

% Start marking a region and set region type to Columns.
% If a region is already marked and is not of type Columns,
% change region type to Columns.
define brief_set_column_mark ()
{
   !if (brief_unmark (2)) {
      Brief_Mark_Type = 2;
      set_mark_cmd ();
      message ("Column mark set.");
   }
}

% Start macro recording. If recording is already in progress, stop recording.
define brief_record_kbdmacro ()
{
   if (DEFINING_MACRO) {
      call ("end_macro");
   }
   else !if (EXECUTING_MACRO or DEFINING_MACRO) {
      call ("begin_macro");
   }
}

% Prototype: brief_next_buffer (int direction)
% This function changes the current buffer depending on value of
% direction:
%    if direction >= 0 ==> next buffer
%    if direction  < 0 ==> prev buffer
% It skips system buffers and buffers with names beginning with '*'. 
define brief_next_buffer (direction)
{
   variable n, buf;
   
   if (MINIBUFFER_ACTIVE) return;

   n = buffer_list ();		       %/* buffers on stack */
   
   if (direction < 0) {
      _stk_roll (-n);
      pop ();
      n--;  
   }
   loop (n) {
      if (direction < 0) _stk_roll (-n);
      buf = ();
      n--;
      if (buf[0] == ' ') continue;
%      if (buf[0] == '*' and buf != "*scratch*") continue;
      if (buf[0] == '*') continue;
      sw2buf (buf);
      loop (n) pop ();
      return;
   }   
}

% int Brief_Last_Column
% Records the last column position before PageUp/PageDown commands.
% Used in brief_pageup () and brief_page_down () to restore the 
% column position after movement.
private variable Brief_Last_Column = 0;
private define brief_store_last_column ()
{
   if (LAST_KBD_COMMAND == "brief_pagedown" or
       LAST_KBD_COMMAND == "brief_pageup")
      return;
   Brief_Last_Column = what_column ();
}

% Prototype: brief_pageup ()
% Moves one page up leaving the cursor on the same position in the
% window.
define brief_pageup ()
{
   variable woffs;
   
   if (MINIBUFFER_ACTIVE) {
      call ("page_up");
      return;
   }
   brief_store_last_column ();
   woffs = window_line ();
   go_up (window_info ('r'));
   while (is_line_hidden() and not bobp()) go_up_1();
   recenter (woffs);
   () = goto_column_best_try (Brief_Last_Column);
}

% Prototype: brief_pagedown ()
% Moves one page down leaving the cursor on the same position in the
% window.
define brief_pagedown ()
{
   variable woffs;
     
   if (MINIBUFFER_ACTIVE) {
      call ("page_down");
      return;
   }
   brief_store_last_column ();
   woffs = window_line ();
   go_down (window_info ('r'));
   while (is_line_hidden() and not eobp()) go_down_1();
   recenter (woffs);   
   () = goto_column_best_try (Brief_Last_Column);   
}

% Prototype: brief_delete_buffer ()
% Deletes the current buffer if it is not the minibuffer.
define brief_delete_buffer ()
{
   if (MINIBUFFER_ACTIVE) return;
   delbuf (whatbuf ());
   brief_next_buffer (1);
}
