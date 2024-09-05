#              _                 _
#   __ _  __ _| | _____ ______ _| | __
#  / _` |/ _` | |/ / _ \_  / _` | |/ /
# | (_| | (_| |   < (_) / / (_| |   <
#  \__,_|\__, |_|\_\___/___\__,_|_|\_\
#        |___/
#
# An asynchronous, dynamic Git prompt for Zsh
#
#
# MIT License
#
# Copyright (c) 2017-2024 Alexandros Kozak
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
#                                           with indicator of changes made,
#                                           surrounded by parentheses and
#                                           preceded by $AGKOZAK_PRE_PROMPT_CHAR
#
# psvar[4]      %4v                         Equals 'vicmd' when vi command mode
#                                           is enabled; otherwise empty
#
# psvar[5]      %5v                         Empty only when
#                                           AGKOZAK_USER_HOST_DISPLAY is 0
#                                           (legacy; deprecated)
#
# psvar[6]      %6v                         Just the branch name
#
# psvar[7]      %7v                         Just the Git symbols
#
# psvar[8]      %8v                         The number of seconds the last
#                                           command ran for; only displayed if
#                                           that time exceeded
#                                           AGKOZAK_CMD_EXEC_TIME (setting the
#                                           latter to 0 turns off the display)
#
# psvar[9]      %9v                         psvar[8] pretty-printed as days,
#                                           hours, minutes, and seconds, thus:
#                                           1d 2h 3m 4s
#
# psvar[10]     %10v                        Name of virtual environment
#
# psvar[11]     %11v                        Number of jobs running in the
#                                           background (legacy; deprecated;
#                                           use %j)
#

# EPOCHSECONDS is needed to display command execution time
(( $+EPOCHSECONDS )) || zmodload zsh/datetime

autoload -Uz is-at-least add-zle-hook-widget

# AGKOZAK is an associative array for storing internal information that is
# discarded when the prompt is unloaded.
#
# AGKOZAK[ASYNC_METHOD] Which asynchronous method is currently in use
# AGKOZAK[FIRST_PROMPT_PRINTED] When AGKOZAK_BLANK_LINES=1, this variable
#                       prevents an unnecessary blank line before the first
#                       prompt of the session
# AGKOZAK[FUNCTIONS]    A list of the prompt's functions
# AGKOZAK[IS_WSL1]      Whether or not the system is WSL1
# AGKOZAK[OLD_PROMPT]   The left prompt before this prompt was loaded
# AGKOZAK[OLD RPROMPT]  The right prompt before this prompt was loaded
# AGKOZAK[PROMPT]       The current state of the left prompt
# AGKOZAK[PROMPT_DIR]   The directory the prompt source code is in
# AGKOZAK[RPROMPT]      The current state of the right prompt
# AGKOZAK[TRAPUSR1_FUNCTION]  The code of the TRAPUSR1 function. If it changes,
#                       the prompt knows to abandon the usr1 method.
# AGKOZAK[USR1_ASYNC_WORKER]  When non-zero, the PID of the asynchronous
#                       function handling Git Status (usr1 method)
typeset -gA AGKOZAK

# Options to reset if the prompt is unloaded
typeset -gA AGKOZAK_OLD_OPTIONS
AGKOZAK_OLD_OPTIONS=(
                      'promptsubst' ${options[promptsubst]}
                      'promptbang' ${options[promptbang]}
                    )

# Store previous prompts and psvars for the unload function
typeset -ga AGKOZAK_OLD_PSVAR
AGKOZAK[OLD_PROMPT]=$PROMPT
AGKOZAK[OLD_RPROMPT]=$RPROMPT
AGKOZAK_OLD_PSVAR=( ${psvar[@]} )

# Names of prompt functions. Used to enable WARN_NESTED_VAR in debug mode
# and for unloading the prompt.
AGKOZAK[FUNCTIONS]='_agkozak_debug_print
                    _agkozak_has_colors
                    _agkozak_is_ssh
                    _agkozak_prompt_dirtrim
                    _agkozak_branch_status
                    _agkozak_set_git_psvars
                    _agkozak_zle-keymap-select
                    TRAPWINCH
                    _agkozak_vi_mode_indicator
                    _agkozak_load_async_lib
                    _agkozak_has_usr1
                    _agkozak_async_init
                    _agkozak_subst_async
                    _agkozak_zsh_subst_async_callback
                    _agkozak_zsh_async
                    _agkozak_zsh_async_callback
                    _agkozak_usr1_async
                    _agkozak_usr1_async_worker
                    TRAPUSR1
                    _agkozak_strip_colors
                    prompt_agkozak_preexec
                    prompt_agkozak_precmd
                    _agkozak_prompt_strings
                    prompt_agkozak-zsh-prompt_preview
                    prompt_agkozak-zsh-prompt_help
                    _agkozak_prompt_cleanup'

# Some global declarations
typeset -g AGKOZAK_PROMPT_DEBUG \
           AGKOZAK_COLORS_EXIT_STATUS \
           AGKOZAK_COLORS_USER_HOST \
           AGKOZAK_COLORS_PATH \
           AGKOZAK_COLORS_BRANCH_STATUS \
           AGKOZAK_COLORS_PROMPT_CHAR \
           AGKOZAK_COLORS_CMD_EXEC_TIME \
           AGKOZAK_COLORS_VIRTUALENV \
           AGKOZAK_COLORS_BG_STRING \
           AGKOZAK_LEFT_PROMPT_ONLY \
           AGKOZAK_MULTILINE \
           AGKOZAK_NAMED_DIRS \
           AGKOZAK_PROMPT_DIRTRIM \
           AGKOZAK_PROMPT_DIRTRIM_STRING \
           AGKOZAK_SHOW_STASH \
           AGKOZAK_USER_HOST_DISPLAY \
           AGKOZAK_CMD_EXEC_TIME \
           AGKOZAK_BLANK_LINES \
           AGKOZAK_SHOW_VIRTUALENV \
           AGKOZAK_SHOW_BG

typeset -ga AGKOZAK_CMD_EXEC_TIME_CHARS \
            AGKOZAK_VIRTUALENV_CHARS

# Set AGKOZAK_PROMPT_DEBUG=1 for debugging mode
: ${AGKOZAK_PROMPT_DEBUG:=0}

############################################################
# Display a message on STDERR if debug mode is enabled
#
# Globals:
#   AGKOZAK_PROMPT_DEBUG
# Arguments:
#   $1  Message to send to STDERR
############################################################
_agkozak_debug_print() {
  if (( AGKOZAK_PROMPT_DEBUG )); then
    _agkozak_has_colors && print -Pn '%F{red}' >&2
    print -n -- "agkozak-zsh-prompt: $1" >&2
    _agkozak_has_colors && print -Pn '%f' >&2
    print >&2
  fi
}

if (( AGKOZAK_PROMPT_DEBUG )); then
  if is-at-least 5.4.0; then
    # Enable WARN_CREATE_GLOBAL for each function of the prompt
    functions -W ${=AGKOZAK[FUNCTIONS][@]}
  fi
fi

# Putting these default options here makes sure that the variables are in the
# environment and can be easily manipulated at the command line using tab
# completion

# Set AGKOZAK_COLORS_* variables to any valid color
#   AGKOZAK_COLORS_EXIT_STATUS changes the exit status color      (default: red)
#   AGKOZAK_COLORS_USER_HOST changes the username/hostname color  (default: green)
#   AGKOZAK_COLORS_PATH changes the path color                    (default: blue)
#   AGKOZAK_COLORS_BRANCH_STATUS changes the branch status color  (default: yellow)
#   AGKOZAK_COLORS_PROMPT_CHAR changes the prompt character color (default: default text color)
#   AGKOZAK_COLORS_CMD_EXEC_TIME changes the command executime time color
#                                                                 (default: magenta)
#   AGKOZAK_COLORS_VIRTUALENV changes the virtual environment color (default: green)
#   AGKOZAK_COLORS_BG_STRING changes the background job indicator color
#                                                                 (default: yellow)
: ${AGKOZAK_COLORS_EXIT_STATUS:=red}
: ${AGKOZAK_COLORS_USER_HOST:=green}
: ${AGKOZAK_COLORS_PATH:=blue}
: ${AGKOZAK_COLORS_BRANCH_STATUS:=yellow}
: ${AGKOZAK_COLORS_PROMPT_CHAR:=default}
: ${AGKOZAK_COLORS_CMD_EXEC_TIME:=default}
: ${AGKOZAK_COLORS_VIRTUALENV:=green}
: ${AGKOZAK_COLORS_BG_STRING:=magenta}

# Whether or not to display the Git status in the left prompt (default: off)
: ${AGKOZAK_LEFT_PROMPT_ONLY:=0}
# Whether or not the left prompt is two lines (default: on)
: ${AGKOZAK_MULTILINE:=1}
# Whether or not to use ZSH's default display of hashed (named) directories as
# ~foo (default: on)
: ${AGKOZAK_NAMED_DIRS:=1}
# The number of path elements to display (default: 2; 0 displays the whole path)
: ${AGKOZAK_PROMPT_DIRTRIM:=2}
# The string to use to indicate that a path has been abbreviated (default: ...)
: ${AGKOZAK_PROMPT_DIRTRIM_STRING:=...}
# Whether or not to display the Git stash (default: on)
: ${AGKOZAK_SHOW_STASH:=1}
# Whether or not to display the username and hostname (default: on)
: ${AGKOZAK_USER_HOST_DISPLAY:=1}
# Threshold for showing command execution time (default: 5 seconds; 0 turns the
# display off
: ${AGKOZAK_CMD_EXEC_TIME:=5}
# Whether or not to put blank lines in between instances of the prompt
: ${AGKOZAK_BLANK_LINES:=0}
# Whether or not to display the virtual environment
: ${AGKOZAK_SHOW_VIRTUALENV:=1}
# Whether or not to indicate if a job is running in the background
: ${AGKOZAK_SHOW_BG:=1}
# Characters to put around the command execution time (default: nothing)
(( $+AGKOZAK_CMD_EXEC_TIME_CHARS )) || AGKOZAK_CMD_EXEC_TIME_CHARS=()
# Characters to put around the virtual environment name (default: square brackets)
(( $+AGKOZAK_VIRTUALENV_CHARS )) || AGKOZAK_VIRTUALENV_CHARS=( '[' ']' )

######################################################################
# GENERAL FUNCTIONS
######################################################################

############################################################
# Are colors available?
#
# Globals:
#   AGKOZAK
############################################################
_agkozak_has_colors() {
    case $TERM in
      *-256color) return 0 ;;
      vt100|dumb) return 1 ;;
      *)
        [[ ${modules[zsh/terminfo]} == loaded ]] || zmodload zsh/terminfo
        (( ${terminfo[colors]:-0} >= 8 ))
        ;;
    esac
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
  [[ -n ${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-} ]]
}

############################################################
# Emulation of bash's PROMPT_DIRTRIM for ZSH
#
# Take PWD and substitute HOME with `~'. If the rest of PWD
# has more than a certain number of elements in its
# directory tree, keep the number specified by
# AGKOZAK_PROMPT_DIRTRIM (default: 2) and abbreviate the
# rest with AGKOZAK_PROMPT_DIRTRIM_STRING (default: `...').
# (Set AGKOZAK_PROMPT_DIRTRIM=0 to disable
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
#   AGKOZAK_PROMPT_DEBUG
#   AGKOZAK_NAMED_DIRS
# Arguments:
#   [Optional] If `-v', store the function's output in
#        psvar[2] instead of printing it to STDOUT
#   [Optional] Number of directory elements to display (default: 2)
############################################################
_agkozak_prompt_dirtrim() {
  emulate -L zsh
  (( AGKOZAK_PROMPT_DEBUG )) && setopt LOCAL_OPTIONS WARN_CREATE_GLOBAL

  # Process arguments
  local argument
  for argument in $@; do
    [[ $argument == '-v' ]] && local var=1
  done
  until [[ $1 != '-v' ]]; do
    shift
  done
  [[ $1 -ge 0 ]] || set 2

  # The ellipsis string to use when trimming paths (default: ...)
  local ellipsis=${AGKOZAK_PROMPT_DIRTRIM_STRING:-...}

  local output

  # Default behavior (when AGKOZAK_NAMED_DIRS is 1)
  if (( ${AGKOZAK_NAMED_DIRS:-1} )); then
    local zsh_pwd
    zsh_pwd=${(%):-%~}

    # IF AGKOZAK_PROMPT_DIRTRIM is not 0, trim directory
    if (( $1 )); then
      case $zsh_pwd in
        \~) output=${(%)zsh_pwd} ;;
        \~/*) output="${(%):-%($(( $1 + 2 ))~|~/${ellipsis}/%${1}~|%~)}" ;;
        \~*) output="${(%):-%($(( $1 + 2 ))~|${zsh_pwd%%${zsh_pwd#\~*\/}}${ellipsis}/%${1}~|%~)}" ;;
        *) output="${(%):-%($(( $1 + 1 ))/|${ellipsis}/%${1}d|%d)}" ;;
      esac
    else
      output=$zsh_pwd
    fi

  # If AGKOZAK_NAMED_DIRS is 0
  else
    local dir dir_count
    case $HOME in
      /) dir=$PWD ;;
      *) dir=${PWD#$HOME} ;;
    esac

    # If AGKOZAK_PROMPT_DIRTRIM is not 0, trim the directory
    if (( $1 > 0 )); then

      # The number of directory elements is the number of slashes in ${PWD#$HOME}
      dir_count=$(( $#dir - ${#${dir//\//}} ))
      if (( dir_count <= $1 )); then
        case $PWD in
          $HOME) output='~' ;;
          ${HOME}*) output="~${dir}" ;;
          *) output="$PWD" ;;
        esac
      else
        local lopped_path i
        lopped_path=$dir
        i=0
        while (( i != $1 )); do
          lopped_path=${lopped_path%\/*}
          (( i++ ))
        done
        case $PWD in
          ${HOME}*) output="~/${ellipsis}${dir#${lopped_path}}" ;;
          *) output="${ellipsis}${PWD#${lopped_path}}" ;;
        esac
      fi

    # If AGKOZAK_PROMPT_DIRTRIM is 0
    else
      case $PWD in
        $HOME) output='~' ;;
        ${HOME}*) output="~${dir}" ;;
        *) output="$PWD" ;;
      esac
    fi
  fi

  # Argument -v stores the output to psvar[2]; otherwise send to STDOUT
  if (( var )); then
    psvar[2]=$output
  else
    print -n -- $output
  fi
}

############################################################
# Display current branch name, followed by symbols
# representing changes to the working copy
#
# Globals:
#   AGKOZAK
#   AGKOZAK_PROMPT_DEBUG
#   AGKOZAK_SHOW_STASH
#   AGKOZAK_GIT_VERSION
#   AGKOZAK_CUSTOM_SYMBOLS
#   AGKOZAK_BRANCH_STATUS_SEPARATOR
############################################################
_agkozak_branch_status() {
  emulate -L zsh
  (( AGKOZAK_PROMPT_DEBUG )) && setopt LOCAL_OPTIONS WARN_CREATE_GLOBAL

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

    if is-at-least 2.14 $AGKOZAK_GIT_VERSION &&
        (( ${AGKOZAK_SHOW_STASH:-1} )); then
      git_status="$(LC_ALL=C GIT_OPTIONAL_LOCKS=0 command git status --show-stash 2>&1)"
    else
      git_status="$(LC_ALL=C GIT_OPTIONAL_LOCKS=0 command git status 2>&1)"
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
    if (( ${AGKOZAK_SHOW_STASH:-1} )); then
      if is-at-least 2.14 $AGKOZAK_GIT_VERSION; then
        case $git_status in
          *'Your stash currently has '*)
            symbols+="${AGKOZAK_CUSTOM_SYMBOLS[$i]:-\$}"
            ;;
        esac
      else
        if LC_ALL=C GIT_OPTIONAL_LOCKS=0 command git rev-parse --verify \
          refs/stash &> /dev/null; then
          symbols+="${AGKOZAK_CUSTOM_SYMBOLS[$i]:-\$}"
        fi
      fi
    fi

    [[ -n $symbols ]] && symbols=" ${symbols}"

    printf -- '%s(%s%s)' "${AGKOZAK_BRANCH_STATUS_SEPARATOR- }" "$branch" \
      "$symbols"
  fi
}

############################################################
# Set psvar[3] to be the Git branch and status in
# parentheses, psvar[6] to be just the Git branch, and
# psvar[7] to be just the Git symbols.
#
# Arguments:
#   $1  The Git branch and status string (the output of
#         _agkozak_branch_status)
############################################################
_agkozak_set_git_psvars() {
  psvar[3]="$1"
  psvar[6]=${${${1#*\(}% *}%\)}
  if [[ ${1#*\(} == *' '* ]]; then
    psvar[7]=${${1%\)}##* }
  else
    psvar[7]=''
  fi
}

############################################################
# Redraw the prompt when the vi mode changes. When the user
# enters vi command mode, the % or # in the prompt changes
# to a colon
############################################################
_agkozak_zle-keymap-select() {
  emulate -L zsh

  [[ $KEYMAP == 'vicmd' ]] && psvar[4]='vicmd' || psvar[4]=''
  zle && { zle .reset-prompt; zle -R; }
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
# (See https://github.com/agkozak/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc)0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}})
0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-$PWD/$0}
AGKOZAK[PROMPT_DIR]="${0:A:h}"

############################################################
# If zsh-async has not already been loaded, try to load it
#
# Globals:
#   AGKOZAK
#   AGKOZAK_PROMPT_DEBUG
############################################################
_agkozak_load_async_lib() {
  if (( ${+functions[async_init]} )); then
    _agkozak_debug_print 'zsh-async already loaded.'
  else
    if (( AGKOZAK_PROMPT_DEBUG )); then
      source "${AGKOZAK[PROMPT_DIR]}/lib/async.zsh"
    else
      source "${AGKOZAK[PROMPT_DIR]}/lib/async.zsh" &> /dev/null
    fi
    local success=$?
    return $success
  fi
}

############################################################
# Is SIGUSR1 is available and not already in use by ZSH?
############################################################
_agkozak_has_usr1() {
  if (( ${+functions[TRAPUSR1]} )); then
    _agkozak_debug_print 'TRAPUSR1 function already defined.'
    if [[ ${functions[TRAPUSR1]} = *_agkozak* ]]; then
      _agkozak_debug_print "Continuing to use agkozak-zsh-prompt's TRAPUSR1 function."
      return 0
    else
      _agkozak_debug_print 'Falling back to subst-async.'
    fi
  else
    case ${signals[@]} in    # Array containing names of available signals
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
# use it; otherwise, determine the optimal asynchronous
# method for the environment (usr1 for MSYS2/Cygwin/WSL1,
# subst-async for everything else), with fallbacks being
# available. Define the necessary asynchronous functions
# (loading async.zsh when necessary).
#
# Globals:
#   AGKOZAK
#   AGKOZAK_FORCE_ASYNC_METHOD
#   AGKOZAK_ASYNC_FD
#   AGKOZAK_PROMPT_DEBUG
############################################################
_agkozak_async_init() {
  emulate -L zsh
  setopt LOCAL_OPTIONS NO_LOCAL_TRAPS

  if [[ $AGKOZAK_FORCE_ASYNC_METHOD == (subst-async|zsh-async|usr1|none) ]]; then
    [[ $AGKOZAK_FORCE_ASYNC_METHOD == 'zsh-async' ]] && _agkozak_load_async_lib
    AGKOZAK[ASYNC_METHOD]=$AGKOZAK_FORCE_ASYNC_METHOD
  elif [[ $TERM == 'dumb' ]]; then
    AGKOZAK[ASYNC_METHOD]='none'
  elif _agkozak_has_usr1; then
    AGKOZAK[ASYNC_METHOD]='usr1'
  else
    AGKOZAK[ASYNC_METHOD]='subst-async'
  fi

  ############################################################
  # Process substitution async method
  #
  # Fork a background process to fetch the Git status and feed
  # it asynchronously to a file descriptor. Install a callback
  # handler to process input from the file descriptor.
  #
  # Globals:
  #   AGKOZAK
  #   AGKOZAK_ASYNC_FD
  ############################################################
  _agkozak_subst_async() {
    emulate -L zsh
    setopt LOCAL_OPTIONS NO_IGNORE_BRACES

    typeset -g AGKOZAK_ASYNC_FD=13371

    # There was a bug in Zsh < 5.8 that required forking
    if is-at-least 5.8; then
      exec {AGKOZAK_ASYNC_FD} < <(_agkozak_branch_status)
    else
      if [[ $OSTYPE == (msys|cygwin) ]]; then
        exec {AGKOZAK_ASYNC_FD} < <(_agkozak_branch_status; command true)
      elif [[ $OSTYPE == solaris* ]]; then
        exec {AGKOZAK_ASYNC_FD} < <(_agkozak_branch_status)
        command sleep 0.01
      elif [[ $ZSH_VERSION == 5.0.[0-2] ]]; then
        exec {AGKOZAK_ASYNC_FD} < <(_agkozak_branch_status)
        command sleep 0.02
      else
        exec {AGKOZAK_ASYNC_FD} < <(_agkozak_branch_status)

        # Bug workaround; see http://www.zsh.org/mla/workers/2018/msg00966.html
        command true
      fi
    fi

    zle -F "$AGKOZAK_ASYNC_FD" _agkozak_zsh_subst_async_callback
  }

  ############################################################
  # ZLE callback handler
  #
  # Read Git status from file descriptor and set the relevant
  # psvars
  #
  # Arguments:
  #   $1  File descriptor
  ############################################################
  _agkozak_zsh_subst_async_callback() {
    emulate -L zsh
    setopt LOCAL_OPTIONS NO_IGNORE_BRACES

    local fd="$1" response

    # Read data from $FD descriptor
    IFS='' builtin read -rs -d $'\0' -u "$fd" response

    # Withdraw callback and close the file descriptor
    zle -F ${fd}; exec {fd}<&-

    # Make the changes visible
    _agkozak_set_git_psvars "$response"
    zle && zle .reset-prompt
  }

  case ${AGKOZAK[ASYNC_METHOD]} in

    zsh-async)

      ############################################################
      # Create zsh-async worker
      ############################################################
      _agkozak_zsh_async() {
        async_start_worker agkozak_git_status_worker -n
        async_register_callback agkozak_git_status_worker \
          _agkozak_zsh_async_callback
        async_job agkozak_git_status_worker _agkozak_branch_status
      }

      ############################################################
      # Update the prompts and stop worker
      ############################################################
      _agkozak_zsh_async_callback() {
        emulate -L zsh

        _agkozak_set_git_psvars "$3"
        zle && zle .reset-prompt
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
      #   AGKOZAK
      ############################################################
      _agkozak_usr1_async() {
        emulate -L zsh

        # Make sure TRAPUSR1 has not been redefined
        if [[ ${functions[TRAPUSR1]} == *_agkozak* ]]; then
          # Kill running child process if necessary
          if (( AGKOZAK[USR1_ASYNC_WORKER] )); then
            kill -s HUP "${AGKOZAK[USR1_ASYNC_WORKER]}" &> /dev/null || :
          fi

          # Start background computation of Git status
          _agkozak_usr1_async_worker &!
          AGKOZAK[USR1_ASYNC_WORKER]="$!"
        else
          _agkozak_debug_print 'TRAPUSR1 has been redefined. Switching to subst-async mode.'
          AGKOZAK[ASYNC_METHOD]='subst-async'
          prompt_agkozak_precmd
        fi
      }

      ############################################################
      # Calculate Git status and store it in a temporary file;
      # then kill own process, sending SIGUSR1
      ############################################################
      _agkozak_usr1_async_worker() {
        # Save Git branch status to temporary file
        _agkozak_branch_status >| /tmp/agkozak_zsh_prompt_$$

        # Signal parent process
        kill -s USR1 $$ &> /dev/null
      }

      ############################################################
      # On SIGUSR1, fetch Git status from temprary file and store
      # it in the relevant psvars. This function caches its own
      # code in AGKOZAK[TRAPUSR1_FUNCTION] so that it can tell if
      # it has been redefined by another script.
      #
      # Globals:
      #   AGKOZAK
      ############################################################
      TRAPUSR1() {
        emulate -L zsh

        # Set prompts from contents of temporary file
        _agkozak_set_git_psvars "$(< /tmp/agkozak_zsh_prompt_$$)"

        # Reset asynchronous process number
        AGKOZAK[USR1_ASYNC_WORKER]=0

        # Redraw the prompt
        zle && zle .reset-prompt
      }

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
#   $1 Name of prompt string variable
############################################################
_agkozak_strip_colors() {
  local prompt_string=${(P)1} newprompt
  local open_braces

  while [[ -n $prompt_string ]]; do
    case $prompt_string in
      %F\{*|%K\{*)
        (( open_braces++ ))
        prompt_string=${prompt_string#%[FK]\{}
        while (( open_braces )); do
          case ${prompt_string:0:1} in
            \{) (( open_braces++ )) ;;
            \}) (( open_braces-- )) ;;
          esac
          prompt_string=${prompt_string#?}
        done
        ;;
      %f*|%k*) prompt_string=${prompt_string#%[fk]} ;;
      *)
        newprompt+="${prompt_string:0:1}"
        prompt_string=${prompt_string#?}
        ;;
    esac
  done

  typeset -g $1=$newprompt
}

############################################################
# Runs right before each command is about to be executed.
# Used to calculate command execution time.
############################################################
prompt_agkozak_preexec() {
  typeset -gi AGKOZAK_CMD_START_TIME=$EPOCHSECONDS
}

############################################################
# Runs right before each prompt is displayed; hooks into
# precmd
#
# Globals:
#   AGKOZAK
#   AGKOZAK_PROMPT_DEBUG
#   AGKOZAK_GIT_VERSION
#   AGKOZAK_USER_HOST_DISPLAY
#   AGKOZAK_MULTILINE
#   AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_PRE_PROMPT_CHAR
#   AGKOZAK_BLANK_LINES
#   AGKOZAK_PROMPT_DIRTRIM
#   AGKOZAK_BG_STRING
############################################################
prompt_agkozak_precmd() {
  emulate -L zsh
  (( AGKOZAK_PROMPT_DEBUG )) && [[ $ZSH_VERSION != 5.0.[0-2] ]] &&
    setopt LOCAL_OPTIONS WARN_CREATE_GLOBAL

  # Calculate the time it took to run the last command
  psvar[8]=''
  psvar[9]=''
  if (( AGKOZAK_CMD_START_TIME && AGKOZAK_CMD_EXEC_TIME )); then
    local cmd_exec_time=$(( EPOCHSECONDS - AGKOZAK_CMD_START_TIME ))
    if (( cmd_exec_time >= AGKOZAK_CMD_EXEC_TIME )); then
      psvar[8]=$cmd_exec_time
      # Pretty printing routine borrowed from pure
      # Compare https://github.com/sindresorhus/pure/blob/c031f6574af3f8afb43920e32ce02ee6d46ab0e9/pure.zsh#L31-L39
      local days=$(( cmd_exec_time / 60 / 60 / 24 ))
      local hours=$(( cmd_exec_time / 60 / 60 % 24 ))
      local minutes=$(( cmd_exec_time / 60 % 60 ))
      local seconds=$(( cmd_exec_time % 60 ))
      (( days )) && psvar[9]+="${days}d "
      (( hours )) && psvar[9]+="${hours}h "
      (( minutes )) && psvar[9]+="${minutes}m "
      psvar[9]+="${seconds}s"
    fi

  fi
  typeset -gi AGKOZAK_CMD_START_TIME=0

  # Prompt element for virtualenv/venv/pipenv/poetry/conda
  #
  # pipenv/poetry: when the virtualenv is in the project directory
  if [[ ${VIRTUAL_ENV:t} == '.venv' ]]; then
    psvar[10]=${VIRTUAL_ENV:h:t}
  # pipenv
  elif (( PIPENV_ACTIVE )); then
    # Remove the hash
    psvar[10]=${${VIRTUAL_ENV%-*}:t}
  # poetry
  elif (( POETRY_ACTIVE )); then
    # Remove the hash and version number
    psvar[10]=${${${VIRTUAL_ENV%-*}%-*}:t}
  # virtualenv/venv/conda
  else
    psvar[10]=${${VIRTUAL_ENV:t}:-${CONDA_DEFAULT_ENV//[$'\t\r\n']/}}
  fi

  # Cache the Git version
  if (( ${AGKOZAK_SHOW_STASH:-1} )); then
    typeset -gx AGKOZAK_GIT_VERSION
    : ${AGKOZAK_GIT_VERSION:=${"$(LC_ALL=C GIT_OPTIONAL_LOCKS=0 command git --version)"#git version }}
  fi

  # Clear the Git status display until it has been recalculated
  _agkozak_set_git_psvars ''

  # It is necessary to clear the vi mode display, too
  psvar[4]=''

  # Choose whether or not to display username and hostname
  # Legacy code to provide %5v for custom prompts that use it.
  if (( ${AGKOZAK_USER_HOST_DISPLAY:-1} )); then
    psvar[5]=${AGKOZAK_USER_HOST_DISPLAY:-1}
  else
    psvar[5]=''
  fi

  # Multiline (default) or single line?
  if (( ! ${AGKOZAK_MULTILINE:-1} )) && [[ -z $INSIDE_EMACS ]]; then
    typeset -g AGKOZAK_PROMPT_WHITESPACE=${AGKOZAK_PRE_PROMPT_CHAR- }
  else
    typeset -g AGKOZAK_PROMPT_WHITESPACE=$'\n'
  fi

  # Optionally put blank lines between instances of the prompt
  (( AGKOZAK_BLANK_LINES && AGKOZAK[FIRST_PROMPT_PRINTED] )) && print
  AGKOZAK[FIRST_PROMPT_PRINTED]=1

  # Begin to calculate the Git status
  case ${AGKOZAK[ASYNC_METHOD]} in
    'subst-async') _agkozak_subst_async ;;
    'zsh-async') _agkozak_zsh_async ;;
    'usr1') _agkozak_usr1_async ;;
    *) _agkozak_set_git_psvars "$(_agkozak_branch_status)" ;;
  esac

  # psvar[11] deprecated in favor of %j

  # Clear background job count
  psvar[11]=''

  # Get the amount of jobs running in the background
  psvar[11]=${${(%):-%j}#0}

  # Construct and display PROMPT and RPROMPT
  _agkozak_prompt_dirtrim -v ${AGKOZAK_PROMPT_DIRTRIM:-2}
  _agkozak_prompt_strings
}

############################################################
# Set the prompt strings
#
# Globals:
#   AGKOZAK
#   AGKOZAK_CUSTOM_PROMPT
#   AGKOZAK_COLORS_EXIT_STATUS
#   AGKOZAK_COLORS_USER_HOST
#   AGKOZAK_COLORS_PATH
#   AGKOZAK_LEFT_PROMPT_ONLY
#   AGKOZAK_COLORS_BRANCH_STATUS AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_COLORS_PROMPT_CHAR
#   AGKOZAK_COLORS_BG_STRING
#   AGKOZAK_PROMPT_CHAR
#   AGKOZAK_CUSTOM_RPROMPT
#   AGKOZAK_MULTILINE
############################################################
_agkozak_prompt_strings() {
  emulate -L zsh

  if (( $+AGKOZAK_CUSTOM_PROMPT )); then
    AGKOZAK[PROMPT]=$AGKOZAK_CUSTOM_PROMPT
  else
    # The color left prompt
    AGKOZAK[PROMPT]=''
    AGKOZAK[PROMPT]+='%(?..%B%F{${AGKOZAK_COLORS_EXIT_STATUS:-red}}(%?%)%f%b )'
    AGKOZAK[PROMPT]+='%(9V.%F{${AGKOZAK_COLORS_CMD_EXEC_TIME:-default}}${AGKOZAK_CMD_EXEC_TIME_CHARS[1]}%9v${AGKOZAK_CMD_EXEC_TIME_CHARS[2]}%f .)'
    if (( AGKOZAK_USER_HOST_DISPLAY )); then
      AGKOZAK[PROMPT]+='%(!.%S%B.%B%F{${AGKOZAK_COLORS_USER_HOST:-green}})%n%1v%(!.%b%s.%f%b) '
    fi
    AGKOZAK[PROMPT]+='%B%F{${AGKOZAK_COLORS_PATH:-blue}}%2v%f%b'
    if (( ${AGKOZAK_SHOW_VIRTUALENV:-1} )); then
      AGKOZAK[PROMPT]+='%(10V. %F{${AGKOZAK_COLORS_VIRTUALENV:-green}}${AGKOZAK_VIRTUALENV_CHARS[1]-[}%10v${AGKOZAK_VIRTUALENV_CHARS[2]-]}%f.)'
    fi
    if (( ${AGKOZAK_SHOW_BG:-1} )); then
      AGKOZAK[PROMPT]+='%(1j. %F{${AGKOZAK_COLORS_BG_STRING:-magenta}}%j${AGKOZAK_BG_STRING:-j}%f.)'
    fi
    if (( ${AGKOZAK_LEFT_PROMPT_ONLY:-0} )); then
      AGKOZAK[PROMPT]+='%(3V.%F{${AGKOZAK_COLORS_BRANCH_STATUS:-yellow}}%3v%f.)'
    fi
    AGKOZAK[PROMPT]+='${AGKOZAK_PROMPT_WHITESPACE}'
    AGKOZAK[PROMPT]+='%F{${AGKOZAK_COLORS_PROMPT_CHAR:-default}}'
    AGKOZAK[PROMPT]+='%(4V.${AGKOZAK_PROMPT_CHAR[3]:-:}.%(!.${AGKOZAK_PROMPT_CHAR[2]:-%#}.${AGKOZAK_PROMPT_CHAR[1]:-%#}))'
    AGKOZAK[PROMPT]+='%f '
  fi

  if (( $+AGKOZAK_CUSTOM_RPROMPT )); then
    AGKOZAK[RPROMPT]=$AGKOZAK_CUSTOM_RPROMPT
  else
    # The color right prompt
    if (( ! ${AGKOZAK_LEFT_PROMPT_ONLY:-0} )); then
      AGKOZAK[RPROMPT]='%(3V.%F{${AGKOZAK_COLORS_BRANCH_STATUS:-yellow}}%3v%f.)'
    else
      AGKOZAK[RPROMPT]=''
    fi
  fi

  if ! _agkozak_has_colors; then
    _agkozak_strip_colors 'AGKOZAK[PROMPT]'
    _agkozak_strip_colors 'AGKOZAK[RPROMPT]'
  fi

  typeset -g PROMPT=${AGKOZAK[PROMPT]}
  typeset -g RPROMPT=${AGKOZAK[RPROMPT]}
}

############################################################
# Prompt setup
#
# Globals:
#   AGKOZAK
#   AGKOZAK_PROMPT_DEBUG
#   AGKOZAK_PROMPT_DIRTRIM
############################################################
prompt_agkozak-zsh-prompt_setup() {
  # `emulate -L zsh' has been removed for promptinit
  # compatibility
  typeset -ga prompt_opts
  prompt_opts=( cr percent sp subst )
  setopt NO_PROMPT_{BANG,PERCENT,SUBST} "PROMPT_${^prompt_opts[@]}"

  _agkozak_async_init

  case ${AGKOZAK[ASYNC_METHOD]} in
    'subst-async') ;;
    'zsh-async') async_init ;;
    'usr1') AGKOZAK[USR1_ASYNC_WORKER]=0 ;;
  esac

  if is-at-least 5.3; then
    add-zle-hook-widget zle-keymap-select _agkozak_zle-keymap-select
  else
    zle -N zle-keymap-select _agkozak_zle-keymap-select
  fi

  # Don't use Zsh hooks in Emacs classic shell
  if (( $+INSIDE_EMACS )) && [[ $TERM == 'dumb' ]]; then
    :
  else
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec prompt_agkozak_preexec
    add-zsh-hook precmd prompt_agkozak_precmd
  fi

  # Only display the HOSTNAME for an SSH connection or for a superuser
  if _agkozak_is_ssh || (( EUID == 0 )); then
    psvar[1]="@${(%):-%m}"
  else
    psvar[1]=''
  fi

  # The DragonFly BSD console and Emacs shell can't handle bracketed paste.
  # Avoid the ugly ^[[?2004 control sequence.
  [[ $TERM == (cons25|dumb) ]] && unset zle_bracketed_paste

  # The Emacs shell has only limited support for some Zsh features, so use a
  # more limited prompt.
  if [[ $TERM == 'dumb' ]]; then
    PROMPT='%(?..(%?%) )'
    PROMPT+='%n%1v '
    PROMPT+='$(_agkozak_prompt_dirtrim "${AGKOZAK_PROMPT_DIRTRIM:-2}")'
    PROMPT+='$(_agkozak_branch_status) '
    PROMPT+='%# '
  else
    # Avoid continuation lines in Emacs term and ansi-term
    (( $+INSIDE_EMACS )) && ZLE_RPROMPT_INDENT=3

    # When VSCode is using the DOM renderer, the right prompt overflows off the
    # side of the screen
    (( $+VSCODE_PID )) && ZLE_RPROMPT_INDENT=6
  fi

  # For promptinit (introduced in Zsh v5.4)
  (( ${+functions[prompt_cleanup]} )) &&
    prompt_cleanup _agkozak_prompt_cleanup

  _agkozak_debug_print "Using async method: ${AGKOZAK[ASYNC_METHOD]}"
}

prompt_agkozak-zsh-prompt_setup

############################################################
# Preview function for promptinit
############################################################

prompt_agkozak-zsh-prompt_preview() {
  print "No preview available. Try \`prompt agkozak-zsh-prompt'."
}

############################################################
# Help function for promptinit
############################################################
prompt_agkozak-zsh-prompt_help() {
  print 'For information about how to configure the agkozak-zsh-prompt, visit https://github.com/agkozak/agkozak-zsh-prompt.' | fold -s
}

############################################################
# Unload function
#
# See https://github.com/agkozak/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#unload-fun
############################################################
agkozak-zsh-prompt_plugin_unload() {
  local x

  [[ ${AGKOZAK_OLD_OPTIONS[promptsubst]} == 'off' ]] && unsetopt PROMPT_SUBST
  [[ ${AGKOZAK_OLD_OPTIONS[promptbang]} == 'on' ]] && setopt PROMPT_BANG

  PROMPT="${AGKOZAK[OLD_PROMPT]}"
  RPROMPT="${AGKOZAK[OLD_RPROMPT]}"

  psvar=( "${AGKOZAK_OLD_PSVAR[@]}" )

  add-zsh-hook -D preexec prompt_agkozak_preexec
  add-zsh-hook -D precmd prompt_agkozak_precmd

  if is-at-least 5.3; then
    add-zle-hook-widget -D zle-keymap-select _agkozak_zle-keymap-select
  else
    zle -D zle-keymap-select
  fi

  for x in ${=AGKOZAK[FUNCTIONS]}; do
    (( ${+functions[$x]} )) && unfunction $x
  done

  unset AGKOZAK AGKOZAK_ASYNC_FD AGKOZAK_OLD_OPTIONS AGKOZAK_OLD_PSVAR \
    AGKOZAK_PROMPT_WHITESPACE

  unfunction $0
}

############################################################
# promptinit cleanup function
#
# prompt_cleanup was introduced in Zsh v5.4
############################################################
_agkozak_prompt_cleanup() {
  setopt LOCAL_OPTIONS NO_KSH_ARRAYS NO_SH_WORD_SPLIT

  add-zsh-hook -D preexec prompt_agkozak_preexec
  add-zsh-hook -D precmd prompt_agkozak_precmd

  if is-at-least 5.3; then
    add-zle-hook-widget -D zle-keymap-select _agkozak_zle-keymap-select
  else
    zle -D zle-keymap-select
  fi
}

# vim: ts=2:et:sts=2:sw=2:
