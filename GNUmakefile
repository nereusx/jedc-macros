#

has_jed_home  := ${shell if [ -z '"${JED_HOME}"' ]; then echo "N"; else echo "Y"; fi}
has_backupdir := ${shell if [ -z '"${BACKUPDIR}"' ]; then echo "N"; else echo "Y"; fi}
has_tcsh      := ${shell if [ -e /bin/tcsh ]; then echo "Y"; else echo "N"; fi}
has_bash      := ${shell if [ -e /bin/bash ]; then echo "Y"; else echo "N"; fi}
has_zsh       := ${shell if [ -e /bin/zsh ]; then echo "Y"; else echo "N"; fi}
has_ash       := ${shell if [ -e /bin/ash ]; then echo "Y"; else echo "N"; fi}
has_dash      := ${shell if [ -e /bin/dash ]; then echo "Y"; else echo "N"; fi}

all: help

clean:
	-rm .jed/.jedrecent .jed/.jedsession-nc .jed/.hist_cmdline

install:
	-mkdir -p ~/.backup/text
	cp -r .jed ~/
	ifeq "$(has_backupdir)" "N"
		ifeq "$(has_tcsh)" "Y"
			echo 'setenv BACKUPDIR=~/.backup/text' >> ~/.tcshrc
		endif
		ifeq "$(has_bash)" "Y"
			echo 'export BACKUPDIR=~/.backup/text' >> ~/.bashrc
		endif
		ifeq "$(has_zsh)" "Y"
			echo 'export BACKUPDIR=~/.backup/text' >> ~/.zshrc
		endif
	endif
	ifeq "$(has_jed_home)" "N"
		ifeq "$(has_tcsh)" "Y"
			echo 'setenv JED_HOME=~/.jed' >> ~/.tcshrc
		endif
		ifeq "$(has_bash)" "Y"
			echo 'export JED_HOME=~/jed' >> ~/.bashrc
		endif
		ifeq "$(has_zsh)" "Y"
			echo 'export JED_HOME=~/.jed' >> ~/.zshrc
		endif
	endif

help:
	@echo "Has \$$JED_HOME " $(has_jed_home)
	@echo "Has \$$BACKUPDIR" $(has_backupdir)
	@echo
	@echo "make [install|clean]"
