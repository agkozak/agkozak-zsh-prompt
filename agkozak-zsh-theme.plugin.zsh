#              _                 _
#   __ _  __ _| | _____ ______ _| | __
#  / _` |/ _` | |/ / _ \_  / _` | |/ /
# | (_| | (_| |   < (_) / / (_| |   <
#  \__,_|\__, |_|\_\___/___\__,_|_|\_\
#        |___/
#
# A dynamic color Git prompt for zsh
#
# Copyright (C) 2017 Alexandros Kozák
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
#
# https://github.com/agkozak/agkozak-zsh-theme
#
# shellcheck disable=SC2148

# Display current branch and status
_branch_status() {
  local ref branch
  ref=$(git symbolic-ref --quiet HEAD 2> /dev/null)
  case $? in        # See what the exit code is.
    0) ;;           # $ref contains the name of a checked-out branch.
    128) return ;;  # No Git repository here.
    # Otherwise, see if HEAD is in detached state.
    *) ref=$(git rev-parse --short HEAD 2> /dev/null) || return ;;
  esac
  branch=${ref#refs/heads/}
  printf ' (%s%s)' "$branch" "$(_branch_changes)"
}

# Display symbols representing the current branch's status
_branch_changes() {
  local git_status symbols

  git_status=$(command git status 2>&1)

  typeset -A messages   # An associative array whose keys correspond to text
                        # potentially found in the `git status` message, and
                        # whose values are the git status symbols in the prompt.

  # shellcheck disable=SC2190
  messages=(
              'renamed:'                '>'
              'Your branch is ahead of' '*'
              'new file:'               '+'
              'Untracked files'         '?'
              'deleted'                 'x'
              'modified:'               '!'
           )

  # shellcheck disable=SC2154
  for k in ${(@k)messages}; do
    case "$git_status" in
      *${k}*) symbols="${messages[$k]}${symbols}" ;;
    esac
  done

  [[ $symbols ]] && printf '%s' " $symbols"
}

_has_colors() {
  [[ $(tput colors) -ge 8 ]]
}

setopt PROMPT_SUBST

# shellcheck disable=SC2034
MODE_INDICATOR=''

zle-keymap-select() {
  zle reset-prompt
  zle -R
}

zle -N zle-keymap-select

# Redraw prompt when terminal size changes
TRAPWINCH() {
  zle && zle -R
}

# When the user enters vi command mode, the % or # in the prompt changes into
# a colon
_vi_mode_indicator() {
  case "$KEYMAP" in
    vicmd) printf '%s' ':' ;;
    *) printf '%s' '%#' ;;
  esac
}

if _has_colors; then
  # Autoload zsh colors module if it hasn't been autoloaded already
  if ! whence -w colors > /dev/null 2>&1; then
    autoload -Uz colors
    colors
  fi

  # shellcheck disable=SC2154
  PS1='%{$fg_bold[green]%}%n@%m%{$reset_color%} %{$fg_bold[blue]%}%(3~|.../%2~|%~)%{$reset_color%}%{$fg[yellow]%}$(_branch_status)%{$reset_color%} $(_vi_mode_indicator) '

  # The right prompt will show the exit code if it is not zero.
  RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"

else
  PS1='%n@%m %(3~|.../%2~|%~)$(_branch_status) $(_vi_mode_indicator) '
  # shellcheck disable=SC2034
  RPS1="%(?..(%?%))"
fi
