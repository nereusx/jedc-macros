#!/bin/sh
[ ! -d ~/.backup/text ] && mkdir -p ~/.backup/text
cp -r .jed ~/

if [ -z "$BACKUPDIR" ]; then
	export BACKUPDIR=${HOME}/.backup
	list=".bashrc .zshrc .yashrc .kshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'export BACKUPDIR=${HOME}/.backup' >> ~/$e
		fi
	done
	list=".cshrc .tcshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'setenv BACKUPDIR ${HOME}/.backup' >> ~/.$e
		fi
	done
	echo "Environmet variable BACKUPDIR added; reload shell's rc required"
fi

if [ -z "$JED_HOME" ]; then
	export JED_HOME=${HOME}/.jed
	list=".bashrc .zshrc .yashrc .kshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'export JED_HOME=${HOME}/.jed' >> ~/$e
		fi
	done
	list=".cshrc .tcshrc"
	for e in $list; do
		if [ -f ~/$e ]; then
			echo 'setenv JED_HOME ${HOME}/.jed' >> ~/.$e
		fi
	done
	echo "Environment variable JED_HOME added; reload shell's rc required"
fi

echo 'Files copied to ~/.jed'
echo '* done *'
