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

setopt PROMPT_SUBST

# Display current branch and status
_branch_status() {
  local ref
  ref=$( command git symbolic-ref --quiet HEAD 2> /dev/null )
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # No git repository here.
    ref=$( command git rev-parse --short HEAD 2> /dev/null ) || return
  fi
  echo "(${ref#refs/heads/}$( _branch_dirty )) "
}

# Display status of current branch
_branch_dirty() {
  local git_status bits

  git_status=$( git status 2>&1 )

  modified=$( grep -q 'modified:' <<< $git_status; echo "$?" )
  untracked=$( grep -q "Untracked files" <<< $git_status; echo "$?" )
  ahead=$( grep -q "Your branch is ahead of" <<<  $git_status; echo "$?" )
  newfile=$( grep -q "new file:" <<< $git_status; echo "$?" )
  renamed=$( grep -q "renamed:" <<< $git_status; echo "$?" )
  deleted=$( grep -q "deleted" <<< $git_status; echo "$?" )

  bits=''
  [[ $renamed = '0' ]] && bits=">${bits}"
  [[ $ahead = '0' ]] && bits="*${bits}"
  [[ $newfile = '0' ]] && bits="+${bits}"
  [[ $untracked = '0' ]] && bits="?${bits}"
  [[ $deleted = '0' ]] && bits="x${bits}"
  [[ $modified = '0' ]] && bits="!${bits}"
  if [[ ! $bits = '' ]]; then
    echo " $bits"
  else
    echo ''
  fi
}

_vi_mode_indicator() {
  echo "${${KEYMAP/vicmd/$mode_indicator}/(main|viins)/}"
}

# Autoload zsh colors module if it hasn't been autloaded already
if ! whence -w colors > /dev/null 2>&1; then
  autoload -Uz colors
  colors
fi

mode_indicator="%{$fg_bold[black]%}%{$bg[white]%}"

# The main prompt
PROMPT='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|%2~|%~)%{$reset_color%} %{$fg[yellow]%}$( _branch_status )%{$reset_color%}$( _vi_mode_indicator )%#%{$reset_color%} '

# The right prompt will show the exit code if it is not zero.
RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
