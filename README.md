# .git_func
Common bash functions to simplify git operations.
```bash
$ cd $HOME
$ git clone https://github.com/dandandanliu915/.git_func.git
$ cd .git_func
$ bash deploy.sh
$ cd <project git repo> 
$ . ~/.bashrc
$ git_func_deploy // follow directions
```


Currently includes functions: 
- git_br_merged_remove
	- Remove merged local branches
- git_br_name 
	- Show current local branch name.
- git_br_pr_show
	- Show pull request related to the remote of local branch.
- git_br_pr_create 
	- Create pull-request for current branch.
- git_br_push
	- Push current local branch to remote, using the short branch name. Return 1 if failed somehow.
- git_br_remote_exists [remote branch name] 
	- Show if input branch name exists. Return 1 if not.
- git_br_reset
	- Reset current local branch to origin/master HEAD
- git_br_suffix [suffix]
	- Add suffix to current local branch name with "." as separator
- git_br_switch [local branch name]
	- Switch to another local branch while switching all local config files to git version
- git_br_ts
	- Show the timestamp when current local branch was created
- git_br_upstream_set [remote branch name]
	- Set remote branch to current local branch 
- git_br_upstream_show
	- Show the remote branch name of current local branch
- git_cherry_pick
	- Interactively prompt user to assist in performing cherry-pick of a commit to another remote branch in a safe way.
- git_commit_diff [commit id]
	- Show current/given commit difference to its previous version
- git_commit_id [commit id]
	- Show current/giveb commit id
- git_commit_list [commit id]
	- Show current/given commited file list
- git_commit_msg [commit id]
        - Show current/given commit message
- git_commit_show [commit id]
        - Show current/given commit summary
- git_config_local
	- Switch config files to local version
- git_config_standard
	- Switch config files to git version
- git_history
	- Show commit summary history
- git_log
	- Show local git operation history
- git_pr_list [-pr|--pr_number pr_number] [-au|--author author] [-rs|--reviewer reviewer] [-b|--head_branch head_branch] [-c|--head_commit head_commit] [-m|--merge_commit merge_commit] [-s state(open/closed/merged/all)] [--all_user] [--online]
	- Show current/given user related pull requests
- git_remove_only [file path]
	- Remove file from current commit. Revert commit to its previous version
- git_remove_restore_recommit [file path]
	- Remove file from current commit. Recommit with exactly same commit message. Restore the single file to its previous version.
- git_remove_retain_recommit [file path]
	- Remoce file from current commit. Recommit with exactly same commit message. Retain its modified version.
- git_show_ones_commits [user name]
	- Show current/given user's authored and committed commit summary history
- git_where_are_the_commits [-v|--verbose] [-a|--all] [-c|--commit commit_id] [-n|--num number] [-s|--start start date] [-e|--end end date]
	- Show which branches the current user's commits are pushed
	- where:
		- -v|--verbose	Show all branches. Otherwise show only CRITICAL_BRANCHES (configured for the git repo) when they all exist
		- -a|--all	Show all commits. Otherwise show commits not in all CRITICAL_BRANCHES yet
		- -c|--commit	Check for particular commit id
		- -n|--num	Check for recent # commits
		- -s|--start	Check for commits created later than start_date
		- -e|--end	Check for commits created later than end_date
