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

# Get current branch in git repository
_parse_git_branch() {
  local ref
  ref=$( command git symbolic-ref --quiet HEAD 2> /dev/null )
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # No git repo.
    ref=$( command git rev-parse --short HEAD 2> /dev/null ) || return
  fi
  echo "(${ref#refs/heads/}$( _parse_git_dirty )) "
}

# Get current status of git repository
_parse_git_dirty() {
  readonly modified='!'
  readonly deleted='x'
  readonly untracked='?'
  readonly newfile='+'
  readonly ahead='*'
  readonly renamed='>'

  local porcelain git_status

  porcelain=$( command git status --porcelain -b 2> /dev/null )

  # Modified
  if grep '^ M ' <<< "$porcelain" &> /dev/null \
    || grep '^AM ' <<< "$porcelain" &> /dev/null \
    || grep '^ T ' <<< "$porcelain" &> /dev/null; then
    git_status="$modified$git_status"
  fi

  # Deleted
  if grep '^ D ' <<< "$porcelain" &> /dev/null \
    || grep '^D  ' <<< "$porcelain" &> /dev/null \
    || grep '^AD ' <<< "$porcelain" &> /dev/null; then
    git_status="$deleted$git_status"
  fi

  # Untracked
  if grep '^?? ' <<< "$porcelain" &> /dev/null; then
    git_status="$untracked$git_status"
  fi

  # New file
  if grep '^A  ' <<< "$porcelain" &> /dev/null \
    || grep '^M  ' <<< "$porcelain" &> /dev/null; then
    git_status="$newfile$git_status"
  fi

  # Ahead
  if grep '^## [^ ]\+ .*ahead' <<< "$porcelain" &> /dev/null; then
    git_status="$ahead$git_status"
  fi

  # Renamed
  if grep '^R  ' <<< "$porcelain" &> /dev/null; then
    git_status="$renamed$git_status"
  fi

  [[ ${git_status} != '' ]] && echo " ${git_status}" || echo ''
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
PROMPT='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|%2~|%~)%{$reset_color%} %{$fg[yellow]%}$( _parse_git_branch )%{$reset_color%}$( _vi_mode_indicator )%#%{$reset_color%} '

# The right prompt will show the exit code if it is not zero.
RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
