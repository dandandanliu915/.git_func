function __git_func_config() {

	function __git_func_deploy() {
		echo $GIT_DIR $DIR
		touch $GIT_DIR/.git_func_config_file_list
		cp $DIR/git_func_config $GIT_DIR/.git_func_config
		. $GIT_DIR/.git_func_config

		read -p "Input local config files (space separated): " input_config
		if [[ -n $input_config ]]
		then
        		echo "$input_config" > $GIT_DIR/.git_func_config_file_list
		fi

		read -p "Input critical branch names (space separated): " input_branch
		if [[ -n $input_branch ]]
		then
        		grep -v "CRITICAL_BRANCHES" $GIT_DIR/.git_func_config > $GIT_DIR/.git_func_config.temp
			echo "export CRITICAL_BRANCHES=\"`echo $input_branch | tr ' ' '|' `\"" >> $GIT_DIR/.git_func_config.temp
        		mv $GIT_DIR/.git_func_config.temp $GIT_DIR/.git_func_config
		fi
		echo "Deployed for $GIT_DIR"
	}

	# Check if current directory is a git repo
	[[ -d .git ]] || git rev-parse --git-dir > /dev/null 2>&1
	if [[ $? -ne 0 ]]
	then
		echo "Not a git repo!"
		return 1
	fi

	# Deploy for the repo if it's the first time or REDEPLOY variable is set
	GIT_DIR="$( cd "$(git rev-parse --git-dir)" >/dev/null 2>&1 && pwd)"
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
	if [[ ! -f $GIT_DIR/.git_func_config ]]
	then
		echo "First time deploying for this git repo"
		__git_func_deploy
	elif [[ -n $REDEPLOY ]]
	then
		read -p "Already deployed. Redeploy? [Y/n] " yn
        	case $yn in
        	    	[Yy]* ) echo "Deploying ..."; __git_func_deploy ;;
	            	*) ;;
        	esac
	fi

	source $GIT_DIR/.git_func_config
}

function __git_list() {
	git diff-tree --name-status -r "$@"
}

function __hub_exists() {
	temp=`which hub`
	if [[ -z "$temp" ]]
	then
		echo "'hub' is not installed yet!"
		return 1
	fi
}

function __remove_file_from_commit() {
	if [[ $# -ne 1 ]]
	then
		echo "-- Invalid input"
		return 1
	fi

	path=$1

	{ git_commit_list; rc=$?; } | grep $path >> /dev/null
	if [[ $rc -eq 0 && $? -eq 0 ]]
	then
		echo "-- Remove file from current commit: $path"
		git reset --soft HEAD~1
		git reset HEAD $path
		return 0
	else
		echo "-- File is not in current commit: $path"
		return 1
	fi
}

function __switch_to_standard(){
	path=$1
	cp $path $path.$USER
	git restore $path
	cp $path $path.orig
}

function __switch_to_local() {
        path=$1
        cp $path $path.orig
	if [[ -f $path.$USER ]]
	then
	        cp $path.$USER $path
	else
		echo "User path not exists: $path.$USER"
	fi
}

function __config() {
	__git_func_config
	echo $CONFIG_FILE_LIST
}
