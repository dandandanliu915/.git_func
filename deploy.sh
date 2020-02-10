#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

grep "git_func" $HOME/.bashrc > /dev/null 2>&1

if [[ $? -ne 0 ]]
then
	cat << EOF >> $HOME/.bashrc
## Add customized git functions
source $DIR/git_func
function git_help() {
	grep "function git_" $DIR/git_func | awk -F " " '{print \$2}' | awk -F "(" '{print \$1}' | sort
}
EOF
else
        read -p "Already deployed. Redeploy? [Y/n] " yn
        case $yn in
    	    [Yy]* ) echo "Deploying ...";;
            [Nn]* ) echo "Canceled"; exit;;
            * ) echo "Canceled"; exit;;
        esac
fi

touch $DIR/.config_file_list
cp $DIR/git_func_config $DIR/.config
. $DIR/.config

read -p "Input local config files (space separated): " input_config
if [[ -n $input_config ]]
then
	echo "$input_config" > $DIR/.config_file_list
fi

read -p "Input critical branch names (space separated): " input_branch
if [[ -n $input_branch ]]
then
	grep -v "CRITICAL_BRANCHES" $DIR/.config > $DIR/.config.temp
	echo "export CRITICAL_BRANCHES=\"`echo $input_branch | tr ' ' '|' `\"" >> $DIR/.config.temp
	mv $DIR/.config.temp $DIR/.config
fi

echo "Deployment finished"
