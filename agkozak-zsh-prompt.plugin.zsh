#              _                 _
#   __ _  __ _| | _____ ______ _| | __
#  / _` |/ _` | |/ / _ \_  / _` | |/ /
# | (_| | (_| |   < (_) / / (_| |   <
#  \__,_|\__, |_|\_\___/___\__,_|_|\_\
#        |___/
#
# An asynchronous, dynamic color prompt for ZSH with Git, vi mode, and exit
# status indicators
#
#
# MIT License
#
# Copyright (c) 2017-2019 Alexandros Kozak
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
# https://github.com/agkozak/agkozak-zsh-prompt
#

# shellcheck disable=SC1090,SC2016,SC2034,SC2088,SC2148,SC2154,SC2190

# psvar[] Usage
#
# psvar Index   Prompt String Equivalent    Usage
#
# psvar[1]      %1v                         Hostname/abbreviated hostname (only
#                                           displayed for SSH connections)
#
# psvar[2]      %2v                         Working directory or abbreviation
#                                           thereof
#
# psvar[3]      %3v                         Current working Git branch, along
#                                           with indicator of changes made
#
# psvar[4]      %4v                         Equals 'vicmd' when vi command mode
#                                           is enabled; otherwise empty
#
# psvar[5]      %5v                         Empty only when
#                                           AGKOZAK_USER_HOST_DISPLAY is 0

autoload -Uz is-at-least

# Set AGKOZAK_PROMPT_DEBUG=1 to see debugging information
AGKOZAK_PROMPT_DEBUG=${AGKOZAK_PROMPT_DEBUG:-0}

############################################################
# Display a message on STDERR if debug mode is enabled
#
# Globals:
#   AGKOZAK_PROMPT_DEBUG
# Arguments:
#   $1  Message to send to STDERR
############################################################
_agkozak_debug_print() {
  (( AGKOZAK_PROMPT_DEBUG )) && print -- "agkozak-zsh-prompt: $1" >&2
}

if (( AGKOZAK_PROMPT_DEBUG )); then
  setopt WARN_CREATE_GLOBAL

  if is-at-least 5.4.0; then
    setopt WARN_NESTED_VAR
  fi
fi

# Set AGKOZAK_PROMPT_DIRTRIM to the desired number of directory elements to
# display, or set it to 0 for no directory trimming
typeset -g AGKOZAK_PROMPT_DIRTRIM=${AGKOZAK_PROMPT_DIRTRIM:-2}

# Set AGKOZAK_MULTILINE to 0 to enable the legacy, single-line prompt
typeset -g AGKOZAK_MULTILINE=${AGKOZAK_MULTILINE:-1}

# Set AGKOZAK_LEFT_PROMPT_ONLY to have the Git status appear in the left prompt
typeset -g AGKOZAK_LEFT_PROMPT_ONLY=${AGKOZAK_LEFT_PROMPT_ONLY:-0}

# Set AGKOZAK_COLORS_* variables to any valid color
#   AGKOZAK_COLORS_EXIT_STATUS changes the exit status color      (default: red)
#   AGKOZAK_COLORS_USER_HOST changes the username/hostname color  (default: green)
#   AGKOZAK_COLORS_PATH changes the path color                    (default: blue)
#   AGKOZAK_COLORS_BRANCH_STATUS changes the branch status color  (default: yellow)
#   AGKOZAK_COLORS_PROMPT_CHAR changes the prompt character color (default: white)
typeset -g AGKOZAK_COLORS_EXIT_STATUS=${AGKOZAK_COLORS_EXIT_STATUS:-red}
typeset -g AGKOZAK_COLORS_USER_HOST=${AGKOZAK_COLORS_USER_HOST:-green}
typeset -g AGKOZAK_COLORS_PATH=${AGKOZAK_COLORS_PATH:-blue}
typeset -g AGKOZAK_COLORS_BRANCH_STATUS=${AGKOZAK_COLORS_BRANCH_STATUS:-yellow}

# AGKOZAK_USER_HOST_DISPLAY determines whether user and host will be
# displayed (default: 1)
typeset -g AGKOZAK_USER_HOST_DISPLAY=${AGKOZAK_USER_HOST_DISPLAY:-1}

# AGKOZAK_SHOW_STASH determines whether stashed changes will be displayed (default: 1)
typeset -g AGKOZAK_SHOW_STASH=${AGKOZAK_SHOW_STASH:-1}

# For single-line prompt, AGKOZAK_PRE_PROMPT_CHAR comes before the prompt
# character (default: space)
typeset -g AGKOZAK_PRE_PROMPT_CHAR=${AGKOZAK_PRE_PROMPT_CHAR- }

setopt PROMPT_SUBST NO_PROMPT_BANG

######################################################################
# GENERAL FUNCTIONS
######################################################################

############################################################
# Are colors available?
#
# Globals:
#   AGKOZAK_HAS_COLORS
############################################################
_agkozak_has_colors() {
  if (( $+AGKOZAK_HAS_COLORS )); then
    :
  else
    case $TERM in
      *-256color) typeset -g AGKOZAK_HAS_COLORS=1 ;;
      vt100|dumb) typeset -g AGKOZAK_HAS_COLORS=0 ;;
      *)
        local colors
        case $OSTYPE in
          freebsd*|dragonfly*) colors=$(tput Co) ;;
          *) colors=$(tput colors) ;;
        esac
        typeset -g AGKOZAK_HAS_COLORS=$(( colors >= 8 ))
        ;;
    esac
  fi
  (( AGKOZAK_HAS_COLORS ))
}

############################################################
# Is the user connected via SSH?
#
# This function works perfectly for regular users. It is
# nearly impossible to detect with accuracy how a superuser
# is connected, so this prompt opts simply to display his or
# her username and hostname in inverse video.
############################################################
_agkozak_is_ssh() {
  [[ -n "${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-}" ]]
}

############################################################
# Emulation of bash's PROMPT_DIRTRIM for ZSH
#
# Take PWD and substitute HOME with `~'. If the rest of PWD
# has more than a certain number of elements in its
# directory tree, keep the number specified by
# AGKOZAK_PROMPT_DIRTRIM (default: 2) and abbreviate the
# rest with `...'. (Set AGKOZAK_PROMPT_DIRTRIM=0 to disable
# directory trimming). For example,
#
#   $HOME/dotfiles/polyglot/img
#
# will be displayed as
#
#   ~/.../polyglot/img
#
# Named directories will by default be displayed using their
# aliases in the prompt (e.g. `~project'). Set
# AGKOZAK_NAMED_DIRS=0 to have them displayed just like any
# other directory.
#
# Globals:
#   AGKOZAK_NAMED_DIRS
# Arguments:
#   $@ [Optional] If `-v', store the function's output in
#        psvar[2] instead of printing it to STDOUT
#   $@ Number of directory elements to display (default: 2)
############################################################
_agkozak_prompt_dirtrim() {
  # Process arguments
  local argument
  for argument in $@; do
    [[ $argument == '-v' ]] && local var=1
  done
  until [[ $1 != '-v' ]]; do
    shift
  done
  [[ $1 -ge 0 ]] || set 2

  # Default behavior (when AGKOZAK_NAMED_DIRS is 1)
  typeset -g AGKOZAK_NAMED_DIRS=${AGKOZAK_NAMED_DIRS:-1}
  if (( AGKOZAK_NAMED_DIRS )); then
    local zsh_pwd
    print -Pnz '%~'

    # IF AGKOZAK_PROMPT_DIRTRIM is not 0, trim directory
    if (( $1 )); then
      read -rz zsh_pwd
      case $zsh_pwd in
        \~) print -Pnz $zsh_pwd ;;
        \~/*) print -Pnz "%($(( $1 + 2 ))~|~/.../%${1}~|%~)" ;;
        \~*) print -Pnz "%($(( $1 + 2 ))~|${zsh_pwd%%${zsh_pwd#\~*\/}}.../%${1}~|%~)" ;;
        *) print -Pnz "%($(( $1 + 1 ))/|.../%${1}d|%d)" ;;
      esac
    fi

  # If AGKOZAK_NAMED_DIRS is 0
  else
    local dir dir_count
    case $HOME in
      /) dir=${PWD} ;;
      *) dir=${PWD#$HOME} ;;
    esac

    # If AGKOZAK_PROMPT_DIRTRIM is not 0, trim the directory
    if (( $1 > 0 )); then

      # The number of directory elements is the number of slashes in ${PWD#$HOME}
      dir_count=$(( ${#dir} - ${#${dir//\//}} ))
      if (( dir_count <= $1 )); then
        case $PWD in
          ${HOME}) print -nz '~' ;;
          ${HOME}*) print -nz "~${dir}" ;;
          *) print -nz "$PWD" ;;
        esac
      else
        local lopped_path i
        lopped_path=${dir}
        i=0
        while (( i != $1 )); do
          lopped_path=${lopped_path%\/*}
          (( i++ ))
        done
        case $PWD in
          ${HOME}*) print -nz "~/...${dir#${lopped_path}}" ;;
          *) print -nz -f '...%s' "${PWD#${lopped_path}}" ;;
        esac
      fi

    # If AGKOZAK_PROMPT_DIRTRIM is 0
    else
      case $PWD in
        ${HOME}) print -nz '~' ;;
        ${HOME}*) print -nz "~${dir}" ;;
        *) print -nz "$PWD" ;;
      esac
    fi
  fi

  local output
  read -rz output

  # Argument -v stores the output to psvar[2]; otherwise send to STDOUT
  if (( var )); then
    psvar[2]=$output
  else
    print $output
  fi
}

############################################################
# Display current branch name, followed by symbols
# representing changes to the working copy
############################################################
_agkozak_branch_status() {
  local ref branch
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  case $? in        # See what the exit code is.
    0) ;;           # $ref contains the name of a checked-out branch.
    128) return ;;  # No Git repository here.
    # Otherwise, see if HEAD is in detached state.
    *) ref=$(command git rev-parse --short HEAD 2> /dev/null) || return ;;
  esac
  branch=${ref#refs/heads/}

  if [[ -n $branch ]]; then
    local git_status symbols i=1 k

    if (( AGKOZAK_SHOW_STASH )); then
      if is-at-least 2.14 ${AGKOZAK_GIT_VERSION}; then
        git_status="$(LC_ALL=C GIT_OPTIONAL_LOCKS=0 command git status --show-stash 2>&1)"
      else
        git_status="$(LC_ALL=C GIT_OPTIONAL_LOCKS=0 command git status 2>&1)"
      fi
    fi

    typeset -A messages
    messages=(
                '&*'  ' have diverged,'
                '&'   'Your branch is behind '
                '*'   'Your branch is ahead of '
                '+'   'new file:   '
                'x'   'deleted:    '
                '!'   'modified:   '
                '>'   'renamed:    '
                '?'   'Untracked files:'
             )

    for k in '&*' '&' '*' '+' 'x' '!' '>' '?'; do
      case $git_status in
        *${messages[$k]}*) symbols+="${AGKOZAK_CUSTOM_SYMBOLS[$i]:-$k}" ;;
      esac
      (( i++ ))
    done

    # Check for stashed changes. If there are any, add the stash symbol to the
    # list of symbols.
    if (( AGKOZAK_SHOW_STASH )); then
      if is-at-least 2.14 ${AGKOZAK_GIT_VERSION}; then
        case $git_status in
          *'Your stash currently has '*)
            symbols+="${AGKOZAK_CUSTOM_SYMBOLS[$i]:-\$}"
            ;;
        esac
      else
        if command git rev-parse --verify refs/stash &> /dev/null; then
          symbols+="${AGKOZAK_CUSTOM_SYMBOLS[$i]:-\$}"
        fi
      fi
    fi

    [[ -n $symbols ]] && symbols=" ${symbols}"

    printf '%s(%s%s)' "${AGKOZAK_BRANCH_STATUS_SEPARATOR- }" "$branch" "$symbols"
  fi
}

############################################################
# Redraw the prompt when the vi mode changes. When the user
# enters vi command mode, the % or # in the prompt changes
# to a colon
############################################################
zle-keymap-select() {
  [[ $KEYMAP == 'vicmd' ]] && psvar[4]='vicmd' || psvar[4]=''
  zle reset-prompt
  zle -R
}

############################################################
# Redraw prompt when terminal size changes
############################################################
TRAPWINCH() {
  zle && zle -R
}

############################################################
# For legacy custom prompts: print a vi mode indicator
############################################################
_agkozak_vi_mode_indicator() {
  case $KEYMAP in
    vicmd) print -n ':' ;;
    *) print -n '%#' ;;
  esac
}

######################################################################
# ASYNCHRONOUS FUNCTIONS
######################################################################

# Standarized $0 handling
# (See https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc)
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
typeset -g AGKOZAK_PROMPT_DIR="${0:A:h}"

############################################################
# If zsh-async has not already been loaded, try to load it
#
# Globals:
#   AGKOZAK_PROMPT_DEBUG
#   AGKOZAK_PROMPT_DIR
############################################################
_agkozak_load_async_lib() {
  if ! whence -w async_init &> /dev/null; then      # Don't load zsh-async twice
    if (( AGKOZAK_PROMPT_DEBUG )); then
      source "${AGKOZAK_PROMPT_DIR}/lib/async.zsh"
    else
      source "${AGKOZAK_PROMPT_DIR}/lib/async.zsh" &> /dev/null
    fi
    local success=$?
    return $success
  fi
}

############################################################
# Is SIGUSR1 is available and not already in use by ZSH?
############################################################
_agkozak_has_usr1() {
  if whence -w TRAPUSR1 &> /dev/null; then
    _agkozak_debug_print 'TRAPUSR1 already defined.'
    return 1
  else
    case $signals in    # Array containing names of available signals
      *USR1*) return 0 ;;
      *)
        _agkozak_debug_print 'SIGUSR1 not available.'
        return 1
        ;;
    esac
  fi
}

############################################################
# If AGKOZAK_FORCE_ASYNC_METHOD is set to a valid value,
# set AGKOZAK_ASYNC_METHOD to that; otherwise, determine
# the optimal asynchronous method from the environment (usr1
# for MSYS2/Cygwin, zsh-async for WSL, subst-async for
# everything else), with fallbacks being available. Define
# the necessary asynchronous functions (loading async.zsh
# when necessary).
#
# Globals:
#   AGKOZAK_IS_WSL
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_FORCE_ASYNC_METHOD
#   AGKOZAK_TRAPUSR1_FUNCTION
############################################################
_agkozak_async_init() {

  # WSL should have BG_NICE disabled, since it does not have a Linux kernel
  setopt LOCAL_OPTIONS EXTENDED_GLOB
  if [[ -e /proc/version ]]; then
    if [[ -n ${(M)${(f)"$(</proc/version)"}:#*Microsoft*} ]]; then
      unsetopt BG_NICE
      typeset -g AGKOZAK_IS_WSL=1   # For later reference
    fi
  fi

  # If AGKOZAK_FORCE_ASYNC_METHOD is set, force the asynchronous method
  [[ $AGKOZAK_FORCE_ASYNC_METHOD == 'zsh-async' ]] && _agkozak_load_async_lib
  if [[ $AGKOZAK_FORCE_ASYNC_METHOD == (subst-async|zsh-async|usr1|none) ]]; then
    typeset -g AGKOZAK_ASYNC_METHOD=$AGKOZAK_FORCE_ASYNC_METHOD

  # Otherwise, first provide for certain quirky systems
  else

    if (( AGKOZAK_IS_WSL )) || [[ $OSTYPE == solaris* ]]; then
      if [[ $ZSH_VERSION != '5.0.2' ]] &&_agkozak_load_async_lib; then
        typeset -g AGKOZAK_ASYNC_METHOD='zsh-async'
      elif _agkozak_has_usr1; then
        typeset -g AGKOZAK_ASYNC_METHOD='usr1'
      else
        typeset -g AGKOZAK_ASYNC_METHOD='subst-async'
      fi

    # SIGUSR1 method is still much faster on MSYS2, Cygwin, and ZSH v5.0.2
    elif [[ $ZSH_VERSION == '5.0.2' ]] || [[ $OSTYPE == (msys|cygwin) ]]; then
      if _agkozak_has_usr1; then
        typeset -g AGKOZAK_ASYNC_METHOD='usr1'
      else
        typeset -g AGKOZAK_ASYNC_METHOD='subst-async'
      fi

    # Asynchronous methods don't work in Emacs shell mode (but they do in term
    # and ansi-term)
    elif [[ $TERM == 'dumb' ]]; then
      typeset -g AGKOZAK_ASYNC_METHOD='none'

    # Otherwise use subst-async
    else
      typeset -g AGKOZAK_ASYNC_METHOD='subst-async'
    fi
  fi

  ############################################################
  # Process substitution async method
  #
  # Fork a background process to fetch the Git status and feed
  # it asynchronously to a file descriptor. Install a callback
  # handler to process input from the file descriptor.
  #
  # Globals:
  #   AGKOZAK_ASYNC_FD
  #   AGKOZAK_IS_WSL
  ############################################################
  _agkozak_subst_async() {
    setopt LOCAL_OPTIONS NO_IGNORE_BRACES
    typeset -g AGKOZAK_ASYNC_FD=13371

    # Workaround for buggy behavior in MSYS2, Cygwin, and Solaris
    if [[ $OSTYPE == (msys|cygwin|solaris*) ]]; then
      exec {AGKOZAK_ASYNC_FD}< <(_agkozak_branch_status; command true)
    # Prevent WSL from locking up when using X; also workaround for ZSH v5.0.2
  elif (( AGKOZAK_IS_WSL )) && (( $+DISPLAY )) \
    || [[ $ZSH_VERSION == '5.0.2' ]]; then
      exec {AGKOZAK_ASYNC_FD}< <(_agkozak_branch_status)
      command sleep 0.01
    else
      exec {AGKOZAK_ASYNC_FD}< <(_agkozak_branch_status)
    fi

    # Bug workaround; see http://www.zsh.org/mla/workers/2018/msg00966.html
    command true

    zle -F "$AGKOZAK_ASYNC_FD" _agkozak_zsh_subst_async_callback
  }

  ############################################################
  # ZLE callback handler
  #
  # Read Git status from file descriptor and set psvar[3]
  #
  # Arguments:
  #   $1  File descriptor
  ############################################################
  _agkozak_zsh_subst_async_callback() {
    setopt LOCAL_OPTIONS NO_IGNORE_BRACES

    local FD="$1" response

    # Read data from $FD descriptor
    IFS='' builtin read -rs -d $'\0' -u "$FD" response

    # Withdraw callback and close the file descriptor
    zle -F ${FD}; exec {FD}<&-

    # Make the changes visible
    psvar[3]="$response"
    zle && zle reset-prompt
  }

  case $AGKOZAK_ASYNC_METHOD in

    zsh-async)

      ############################################################
      # Create zsh-async worker
      ############################################################
      _agkozak_zsh_async() {
          async_start_worker agkozak_git_status_worker -n
          async_register_callback agkozak_git_status_worker _agkozak_zsh_async_callback
          async_job agkozak_git_status_worker _agkozak_branch_status
      }

      ############################################################
      # Set RPROMPT and stop worker
      ############################################################
      _agkozak_zsh_async_callback() {
        psvar[3]=$3
        zle && zle reset-prompt
        async_stop_worker agkozak_git_status_worker -n
      }
      ;;

    usr1)

      ############################################################
      # Launch async workers to calculate Git status. TRAPUSR1
      # actually displays the status; if some other script
      # redefines TRAPUSR1, drop the prompt into synchronous mode.
      #
      # Globals:
      #   AGKOZAK_TRAPUSR1_FUNCTION
      #   AGKOZAK_USR1_ASYNC_WORKER
      #   AGKOZAK_ASYNC_METHOD
      ############################################################
      _agkozak_usr1_async() {
        if [[ "$(builtin which TRAPUSR1)" = "$AGKOZAK_TRAPUSR1_FUNCTION" ]]; then
          # Kill running child process if necessary
          if (( AGKOZAK_USR1_ASYNC_WORKER )); then
            kill -s HUP "$AGKOZAK_USR1_ASYNC_WORKER" &> /dev/null || :
          fi

          # Start background computation of Git status
          _agkozak_usr1_async_worker &!
          typeset -g AGKOZAK_USR1_ASYNC_WORKER=$!
        else
          _agkozak_debug_print 'TRAPUSR1 has been redefined. Switching to subst-async mode.'
          typeset -g AGKOZAK_ASYNC_METHOD='subst-async'
          psvar[3]="$(_agkozak_branch_status)"
        fi
      }

      ############################################################
      # Calculate Git status and store it in a temporary file;
      # then kill own process, sending SIGUSR1
      #
      # Globals:
      #   AGKOZAK_PROMPT_DEBUG
      ############################################################
      _agkozak_usr1_async_worker() {
        # Save Git branch status to temporary file
        _agkozak_branch_status >| /tmp/agkozak_zsh_prompt_$$

        # Signal parent process
        if (( AGKOZAK_PROMPT_DEBUG )); then
          kill -s USR1 $$
        else
          kill -s USR1 $$ &> /dev/null
        fi
      }

      ############################################################
      # On SIGUSR1, fetch Git status from temprary file and store
      # it in psvar[3]. This function caches its own code in
      # AGKOZAK_TRAPUSR1_FUNCTION so that it can tell if it has
      # been redefined by another script.
      #
      # Globals:
      #   AGKOZAK_USR1_ASYNC_WORKER
      #   AGKOZAK_TRAPUSR1_FUNCTION
      ############################################################
      TRAPUSR1() {
        # Set prompt from contents of temporary file
        psvar[3]=$(print -n -- "$(< /tmp/agkozak_zsh_prompt_$$)")

        # Reset asynchronous process number
        typeset -g AGKOZAK_USR1_ASYNC_WORKER=0

        # Redraw the prompt
        zle && zle reset-prompt
      }

      typeset -g AGKOZAK_TRAPUSR1_FUNCTION="$(builtin which TRAPUSR1)"
      ;;
  esac
}

######################################################################
# THE PROMPT
######################################################################

############################################################
# Strip color codes from a prompt string
#
# Arguments:
#   $1 The prompt string
############################################################
_agkozak_strip_colors() {

  local prompt=$1
  local open_braces

  while [[ -n $prompt ]]; do
    case $prompt in
      %F\{*|%K\{*)
        (( open_braces++ ))
        prompt=${prompt#%[FK]\{}
        while (( open_braces )); do
          case ${prompt:0:1} in
            \{) (( open_braces++ )) ;;
            \}) (( open_braces-- )) ;;
          esac
          prompt=${prompt#?}
        done
        ;;
      %f*|%k*) prompt=${prompt#%[fk]} ;;
      *)
        print -n -- "${prompt:0:1}"
        prompt=${prompt#?}
        ;;
    esac
  done
}

############################################################
# Runs right before each prompt is displayed; hooks into
# precmd
#
# 1) Redisplays path ($psvar[2]) whenever the value of
#      AGKOZAK_PROMPT_DIRTRIM or AGKOZAK_NAMED_DIRS changes
# 2) If AGKOZAK_MULTILINE is changed to 0, set
#      AGKOZAK_LEFT_PROMPT_ONLY=0
# 3) If AGKOZAK_LEFT_PROMPT_ONLY is changed, updated both
#      prompt strings
# 4) Resets Git status and vi mode display
# 5) Begins to calculate Git status
# 6) Sets AGKOZAK_PROMPT_WHITESPACE based on value of
#      AGKOZAK_MULTILINE
# 7) Optionally display a blank line (AGKOZAK_BLANK_LINES),
#      while avoiding a blank line when the shell is first
#      loaded
# 8) If custom prompts are defined, update the prompt
#      strings
#
# TODO: Consider making AGKOZAK_PROMPT_WHITESPACE a psvar
#
# Globals:
#   AGKOZAK_SHOW_STASH
#   AGKOZAK_GIT_VERSION
#   AGKOZAK_PROMPT_DIRTRIM
#   AGKOZAK_OLD_PROMPT_DIRTRIM
#   AGKOZAK_NAMED_DIRS
#   AGKOZAK_OLD_NAMED_DIRS
#   AGKOZAK_MULTILINE
#   AGKOZAK_OLD_MULTILINE
#   AGKOZAK_LEFT_PROMPT_ONLY
#   AGKOZAK_OLD_LEFT_PROMPT_ONLY
#   AGKOZAK_USER_HOST_DISPLAY
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_PRE_PROMPT_CHAR
#   AGKOZAK_BLANK_LINES
#   AGKOZAK_FIRST_PROMPT_PRINTED
#   AGKOZAK_CUSTOM_PROMPT
#   AGKOZAK_CURRENT_CUSTOM_PROMPT
#   AGKOZAK_CUSTOM_RPROMPT
#   AGKOZAK_CURRENT_CUSTOM_RPROMPT
############################################################
_agkozak_precmd() {
  # Cache the Git version for use in _agkozak_branch_status
  (( AGKOZAK_SHOW_STASH )) && \
    typeset -gx AGKOZAK_GIT_VERSION=${${AGKOZAK_GIT_VERSION:=$(command git --version)}#git version }

  # Update displayed directory when AGKOZAK_PROMPT_DIRTRIM or AGKOZAK_NAMED_DIRS
  # changes or when first sourcing this script
  if (( AGKOZAK_PROMPT_DIRTRIM != AGKOZAK_OLD_PROMPT_DIRTRIM )) \
    || (( AGKOZAK_NAMED_DIRS != AGKOZAK_OLD_NAMED_DIRS )) \
    || (( ! $+psvar[2] )); then
    _agkozak_prompt_dirtrim -v $AGKOZAK_PROMPT_DIRTRIM
    typeset -g AGKOZAK_OLD_PROMPT_DIRTRIM=$AGKOZAK_PROMPT_DIRTRIM
    typeset -g AGKOZAK_OLD_NAMED_DIRS=$AGKOZAK_NAMED_DIRS
  fi

  if (( AGKOZAK_MULTILINE != AGKOZAK_OLD_MULTILINE )); then
    (( AGKOZAK_MULTILINE == 0 )) && AGKOZAK_LEFT_PROMPT_ONLY=0
    typeset -g AGKOZAK_OLD_MULTILINE=$AGKOZAK_MULTILINE
  fi

  if (( AGKOZAK_LEFT_PROMPT_ONLY != AGKOZAK_OLD_LEFT_PROMPT_ONLY )); then
    unset AGKOZAK_CUSTOM_PROMPT AGKOZAK_CUSTOM_RPROMPT
    typeset -g AGKOZAK_OLD_LEFT_PROMPT_ONLY=$AGKOZAK_LEFT_PROMPT_ONLY
    _agkozak_prompt_string
  fi

  psvar[3]=''
  psvar[4]=''

  if (( AGKOZAK_USER_HOST_DISPLAY )); then
    psvar[5]=${AGKOZAK_USER_HOST_DISPLAY}
  else
    psvar[5]=''
  fi

  case $AGKOZAK_ASYNC_METHOD in
    'subst-async') _agkozak_subst_async ;;
    'zsh-async') _agkozak_zsh_async ;;
    'usr1') _agkozak_usr1_async ;;
    *) psvar[3]="$(_agkozak_branch_status)" ;;
  esac

  if (( AGKOZAK_MULTILINE == 0 )) && (( ! AGKOZAK_LEFT_PROMPT_ONLY )) \
    && [[ -z $INSIDE_EMACS ]]; then
    typeset -g AGKOZAK_PROMPT_WHITESPACE=${AGKOZAK_PRE_PROMPT_CHAR}
  else
    typeset -g AGKOZAK_PROMPT_WHITESPACE=$'\n'
  fi

  if (( AGKOZAK_BLANK_LINES )); then
    if (( AGKOZAK_FIRST_PROMPT_PRINTED )); then
      print
    fi
    typeset -g AGKOZAK_FIRST_PROMPT_PRINTED=1
  fi

  # If AGKOZAK_CUSTOM_PROMPT or AGKOZAK_CUSTOM_RPROMPT changes, the
  # corresponding prompt is updated

  if [[ ${AGKOZAK_CUSTOM_PROMPT} != "${AGKOZAK_CURRENT_CUSTOM_PROMPT}" ]]; then
    typeset -g AGKOZAK_CURRENT_CUSTOM_PROMPT=${AGKOZAK_CUSTOM_PROMPT}
    PROMPT=${AGKOZAK_CUSTOM_PROMPT}
    if ! _agkozak_has_colors; then
      PROMPT=$(_agkozak_strip_colors "${PROMPT}")
    fi
  fi

  if [[ ${AGKOZAK_CUSTOM_RPROMPT} != "${AGKOZAK_CURRENT_CUSTOM_RPROMPT}" ]]; then
    typeset -g AGKOZAK_CURRENT_CUSTOM_RPROMPT=${AGKOZAK_CUSTOM_RPROMPT}
    RPROMPT=${AGKOZAK_CUSTOM_RPROMPT}
    if ! _agkozak_has_colors; then
      RPROMPT=$(_agkozak_strip_colors "${RPROMPT}")
    fi
  fi
}

############################################################
# Set the prompt strings
#
# Globals:
#   AGKOZAK_CUSTOM_PROMPT
#   AGKOZAK_COLORS_EXIT_STATUS
#   AGKOZAK_COLORS_USER_HOST
#   AGKOZAK_COLORS_PATH
#   AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_COLORS_PROMPT_CHAR
#   AGKOZAK_PROMPT_CHAR
#   AGKOZAK_CURRENT_CUSTOM_PROMPT
#   AGKOZAK_CUSTOM_RPROMPT
#   AGKOZAK_COLORS_BRANCH_STATUS
#   AGKOZAK_CURRENT_CUSTOM_RPROMPT
############################################################
_agkozak_prompt_string () {
  if (( $+AGKOZAK_CUSTOM_PROMPT )); then
    PROMPT=${AGKOZAK_CUSTOM_PROMPT}
  else
    # The color left prompt
    PROMPT='%(?..%B%F{${AGKOZAK_COLORS_EXIT_STATUS}}(%?%)%f%b )'
    PROMPT+='%(5V.%(!.%S%B.%B%F{${AGKOZAK_COLORS_USER_HOST}})%n%1v%(!.%b%s.%f%b) .)'
    PROMPT+='%B%F{${AGKOZAK_COLORS_PATH}}%2v%f%b'
    if (( AGKOZAK_LEFT_PROMPT_ONLY )); then
      PROMPT+='%(3V.%F{${AGKOZAK_COLORS_BRANCH_STATUS}}%3v%f.)'
    fi
    PROMPT+='${AGKOZAK_PROMPT_WHITESPACE}'
    PROMPT+='${AGKOZAK_COLORS_PROMPT_CHAR:+%F{${AGKOZAK_COLORS_PROMPT_CHAR}\}}'
    PROMPT+='%(4V.${AGKOZAK_PROMPT_CHAR[3]:-:}.%(!.${AGKOZAK_PROMPT_CHAR[2]:-%#}.${AGKOZAK_PROMPT_CHAR[1]:-%#}))'
    PROMPT+='${AGKOZAK_COLORS_PROMPT_CHAR:+%f} '

    typeset -g AGKOZAK_CUSTOM_PROMPT=${PROMPT}
    typeset -g AGKOZAK_CURRENT_CUSTOM_PROMPT=${AGKOZAK_CUSTOM_PROMPT}
  fi

  if (( $+AGKOZAK_CUSTOM_RPROMPT )); then
    RPROMPT=${AGKOZAK_CUSTOM_RPROMPT}
  else
    # The color right prompt
    if (( ! AGKOZAK_LEFT_PROMPT_ONLY )); then
      typeset -g RPROMPT='%(3V.%F{${AGKOZAK_COLORS_BRANCH_STATUS}}%3v%f.)'
    else
      typeset -g RPROMPT=''
    fi

    typeset -g AGKOZAK_CUSTOM_RPROMPT=${RPROMPT}
    typeset -g AGKOZAK_CURRENT_CUSTOM_RPROMPT=${RPROMPT}
  fi

  if ! _agkozak_has_colors; then
    PROMPT=$(_agkozak_strip_colors "$PROMPT")
    RPROMPT=$(_agkozak_strip_colors "$RPROMPT")
  fi
}

############################################################
# Prompt setup
#
# Globals:
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_USR1_ASYNC_WORKER
#   AGKOZAK_PROMPT_DIRTRIM
############################################################
() {

  _agkozak_async_init

  case $AGKOZAK_ASYNC_METHOD in
    'subst-async') ;;
    'zsh-async') async_init ;;
    'usr1') typeset -g AGKOZAK_USR1_ASYNC_WORKER=0 ;;
  esac

  zle -N zle-keymap-select

  # Don't use ZSH hooks in Emacs classic shell
  if (( $+INSIDE_EMACS )) && [[ $TERM == 'dumb' ]]; then
    :
  else
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _agkozak_precmd

    ############################################################
    # Update the displayed directory when the PWD changes
    ############################################################
    _agkozak_chpwd() {
      _agkozak_prompt_dirtrim -v $AGKOZAK_PROMPT_DIRTRIM
    }

    add-zsh-hook chpwd _agkozak_chpwd
  fi

  # Only display the HOSTNAME for an SSH connection or for a superuser
  if _agkozak_is_ssh || (( EUID == 0 )); then
    psvar[1]="@${HOST%%.*}"
  else
    psvar[1]=''
  fi

  # The DragonFly BSD console and Emacs shell can't handle bracketed paste.
  # Avoid the ugly ^[[?2004 control sequence.
  if [[ $TERM == 'cons25' ]] || [[ $TERM == 'dumb' ]]; then
    unset zle_bracketed_paste
  fi

  # The Emacs shell has only limited support for some ZSH features, so use a
  # more limited prompt.
  if [[ $TERM == 'dumb' ]]; then
    PROMPT='%(?..(%?%) )'
    PROMPT+='%n%1v '
    PROMPT+='$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")'
    PROMPT+='$(_agkozak_branch_status) '
    PROMPT+='%# '
  else
    # Avoid continuation lines in Emacs term and ansi-term
    (( $+INSIDE_EMACS )) && ZLE_RPROMPT_INDENT=3

    # When VSCode is using the DOM renderer, the right prompt overflows off the
    # side of the screen
    (( $+VSCODE_PID )) && ZLE_RPROMPT_INDENT=6

    _agkozak_prompt_string

  fi

  _agkozak_debug_print "Using async method: $AGKOZAK_ASYNC_METHOD"
}

# Clean up environment
(( AGKOZAK_PROMPT_DEBUG )) \
  || unfunction _agkozak_load_async_lib _agkozak_has_usr1 _agkozak_async_init

# vim: ts=2:et:sts=2:sw=2:
