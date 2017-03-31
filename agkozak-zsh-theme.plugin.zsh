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
  readonly modified='!'
  readonly deleted='x'
  readonly untracked='?'
  readonly newfile='+'
  readonly ahead='*'
  readonly renamed='>'

  local porcelain git_status

  porcelain=$( command git status --porcelain -b 2> /dev/null )

  # Modified
  if grep -q '^ M ' <<< "$porcelain" \
    || grep -q '^AM ' <<< "$porcelain" \
    || grep -q '^ T ' <<< "$porcelain"; then
    git_status="$modified$git_status"
  fi

  # Deleted
  if grep -q '^ D ' <<< "$porcelain" \
    || grep -q '^D  ' <<< "$porcelain" \
    || grep -q '^AD ' <<< "$porcelain"; then
    git_status="$deleted$git_status"
  fi

  # Untracked
  if grep -q '^?? ' <<< "$porcelain"; then
    git_status="$untracked$git_status"
  fi

  # New file
  if grep -q '^A  ' <<< "$porcelain" \
    || grep -q '^M  ' <<< "$porcelain"; then
    git_status="$newfile$git_status"
  fi

  # Ahead
  # TODO: Does not work with antiquated versions of Git
  if grep -q '^## [^ ]\+ .*ahead' <<< "$porcelain"; then
    git_status="$ahead$git_status"
  fi

  # Renamed
  if grep -q '^R  ' <<< "$porcelain"; then
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
PROMPT='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|%2~|%~)%{$reset_color%} %{$fg[yellow]%}$( _branch_status )%{$reset_color%}$( _vi_mode_indicator )%#%{$reset_color%} '

# The right prompt will show the exit code if it is not zero.
RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
