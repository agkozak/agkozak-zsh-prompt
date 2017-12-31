#              _                 _
#   __ _  __ _| | _____ ______ _| | __
#  / _` |/ _` | |/ / _ \_  / _` | |/ /
# | (_| | (_| |   < (_) / / (_| |   <
#  \__,_|\__, |_|\_\___/___\__,_|_|\_\
#        |___/
#
# An asynchronous, dynamic color prompt for zsh with Git, vi mode, and exit
# status indicators
#
#
# MIT License
#
# Copyright (c) 2017-2018 Alexandros Kozak
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#
# https://github.com/agkozak/agkozak-zsh-theme
#

# shellcheck disable=SC2034,SC2088,SC2148,SC2154,SC2190

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

###########################################################
# Is the user connected via SSH?
###########################################################
_agkozak_is_ssh() {
  if [[ -n $SSH_CONNECTION ]] || [[ -n $SSH_CLIENT ]] || [[ -n $SSH_TTY ]]; then
    true
  else
    case $EUID in
      0)
        case $(ps -o comm= -p $PPID) in
          sshd|*/sshd) true ;;
          *) false ;;
        esac
        ;;
      *) false ;;
    esac
  fi
}

###########################################################
# Does the terminal support enough colors?
###########################################################
_agkozak_has_colors() {
  (( $(tput colors) >= 8 ))
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
_agkozak_prompt_dirtrim() {
  [[ $1 -ge 1 ]] || set 2
  local abbreviated_path
  case $PWD in
    $HOME) print -n '~' ;;  # For TrueOS
    $HOME*)
      abbreviated_path=$(print -Pn "%($(($1 + 2))~|~/.../%${1}~|%~)")
      ;;
    *)
      abbreviated_path=$(print -Pn "%($(($1 + 1))~|.../%${1}~|%~)")
      ;;
  esac
  print -n "$abbreviated_path"
}

###########################################################
# Display current branch name, followed by symbols
# representing changes to the working copy
###########################################################
_agkozak_branch_status() {
  local ref branch
  ref=$(git symbolic-ref --quiet HEAD 2> /dev/null)
  case $? in        # See what the exit code is.
    0) ;;           # $ref contains the name of a checked-out branch.
    128) return ;;  # No Git repository here.
    # Otherwise, see if HEAD is in detached state.
    *) ref=$(git rev-parse --short HEAD 2> /dev/null) || return ;;
  esac
  branch=${ref#refs/heads/}
  printf ' (%s%s)' "$branch" "$(_agkozak_branch_changes)"
}

###########################################################
# Display symbols representing changes to the working copy
###########################################################
_agkozak_branch_changes() {
  local git_status symbols k

  git_status=$(LC_ALL=C command git status 2>&1)

  declare -A messages

  messages=(
              'renamed:'                '>'
              'Your branch is ahead of' '*'
              'new file:'               '+'
              'Untracked files'         '?'
              'deleted'                 'x'
              'modified:'               '!'
           )

  for k in ${(@k)messages}; do
    case $git_status in
      *${k}*) symbols="${messages[$k]}${symbols}" ;;
    esac
  done

  [[ -n $symbols ]] && printf ' %s' "$symbols"
}

###########################################################
# Asynchronous Git branch status routine
###########################################################
_agkozak_async() {
  # Save Git branch status to temporary file
  _agkozak_branch_status > "/tmp/agkozak_zsh_theme_$$"

  # Signal parent process
  kill -s USR1 $$
}

###########################################################
# Runs right before the prompt is displayed
#
# 1) Imitates bash's PROMPT_DIRTRIM behavior
# 2) Calculates working branch and working copy status
###########################################################
precmd() {
  psvar[2]=$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")

  if (( AGKOZAK_NO_ASYNC != 1 )); then

    psvar[3]=''

    # Kill running child process if necessary
    if (( AGKOZAK_ASYNC_PROC != 0 )); then
        kill -s HUP $AGKOZAK_ASYNC_PROC &> /dev/null || :
    fi

    # Start background computation of Git status
    _agkozak_async &!
    AGKOZAK_ASYNC_PROC=$!
  else
    psvar[3]=$(_agkozak_branch_status)
  fi
}

###########################################################
# When the user enters vi command mode, the % or # in the
# prompt changes into a colon
###########################################################
_agkozak_vi_mode_indicator() {
  case $KEYMAP in
    vicmd) print -n ':' ;;
    *) print -n '%#' ;;
  esac
}

###########################################################
# Redraw the prompt when the vi mode changes
###########################################################
zle-keymap-select() {
  zle reset-prompt
  zle -R
}

###########################################################
# Redraw prompt when terminal size changes
###########################################################
TRAPWINCH() {
  zle && zle -R
}

###########################################################
# On signal USR1, redraw prompt
###########################################################
TRAPUSR1() {
  # read from temp file
  psvar[3]=$(cat /tmp/agkozak_zsh_theme_$$)

  # Reset asynchronous process number
  AGKOZAK_ASYNC_PROC=0

  # Redraw the prompt
  zle && zle reset-prompt
}

AGKOZAK_ASYNC_PROC=0

zle -N zle-keymap-select

# Only display the $HOSTNAME for an ssh connection
if _agkozak_is_ssh; then
  psvar[1]=$(print -Pn "@%m")
else
  psvar[1]=''
fi

if (( AGKOZAK_NO_ASYNC !=1 )); then
  if _agkozak_has_colors; then
    PS1='%(?..%B%F{red}(%?%)%f%b )%B%F{green}%n%1v%f%b %B%F{blue}%2v%f%b $(_agkozak_vi_mode_indicator) '
    RPS1='%F{yellow}%3v%f'
  else
    PS1='%(?..(%?%) )%n%1v %2v $(_agkozak_vi_mode_indicator) '
    RPS1='%3v'
  fi
else
  if _agkozak_has_colors; then
    PS1='%B%F{green}%n%1v%f%b %B%F{blue}%2v%f%b%F{yellow}%3v%f $(_agkozak_vi_mode_indicator) '
    # The right prompt will show the exit code if it is not zero.
    RPS1="%(?..%B%F{red}(%?%)%f%b)"
  else
    PS1='%n%1v %2v%3v $(_agkozak_vi_mode_indicator) '
    RPS1="%(?..(%?%))"
  fi
fi

# Clean up environment
unset -f _agkozak_is_ssh _agkozak_has_colors

# vim: ts=2:et:sts=2:sw=2:
