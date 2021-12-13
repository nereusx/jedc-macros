# jedc-macros

CBrief compatibility for Jed (see patched version nereusx/jedc)

## Require
packages libslang/slang slsh gettext xclip

## Environment

Backups directory
```
mkdir -p ~/.backup/text
```

Add the lines to your profile
```
export BACKUPDIR=~/.backup/text
export JED_HOME=~/.jed
alias b=jed
```

[t]csh users
```
setenv BACKUPDIR ~/.backup/text
setenv JED_HOME ~/.jed
alias b jed
```

## Install macros
```
git clone https://github.com/jedc-macros
cd jedc-macros
cp -r .jed ~/
```

## Install patced version of jed
```
git clone https://github.com/jedc
cd jedc
./configure
make
# make xjed
make install
```

## Differences

*Jed* has not the same abilities with BRIEF's windows system.
It is only creates vertically windows. Anyway, the macros uses
*BRIEF* keys with similar way.

**Additional** to the original BRIEF keys:
```
Alt+F               Search forward
Ctrl+F              Search backward
Ctrl+Q              Cancel (ESC works too, just waits 1 sec in Unix)
[Alt+\]]            Matching delimiters
[Alt+/]             Completion
[Alt+!]             Run shell command and capture its output in new buffer
[Alt+,]             Uncomment
[Alt+.]             Comment
```

``` Additional function keys
[F10]               CBRIEF's Command line
                    Executes CBRIEF's macro or: 
                    if begins with '?', prints the result.
                    if begins with '$', runs SLang code.
                    if begins with '!', runs shell command and returns the output in new buf.
                    if begins with '<', runs shell command and insert the output in cur buf.
                    if begins with '>', writes the selected block or the whole buffer to file.
                    if begins with ">>", appends the selected block or the whole buffer to file.
                    if begins with '|', pipes the selected block or the whole buffer to file.
                    if begins with '&', execute in background and in new terminal on XJed.                             
[Alt+F10]           Compile Buffer
[Ctrl+F10]          Make (non-brief)
[Ctrl+F9]           Borland's compile key
[F9]                Make (Borland's build and run)
[F11]               JED's Dired
[F12]               JED's menu
```

Win/KDE clipboard keys (default on)
```
Ctrl+C              Copy
Ctrl+V              Paste
Ctrl+X              Cut
```

X11 clipboard
```
Alt+Ctrl+C = Copy
Alt+Ctrl+V = Paste
Alt+Ctrl+X = Cut
```

Emacs/Readline compatibility (default on)
```
Ctrl+A = Home
Ctrl+E = End
```

Laptop mode (default off)
```
Ctrl+Up    = PageUp
Ctrl+Down  = PageDown
Ctrl+Left  = Home
Ctrl+Right = End
```

## User's terminal codes fix file

The `~/.jed/terminal.sl` file is used for any user to fix terminal incompatibilities.


