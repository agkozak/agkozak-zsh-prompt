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

# Set $AGKOZAK_THEME_DEBUG to 1 to see debugging information
typeset -g AGKOZAK_THEME_DEBUG=${AGKOZAK_THEME_DEBUG:-0}

(( AGKOZAK_THEME_DEBUG )) && setopt WARN_CREATE_GLOBAL

setopt PROMPT_SUBST NO_PROMPT_BANG

############################################################
# BASIC FUNCTIONS
############################################################

############################################################
# Is the user connected via SSH?
############################################################
_agkozak_is_ssh() {
  if [[ -n $SSH_CONNECTION ]] || [[ -n $SSH_CLIENT ]] || [[ -n $SSH_TTY ]]; then
    true
  else
    case $EUID in
      0)  # Superuser
        case $(ps -o comm= -p $PPID &> /dev/null) in
          sshd|*/sshd) true ;;
          # Note: it can be exceedingly difficult to detect an SSH connection
          # when the user is running as a superuser, especially when using
          # screen or tmux. In these instances, when SSH or its absence cannot
          # be detected, I have opted always to display the hostname in the
          # interest of providing more information. Superusers'
          # usernames and hostnames will be displayed in reverse video.
          *) true ;;
        esac
        ;;
      *) false ;;
    esac
  fi
}

############################################################
# Does the terminal support enough colors?
############################################################
_agkozak_has_colors() {
  (( $(tput colors) >= 8 ))
}

############################################################
# Emulation of bash's PROMPT_DIRTRIM for zsh
#
# In $PWD, substitute $HOME with ~; if the remainder of the
# $PWD has more than a certain number of directory elements
# to display (default: 2), abbreviate it with '...', e.g.
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
      abbreviated_path="$(print -Pn "%($(($1 + 2))~|~/.../%${1}~|%~)")"
      ;;
    *)
      abbreviated_path="$(print -Pn "%($(($1 + 1))~|.../%${1}~|%~)")"
      ;;
  esac
  print -n "$abbreviated_path"
}

############################################################
# Display current branch name, followed by symbols
# representing changes to the working copy
############################################################
_agkozak_branch_status() {
  local ref branch
  ref="$(git symbolic-ref --quiet HEAD 2> /dev/null)"
  case $? in        # See what the exit code is.
    0) ;;           # $ref contains the name of a checked-out branch.
    128) return ;;  # No Git repository here.
    # Otherwise, see if HEAD is in detached state.
    *) ref="$(git rev-parse --short HEAD 2> /dev/null)" || return ;;
  esac
  branch="${ref#refs/heads/}"
  printf ' (%s%s)' "$branch" "$(_agkozak_branch_changes)"
}

############################################################
# Display symbols representing changes to the working copy
############################################################
_agkozak_branch_changes() {
  local git_status symbols k

  git_status="$(LC_ALL=C command git status 2>&1)"

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

############################################################
# When the user enters vi command mode, the % or # in the
# prompt changes into a colon
############################################################
_agkozak_vi_mode_indicator() {
  case $KEYMAP in
    vicmd) print -n ':' ;;
    *) print -n '%#' ;;
  esac
}

############################################################
# Redraw the prompt when the vi mode changes
############################################################
zle-keymap-select() {
  zle reset-prompt
  zle -R
}

############################################################
# Redraw prompt when terminal size changes
############################################################
TRAPWINCH() {
  zle && zle -R
}

###########################################################
# ASYNCHRONOUS FUNCTIONS
###########################################################

typeset -g AGKOZAK_THEME_DIR
AGKOZAK_THEME_DIR=${0:a:h}

###########################################################
# If zsh-async has not already been loaded, try to load it;
# the exit code should indicate success or failure
###########################################################
_agkozak_load_async_lib() {
  if ! whence -w async_init &> /dev/null; then      # Don't load zsh-async twice
    if (( AGKOZAK_THEME_DEBUG )); then
      source ${AGKOZAK_THEME_DIR}/lib/async.zsh
    else
      source ${AGKOZAK_THEME_DIR}/lib/async.zsh &> /dev/null
    fi
    local success=$?
    return $success
  fi
}

###########################################################
# If SIGUSR1 is available and not already in use by
# zsh, use it; otherwise disable asynchronous mode
###########################################################
_agkozak_has_usr1() {
  if whence -w TRAPUSR1 &> /dev/null; then
    (( AGKOZAK_THEME_DEBUG )) && echo 'TRAPUSR1() already defined'
    false
  else
    case $signals in    # Array containing names of available signals
      *USR1*) true ;;
      *)
        (( AGKOZAK_THEME_DEBUG )) && echo 'SIGUSR1 not available'
        false
        ;;
    esac
  fi
}

###########################################################
# Force the async method, if set in $AGKOZAK_FORCE_ASYNC_METHOD.
# Otherwise, determine the async method from the environment,
# whether or not zsh-async will load successfully, and whether
# or not SIGUSR1 is already taken
###########################################################
_agkozak_async_init() {
  typeset -g AGKOZAK_ASYNC_METHOD RPS1

  case $AGKOZAK_FORCE_ASYNC_METHOD in
    zsh-async)
      _agkozak_load_async_lib
      AGKOZAK_ASYNC_METHOD=$AGKOZAK_FORCE_ASYNC_METHOD
      ;;
    usr1|none)
      AGKOZAK_ASYNC_METHOD=$AGKOZAK_FORCE_ASYNC_METHOD
      ;;
    *)
      # Avoid trying to load zsh-async on systems where it is known not to work
      #
      # Msys2) it doesn't load successfully
      # Cygwin) it loads but doesn't work (see
      #   https://github.com/sindresorhus/pure/issues/141)
      # TODO: WSL seems to work perfectly now with zsh-async, but it may not
      #   have in the past
      local sysinfo="$(uname -a)"

      case $sysinfo in
        # On Msys2, zsh-async won't load; on Cygwin, it loads but does not work.
        *Msys|*Cygwin) AGKOZAK_ASYNC_METHOD='usr1' ;;
        *)
          # Avoid loading zsh-async on zsh v5.0.2
          # See https://github.com/mafredri/zsh-async/issues/12
          # The theme appears to work properly now with zsh-async and zsh v5.0.8
          case $ZSH_VERSION in
            '5.0.2')
              if _agkozak_has_usr1; then
                AGKOZAK_ASYNC_METHOD='usr1';
              else
                AGKOZAK_ASYNC_METHOD='none'
              fi
              ;;
            *)

              # Having exhausted known problematic systems, try to load
              # zsh-async; in case that doesn't work, try the SIGUSR1 method if
              # SIGUSR1 is available and TRAPUSR1() hasn't been defined; failing
              # that, switch off asynchronous mode
              if _agkozak_load_async_lib; then
                AGKOZAK_ASYNC_METHOD='zsh-async'
              else
                if _agkozak_has_usr1; then
                  case $sysinfo in
                    *Microsoft*Linux)
                      unsetopt BG_NICE                # nice doesn't work on WSL
                      AGKOZAK_ASYNC_METHOD='usr1'
                      ;;
                    # TODO: the SIGUSR1 method doesn't work on Solaris 11 yet
                    # but it does work on OpenIndiana
                    # SIGUSR2 works on Solaris 11
                    *solaris*) AGKOZAK_ASYNC_METHOD='none' ;;
                    *) AGKOZAK_ASYNC_METHOD='usr1' ;;
                  esac
                else
                  AGKOZAK_ASYNC_METHOD='none'
                fi
              fi
              ;;
          esac
          ;;
      esac
      ;;
  esac

  case $AGKOZAK_ASYNC_METHOD in
    zsh-async)

      ########################################################
      # Create zsh-async worker
      ########################################################
      _agkozak_zsh_async() {
          async_start_worker agkozak_git_status_worker -n
          async_register_callback agkozak_git_status_worker _agkozak_zsh_async_callback
          async_job agkozak_git_status_worker :
      }

      ########################################################
      # Set RPROPT and stop worker
      ########################################################
      _agkozak_zsh_async_callback() {
        psvar[3]="$(_agkozak_branch_status)"
        zle && zle reset-prompt
        async_stop_worker agkozak_git_status_worker -n
      }
      ;;

    usr1)

      ########################################################
      # precmd uses this function to launch async workers to
      # calculate the Git status. It can tell if anything has
      # redefined the TRAPUSR1() function that actually
      # displays the status; if so, it will drop the theme
      # down into non-asynchronous mode.
      ########################################################
      _agkozak_usr1_async() {
        if [[ "$(builtin which TRAPUSR1)" = $AGKOZAK_TRAPUSR1_FUNCTION ]]; then
          # Kill running child process if necessary
          if (( AGKOZAK_USR1_ASYNC_WORKER )); then
              kill -s HUP $AGKOZAK_USR1_ASYNC_WORKER &> /dev/null || :
          fi

          # Start background computation of Git status
          _agkozak_usr1_async_worker &!
          AGKOZAK_USR1_ASYNC_WORKER=$!
        else
          echo 'agkozak-zsh-theme warning: TRAPUSR1() has been redefined. Disabling asynchronous mode.'
          AGKOZAK_ASYNC_METHOD='none'
        fi
      }

      ########################################################
      # Asynchronous Git branch status using SIGUSR1
      ########################################################
      _agkozak_usr1_async_worker() {
        # Save Git branch status to temporary file
        _agkozak_branch_status > "/tmp/agkozak_zsh_theme_$$"

        # Signal parent process
        if (( AGKOZAK_THEME_DEBUG )); then
          kill -s USR1 $$
        else
          kill -s USR1 $$ &> /dev/null
        fi
      }

      ########################################################
      # On SIGUSR1, redraw prompt
      ########################################################
      TRAPUSR1() {
        # read from temp file
        psvar[3]="$(cat /tmp/agkozak_zsh_theme_$$)"

        # Reset asynchronous process number
        AGKOZAK_USR1_ASYNC_WORKER=0

        # Redraw the prompt
        zle && zle reset-prompt
      }

      typeset -g AGKOZAK_TRAPUSR1_FUNCTION
      AGKOZAK_TRAPUSR1_FUNCTION="$(builtin which TRAPUSR1)"
      ;;
  esac
}

############################################################
# THE PROMPT
############################################################

############################################################
# Runs right before the prompt is displayed
#
# 1) Imitates bash's PROMPT_DIRTRIM behavior
# 2) Calculates working branch and working copy status
############################################################
_agkozak_precmd() {
  psvar[2]="$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")"
  psvar[3]=''

  case $AGKOZAK_ASYNC_METHOD in
    'zsh-async') _agkozak_zsh_async ;;
    'usr1') _agkozak_usr1_async ;;
    *) psvar[3]="$(_agkozak_branch_status)" ;;
  esac

}

############################################################
# Theme setup
############################################################
agkozak_zsh_theme() {

  _agkozak_async_init

  case $AGKOZAK_ASYNC_METHOD in
    'zsh-async')
      async_init
      ;;
    'usr1')
      typeset -g AGKOZAK_USR1_ASYNC_WORKER
      AGKOZAK_USR1_ASYNC_WORKER=0
      ;;
  esac

  zle -N zle-keymap-select

  typeset -ga precmd_functions
  precmd_functions+=(_agkozak_precmd)

  # Only display the $HOSTNAME for an ssh connection
  if _agkozak_is_ssh; then
    psvar[1]="$(print -Pn "@%m")"
  else
    psvar[1]=''
  fi

  # When the user is a superuser, the username and hostname are
  # displayed in reverse video
  if _agkozak_has_colors; then
    PS1='%(?..%B%F{red}(%?%)%f%b )%(!.%S.%B%F{green})%n%1v%(!.%s.%f%b) %B%F{blue}%2v%f%b $(_agkozak_vi_mode_indicator) '
    RPS1='%F{yellow}%3v%f'
  else
    PS1='%(?..(%?%) )%(!.%S.)%n%1v%(!.%s.) %2v $(_agkozak_vi_mode_indicator) '
    RPS1='%3v'
  fi

  if (( AGKOZAK_THEME_DEBUG )); then
    echo "agkozak-zsh-theme using async method: $AGKOZAK_ASYNC_METHOD"
  fi
}

agkozak_zsh_theme

if (( AGKOZAK_THEME_DEBUG )); then
  unsetopt WARN_CREATE_GLOBAL
else
  # Clean up environment
  unset AGKOZAK_THEME_DIR
  unfunction _agkozak_load_async_lib _agkozak_has_usr1 \
    _agkozak_is_ssh _agkozak_has_colors
fi

# vim: ts=2:et:sts=2:sw=2:
