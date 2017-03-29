#              _                 _
#   __ _  __ _| | _____ ______ _| | __
#  / _` |/ _` | |/ / _ \_  / _` | |/ /
# | (_| | (_| |   < (_) / / (_| |   <
#  \__,_|\__, |_|\_\___/___\__,_|_|\_\
#        |___/
#
# agkozak zsh theme
#
# https://github.com/agkozak/agkozak-zsh-theme
#
# Functions derived from https://github.com/jmatth/ezprompt/blob/master/js/easyprompt.js

setopt PROMPT_SUBST

# Get current branch in git repository
function parse_git_branch {
  BRANCH=$( git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/' )
  if [[ ! "${BRANCH}" == "" ]]
  then
    STAT=$( parse_git_dirty )
    echo "(${BRANCH}${STAT}) "
  else
    echo ""
  fi
}

# Get current status of git repository
function parse_git_dirty {
  git_status=$( git status 2>&1 | tee )
  dirty=$( echo -n "${git_status}" 2> /dev/null | grep "modified:" &> /dev/null; echo "$?" )
  untracked=$( echo -n "${git_status}" 2> /dev/null | grep "Untracked files" &> /dev/null; echo "$?" )
  ahead=$( echo -n "${git_status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; echo "$?" )
  newfile=$( echo -n "${git_status}" 2> /dev/null | grep "new file:" &> /dev/null; echo "$?" )
  renamed=$( echo -n "${git_status}" 2> /dev/null | grep "renamed:" &> /dev/null; echo "$?" )
  deleted=$( echo -n "${git_status}" 2> /dev/null | grep "deleted:" &> /dev/null; echo "$?" )
  bits=''
  [[ "${renamed}" == "0" ]] && bits=">${bits}"
  [[ "${ahead}" == "0" ]] && bits="*${bits}"
  [[ "${newfile}" == "0" ]] && bits="+${bits}"
  [[ "${untracked}" == "0" ]] && bits="?${bits}"
  [[ "${deleted}" == "0" ]] && bits="x${bits}"
  [[ "${dirty}" == "0" ]] && bits="!${bits}"
  if [[ ! "${bits}" == "" ]]; then
    echo " ${bits}"
  else
    echo ""
  fi
}

# Autoload zsh colors module if it hasn't been autloaded already
if ! whence -w colors > /dev/null 2>&1; then
	autoload -Uz colors
	colors
fi

MODE_INDICATOR="%{$fg_bold[red]%}"

# If the vi-mode plugin is not loaded, vi_mode_prompt_info() should do nothing
if ! whence -w vi_mode_prompt_info > /dev/null 2>&1; then
  vi_mode_prompt_info() {
    echo ''
  }
fi

# The main prompt
PROMPT='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|%2~|%~)%{$reset_color%} %{$fg[yellow]%}$( parse_git_branch )%{$reset_color%}$( vi_mode_prompt_info )%%%{$reset_color%} '

# The right prompt will show the exit code if it is not zero.
RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
