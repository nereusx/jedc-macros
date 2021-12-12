%% -*- mode: slang; tab-width: 4; indent-style: tab; encoding: utf-8; -*-
%%
%%	OR (|) separated string list
%%
%%	Copyleft (c) 2016-17 Nicholas Christopoulos.
%%	Released under the terms of the GNU General Public License (ver. 3 or later)

%% returns non-zero if 'str' exists in 'list'
public define osl_isset(list, str) {
	variable e, a;
	a = strchop(list, '|', 0);
	foreach e ( a ) {
		if ( e == str )
			return 1;
		}
	return 0;
	}

%% OR (|) separated string list
%% sets a flag (str) in the 'list'
public define osl_set(list, str) {
	if ( strlen(@list) == 0 )
		@list = str;
	else {
		ifnot ( osl_isset(@list, str) )
			@list = @list + "|" + str;
		}
	}

%% OR (|) separated string list
%% removes a flag (str) from the 'list'
%% TODO: optimize, can be a lot faster
public define osl_unset(list, str) {
	if ( strlen(@list) ) {
		if ( osl_isset(@list, str) ) {
			variable e, a, newlist;
			newlist = "";
			a = strchop(@list, '|', 0);
			foreach e ( a ) {
				if ( e != str )
					osl_set(newlist, e);
				}
			@list = newlist;
			}
		}
	}

