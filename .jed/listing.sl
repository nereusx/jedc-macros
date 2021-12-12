% listing.sl: A list widget for modes like dired, grep, locate, ...
%
% Copyright © 2006 Dino Sangoi, Günter Milde
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version    0.1   Dino Sangoi   first version
% 	     0.9   Günter Milde
%                  * "outsourcing" of the linklist datatype
%                  * Tags list is now buffer-local
%            0.9.1 * Tags list implemented as array
%            0.9.2 * Use array_map for most mappings
%                  * introduced the scope-argument
%            0.9.3 * Mode menu, more keybindings
%                	* new functions: edit, listing_list_tags
%            0.9.4 * replaced use of obsolete function array_concat
%            0.9.5 * optional argument "default" for get_confirmation()
% 2004-02-05 0.9.6 * bugfix: listing_mode no longer tries to delete
%                    empty lines (P. Boekholt)
% 2005-03-31 1.9.7 * made slang-2 proof: A[[0:-2]] --> A[[:-2]]
% 2005-11-08 1.9.8 * changed _implements() to implements()
% 2005-11-23 1.9.9 * docu bugfix in listing_list_tags
% 2006-01-24 2.0   * new keybinding: Key_Return calls "listing_return_hook"
% 2006-02-03 2.1   * removed the "listing_return_hook" again, as
%    	     	     set_buffer_hook("newline_indent_hook", &my_return_hook);
%    	     	     can be used instead. (tip by Paul Boekholt)
% 2006-10-05 3.0   * use the new (SLang2) "list" datatype,
% 	     	     removed obsolete static functions get_tag() and
% 	     	     delete_tagged_lines()
% 2007-04-17 3.1   * removed the dired-style Key_BS binding (tag&up) as this
% 	     	     overrides the default (page_up) of the basic "view" mode
% 2007-04-19 3.1.1 * added a "Save Listing" entry to the mode menu
% 2009-02-16 3.1.2 * code cleanup
% 2009-12-08 3.1.3 * adapt to new require() syntax in Jed 0.99.19
% 2010-12-08       * list_concat() -> list_extend() (datutils 2.3)
%
% TODO:  * Shift-Click tags from point to Mousepoint
%          may be also: right-drag tags lines


% Requirements
% ------------
%
% * S-Lang >= 2.0 (introduces the List_Type datatype)
% * extensions from http://jedmodes.sf.net/

#if (_jed_version > 9918)
require("keydefs", "Global"); % from jed's standard library
require("view", "Global"); % readonly-keymap depends on bufutils.sl
#else
require("keydefs");
require("view");
#endif
autoload("list_extend", "datutils");  % >= 2.3
autoload("push_defaults", "sl_utils");

% --- name it
provide("listing");
provide("listing-list");
implements("listing");
private variable mode = "listing";

% --- Variables -------------------------------------------------------

custom_variable("ListingSelectColor", color_number("menu_selection"));
custom_variable("ListingMarkColor", color_number("region"));

% this one is for communication between different calls to
% get_confirmation
static variable Dont_Ask = 0;

% --- Functions --------------------------------------------------

% --- Helper Functions (static)

% helper function: just return the arguments
static define null_fun() { }

%!%+
%\function{get_confirmation}
%\synopsis{Ask whether a list of actions should go on}
%\usage{Int  listing->get_confirmation(Str prompt, Str default="")}
%\description
%   If an action (e.g. deleting) on tagged lines needs a user confirmation,
%   the function in question can use get_confirmation(prompt) instead of
%   get_y_or_n(prompt) to offer more choices. The keybindings are a subset
%   from jed's replace command:
%        y: yes,   return 1
%        n: no,    return 0
%        !: all,   return 1, set Dont_Ask
%        q: quit,  throw UserBreakError
%   and also
%        r: recenter window, ask again
%   Return: enter, default action if \var{default} == "y" or "n".
%\notes
%   The static variable listing->Dont_Ask saves the "!: all" decision (so
%   the next invocation of get_confirmation doesnot ask but returns always
%   1.) The function that starts the mapping of the action on the list must
%   reset listing->Dont_Ask to 0. (\sfun{listing_map} does this, so it is
%   save to use \sfun{get_confirmation} in a function that gets called from
%   \sfun{listing_map}.)
%\seealso{listing_map, get_y_or_n}
%!%-
static define get_confirmation() % (prompt, [default])
{
   variable key, prompt, default;
   (prompt, default) = push_defaults( , "", _NARGS);

   if (Dont_Ask == 1)
     return 1;

   flush(prompt + " (y/n/!/q): " + default);
   loop(3)
     {
	key = getkey();
	if (key == '\r')
	  key = default[0];
	switch(key)
	  { case 'y' : return 1; }
	  { case 'n' : return 0; }
	  { case '!' : Dont_Ask = 1; return 1; }
	  { case 'q' or case '\e': throw UserBreakError, "Quit"; }
	  { case 'r' : recenter (window_info('r') / 2); }
	  { flush(prompt + " y:yes n:no !:yes to all q:quit r:recenter"); }
     }
   throw UserBreakError, "3x wrong key";
}

%!%+
%\function{tags_length}
%\synopsis{Return the number of tagged lines.}
%\usage{Int tags_length(scope=2)}
%\description
%  Return the number of tagged lines, considering scope.
%  For a discussion of the scope parameter see \var{listing_map}
%\seealso{listing_map, listing_mode, list_tags}
%!%-
static define tags_length() % (scope=2)
{
   variable scope = push_defaults(2, _NARGS);
   variable taglength = length(get_blocal_var("Tags"));
   switch (scope)
     { case 0: return 1; }                       % 0 current line
     { case 1 and taglength: return taglength; } % 1 tagged lines
     { case 1 and not(taglength): return 1; }	 %   or current line, if no line is tagged.
     { case 2: return taglength; }	    	 % 2 tagged lines
}

% find out if the current line is tagged.
% If so, return the index of the mark + 1, else return 0
static define line_is_tagged()
{
   variable tag_mark, n = 1;
   variable line = what_line();

   push_spot();   % remember position
   foreach tag_mark (get_blocal_var("Tags"))
     {
	goto_user_mark(tag_mark); % only way to find out mark.line
	if (line == what_line())
	  {
	     pop_spot();
	     return(n);
	  }
	n++;
     }
   pop_spot();
   return(0);
}

%!%+
%\function{tag}
%\synopsis{Mark the current line and append to the Tags list}
%\usage{Void tag(how = 1)}
%\description
%  Tag/untag the current line according to the (optional) argument how:
%     0 untag,
%     1 tag (default),
%     2 toggle
%\seealso{listing_mode, listing_map}
%!%-
static define tag() % (how = 1)
{
   variable how = push_defaults(1, _NARGS);

   variable tags = get_blocal_var("Tags");
   % see whether the line is already tagged
   variable is_tagged = line_is_tagged();
   % toggle: change the tag status
   if (how == 2)
     how = not(is_tagged);
   % already as we wish it
   if (how == (is_tagged > 0))
     return;

   if (how) % tag
     list_append(tags, create_line_mark(ListingMarkColor), -1);
   else % untag
     list_delete(tags, is_tagged-1);
}

%!%+
%\function{tag_all}
%\synopsis{(Un)Tag all lines}
%\usage{Void tag_all(how = 1)}
%\description
%  Tag/untag all lines according to the (optional) argument how.
%\seealso{tag, listing_mode, listing_map}
%!%-
static define tag_all() % (how = 1)
{
   variable how = push_defaults(1, _NARGS);
   variable on_region = is_visible_mark();
   if(on_region)
     narrow();
   push_spot_bob();
   switch (how)
     { case 0:
        set_blocal_var({}, "Tags");
     }
     { case 1:
        variable tags = {};
        do
          list_append(tags, create_line_mark(ListingMarkColor), -1);
        while (down_1());
        set_blocal_var(tags, "Tags");
     }
     { case 2:
        do
          tag(how);
        while (down_1());
     }

   pop_spot();
   if (on_region)
     widen();
}

% Tag all lines that match a regex pattern
static define tag_matching() %(how)
{
   variable how = push_defaults(1, _NARGS);

   variable prompt = ["Untag", "Tag"][how==1] + " all lines containing regexp:";

   variable pat = read_mini(prompt, "", ".*");
   push_spot_bob();
   while (re_fsearch(pat) and not(eobp))
     {
	tag(how);
	eol();
	go_right_1();
     }
   pop_spot();
}

% Switch to normal editing mode (text_mode)
static define edit()
{
   set_readonly(0);
   set_blocal_var({}, "Tags"); % untag
   set_blocal_var(NULL, "Current_Line");  % remove highlight from current line
   text_mode();

%   set_status_line("", 0);
}

% --- Public Functions

%!%+
%\function{listing_map}
%\synopsis{Call a function for tagged lines.}
%\usage{Void listing_map(Int scope, Ref fun, [args])}
%\description
%  Call fun (given as reference) for marked lines, i.e. tagged lines or
%  the current line depending on the value of the first argument scope
%     0 current line
%     1 tagged lines or current line, if no line is tagged.
%     2 tagged lines
%  The function will receive the tagged line as String as first argument and
%  must return an integer, with the meaning:
%     0    leave tag
%     1    untag line
%     2	   delete line
%
%\seealso{listing_mode, tag, list_tags}
%!%-
public  define listing_map() % (scope, fun, [args])
{
   % get arguments
   variable scope, fun, args, buf = whatbuf();
   args = __pop_args(_NARGS - 2);
   (scope, fun) = ( , );

   variable tag, tags = (get_blocal_var("Tags")), newtags = {}, result;

   scope -= not(length(tags)); % -> if (scope <= 0) use current line

   % tag current line, if we are to use it
   if (scope <= 0)
     tags = {create_user_mark()};

   !if (length(tags))
     throw UsageError, "No tags set";

   % Reset the static variable used by get_confirmation()
   Dont_Ask = 0;

   % now do the actual mapping
   set_readonly(0);
   loop (length(tags))
     {
	tag = list_pop(tags);
	goto_user_mark(tag);
	if (is_line_hidden)
	  {
	     list_append(newtags, tag, -1);
	     continue;
	  }
	update(1);
	% show("calling", fun, tag);
	try
	  result = @fun(line_as_string(), __push_args(args));
	catch UserBreakError:
	  {
	     set_readonly(1);
	     set_buffer_modified_flag(0);
	     !if (scope <= 0) % not current line
	       {
		  list_append(newtags, tag, -1);
		  list_extend(newtags, tags);
		  set_blocal_var(newtags, "Tags");
	       }
	     throw UserBreakError, "Quit";
	  }
	switch (result)
	  { case 0: list_append(newtags, tag, -1); }
	  % { case 1: ;} % nothing to do
	  { case 2: setbuf(buf); delete_line(); }
     }
   set_readonly(1);
   set_buffer_modified_flag(0);
   % clean up
   !if (scope <= 0) % not current line (but tags)
     set_blocal_var(newtags, "Tags");
}

%!%+
%\function{listing_list_tags}
%\synopsis{Return an array of tagged lines.}
%\usage{Array[String] listing_list_tags(scope=2, untag=0)}
%\description
%  Return an array of tagged lines.
%  For a discussion of the \var{scope} and \var{untag} parameters
%  see \sfun{listing_map}
%\example
%  Pop up a listing and let the user select some items.
%#v+
% private define select_database_return_hook()
% {
%    variable database = listing_list_tags(1);
%    close_buffer();
%    return strjoin(database, ",");
% }
% define select_database()
% {
%    dictionary_list = shell_command(dict_cmd + " --dbs", 3);
%    popup_buffer("*dict database*");
%    insert(dictionary_list);
%    bob();
%    listing_mode();
%    set_buffer_hook("newline_indent_hook", &select_database_return_hook);
%    message("Select and press Return to apply");
%#v-
%\seealso{listing_map, listing_mode, tag, tags_length}
%!%-
public  define listing_list_tags() % (scope=2, untag=0)
{
   variable scope, untag;
   (scope, untag) = push_defaults(2, 0, _NARGS);

   return [listing_map(scope, &null_fun, untag)];
}

% ---- The listing mode ----------------------------------------------------

% Update hook to highlight current line.
static define listing_update_hook()
{
   move_user_mark(get_blocal_var("Current_Line"));
}

% --- Keybindings

!if (keymap_p(mode))
  copy_keymap(mode, "view");

definekey("listing->edit",              "e", mode);
definekey("listing->tag(2)",            "t", mode); % toggle tag
definekey("listing->tag(1); go_down_1", "d", mode); % dired-like
definekey("listing->tag(0); go_down_1", "u", mode); % untag (dired-like)
definekey("listing->tag_matching(1)",   "+", mode);
definekey("listing->tag_matching(0)",   "-", mode);
definekey("listing->tag_all(2)",        "*", mode); % toggle all tags
definekey("listing->tag_all(1)",        "a", mode);
definekey("listing->tag_all(0)",        "z", mode);
definekey("listing->tag_all(0)",        "\e\e\e",       mode); % "meta-escape"
definekey("listing->tag(2); go_down_1", Key_Ins,        mode); % MC like
% this overwrites the page-up binding of the view map:
% definekey("go_up_1; listing->tag(2)",   Key_BS,         mode); % Dired
definekey("listing->tag(2); go_down_1", Key_Shift_Down, mode); % CUA style
definekey("listing->tag(2); go_up_1",   Key_Shift_Up,   mode); % CUA style

% --- the mode dependend menu
static define listing_menu(menu)
{
   menu_append_item(menu, "&Tag/Untag",      "listing->tag(2)");
   menu_append_item(menu, "Tag &All", 	     "listing->tag_all(1)");
   menu_append_item(menu, "Untag A&ll",      "listing->tag_all(0)");
   menu_append_item(menu, "Tag &Matching",   "listing->tag_matching(1)");
   menu_append_item(menu, "&Untag Matching", "listing->tag_matching(0)");
   menu_append_item(menu, "&Invert Tags",    "listing->tag_all(2)");
   menu_append_item(menu, "&Edit Listing",   "listing->edit");
   % menu_append_item(menu, "&Save Listing",   "save_buffer_as");
   menu_append_item(menu, "&Quit",           "close_buffer");
}

public define listing_mode()
{
   set_buffer_modified_flag (0); % so delbuf does not ask whether to save
   set_readonly(1);
   set_mode(mode, 0);
   use_keymap(mode);
   mode_set_mode_info(mode, "init_mode_menu", &listing_menu);
   % TODO set_buffer_hook("mouse_2click", &listing_mouse_2click_hook);
   define_blocal_var("Current_Line", create_line_mark(ListingSelectColor));
   define_blocal_var("Tags", {}); % list of tagged lines
   set_buffer_hook("update_hook", &listing_update_hook); % mark current line
   run_mode_hooks(mode+"_mode_hook");
}
