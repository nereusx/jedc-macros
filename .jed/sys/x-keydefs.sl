% x-keydefs.sl: Extended set of key variables
% *******************************************
%
%   * add key definitions
%     (Key_Esc, Key_Alt, Key_*_Return, Key_*_Tab, Key_KP_*)
%   * On xjed, call x_set_keysym for "special_keys"
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Versions
% ========
%
% 1.1   2004-12-01  first public version
% 1.2   2004-12-03  merged files x-keydefs.sl and x-keysyms.sl
%                   with call to x_keydefs_hook for customization
% 1.3   2005-09-20  set Key_Alt_* in a loop
% 1.4   2005-10-12  (re) use the definitions in standard keydefs.sl,
%                   let it work on "non-X" jed versions
% 1.5               prepare IBMPC support (incomplete, untested)
%                   set Key_Shift_Tab for xjed
% 1.5.1 2005-11-21  documentation fix (autoload get_keystring from strutils)
% 1.5.2 2006-01-17  documentation fix (warn about ESC redefinition, workaround)
% 1.5.3 2006-01-17  jed compatible default for Key_Esc ("\e" not "\e\e\e")
% 1.5.4 2006-01-18  added termcap entries for keypad keys (where possible)
% 1.5.5 2006-01-19  updated the IBMPC definitions (not fully tested yet)
% 1.5.6 2006-01-20  changed back IBMPC for Key_Alt_Return after report by
%                   M Mahnic that it works in wjed. (it will not harm in DOS
%                   or jed in a DOS window).
% 1.6   2006-03-29  renamed KP_Return to KP_Enter (Thei Wejnen)
% 1.6.1 2007-07-25  renamed set_keyvar() to _keystr()
% 1.7   2008-01-04  bugfix: set default for Key_Esc to "\e\e\e" 
% 		    (triple escape) this is:
% 		      + compatible with cuamisc.sl and cua.sl
% 		      + save (a lot of keys emit "\e" and some "\e\e" as 
% 		        leading part of their keystring).
% 		    In xjed, pressing [Esc] will emit Key_Escape. In
% 		    (non-x) jed, distinguishing these is tricky but can
% 		    be achieved with cua_one_press_escape() from cuamisc.sl
% 1.7.1 2008-01-07  do not change the keystring of the [Esc] key to Key_Escape
% 		    as this breaks compatibility in non-CUA emulation modes. 
% 		    (See cuamisc.sl for functions and documentation to 
% 		    configure it for other modes.)
%       
% Usage
% =====
%
% Place in the jed library path.
%
% Do not byte-compile, if you plan to use this file for both, Unix and
% DOS/Windows from one libdir! Byte compiling is OK for xjed and jed on a
% console or terminal emulator.
%
% To make the Key_Vars available, write (e.g. in your jed.rc or .jedrc file)
%
%    require("x-keydefs");
% 
% x-keydefs in turn do require("keydefs"), so the full set of key variables
% is available.
%
% !! Attention !!
% 
%   On xjed, `x_set_keysym' is used to make sure the keys send the
%   strings as defined here (or in the x_keydefs_hook() described below).
%   
%   While generally this leads to the expected behaviour with a
%   simple  require("x-keydefs"), some modes that define keybindings
%   without use of Key_* variables may break.
% 
% Customisation and Extension
% ===========================
%
% If you want to use alternative key strings, define x_keydefs_hook(). e.g.
% ::
% 
%    define x_keydefs_hook()
%    {
%       % Alternative keystring values:
%       Key_Return = "\e[8~";
%       Key_BS     = "\e[16~";
%       Key_Tab    = "\e[z";
%       % new definitions:
%       global variable Key_Shift_Ctrl_Right = "\e[^c"
%    }
%
% In xjed, additional bindings can be enabled with x_set_keysym():
%
% Get the keysyms from the file keysymdef.h or the Jed variable X_LAST_KEYSYM
% e.g. with::
% 
%  autoload("get_keystring", "strutils");  % from jedmodes.sf.net
%  public define showkey_literal()
%  {
%     flush ("Press key:");
%     variable key = get_keystring();
%     if (prefix_argument(0))
%       insert (key);
%     else
%       {
%  #ifdef XWINDOWS
%         key += sprintf(" X-Keysym: %X", X_LAST_KEYSYM);
%  #endif
%         message ("Key sends " + key);
%       }
%  }
%
% Attention: In JED <= 99.16, x_set_keysym() works only for keysyms in the
%            range `0xFF00' to `0xFFFF'. Since JED 99.17 this restriction is
%            gone.
%
% Shift-Tab on X-Windows
% ----------------------
%
% Unfortunately, Shift-Tab doesnot send any keystring in most X-Window setups
% as it is bound to "ISO_Left_Tab", Keysym 0xFE20
%
% This is fixed by x-keydefs using x_set_keysym().
% 
% For jed < 99.17, x_set_keysym() does not work for Shift-Tab. A line
%      keycode 23 = Tab
% in ~/.Xmodmap can cure this problem. However, this doesnot work
% with the XKB keyboard driver
%
%
% TODO: test IBMPC keystrings, 
%       find keystrings for Ctrl-Shift Movement keys

% Definitions
% ===========

% make sure we have the basic definitions loaded:
require("keydefs");

provide("x-keydefs");  % eXtended set of key definitions

% Auxiliary function to define symbolic keynames to count for different
% operating systems. (Extended version of the auxiliary fun in keydefs.sl
% including the ibmpc string.)
private variable Is_Xjed = is_defined("x_server_vendor");
static define _keystr(ibmpc, termcap, default)
{
#ifdef IBMPC_SYSTEM
   return ibmpc;
#endif
   if (Is_Xjed)
     return default;
#ifexists get_termcap_string
   variable s = get_termcap_string(termcap);
   if (s == "")
     return default;
   return s;
#else
   return default;
#endif
}

#ifdef Test
putenv("TERM=foo");
vmessage("TERM is '%s'", getenv("TERM"));
show("Key_Up", get_termcap_string("ku"));
show("Key_Shift_Tab", get_termcap_string("bt"));
#endif

variable Key_Ctrl_Shift_C       = "\eAc";
variable Key_Ctrl_Shift_V       = "\eAv";
variable Key_Ctrl_Shift_X       = "\eAx";

% Numeric Keypad
% --------------

% * variable names are chosen to match X-Window's keysymdef.h
% 
% * default strings as in rxvt without active Num Lock
%   and in X-Windows (where Num Lock only affects the string sent by [,|Del])
%   
% * By default, KP_Divide, KP_Multiply, and KP_Add send "/", "*", and "+" in 
%   xjed (their keysym does not change with Num Lock). 
%   x-keydefs.sl uses x_set_keysym to change this to the variables values
%   (therefore you should use the x_keydefs_hook() to change the value so xjed 
%   will see the changes)
% 
% * ibmpc strings correspond to VT220 codes
% 
% TODO: check IBMPC keystrings, if different use _keystr()

variable Key_KP_Enter    = "\eOM";
variable Key_KP_Divide    = _keystr("\eOQ", "", "\eOo"); 
variable Key_KP_Multiply  = _keystr("\eOR", "", "\eOj"); 
variable Key_KP_Add       = _keystr("\eOm", "", "\eOk"); 
variable Key_KP_Subtract  = _keystr("\eOS", "", "\eOm"); 
variable Key_KP_Separator = "\eOl";  % Key [./Del] with Num Lock in Xjed
variable Key_KP_Delete    = "\eOn";  % Key [./Del] without Num Lock in Xjed

variable Key_KP_0         = "\eOp";
variable Key_KP_1         = _keystr("\eOq", "K4", "\eOq");
variable Key_KP_2         = "\eOr";
variable Key_KP_3         = _keystr("\eOs", "K5", "\eOs");
variable Key_KP_4         = "\eOt";
variable Key_KP_5         = _keystr("\eOu", "K2", "\eOu");
variable Key_KP_6         = "\eOv";
variable Key_KP_7         = _keystr("\eOw", "K1", "\eOw");
variable Key_KP_8         = "\eOx";
variable Key_KP_9         = _keystr("\eOy", "K3", "\eOy");

% Alt and Escape
% --------------

% (Some jed versions (console) don' set ALT_CHAR)
custom_variable("ALT_CHAR", 27); % '\e'

variable Key_Alt          = _keystr("", "", char(ALT_CHAR));

% see also cuamisc.sl
custom_variable("Key_Esc", _keystr("", "", "\e\e\e"));

% Tab
% ---

variable Key_Tab          = _keystr("^I", "", "^I");    % alternative "\e[z"
variable Key_Shift_Tab    = _keystr("^@^O", "", "\e[Z");  % reverse_tab
variable Key_Ctrl_Tab     = _keystr("", "", "\e[^Z");
variable Key_Alt_Tab      = _keystr("", "", strcat(Key_Alt, Key_Tab));

% Return
% ------

variable Key_Return       = _keystr("^M", "", "^M");    % alternative "\e[8~"
variable Key_Shift_Return = _keystr("", "", "\e[8$");
variable Key_Ctrl_Return  = _keystr("^J", "", "\e[8^");
variable Key_Alt_Return   = strcat(Key_Alt, Key_Return);


% Shift-Control Movement Keys
% ---------------------------

% TODO: find keystrings
% variable Key_Ctrl_Shift_Up      = _keystr("", "", "\e[%A");
% variable Key_Ctrl_Shift_Down    = _keystr("", "", "\e[%B");
% variable Key_Ctrl_Shift_Right   = _keystr("", "", "\e[%C");
% variable Key_Ctrl_Shift_Left    = _keystr("", "", "\e[%D");
variable Key_Ctrl_Shift_Home    = _keystr("", "", "\e[1%");
variable Key_Ctrl_Shift_End     = _keystr("", "", "\e[4%");
variable Key_Ctrl_Shift_PgUp    = _keystr("", "", "\e[5%");
variable Key_Ctrl_Shift_PgDn    = _keystr("", "", "\e[6%");


% Customziation by hook
% ---------------------

runhooks("x_keydefs_hook");

% abort here, if we are on DOS or Windows
#ifdef IBMPC_SYSTEM
#stop
#endif

% Additional keystrings with Xjed
% -------------------------------

% We need to trick the function check for non-X jed (we cannot use #ifdef
% XWINDOWS, as the byte-compiled file should be usable with jed on a console
% as well.)
private variable x_set_keysym_p = __get_reference("x_set_keysym");

if (is_defined("x_server_vendor"))
{
   % ESC already emits a recognized keystring ("\e"). As some users or
   % emulations prefer it this way (to use the ESC as a prefix key) changing
   % this to let the key ESC emit Key_Esc is left to the emulation or a users
   % jed.rc (see cuamisc.sl for more details).
   %@x_set_keysym_p(0xFF1B, 0,    Key_Esc);

   % DEL (see also .jedrc for this topic)
   % (on my system it did not distinguish modifiers)
   @x_set_keysym_p(0xFFFF,  0,   Key_Del);
   @x_set_keysym_p(0xFFFF , '$', Key_Shift_Del);
   @x_set_keysym_p(0xFFFF , '^', Key_Ctrl_Del);

   % Backspace:
   @x_set_keysym_p(0xFF08 , 0,   Key_BS);
   @x_set_keysym_p(0xFF08 , '$', Key_Shift_BS);
   @x_set_keysym_p(0xFF08 , '^', Key_Ctrl_BS);

   % Return: (make it distinguishable from ^M)
   @x_set_keysym_p(0xFF0D , 0,   Key_Return);
   @x_set_keysym_p(0xFF0D , '^', Key_Ctrl_Return);
   @x_set_keysym_p(0xFF0D , '$', Key_Shift_Return);

   % TAB:
   @x_set_keysym_p(0xFF09 , 0,   Key_Tab);
   @x_set_keysym_p(0xFF09 , '^', Key_Ctrl_Tab);
#ifeval (_jed_version >= 9917)
   @x_set_keysym_p(0xFE20, '$',  Key_Shift_Tab);
#endif

   % numeric keypad (keys whose keysym do not change with Num Lock)
   @x_set_keysym_p(0xFFAA , 0,   Key_KP_Multiply);
   @x_set_keysym_p(0xFFAB , 0,   Key_KP_Add);
   @x_set_keysym_p(0xFFAF , 0,   Key_KP_Divide);

   % Shift-Control Movement Keys
   @x_set_keysym_p(0xFF50 , '%', Key_Ctrl_Shift_Home);
   % @x_set_keysym_p(0xFF51 , '%', Key_Ctrl_Shift_Left);
   % @x_set_keysym_p(0xFF52 , '%', Key_Ctrl_Shift_Up);
   % @x_set_keysym_p(0xFF53 , '%', Key_Ctrl_Shift_Right);
   % @x_set_keysym_p(0xFF54 , '%', Key_Ctrl_Shift_Down);
   @x_set_keysym_p(0xFF55 , '%', Key_Ctrl_Shift_PgUp);   
   @x_set_keysym_p(0xFF56 , '%', Key_Ctrl_Shift_PgDn);           
   @x_set_keysym_p(0xFF57 , '%', Key_Ctrl_Shift_End);  

   @x_set_keysym_p(0xFF03 , '%', Key_Ctrl_Shift_C);
   @x_set_keysym_p(0xFF22 , '%', Key_Ctrl_Shift_V);
   @x_set_keysym_p(0xFF24 , '%', Key_Ctrl_Shift_X);
}
