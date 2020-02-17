DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

function __git_repo_check() {
	# Check if current directory is a git repo
        [[ -d .git ]] || git rev-parse --git-dir > /dev/null 2>&1
        if [[ $? -ne 0 ]]
        then
                >&2 echo "Not a git repo!"
                return 1
        else
        	echo "$( cd "$(git rev-parse --git-dir)" >/dev/null 2>&1 && pwd)"
	fi
}

function git_func_deploy() {

	function deploy() {
		FILE_LIST=$GIT_DIR/.git_func_config_file_list
		CONFIG=$GIT_DIR/.git_func_config

		touch $FILE_LIST
		[[ ! -f $CONFIG ]] || cp $DIR/git_func_config $CONFIG
		source $CONFIG

		read -p "Input local config files (space separated OR enter to skip): " input_file_list
		if [[ -n $input_file_list ]]
		then
			echo "$input_config" > $FILE_LIST.temp
			if [[ -f $FILE_LIST ]] & [[ -s $FILE_LIST ]]
			then
				read -p "Local config files already exist, replace? (Y/n)" yn
				case $yn in
                        		[Yy]* )
						echo "\tReplaced file list"
						mv $FILE_LIST.temp $FILE_LIST
						;;
                	        	*)
						cat $FILE_LIST.temp >> $FILE_LIST
                				rm $FILE_LIST.temp
						;;
				esac
			else
				mv $FILE_LIST.temp $FILE_LIST
			fi
		fi

		config_file=`cat $CONFIG`
		config_file_header=${config_file%\#\#*}
		config_file_vars=${config_file#*\#\#}

		echo "$config_file_header##" > $CONFIG.temp

		vars=`echo $config_file_vars | grep "export" | awk -F "=" '{print $1}' | awk -F " " '{print $NF}'`
		for var in $vars
		do
			read -p "Input new value for $var=${!var} (space separated OR enter to skip): " input_value
			if [[ -n $input_value ]]
			then
				echo "export $var=\"`echo $input_value | tr ' ' '|' `\"" >> $CONFIG.temp
			else
				echo "export $var=${!var}" >> $CONFIG.temp
			fi
		done
		mv $CONFIG.temp $CONFIG

		echo "Deployed for $GIT_DIR"
	}

        GIT_DIR=`__git_repo_check`

	# Deploy for the repo if it's the first time or REDEPLOY variable is set
	if [[ ! -f $GIT_DIR/.git_func_config ]]
	then
		echo "First time deploying for this git repo"
		deploy
	else
		read -p "Already deployed. Redeploy? [Y/n] " yn
        	case $yn in
        	    	[Yy]* )
				echo "Redeploying ..."
				deploy
				;;
	            	*) ;;
        	esac
	fi
}

function __git_func_config() {
	GIT_DIR=`__git_repo_check`
	if [[ ! -f $GIT_DIR/.git_func_config ]]
        then
                echo "First time deploying for this git repo"
                git_func_deploy
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
