#!/bin/bash

touch .config_file_list
cp ./git_func_config ./.config
. ./.config

read -p "Input local config files: " input_config
if [[ -n $input_config ]]
then
	echo "$input_config" >> .config_file_list
fi

read -p "Input critical branch names: " input_branch
if [[ -n $input_branch ]]
then
	grep -v "critical_branches" ./.config > ./.config.temp
	echo "export critical_branches=\"`echo $input_branch | tr ' ' '|' `\"" >> ./.config.temp
	mv ./.config.temp ./.config
fi

grep "git_func" $HOME/.bashrc > /dev/null 2>&1

if [[ $? -ne 0 ]]
then
	cat << EOF >> $HOME/.bashrc
## Add customized git functions
source ~/.git_func/git_func
function git_help() {
	grep "function git_" ~/.git_func/git_func | awk -F " " '{print $2}' | awk -F "(" '{print $1}' | sort
}
EOF
fi
