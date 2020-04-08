source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"/git_func_helper.sh

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
	# changed=`git diff --name-only origin/master $(git_br_name)`
	branch_status=`git rev-list --left-right --count origin/master...$(git_br_name)`
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

function git_br_name() {
	git branch --show-current
}

function git_br_ts() {
	git reflog show --date=format:'%Y-%m-%d %H:%M:%S' --all | sed "s!^.*refs/!refs/!" | grep "branch:"
}

function git_br_suffix() {
	suffix="$1"
	git branch -m "$(git_br_name).$1"
}

function git_br_upstream_set() {
	remote=`[[ -n "$1" ]] && echo "$1" || echo "origin/master"`
	echo $remote | grep -E "^origin/" >/dev/null 2>&1
	if [[ $? -ne 0 ]]
	then
		remote="origin/$remote"
	fi
	git branch --set-upstream-to "$remote"
}

function git_br_upstream_show() {
	local_branch=`[[ -n "$1" ]] && echo "$1" || git_br_name`
	#git status -sb  | grep -E "^#" | awk -F " " '{print $2}' | awk -F "." '{print $NF}'
	eval "git rev-parse --abbrev-ref --symbolic-full-name $local_branch@{upstream} 2>/dev/null"
}

function git_br_merged_remove() {
	git switch master; git pull
	local_branches=`git branch | grep -vE "^\*" |  awk -F " " '{print $1}'`
	for local_branch in $local_branches
	do
		remote_branch=`git_br_upstream_show $local_branch`
		echo $local_branch $remote_branch
		if [[ -z $remote_branch ]]
		then
			rc=0
		else
			git branch -r --merged | grep "$remote_branch" > /dev/null
			rc=$?
		fi
		if [[ $remote_branch = "origin/master" || $rc -eq 0 ]]
		then
			continue
		fi
		echo "-- Removing $local_branch"
		git branch -d "$local_branch"
	done
}

function git_br_push() {
	git cherry -v master
	read -p "Are you confirmed to push these commits? (Yn) " yn
        case $yn in
                [Yy]*) ;;
                *) echo "Canceled"; return 1 ;;
        esac

	git_br_name_short=`git_br_name | awk -F "." '{print $1}'`
	echo $git_br_name_short| grep master > /dev/null
	if [[ $? -eq 0 ]]
	then
		echo "Pushing master is not recommended"
		return 1
	elif [[ -n $(git_br_upstream_show 2>/dev/null) ]]
	then
		if [[ "$(git_br_upstream_show)" != "origin/$git_br_name_short" ]]
		then
			echo "Upstream remote branch exists and not matching: $(git_br_upstream_show)"
			return 1
		fi
	fi

	git push -u origin `git_br_name`:"$git_br_name_short"
}

function git_br_remote_exists() {
	temp=`git ls-remote --exit-code --heads origin "$1"`
	if [[ -z "$temp" ]]
	then
		echo "-- Branch origin/$1 does not exist now! Check again"
		return 1
	fi
}

function git_br_pr_show() {
	__hub_exists || return 1

	git_br_upstream=`git_br_upstream_show | awk -F "/" '{print $NF}'`
	hub pr list -f "|pr_number:%I|author:%au|reviewers:%rs|state:%S|pr_state:%pS|title:%t|url:%U%n" --head "$git_br_upstream" -s all
}

function git_br_pr_create() {
	__hub_exists || return 1

	git cherry -v master
	read -p "Are you confirmed to pull request these commits? (Yn) " yn
	case $yn in
		[Yy]*) ;;
		*) echo "Canceled"; return 1 ;;
	esac

	git_br_upstream=`git_br_upstream_show | awk -F "/" '{print $NF}'`
	git_commit_msg
	read -p "Press any key to continue ..." yn

	__git_func_config
	hub pull-request --push --head "$git_br_upstream" --reviewer "$PR_REVIEWER" --assign "$PR_ASSIGNEE" --labels "$PR_LABELS"

	git_pr_list --online
}

function git_pr_list() {
	__hub_exists || return 1

	# Default values
	pr_number=""
	author=""
	reviewer=""
	head_branch=""
	head_commit=""
	merge_commit=""
	state="open"
	all_user=""
	online=""
	regex=""

	# Get arguments
        while [[ $# -gt 0 ]]
        do
        key="$1"

        case $key in
		-pr|--pr_number)
		pr_number="$2"
		shift
		shift
		;;
                -au|--author)
                author="$2"
                shift
                shift
                ;;
		-rv|--reviewer)
		reviewer="$2"
		shift
		shift
		;;
		-b|--head_branch)
		head_branch="$2"
		shift
		shift
		;;
		-c|--head_commit)
		head_commit="$2"
		shift
		shift
		;;
		-m|--merge_commit)
		merge_commit="$2"
		shift
		shift
		;;
		-s|--state)
		state="$2"
		case $state in
			open|closed|merged|all)
			;;
			*)
			echo "Invalid state: $state, must be one of open|closed|merged|all"
			return 1
		esac
		shift
		shift
		;;
		--all_user)
		all_user="true"
		shift
		;;
		--online)
		online="true"
		shift
		;;
		-h|--help)
		git_help -v | grep "${FUNCNAME[0]}"
		return
		;;
		*)
		echo "Invalid argument: $key"
		git_help -v | grep "${FUNCNAME[0]}"
		return 1
		;;
	esac
	done

	GIT_DIR=`__git_repo_check`
	PR_LIST=$GIT_DIR/.git_func_config_pr_list
	if [[ -n $online || ! -e $PR_LIST || ! -f  $PR_LIST ]]
	then
		echo "Updating from online ..."
		date +'%Y-%m-%d %H:%M:%S %A' > $PR_LIST.temp
		hub pr list -f '|pr_number:%I|author:%au|reviewers:%rs|state:%S|pr_state:%pS|head_branch:%H|head_commit:%sH|merge_commit:%sm|created_at:%cI|updated_at:%uI|merged_at:%mI|title:%t|url:%U%n' -s all >> $PR_LIST.temp
		if [[ $? -eq 0 ]]
		then
			mv $PR_LIST.temp $PR_LIST
		fi
	fi

        if [[ -z $author ]]
        then
                author=`[[ -n $(git config user.name) ]] && echo $(git config user.name) || echo $USER`
        fi

	regex=$regex$([[ -z $all_user ]] && echo " | grep -iE \"\|author:[^\|]*$author[^\|]*\|\"" || echo "")
	regex=$regex$([[ -n $reviewer ]] && echo " | grep -E \"\|reviewers:[^\|]*$reviewer[^\|]*\|\"" || echo "")
	regex=$regex$([[ -n $pr_number ]] && echo " | grep -E \"\|pr_number:[^\|]*$pr_number[^\|]*\|\"" || echo "")
	regex=$regex$([[ -n $head_branch ]] && echo " | grep -E \"\|head_branch:[^\|]*$head_branch[^\|]*\|\"" || echo "")
	regex=$regex$([[ -n $head_commit ]] && echo " | grep -E \"\|head_commit:[^\|]*$head_commit[^\|]*\|\"" || echo "")
	regex=$regex$([[ -n $merge_commit ]] && echo " | grep -E \"\|merge_commit:[^\|]*$merge_commit[^\|]*\|\"" || echo "")
	regex=$regex$([[ ! $state = "all" ]] && echo " | grep -E \"\|pr_state:[^\|]*$state[^\|]*\|\"" || echo "")
	#echo "$regex"

	echo "Searching for criteria: "$([[ -n $pr_number ]] && echo "pr_number: $pr_number, " || echo "")$([[ -n $author ]] && echo "author: $author, " || echo "")$([[ -n $reviewer ]] && echo "reviewer: $reviewer, " || echo "")$([[ -n $head_branch ]] && echo "head_branch: $head_branch, " || echo "")$([[ -n $head_commit ]] && echo "head_commit: $head_commit, " || echo "")$([[ -n $merge_commit ]] && echo "merge_commit: $merge_commit, " || echo "")$([[ -n $state ]] && echo "state: $state, " || echo "")

	line_limit=10
	line_cnt=`eval "cat $PR_LIST $regex" | wc -l`
	if [[ $line_cnt -eq 0 ]]
	then
		echo "No result found"
		return
	elif [[ $line_cnt -gt $line_limit ]]
	then
		read -p "Found $line_cnt results, show in console? (Yn)" yn
		case $yn in
			[Yy]*) ;;
			*)
			echo "Show first $line_limit results ..."
			eval "head -1 $PR_LIST; cat $PR_LIST $regex | head -$line_limit"
			return
			;;
		esac
	fi
	eval "head -1 $PR_LIST; cat $PR_LIST $regex"
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
	git_br_remote_exists $branch
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

	_safe_exit "FINISHED"; return
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

function git_br_reset() {
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
	__git_func_config

	files="$CONFIG_FILE_LIST"
	for file in $files
        do
                __switch_to_local $file
        done
}

function git_config_standard() {
	__git_func_config

        files="$CONFIG_FILE_LIST"

        for file in $files
        do
		__switch_to_standard $file
        done
}

function git_br_switch() {
	if [ $# -ne 1 ]
        then
                echo "Invalid input"
                return 1
        fi

	branch=$1

	__git_func_config

        files="$CONFIG_FILE_LIST"
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
	to_grep=`echo "^  origin/($CRITICAL_BRANCHES)$" | tr "," "|"`
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
		-h|--help)
                git_help -v | grep "${FUNCNAME[0]}"
                return
                ;;
		*)
		echo "Invalid input: $1"
		git_help -v | grep "${FUNCNAME[0]}"
		return 1
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
		if [[ -n $start ]] && ! date -f "%Y-%m-%d" -j "$start" >>/dev/null 2>&1
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
		echo "Check if critical branches $CRITICAL_BRANCHES exist..."
		for b in `echo $CRITICAL_BRANCHES | tr "," "\n"`
		do
			git_br_remote_exists "$b"
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
			temp=`git branch -r --contains $commit | grep -E "$to_grep" | wc -l`
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
		git branch -r --contains $commit | sort | grep -E "$to_grep"
	done
}
