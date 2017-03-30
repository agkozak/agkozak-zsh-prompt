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
  local git_branch="$( git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/' )"
  if [[ ! ${git_branch} == '' ]]
  then
    local git_status="$( _parse_git_dirty )"
    echo "(${git_branch}${git_status}) "
  else
    echo ''
  fi
}

# Get current status of git repository
_parse_git_dirty() {
  local git_status="$( git status 2>&1 | tee )"
  local dirty="$( echo -n "${git_status}" 2> /dev/null | grep "modified:" &> /dev/null; echo "$?" )"
  local untracked="$( echo -n "${git_status}" 2> /dev/null | grep "Untracked files" &> /dev/null; echo "$?" )"
  local ahead="$( echo -n "${git_status}" 2> /dev/null | grep "Your branch is ahead of" &> /dev/null; echo "$?" )"
  local newfile="$( echo -n "${git_status}" 2> /dev/null | grep "new file:" &> /dev/null; echo "$?" )"
  local renamed="$( echo -n "${git_status}" 2> /dev/null | grep "renamed:" &> /dev/null; echo "$?" )"
  local deleted="$( echo -n "${git_status}" 2> /dev/null | grep "deleted:" &> /dev/null; echo "$?" )"
  local bits=''
  [[ ${renamed} == '0' ]] && bits=">${bits}"
  [[ ${ahead} == '0' ]] && bits="*${bits}"
  [[ ${newfile} == '0' ]] && bits="+${bits}"
  [[ ${untracked} == '0' ]] && bits="?${bits}"
  [[ ${deleted} == '0' ]] && bits="x${bits}"
  [[ ${dirty} == '0' ]] && bits="!${bits}"
  if [[ ! ${bits} == '' ]]; then
    echo " ${bits}"
  else
    echo ''
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
    :
  }
fi

# The main prompt
PROMPT='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|%2~|%~)%{$reset_color%} %{$fg[yellow]%}$( _parse_git_branch )%{$reset_color%}$( vi_mode_prompt_info )%#%{$reset_color%} '

# The right prompt will show the exit code if it is not zero.
RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
