DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source $DIR/git_func_helper.sh

function git_log() {
	git reflog --date=iso
}

function git_history() {
	git log "$@"
}

function git_commit_id() {
	commit=`[[ -n "$1" ]] && echo "$1" || echo "HEAD"`
	git rev-parse "$commit"
}

function git_commit_show() {
	commit=`[[ -n "$1" ]] && echo "$1" || echo "HEAD"`
	git show --no-patch "$commit"
}

function git_commit_msg() {
	commit=`[[ -n "$1" ]] && echo "$1" || echo "HEAD"`
	git log --format="%B" -n 1 "$commit"
}

function git_commit_diff() {
	commit=`[[ -n "$1" ]] && echo "$1" || echo "HEAD"`
	git diff "$commit~1" "$commit"
}

function git_commit_list() { 
	commit=$1
	# changed=`git diff --name-only origin/master $(git_branch_name)`
	branch_status=`git rev-list --left-right --count origin/master...$(git_branch_name)`
	behind=`echo "$branch_status" | awk -F " " '{print $1}'`
	ahead=`echo "$branch_status" | awk -F " " '{print $2}'`
	if [[ -n "$commit" || "$ahead" -ne 0 ]]
	then
		if [[ -z "$commit" && "$behind" -ne 0 ]]
		then
			git pull --rebase
		fi

		commit=`[[ -n "$commit" ]] && echo "$commit" || echo "HEAD"`

		changed_list=`__git_list "$commit"`
		wc=$((`echo "$changed_list" | wc -l`-1))
		echo "-- $wc files in commit: $changed_list "
	else
		echo "-- No commit made, check status below: "
		git status
		return 1
	fi
}

function git_branch_name() {
	git branch --show-current
}

function git_branch_ts() {
	git reflog show --date=format:'%Y-%m-%d %H:%M:%S' --all | sed "s!^.*refs/!refs/!" | grep "branch:"
}

function git_branch_suffix() {
	suffix="$1"
	git branch -m "$(git_branch_name).$1"
}

function git_branch_upstream_set() {
	remote=`[[ -n "$1" ]] && echo "$1" || echo "origin/master"`
	git branch --set-upstream-to "$remote"
}

function git_branch_upstream_show() {
	#git status -sb  | grep -E "^#" | awk -F " " '{print $2}' | awk -F "." '{print $NF}'
	git rev-parse --abbrev-ref --symbolic-full-name `git_branch_name`@{upstream}
}

function git_branch_push() {
	git_branch_name_short=`git_branch_name | awk -F "." '{print $1}'`
	echo $git_branch_name_short| grep master > /dev/null
	if [[ $? -eq 0 ]]
	then
		echo "Pushing master is not recommended"
		return 1
	elif [[ -n $(git_branch_upstream_show 2>/dev/null) ]]
	then
		if [[ "$(git_branch_upstream_show)" != "origin/$git_branch_name_short" ]]
		then
			echo "Upstream remote branch exists and not matching: $git_branch_upstream_show"
			return 1
		fi
	fi

	git push -u origin `git_branch_name`:"$git_branch_name_short"
}

function git_branch_remote_exists() {
	temp=`git ls-remote --exit-code --heads origin "$1"`
	if [[ -z "$temp" ]]
	then
		echo "-- Branch origin/$1 does not exist now! Check again"
		return 1
	fi
}

function git_branch_pr() {
	__hub_exists
	if [[ $? -ne 0 ]]
	then
		return 1
	fi
	hub pr list -s all -f "%I|%au|%S|%pS|%t|%U%n" -h `git_branch_upstream_show`
}

function git_pr_list() {
	__hub_exists
	if [ $? -ne 0 ]
        then
                return 1
        fi

	user="$1"
        if [[ -z $user ]]
        then
                user=`[[ -n $(git config user.name) ]] && echo $(git config user.name) || echo $USER`
        fi
	regex="\|$user.*\|"
	hub pr list -s all -f "%I|%au|%S|%pS|%t|%U%n" | grep -E "$regex"
}

function git_cherry_pick() {
	function _safe_exit(){
		echo "\nSafe Exited: $1"
		if [[ -n $branch ]]
		then
			git branch | grep $branch > /dev/null
			if [[ $? -eq 0 ]]
			then
				echo "-- Removing branch and return to original branch"
				git switch -
				git branch -d "$branch"
			fi
		fi
		trap - INT TERM EXIT
	}
	function _trap() {
		for sig ; do
			trap "_safe_exit $sig; return 1" "$sig"
		done
	}
	_trap INT TERM EXIT

	read -p "-- Input remote branch name to cherry-pick: " branch
	git_branch_remote_exists $branch
	if [[ $? -ne 0 ]]
	then
		_safe_exit "ERROR"; return
	else
		echo "-- Checking out remote branch to local"
		git checkout -B "$branch" "origin/$branch"
		if [[ $? -ne 0 ]]
		then
			echo "-- Cheking out branch failed"
			_safe_exit "ERROR"; return
		fi
	fi

	read -p "-- Input commit to be cherry-pick: " commit_id
	git rev-parse --verify $commit_id 
	if [[ $? -ne 0 ]]
        then
                echo "-- Failed to find commit: $commit_id"
                _safe_exit "ERROR"; return
        fi
	echo "-- Here is a brief of input commit: "
	git_commit_msg $commit_id
	git_commit_list $commit_id
	read -p "-- Continue? [Y/n] " yn
	case $yn in
            [Yy]* ) echo "-- Cherry picking $commit_id";;
            * ) echo "Canceled"; _safe_exit "CANCELED"; return;;
        esac
	git cherry-pick "$commit_id"
	if [[ $? -ne 0 ]]
        then
                echo "-- Cherry pick failed"
                _safe_exit "ERROR"; return
        fi

	echo "-- Pushing to remote branch: $branch"
	git push origin "$branch:$branch"
	if [[ $? -ne 0 ]]
        then
                echo "-- Pushing failed"
                _safe_exit "ERROR"; return
        fi

	safe_exit "FINISHED"; return
}

function git_remove_restore_recommit() {
	path="$1"
	message=`git_commit_msg`

	__remove_file_from_commit "$path"
	if [[ $? -ne 0 ]]
	then
		echo "-- Failed when remove from commit: $path"
		return 1
	fi

	if [[ -n $__retain ]]
	then
		echo "-- Save file copy: $path.$USER"
		cp $path $path.$USER
	fi

	if [[ -n $__remove_only ]]
	then
		echo "-- Save previous commit message to .git/COMMIT_EDITMSG.orig"
                echo "$message" > $CL_HOME/.git/COMMIT_EDITMSG.orig
	else
		echo "-- Restore file: $path"
                git restore "$path"

		staged=`git diff --name-only --cached`
		if [[ -n $staged ]]
		then
			echo "-- Reapply commit message ..."
			git commit -a -m "$message"
		else
			echo "-- Nothing to recommit"
			echo "-- Save message to .git/COMMIT_EDITMSG.orig"
			echo "$message" > $CL_HOME/.git/COMMIT_EDITMSG.orig
		fi
	fi

	if [[ -n $__retain ]]
	then
		for path in "$@"
		do
			echo "-- Retain from file copy: $path.$USER"
			cp $path.$USER $path
		done
	fi

	git_commit_list
}

function git_remove_only() {
	export __remove_only="True"
	git_remove_restore_recommit "$@"
	unset __remove_only
}

function git_remove_retain_recommit() {
	export __retain="True"
	git_remove_restore_recommit "$@"
	unset __retain
}

function git_branch_reset() {
	while true; do
        read -p "This will force current branch to origin/master and abondon all untracked changes. Continue? [y/n] " yn
		case $yn in
			[Yy]* ) break;;
                        [Nn]* ) echo "Canceled"; return;;
                        * ) echo "Canceled"; return;;
                esac
        done
	git reset --hard origin/master
}

function git_config_local() {
	files=`__config`
	for file in $files
        do
                __switch_to_local $file
        done
}

function git_config_standard() {
	files=`__config`
        for file in $files
        do
		__switch_to_standard $file
        done
}

function git_branch_switch() {
	if [ $# -ne 1 ]
        then
                echo "Invalid input"
                return 1
        fi

	branch=$1

	files=`__config`
	for file in $files
	do
		check=`git diff --name-only HEAD~1 HEAD | grep "$file"`
		if [[ -n $check ]]
		then
			__switch_to_standard $file
		fi
	done

	git switch $branch
}

function git_show_ones_commits() {
	if [[ $# -gt 1 ]]
	then
		echo "Function doesn't work with spaces in author name"
		return
	fi
	user="$1"
	if [[ -z $user ]]
	then
		user=`[[ -n $(git config user.name) ]] && echo $(git config user.name) || echo $USER`
	fi
	regex="^((?!"$user").*)$"
	git --no-pager log --author="$user"
	git --no-pager log --perl-regexp --author="$regex" --committer="$user"
}

function git_where_are_the_commits() {
	__git_func_config

	# Default values
	commits=""
	num=""
	start=""
	end=""
	to_grep=$CRITICAL_BRANCHES
	verbose=false
	all=false

	# Get arguments
	while [[ $# -gt 0 ]]
	do
	key="$1"

	case $key in
		-c|--commit)
		commits="$commits$2 "
		shift
		shift
		;;
		-n|--num)
		num="$2"
		shift
		shift
		;;
		-s|--start)
		start="$2"
		shift
		shift
		;;
		-e|--end)
		end="$2"
		shift
		shift
		;;
		-v|--verbose)
		verbose=true
		shift
		;;
		-a|--all)
		all=true
		shift
		;;
		*)
		echo "Invalid input: $1"
		return
		;;
	esac
	done

	# Validate input commits and num
	if [[ -n $commits && -n $num ]]
	then
		echo "Invalid input: Input only commits or num"
		return
	fi

	# Validate input start and end date
	OS=`uname`
	case $OS in
	  'Linux')
		# Linux
		if ! date -d "$start" >>/dev/null 2>&1
		then
			echo "Invalid input: Start date has to be in format: yyyy-mm-dd"
			return
		elif ! date -d "$end" >>/dev/null 2>&1
		then
			echo "Invalid input: End date has to be in format: yyyy-mm-dd"
			return
		fi
	  ;;
	  'Darwin') 
		# Mac
		if [[ -n $start ]] && ! date -f "%Y-%m-%d" -j "$start" >/dev/null 2>&1 
		then
			echo "Invalid input: Start date has to be in format: yyyy-mm-dd"
			return
		elif [[ -n $end ]] && ! date -f "%Y-%m-%d" -j "$end" >>/dev/null 2>&1 
		then
			echo "Invalid input: End date has to be in format: yyyy-mm-dd"
			return
		fi
	  ;;
	  *) ;;
	esac

	# Check if critical branches exist
	if $verbose
	then
		to_grep='.*'
	else
		echo "Check if critical branches $to_grep exist..."
		for b in `echo $to_grep | tr "|" "\n"`
		do
			git_branch_remote_exists "$b"
			if [[ $? -ne 0 ]]
			then
				return
			fi
		done
		echo "Critical branches exist"
		echo
	fi

	# Get commits ref list (unless specific commits was input)
	if [[ -z $commits ]]
	then
		commits=`git_show_ones_commits | grep commit | awk -F " " '{print $2}'`
		if [[ -n $num ]]
		then
			commits=`echo $commits | tr " " "\n" | head -$num`
		fi
	fi

	# Update commit list that not in production yet (unless all flag was input)
	if $all
	then
		echo "-- Get all my commits ..."
		commits_updated=$commits
	else
		echo "-- Get commits not in all critical branches yet ..."
		commits_updated=""
		critical_branch_cnt=`echo $to_grep | tr "|" "\n" | wc -l`
		for commit in $commits
		do
			temp=`git branch -r --contains $commit | grep -v "origin/HEAD" | grep -E "origin/($to_grep)" | wc -l`
			if [[ $temp -ne $critical_branch_cnt ]]
			then
				commits_updated="$commits_updated$commit "
			fi
		done
	fi
	commits=$commits_updated

	# Update commit list between start and end date
	if [[ -z $start && -z $end ]]
        then
		echo "-- Checking all dates..."
		commits_updated=$commits
	else
                echo "-- Looking for commits between ("`[[ -n $start ]] && echo "$start" || echo "-"`", "`[[ -n $end ]] && echo "$end" || echo "-"`")"
		commits_updated=""
		for commit in $commits
		do
			temp=`git show $commit --no-patch --no-notes --pretty='%ci'`
			if [[ -z $start || "$temp" > "$start" ]] && [[ -z $end || "$temp" < "$end" ]]
			then
				commits_updated="$commits_updated$commit "
			fi
		done
	fi
	commits=$commits_updated

	# Get each commit info
	if [[ -z $commits ]]
	then
		echo "No commits found"
		return
	fi
	echo "Commit info: "
	for commit in $commits
	do
		git show $commit --oneline --no-patch
		echo "Authored at:  "`git show $commit --no-patch --no-notes --pretty='%ad'`
		echo "Committed at: "`git show $commit --no-patch --no-notes --pretty='%cd'`
		echo "Remote branches: "
		git branch -r --contains $commit | sort | grep -E "origin/($to_grep)"
	done
}
