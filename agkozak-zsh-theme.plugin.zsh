#              _                 _
#   __ _  __ _| | _____ ______ _| | __
#  / _` |/ _` | |/ / _ \_  / _` | |/ /
# | (_| | (_| |   < (_) / / (_| |   <
#  \__,_|\__, |_|\_\___/___\__,_|_|\_\
#        |___/
#
# A dynamic color prompt for zsh with Git, vi mode, and exit status indicators
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

# $psvar[] Usage
#
# $psvar Index  Prompt String Equivalent    Usage
#
# $psvar[1]     %1v                         Hostname/abbreviated hostname (only
#                                           displayed for SSH connections)
# $psvar[2]     %2v                         Working directory or abbreviation
#                                           thereof
# $psvar[3]     %3v                         Current working Git branch, along
#                                           with indicator of changes made

setopt PROMPT_SUBST

# Set $AGKOZAK_PROMPT_DIRTRIM in .zshrc to desired length of displayed path
[[ -z $AGKOZAK_PROMPT_DIRTRIM ]] && AGKOZAK_PROMPT_DIRTRIM=2

_is_ssh() {
  if [[ -n $SSH_CLIENT ]] || [[ -n $SSH_TTY ]]; then
    true
  else
    case $EUID in
      0)
        case $(ps -o comm= -p $PPID) in
          sshd|*/sshd) true ;;
        esac
        ;;
      *) false;
    esac
  fi
}

_has_colors() {
  [[ $(tput colors) -ge 8 ]]
}

############################################################
# Emulation of bash's PROMPT_DIRTRIM for zsh
#
# In $PWD, substitute $HOME with ~; if the remainder of the
# $PWD has more than two directory elements to display,
# abbreviate it with '...', e.g.
#
#   $HOME/dotfiles/polyglot/img
#
# will be displayed as
#
#   ~/.../polyglot/img
#
# Arguments
#  $1 Number of directory elements to display
############################################################
_prompt_dirtrim() {
  local dir_count last_two_dirs
  [[ $1 -lt 1 ]] && set 2 # $POLYGLOT_PROMPT_DIRTRIM should not be less than 1
  dir_count=$(echo "${PWD#$HOME}" | awk -F/ '{c += NF - 1} END {print c}')
  if [[ $dir_count -le $1 ]]; then
      # shellcheck disable=SC2088
      case $PWD in
        $HOME*) printf '~%s' "${PWD#$HOME}" ;;
        *) printf '%s' "$PWD" ;;
      esac
  else
    last_two_dirs=$(echo "${PWD#$HOME}" \
      | awk '{ for(i=length();i!=0;i--) x=(x substr($0,i,1))  }{print x;x=""}' \
      | cut -d '/' -f-"$1" \
      | awk '{ for(i=length();i!=0;i--) x=(x substr($0,i,1))  }{print x;x=""}')
      # shellcheck disable=SC2088
      case $PWD in
        $HOME*) printf '~/.../%s' "$last_two_dirs" ;;
        *) printf '.../%s' "$last_two_dirs" ;;
      esac
  fi
}

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

  # $messages is an associative array whose keys are text to be looked for in
  # $git_status and whose values are symbols used in the prompt to represent
  # changes to the working branch
  declare -A messages

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
    case $git_status in
      *${k}*) symbols="${messages[$k]}${symbols}" ;;
    esac
  done

  [[ ! -z $symbols ]] && printf ' %s' "$symbols"
}

###########################################################
# Runs right before the prompt is displayed
#
# 1) Imitates bash's PROMPT_DIRTRIM behavior
# 2) Calculates working branch and working copy status
###########################################################
precmd() {
  psvar[2]=$(_prompt_dirtrim $AGKOZAK_PROMPT_DIRTRIM)
  # shellcheck disable=SC2119
  psvar[3]=$(_branch_status)
}

# When the user enters vi command mode, the % or # in the prompt changes into
# a colon
_vi_mode_indicator() {
  case $KEYMAP in
    vicmd) printf '%s' ':' ;;
    *) printf '%s' '%#' ;;
  esac
}

# Redraw prompt when vi mode changes
zle-keymap-select() {
  zle reset-prompt
  zle -R
}

# Redraw prompt when terminal size changes
TRAPWINCH() {
  zle && zle -R
}

zle -N zle-keymap-select

if _is_ssh; then
  psvar[1]=$(print -P "@%m")
else
  # shellcheck disable=SC2034
  psvar[1]=''
fi

if _has_colors; then
  # Autoload zsh colors module if it hasn't been autoloaded already
  if ! whence -w colors > /dev/null 2>&1; then
    autoload -Uz colors
    colors
  fi

  # shellcheck disable=SC2154
  PS1='%{$fg_bold[green]%}%n%1v%{$reset_color%} %{$fg_bold[blue]%}%2v%{$reset_color%}%{$fg[yellow]%}%3v%{$reset_color%} $(_vi_mode_indicator) '

  # The right prompt will show the exit code if it is not zero.
  RPS1="%(?..%{$fg_bold[red]%}(%?%)%{$reset_color%})"
else
  PS1='%n%1v %2v%3v $(_vi_mode_indicator) '
  # shellcheck disable=SC2034
  RPS1="%(?..(%?%))"
fi

# vim: tabstop=2 expandtab:
