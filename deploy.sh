#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

grep "git_func" $HOME/.bashrc > /dev/null 2>&1

if [[ $? -ne 0 ]]
then
	cat << EOF >> $HOME/.bashrc
## Add customized git functions
source $DIR/git_func.sh
function git_help() {
	grep "function git_" $DIR/git_func.sh | awk -F " " '{print \$2}' | awk -F "(" '{print \$1}' | sort
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

echo "Global deployment finished. Run git_func_deploy in your git repo to add configuration locally."
