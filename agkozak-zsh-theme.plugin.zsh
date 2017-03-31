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
_parse_git_branch() {
  local ref
  ref=$( command git symbolic-ref --quiet HEAD 2> /dev/null )
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # No git repo.
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  local git_status
  git_status="$( _parse_git_dirty )"
  echo "(${ref#refs/heads/}${git_status}) "
}

# Get current status of git repository
_parse_git_dirty() {
  local git_status dirty untracked ahead newfile renamed deleted bits
  git_status="$( git status 2>&1 | tee )"
  dirty="$( echo -n "${git_status}" 2> /dev/null | grep "modified:" &> /dev/null; echo "$?" )"
  untracked="$( echo -n "${git_status}" 2> /dev/null | grep "Untracked files" &> /dev/null; echo "$?" )"
  ahead="$( echo -n "${git_status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; echo "$?" )"
  newfile="$( echo -n "${git_status}" 2> /dev/null | grep "new file:" &> /dev/null; echo "$?" )"
  renamed="$( echo -n "${git_status}" 2> /dev/null | grep "renamed:" &> /dev/null; echo "$?" )"
  deleted="$( echo -n "${git_status}" 2> /dev/null | grep "deleted:" &> /dev/null; echo "$?" )"
  bits=''
  [[ ${renamed} == '0' ]] && bits=">${bits}"
  [[ ${ahead} == '0' ]] && bits="*${bits}"
  [[ ${newfile} == '0' ]] && bits="+${bits}"
  [[ ${untracked} == '0' ]] && bits="?${bits}"
  [[ ${deleted} == '0' ]] && bits="x${bits}"
  [[ ${dirty} == '0' ]] && bits="!${bits}"
  [[ ${bits} != '' ]] && echo " ${bits}" || echo ''
}

# Autoload zsh colors module if it hasn't been autloaded already
if ! whence -w colors > /dev/null 2>&1; then
	autoload -Uz colors
	colors
fi

mode_indicator="%{$fg_bold[black]%}%{$bg[white]%}"

_vi_mode_indicator() {
  echo "${${KEYMAP/vicmd/$mode_indicator}/(main|viins)/}"
}

# The main prompt
PROMPT='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|%2~|%~)%{$reset_color%} %{$fg[yellow]%}$( _parse_git_branch )%{$reset_color%}$( _vi_mode_indicator )%#%{$reset_color%} '

# The right prompt will show the exit code if it is not zero.
RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
