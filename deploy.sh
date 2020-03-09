#!/bin/bash

function deploy() {
	function command() {
		cat << 'EOF'

## >>> git_func >>>
source %s/git_func.sh
function git_help() {
        help_doc=`cat %s/README.md`
        verbose_doc=${help_doc#*Currently includes functions:}
        doc=`echo "$verbose_doc" | grep -E "^- " | awk -F " " '{print $2}'`

	if [[ $# -gt 0 ]]
	then
	key="$1"
	        case $key in
			-v|--verbose)
			echo "$verbose_doc"
			;;
			*)
			;;
		esac
	else
		echo "$doc"
	fi
}
## <<< git_func <<<

EOF
	}
	temp=`command`
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	printf "$temp" "$DIR" "$DIR"
}

grep "git_func" $HOME/.bashrc > /dev/null 2>&1

if [[ $? -ne 0 ]]
then
	cp $HOME/.bashrc $HOME/.bashrc.temp
	deploy >> $HOME/.bashrc.temp
	cat $HOME/.bashrc.temp | sed '/^$/N;/^\n$/D' > $HOME/.bashrc
	rm $HOME/.bashrc.temp
	echo "Global deployment finished."
else
        read -p "Already deployed. Redeploy? [Y/n] " yn
        case $yn in
    	    [Yy]* )
		echo "Deploying ..."
		orig=`cat $HOME/.bashrc`
		orig_prev=${orig%\#\# >>> git_func >>>*}
		orig_tail=${orig#*\#\# <<< git_func <<<}
		dep=`deploy`
		echo "$orig_prev$dep$orig_tail" > $HOME/.bashrc.temp
        	cat $HOME/.bashrc.temp | sed '/^$/N;/^\n$/D' > $HOME/.bashrc
        	rm $HOME/.bashrc.temp
		echo "Global deployment finished."
		;;
            * ) echo "Canceled";;
        esac
fi
echo "Run git_func_deploy in your git repo to add configuration locally."
