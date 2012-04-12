##
## Load with `autoload -U zgitinit; zgitinit'
##

typeset -gA zgit_info
zgit_info=()

zgit_chpwd_hook() {
	zgit_info_update
}

zgit_preexec_hook() {
	if [[ $2 == git\ * ]] || [[ $2 == *\ git\ * ]]; then
		zgit_precmd_do_update=1
	fi
}

zgit_precmd_hook() {
	if [ $zgit_precmd_do_update ]; then
		unset zgit_precmd_do_update
		zgit_info_update
	fi
}

zgit_info_update() {
	zgit_info=()

	local gitdir="$(git rev-parse --git-dir 2>/dev/null)"
	if [ $? -ne 0 ] || [ -z "$gitdir" ]; then
		return
	fi

	zgit_info[dir]=$gitdir
	zgit_info[bare]=$(git rev-parse --is-bare-repository)
	zgit_info[inwork]=$(git rev-parse --is-inside-work-tree)
}

zgit_isgit() {
	if [ -z "$zgit_info[dir]" ]; then
		return 1
	else
		return 0
	fi
}

zgit_inworktree() {
	zgit_isgit || return
	if [ "$zgit_info[inwork]" = "true" ]; then
		return 0
	else
		return 1
	fi
}

zgit_isbare() {
	zgit_isgit || return
	if [ "$zgit_info[bare]" = "true" ]; then
		return 0
	else
		return 1
	fi
}

zgit_head() {
	zgit_isgit || return 1

	if [ -z "$zgit_info[head]" ]; then
		local name=''
		name=$(git symbolic-ref -q HEAD)
		if [ $? -eq 0 ]; then
			if [[ $name == refs/(heads|tags)/* ]]; then
				name=${name#refs/(heads|tags)/}
			fi
		else
			name=$(git name-rev --name-only --no-undefined --always HEAD)
			if [ $? -ne 0 ]; then
				return 1
			elif [[ $name == remotes/* ]]; then
				name=${name#remotes/}
			fi
		fi
		zgit_info[head]=$name
	fi

	echo $zgit_info[head]
}

zgit_branch() {
	zgit_isgit || return 1
	zgit_isbare && return 1

	if [ -z "$zgit_info[branch]" ]; then
		local branch=$(git symbolic-ref HEAD 2>/dev/null)
		if [ $? -eq 0 ]; then
			branch=${branch##*/}
		else
			branch=$(git name-rev --name-only --always HEAD)
		fi
		zgit_info[branch]=$branch
	fi

	echo $zgit_info[branch]
	return 0
}

zgit_tracking_remote() {
	zgit_isgit || return 1
	zgit_isbare && return 1

	local branch
	if [ -n "$1" ]; then
		branch=$1
	elif [ -z "$zgit_info[branch]" ]; then
		branch=$(zgit_branch)
		[ $? -ne 0 ] && return 1
	else
		branch=$zgit_info[branch]
	fi

	local k="tracking_$branch"
	local remote
	if [ -z "$zgit_info[$k]" ]; then
		remote=$(git config branch.$branch.remote)
		zgit_info[$k]=$remote
	fi

	echo $zgit_info[$k]
	return 0
}

zgit_tracking_merge() {
	zgit_isgit || return 1
	zgit_isbare && return 1

	local branch
	if [ -z "$zgit_info[branch]" ]; then
		branch=$(zgit_branch)
		[ $? -ne 0 ] && return 1
	else
		branch=$zgit_info[branch]
	fi

	local remote=$(zgit_tracking_remote $branch)
	[ $? -ne 0 ] && return 1
	if [ -n "$remote" ]; then # tracking branch
		local merge=$(git config branch.$branch.merge)
		if [ $remote != "." ]; then
			merge=$remote/$(basename $merge)
		fi
		echo $merge
		return 0
	else
		return 1
	fi
}

zgit_isindexclean() {
	zgit_isgit || return 1
	if git diff --quiet --cached 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

zgit_isworktreeclean() {
	zgit_isgit || return 1
	if git diff --quiet 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

zgit_hasuntracked() {
	zgit_isgit || return 1
	local -a flist
	flist=($(git ls-files --others --exclude-standard))
	if [ $#flist -gt 0 ]; then
		return 0
	else
		return 1
	fi
}

zgit_hasunmerged() {
	zgit_isgit || return 1
	local -a flist
	flist=($(git ls-files -u))
	if [ $#flist -gt 0 ]; then
		return 0
	else
		return 1
	fi
}

zgit_svnhead() {
	zgit_isgit || return 1

	local commit=$1
	if [ -z "$commit" ]; then
		commit='HEAD'
	fi

	git show --raw $commit | \
		grep git-svn-id | \
			sed -re 's/^\s*git-svn-id: .*@([0-9]+).*$/\1/'
}

zgit_rebaseinfo() {
	zgit_isgit || return 1
	if [ -d $zgit_info[dir]/rebase-merge ]; then
		dotest=$zgit_info[dir]/rebase-merge
	elif [ -d $zgit_info[dir]/.dotest-merge ]; then
		dotest=$zgit_info[dir]/.dotest-merge
	elif [ -d .dotest ]; then
		dotest=.dotest
	else
		return 1
	fi

	zgit_info[dotest]=$dotest

	zgit_info[rb_onto]=$(cat "$dotest/onto")
	zgit_info[rb_upstream]=$(cat "$dotest/upstream")
	if [ -f "$dotest/orig-head" ]; then
		zgit_info[rb_head]=$(cat "$dotest/orig-head")
	elif [ -f "$dotest/head" ]; then
		zgit_info[rb_head]=$(cat "$dotest/head")
	fi
	zgit_info[rb_head_name]=$(cat "$dotest/head-name")

	return 0
}

zgitinit() {
	typeset -ga chpwd_functions
	typeset -ga preexec_functions
	typeset -ga precmd_functions
	chpwd_functions+='zgit_chpwd_hook'
	preexec_functions+='zgit_preexec_hook'
	precmd_functions+='zgit_precmd_hook'
}

zgitinit
zgit_info_update

# vim:set ft=zsh:
# grb prompt theme
# copied from wunjo prompt theme and modified

autoload -U zgitinit
zgitinit

prompt_grb_help () {
  cat <<'EOF'

  prompt grb

EOF
}

revstring() {
	git describe --always $1 2>/dev/null ||
	git rev-parse --short $1 2>/dev/null
}

coloratom() {
	local off=$1 atom=$2
	if [[ $atom[1] == [[:upper:]] ]]; then
		off=$(( $off + 60 ))
	fi
	echo $(( $off + $colorcode[${(L)atom}] ))
}
colorword() {
	local fg=$1 bg=$2 att=$3
	local -a s

	if [ -n "$fg" ]; then
		s+=$(coloratom 30 $fg)
	fi
	if [ -n "$bg" ]; then
		s+=$(coloratom 40 $bg)
	fi
	if [ -n "$att" ]; then
		s+=$attcode[$att]
	fi

	echo "%{"$'\e['${(j:;:)s}m"%}"
}

function minutes_since_last_commit {
    now=`date +%s`
    last_commit=`git log --pretty=format:'%at' -1 2>/dev/null`
    if $lastcommit ; then
      seconds_since_last_commit=$((now-last_commit))
      minutes_since_last_commit=$((seconds_since_last_commit/60))
      echo $minutes_since_last_commit
    else
      echo "-1"
    fi
}

function prompt_grb_scm_time_since_commit() {
	local -A pc
	pc=(${(kv)wunjo_prompt_colors})

	if zgit_inworktree; then
        local MINUTES_SINCE_LAST_COMMIT=`minutes_since_last_commit`
        if [ "$MINUTES_SINCE_LAST_COMMIT" -eq -1 ]; then
          COLOR="$pc[scm_time_uncommitted]"
          local SINCE_LAST_COMMIT="${COLOR}uncommitted$pc[reset]"  
        else
          if [ "$MINUTES_SINCE_LAST_COMMIT" -gt 30 ]; then
            COLOR="$pc[scm_time_long]"
          elif [ "$MINUTES_SINCE_LAST_COMMIT" -gt 10 ]; then
            COLOR="$pc[scm_time_medium]"
          else
            COLOR="$pc[scm_time_short]"
          fi
          local SINCE_LAST_COMMIT="${COLOR}$(minutes_since_last_commit)m$pc[reset]"
        fi
        echo $SINCE_LAST_COMMIT
    fi
}

function prompt_grb_scm_info() {
    if zgit_inworktree; then
        echo "($(prompt_wunjo_scm_branch))"
    fi
}

prompt_grb_setup() {
    local verbose
    if [[ $TERM == screen* ]] && [ -n "$STY" ]; then
      verbose=
    else
      verbose=1
    fi
  
    typeset -A colorcode
    colorcode[black]=0
    colorcode[red]=1
    colorcode[green]=2
    colorcode[yellow]=3
    colorcode[blue]=4
    colorcode[magenta]=5
    colorcode[cyan]=6
    colorcode[white]=7
    colorcode[default]=9
    colorcode[k]=$colorcode[black]
    colorcode[r]=$colorcode[red]
    colorcode[g]=$colorcode[green]
    colorcode[y]=$colorcode[yellow]
    colorcode[b]=$colorcode[blue]
    colorcode[m]=$colorcode[magenta]
    colorcode[c]=$colorcode[cyan]
    colorcode[w]=$colorcode[white]
    colorcode[.]=$colorcode[default]
  
    typeset -A attcode
    attcode[none]=00
    attcode[bold]=01
    attcode[faint]=02
    attcode[standout]=03
    attcode[underline]=04
    attcode[blink]=05
    attcode[reverse]=07
    attcode[conceal]=08
    attcode[normal]=22
    attcode[no-standout]=23
    attcode[no-underline]=24
    attcode[no-blink]=25
    attcode[no-reverse]=27
    attcode[no-conceal]=28
  
    local -A pc
    pc[default]='default'
    pc[date]='cyan'
    pc[time]='Blue'
    pc[host]='Green'
    pc[user]='cyan'
    pc[punc]='yellow'
    pc[line]='magenta'
    pc[hist]='green'
    pc[path]='Cyan'
    pc[shortpath]='default'
    pc[rc]='red'
    pc[scm_branch]='green'
    pc[scm_commitid]='Yellow'
    pc[scm_status_dirty]='Red'
    pc[scm_status_staged]='Green'
    pc[scm_time_short]='green'
    pc[scm_time_medium]='yellow'
    pc[scm_time_long]='red'
    pc[scm_time_uncommitted]='Magenta'
    pc[#]='Yellow'
    for cn in ${(k)pc}; do
      pc[${cn}]=$(colorword $pc[$cn])
    done
    pc[reset]=$(colorword . . 00)

	typeset -Ag wunjo_prompt_colors
	wunjo_prompt_colors=(${(kv)pc})

	local p_date p_line p_rc

	p_date="$pc[date]%D{%Y-%m-%d} $pc[time]%D{%T}$pc[reset]"

	p_line="$pc[line]%y$pc[reset]"

	PROMPT=
	if [ $verbose ]; then
		PROMPT+="$pc[host]%m$pc[reset]"
	fi
	#PROMPT+="$pc[path]%(2~.%~.%/)$pc[reset]"
	#PROMPT+="\$(prompt_wunjo_scm_status)"
	#PROMPT+="%(?.. $pc[rc]exited %1v$pc[reset])"
        #PROMPT+=""
	#PROMPT+="($pc[hist]%h$pc[reset])"
	PROMPT+=":$pc[shortpath]%1~$pc[reset]"
        PROMPT+="($pc[scm_branch]\$(prompt_wunjo_scm_branch)$pc[reset])"
	PROMPT+=" $pc[#]\$$pc[reset] "

    #RPROMPT=
    #if [ $verbose ]; then
    #	RPROMPT+="$p_date "
    #fi
    #RPROMPT+="$pc[user]%n$pc[reset]"
    #RPROMPT+=" $p_line"

	export PROMPT RPROMPT
	precmd_functions+='prompt_wunjo_precmd'
}

function git_time_since_commit() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Only proceed if there is actually a commit.
        if [[ $(git log 2>&1 > /dev/null | grep -c "^fatal: bad default revision") == 0 ]]; then
            # Get the last commit.
            last_commit=`git log --pretty=format:'%at' -1 2> /dev/null`
            now=`date +%s`
            seconds_since_last_commit=$((now-last_commit))

            # Totals
            MINUTES=$((seconds_since_last_commit / 60))
            HOURS=$((seconds_since_last_commit/3600))

            # Sub-hours and sub-minutes
            DAYS=$((seconds_since_last_commit / 86400))
            SUB_HOURS=$((HOURS % 24))
            SUB_MINUTES=$((MINUTES % 60))

            if [[ -n $(git status -s 2> /dev/null) ]]; then
                if [ "$MINUTES" -gt 30 ]; then
                    COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_LONG"
                elif [ "$MINUTES" -gt 10 ]; then
                    COLOR="$ZSH_THEME_GIT_TIME_SHORT_COMMIT_MEDIUM"
                else
                    COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_SHORT"
                fi
            else
                COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL"
            fi

            if [ "$HOURS" -gt 24 ]; then
                echo "($COLOR${DAYS}d${SUB_HOURS}h${SUB_MINUTES}m%{$reset_color%}|"
            elif [ "$MINUTES" -gt 60 ]; then
                echo "($COLOR${HOURS}h${SUB_MINUTES}m%{$reset_color%}|"
            else
                echo "($COLOR${MINUTES}m%{$reset_color%}|"
            fi
        else
            COLOR="$ZSH_THEME_GIT_TIME_SINCE_COMMIT_NEUTRAL"
            echo "($COLOR~|"
        fi
    fi
}
prompt_wunjo_precmd() {
	local ex=$?
	psvar=()

	if [[ $ex -ge 128 ]]; then
		sig=$signals[$ex-127]
		psvar[1]="sig${(L)sig}"
	else
		psvar[1]="$ex"
	fi
}

prompt_wunjo_scm_status() {
	zgit_isgit || return
	local -A pc
	pc=(${(kv)wunjo_prompt_colors})

	head=$(zgit_head)
	gitcommit=$(revstring $head)

	local -a commits

	if zgit_rebaseinfo; then
		orig_commit=$(revstring $zgit_info[rb_head])
		orig_name=$(git name-rev --name-only $zgit_info[rb_head])
		orig="$pc[scm_branch]$orig_name$pc[punc]($pc[scm_commitid]$orig_commit$pc[punc])"
		onto_commit=$(revstring $zgit_info[rb_onto])
		onto_name=$(git name-rev --name-only $zgit_info[rb_onto])
		onto="$pc[scm_branch]$onto_name$pc[punc]($pc[scm_commitid]$onto_commit$pc[punc])"

		if [ -n "$zgit_info[rb_upstream]" ] && [ $zgit_info[rb_upstream] != $zgit_info[rb_onto] ]; then
			upstream_commit=$(revstring $zgit_info[rb_upstream])
			upstream_name=$(git name-rev --name-only $zgit_info[rb_upstream])
			upstream="$pc[scm_branch]$upstream_name$pc[punc]($pc[scm_commitid]$upstream_commit$pc[punc])"
			commits+="rebasing $upstream$pc[reset]..$orig$pc[reset] onto $onto$pc[reset]"
		else
			commits+="rebasing $onto$pc[reset]..$orig$pc[reset]"
		fi

		local -a revs
		revs=($(git rev-list $zgit_info[rb_onto]..HEAD))
		if [ $#revs -gt 0 ]; then
			commits+="\n$#revs commits in"
		fi

		if [ -f $zgit_info[dotest]/message ]; then
			mess=$(head -n1 $zgit_info[dotest]/message)
			commits+="on $mess"
		fi
	elif [ -n "$gitcommit" ]; then
		commits+="on $pc[scm_branch]$head$pc[punc]($pc[scm_commitid]$gitcommit$pc[punc])$pc[reset]"
		local track_merge=$(zgit_tracking_merge)
		if [ -n "$track_merge" ]; then
			if git rev-parse --verify -q $track_merge >/dev/null; then
				local track_remote=$(zgit_tracking_remote)
				local tracked=$(revstring $track_merge 2>/dev/null)

				local -a revs
				revs=($(git rev-list --reverse $track_merge..HEAD))
				if [ $#revs -gt 0 ]; then
					local base=$(revstring $revs[1]~1)
					local base_name=$(git name-rev --name-only $base)
					local base_short=$(revstring $base)
					local word_commits
					if [ $#revs -gt 1 ]; then
						word_commits='commits'
					else
						word_commits='commit'
					fi

					local conj="since"
					if [[ "$base" == "$tracked" ]]; then
						conj+=" tracked"
						tracked=
					fi
					commits+="$#revs $word_commits $conj $pc[scm_branch]$base_name$pc[punc]($pc[scm_commitid]$base_short$pc[punc])$pc[reset]"
				fi

				if [ -n "$tracked" ]; then
					local track_name=$track_merge
					if [[ $track_remote == "." ]]; then
						track_name=${track_name##*/}
					fi
					tracked=$(revstring $tracked)
					commits+="tracking $pc[scm_branch]$track_name$pc[punc]"
					if [[ "$tracked" != "$gitcommit" ]]; then
						commits[$#commits]+="($pc[scm_commitid]$tracked$pc[punc])"
					fi
					commits[$#commits]+="$pc[reset]"
				fi
			fi
		fi
	fi

	gitsvn=$(git rev-parse --verify -q --short git-svn)
	if [ $? -eq 0 ]; then
		gitsvnrev=$(zgit_svnhead $gitsvn)
		gitsvn=$(revstring $gitsvn)
		if [ -n "$gitsvnrev" ]; then
			local svninfo=''
			local -a revs
			svninfo+="$pc[default]svn$pc[punc]:$pc[scm_branch]r$gitsvnrev"
			revs=($(git rev-list git-svn..HEAD))
			if [ $#revs -gt 0 ]; then
				svninfo+="$pc[punc]@$pc[default]HEAD~$#revs"
				svninfo+="$pc[punc]($pc[scm_commitid]$gitsvn$pc[punc])"
			fi
			commits+=$svninfo
		fi
	fi

	if [ $#commits -gt 0 ]; then
		echo -n " ${(j: :)commits}"
	fi
}

prompt_wunjo_scm_branch() {
	zgit_isgit || return
	local -A pc
	pc=(${(kv)wunjo_prompt_colors})

	echo -n "$pc[punc]$pc[scm_branch]$(zgit_head)"

	if zgit_inworktree; then
		if ! zgit_isindexclean; then
			echo -n "$pc[scm_status_staged]+"
		fi

		local -a dirty
		if ! zgit_isworktreeclean; then
			dirty+='!'
		fi

		if zgit_hasunmerged; then
			dirty+='*'
		fi

		if zgit_hasuntracked; then
			dirty+='?'
		fi

		if [ $#dirty -gt 0 ]; then
			echo -n "$pc[scm_status_dirty]${(j::)dirty}"
		fi
	fi

	echo $pc[reset]
}

prompt_grb_setup "$@"

# vim:set ft=zsh:

