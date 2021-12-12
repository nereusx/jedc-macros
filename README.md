# jedc-macros

CBrief compatibility for Jed (see patched version nereusx/jedc)

## Require
packages libslang/slang slsh gettext

## Environment variables

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


