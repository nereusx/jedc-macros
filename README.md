# jedc-macros

CBrief compatibility for Jed (see patched version nereusx/jedc)

## Require
packages libslang/slang slsh gettext

## Environment variables

Add this line to your profile
```
export JED_HOME=~/.jed
```

for [t]csh users, add this line to your ~/.tcshrc
```
setenv JED_HOME ~/.jed
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


