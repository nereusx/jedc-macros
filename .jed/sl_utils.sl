% Various programming utils that are used by most of my other modes.
%
% Copyright (c) 2006 Guenter Milde (milde users.sf.net)
% Released under the terms of the GNU General Public License (ver. 2 or later)
%
% Version    1.0   first public release
%            1.1   new: max(), contract_filename()
%            1.2   new: normalize_modename(), what_line_if_wide()
%            1.3   backwards compatibility: emulate run_program() if not
%                  existent (works only in xjed)
% 2004-03-22 1.3.1 bugfix in contract_filename() error if  HOME
%                  environment variable is missing (report Thomas Koeckritz)
%            1.3.2 removed max(), as it contradicts the intrinsic max()
%                  definition (which resembles array_max() from datutils.sl)
% 2005-04-11 1.4   new function prompt_for_argument()
%                  added provide("sl_utils")
%            1.5   new function _implements(): implement a "named" namespace
%                  but allow re-evaluation if `_debug_info` is TRUE
% 2005-05-23 1.5.1 bugfix in _implements(): separate _implement and provide,
%                  do not rely on _featurep()
% 2005-06-07 1.5.2 moved run_program emulation to compat16-15.sl
% 2005-10-05 1.5.3 Simplified _implements(). Developers working with SLang2 
%                  should switch to using the standard implements().
%                  (Normal users will will usually not re-evaluate.)
%            1.5.4 Documentation update for run_function mentioning call_function
%            1.5.5 Documentation fix for push_defaults()
% 2008-01-11 1.5.6 Documentation update for run_function() and get_blocal()

% _debug_info = 1;

provide("sl_utils");

%!%+
%\function{push_defaults}
%\synopsis{Push N args to the stack}
%\usage{(a_1, ..., a_N) = push_defaults(d_1, ..., d_N, N)}
%\description
% Push N args to the stack. Together with \var{_NARGS} this enables the
% definition of slang functions with optional arguments.
%\example
% A function with one compulsory and two optional arguments
%#v+
%   define fun() % (a1, a2="d2", a3=whatbuf())
%   {
%      variable a1, a2, a3;
%      (a1, a2, a3) = push_defaults( , "d2", whatbuf(), _NARGS-1);
%      vmessage("(%S, %S, %S)", a1, a2, a3);
%   }
%#v-
% results in:
%   fun(1)       %  --> (1, d2, *scratch*)
%   fun(1, 2)    %  --> (1, 2, *scratch*)
%   fun(1, 2, 3) %  --> (1, 2, 3)
% but
%   fun()        %  --> !!compulsory arg missing!!
%   fun(1, , )   %  --> (1, NULL, NULL)  !!empty args replaced with NULL!!
%\notes
% Never forget the _NARGS argument to \sfun{push_defaults}!
% 
% Mixed compulsory-optional arguments can be defined somewhat simpler, if
% the compulsory argument comes last:
%#v+
%   define fun2(a2) % (a1="d1", a2)
%   {
%      variable a1 = push_defaults("d1", _NARGS-1);
%      vmessage("(%S, %S)", a1, a2);
%   }
%#v-
% (To the author, the compulsory-first ordering appears more "natural",
% though. Maybe this is due to the Python experience where compulsory
% arguments need to precede optional ones.)
% 
% The arguments to push_defaults will always be evaluated. If time is an issue,
% use a placeholder (e.g. NULL) or a construct like
%#v+
%   define fun() % (a=time_consuming_fun())
%   {
%      !if (_NARGS)
%        time_consuming_fun();
%      variable a = ();
%      ...
%   }
%#v-
%\seealso{__push_args, __pop_args, _NARGS }
%!%-
define push_defaults() % args, n
{
   variable n = ();
   variable args = __pop_args(_NARGS-1);
   __push_args(args[[n:]]);
}

%!%+
%\function{prompt_for_argument}
%\synopsis{Prompt for an optional argument if it is not given.}
%\usage{Str prompt_for_argument(Ref prompt_function, [args], Int use_stack)}
%\description
%  This function facilitates the definition of function with optional
%  arguments.
%
%  The first argument is a prompt function (e.g. \sfun{read_mini} or
%  \sfun{read_with_completion}, followed by its arguments and the
%  \var{use_stack} argument.
%
%  If \var{use_stack} is non-zero, this function simply returns and
%  the calling code picks up the top element from stack.
%  Otherwise, \var{prompt_function} is called with the given arguments
%  (except when the minibuffer is already active, in which case an error
%  is risen).
%\example
%#v+
%  define prompt_for_message() % ([str])
%  {
%     variable str = prompt_for_argument(&read_mini,
%                                        "Message:", "", "", _NARGS);
%     message(str);
%  }
%#v-
%\seealso{push_defaults, _NARGS, read_mini, read_with_completion}
%!%-
define prompt_for_argument() % (fun, [args], use_stack)
{
   variable use_stack = ();
   variable args = __pop_args(_NARGS-2);
   variable fun = ();
   if (use_stack)
     return ();  % argument is already on stack
   else
     {
        if (MINIBUFFER_ACTIVE) % cannot use minibuffer for prompting
          error("missing argument");
        return @fun(__push_args(args));
     }
}

%!%+
%\function{push_array}
%\synopsis{Push an ordinary array on stack}
%\usage{(a[0], ..., a[-1])  push_array(Array a)}
%\description
% Push the elements of an array to the stack. This works like
% __push_args(args) but with an ordinary array (all types)
%\example
%#v+
%   variable a = ["message", "hello world"];
%   runhooks(push_array(a));
%#v-
%\notes
%   Elements of an Any_Type-array are references. They are dereferenced
%   in order to get type-independend behaviour.
%\seealso{array, pop2array, __push_args, __pop_args}
%!%-
define push_array(a)
{
   if (_typeof(a) == Any_Type)
        foreach (a)
             if (dup == NULL)
               ();
             else
              @();
   else
     foreach (a)
       ();
}

%!%+
%\function{get_blocal}
%\synopsis{Return value of blocal variable or default}
%\usage{Any get_blocal(String name, [Any default=NULL])}
%\description
% Deprecated: use the standard function \var{get_blocal_var} with a second
% argument.
% 
% This function is similar to get_blocal_var, but if the local variable
% "name" doesnot exist, it returns NULL or the default value instead 
% of an error.
%\example
% Since some time (which Jed version??), \var{get_blocal_var} also takes an
% optional default value:
%#v+
%    !if (get_blocal_var(foo), 0)
%      message("this buffer lacks foo");
%#v-
% prints the message if the blocal variable "foo" is zero or does not exist.
%\note
% There is no "default default" in \var{get_blocal_var}. Instead, it will
% throw an error, if there is no blocal_variable with \var{name} and no
% \var{default} argument is specified.
%\seealso{get_blocal_var, blocal_var_exists, set_blocal_var, define_blocal_var}
%!%-
define get_blocal() % (name, default=NULL)
{
   variable name, default;
   (name, default) = push_defaults( , NULL, _NARGS);

   if (blocal_var_exists(name))
     return get_blocal_var(name);
   return default;
}

%!%+
%\function{run_function}
%\synopsis{Run a function if it exists, return if fun is found.}
%\usage{Int_Type run_function(fun, [args])}
%\description
% Run a function (if it exists) pushing \var{args} as argument list.
% In contrast to \sfun{call_function}, there is a return value
% (pushed on the stack after the function call):
% 
%  1 the function was found (is_defined or internal)
%  0 the function was not found
%  
% The \var{fun} can be a function name or reference (this allows both:
% yet undefined functions (as string) as well as private or static functions
% (as reference).
%\example
%#v+
%
%    if (run_function("foo"))
%       message("\"foo\" successfull called");
%
%    !if (run_function(&foo))
%       message("\"foo\" is not defined");
%#v-
% The return value can be used to decide whether to take up a return value:
%#v+
%
%    if (run_function("filter", str))
%       str = ();
%#v-
%\notes
% If fun is (solely) an internal function, the optional arguments will be
% silently popped. If there are both, an internal and an intrinsic or library
% variant of a function, the non-internal takes precedence. Use \sfun{call} to
% explicitely call an internal function. 
%\seealso{call_function, runhooks, run_local_hook, call}
%!%-
define run_function()  % (fun, [args])
{
   variable args = __pop_args(_NARGS-1);
   variable fun = ();
   if (typeof(fun) == String_Type)
     {
        if (is_defined(fun) > 0)
          fun = __get_reference(fun);
        else if (is_internal(fun))
          {
             call(fun);
             return 1;
          }
     }
   if (typeof(fun) == Ref_Type)
     {
        @fun(__push_args(args));
        return 1;
     }
   return 0;
}

%!%+
%\function{contract_filename}
%\synopsis{Make a filename as short as possible without ambiguity}
%\usage{contract_filename(file, cwd=getcwd())}
%\description
%  The opposite of \sfun{expand_filename} (in some case of view)
%  Make a filename as short as possible without loss of information.
%  
%  * If the path starts with \var{cwd}, strip it.
%    (This maight fail on case insensitive filesystems).
%  * If the path starts with the home-dir, replace it with "~".
%\notes  
%  \sfun{expand_filname} will restore the original value.
%\seealso{expand_filename}
%!%-
define contract_filename() % (file, cwd=getcwd())
{
   variable file, cwd;
   (file, cwd) = push_defaults( , getcwd(), _NARGS);
   variable home = getenv("HOME");
   % strip leading cwd
   cwd = path_concat(cwd, ""); % ensure that cwd has a trailing dirsep
   if (is_substr(file, cwd) == 1)
     file = file[[strlen(cwd):]];
   % or replace HOME with ~
   else if (andelse{home != NULL}{strlen(home)})
     {
        home = path_concat(home, ""); % ensure home has a trailing dirsep
        if (is_substr(file, home) == 1)
          file = path_concat("~", file[[strlen(home):]]);
     }
   return file;
}

% when a buffer is folded what_line may give the false number
define what_line_if_wide ()
{
  if (count_narrows ())
    {
      push_narrow ();
      widen_buffer ();
      what_line ();
      pop_narrow ();
    }
  else
    what_line ();
}

%!%+
%\function{_implements}
%\synopsis{Create or reuse a new static namespace}
%\usage{_implements(Str name)}
%\description
%  The \sfun{_implements} function creates a new static namespace 
%  and associates it with the current compilation unit.
%  
%  If a namespace with the specified name already exists, the the current
%  static namespace is changed  to \var{name} with \sfun{use_namespace}.
%  
%  This alows re-evaluation of files in debugging|development mode.
%  
%\notes  
%  Since SLang 2 the standard implements() (re)uses a namespace if it was
%  defined in the same file. If defined in another file, it still throws a
%  namespace error.
%\example
%  To allow easy re-evaluation of a mode during development, write
%#v+
%   autoload("_implements", "sl_utils");
%   % other autoloads that should bind to the "Global" namespace
%   _implements("foo");
%   % autoloads, require, and function and variable definitions now go to the
%   % namespace "foo"
%#v-
%\seealso{implements, use_namespace}
%!%-
define _implements(name)
{
  if (length(where(name == _get_namespaces())))
    use_namespace(name);
  else
    implements(name);
}

%!%+
%\function{autoloads}
%\synopsis{Load functions from a file}
%\usage{autoloads(String funct, [String funct2 , ...], String file)}
%\description
% The `autoloads' function is used to declare a variable number of
% functions `funct' to the interpreter and indicate that they should be
% loaded from `file' when actually used.
% It does so by calling autoload(funct, file) for all \var{funct} arguments.
%\notes
% A future version of \sfun{autload} might provide for mulitple funct
% arguments and render \sfun{autoloads} obsolete.
% 
% _autoload(funct, file, funct2, file, ..., functN, file, N) is faster,
% (albeit less convenient to write and needing an explicit number argument).
% Use this for time-critical cases.
%\seealso{_autoload, autoload, require, evalfile}
%!%-
define autoloads(file) % (funct, [funct2 , ...], file)
{
   loop(_NARGS - 1) 
     autoload((), file);
}

