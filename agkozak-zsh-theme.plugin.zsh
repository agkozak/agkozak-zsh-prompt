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
  local ref ret branch
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # No git repository here.
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  branch="${ref#refs/heads/}"
  echo "(${branch}$(_branch_changes)) "
}

# Display status of current branch
_branch_changes() {
  local git_status symbols

  git_status=$(command git status 2>&1)

  declare -A messages   # An associative array whose keys correspond to text
                        # potentially found in the `git status` message, and
                        # whose values are the git status symbols in the prompt.
  messages=(
              'renamed:'                '>'
              'Your branch is ahead of' '*'
              'new file:'               '+'
              'Untracked files'         '?'
              'deleted'                 'x'
              'modified:'               '!'
           )

  for k in ${(@k)messages}; do
    case "$git_status" in
      *${k}*) symbols="${messages[$k]}${symbols}" ;;
    esac
  done

  if [[ ! $symbols = '' ]]; then
    echo " $symbols"
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
PROMPT='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|%2~|%~)%{$reset_color%} %{$fg[yellow]%}$(_branch_status)%{$reset_color%}$(_vi_mode_indicator)%#%{$reset_color%} '

# The right prompt will show the exit code if it is not zero.
RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
