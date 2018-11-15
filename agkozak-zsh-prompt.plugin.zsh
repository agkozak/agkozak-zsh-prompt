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
# https://github.com/agkozak/agkozak-zsh-prompt
#

# shellcheck disable=SC1090,SC2016,SC2034,SC2088,SC2148,SC2154,SC2190

# psvar[] Usage
#
# psvar Index   Prompt String Equivalent    Usage
#
# psvar[1]      %1v                         Hostname/abbreviated hostname (only
#                                           displayed for SSH connections)
# psvar[2]      %2v                         Working directory or abbreviation
#                                           thereof
# psvar[3]      %3v                         Current working Git branch, along
#                                           with indicator of changes made
# psvar[4]      %4v                         Equals 'vicmd' when vi command mode
#                                           is enabled; otherwise empty

# Set AGKOZAK_PROMPT_DEBUG=1 to see debugging information
AGKOZAK_PROMPT_DEBUG=${AGKOZAK_PROMPT_DEBUG:-0}

############################################################
# Display a message on STDERR if debug mode is enabled.
#
# Globals:
#   AGKOZAK_PROMPT_DEBUG
#
# Arguments:
#   $1  Message to send to STDERR
############################################################
_agkozak_debug_print() {
  (( AGKOZAK_PROMPT_DEBUG )) && print "agkozak-zsh-prompt: $1" >&2
}

if (( AGKOZAK_PROMPT_DEBUG )); then
  autoload -Uz is-at-least

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

# Set AGKOZAK_COLORS_* variables to any valid color
#   AGKOZAK_COLORS_EXIT_STATUS changes the exit status color     (default: red)
#   AGKOZAK_COLORS_USER_HOST changes the username/hostname color (default: green)
#   AGKOZAK_COLORS_PATH changes the path color                   (default: blue)
#   AGKOZAK_COLORS_BRANCH_STATUS changes the branch status color (default: yellow)
typeset -g AGKOZAK_COLORS_EXIT_STATUS=${AGKOZAK_COLORS_EXIT_STATUS:-red}
typeset -g AGKOZAK_COLORS_USER_HOST=${AGKOZAK_COLORS_USER_HOST:-green}
typeset -g AGKOZAK_COLORS_PATH=${AGKOZAK_COLORS_PATH:-blue}
typeset -g AGKOZAK_COLORS_BRANCH_STATUS=${AGKOZAK_COLORS_BRANCH_STATUS:-yellow}

setopt PROMPT_SUBST NO_PROMPT_BANG

############################################################
# BASIC FUNCTIONS
############################################################

###########################################################
# Are colors available?
#
# Globals:
#   AGKOZAK_HAS_COLORS
###########################################################
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
# Emulation of bash's PROMPT_DIRTRIM for zsh
#
# In PWD, substitute HOME with ~; if the remainder of the
# PWD has more than a certain number of directory elements
# to display (default: 2), abbreviate it with '...', e.g.
#
#   $HOME/dotfiles/polyglot/img
#
# will be displayed as
#
#   ~/.../polyglot/img
#
# Set AGKOZAK_PROMPT_DIRTRIM to the number of directory
# elements you want to display, or to 0 to disable
# abbreviation.
#
# Named directories will by default be displayed using their
# aliases in the prompt. Set AGKOZAK_NAMED_DIRS=0 to have
# them displayed just like any other directory.
#
# Arguments:
#   -v [Optional] Store the output in psvar[2] instead of
#      printing it to STDOUT
#   $1 Number of directory elements to display (default: 2)
############################################################
_agkozak_prompt_dirtrim() {
  [[ $1 == '-v' ]] && local var=1 && shift
  [[ $1 -ge 0 ]] || set 2
  typeset -g AGKOZAK_NAMED_DIRS=${AGKOZAK_NAMED_DIRS:-1}
  if (( AGKOZAK_NAMED_DIRS )); then
    local zsh_pwd
    print -Pnz '%~'
    if (( $1 )); then # If AGKOZAK_PROMPT_DIRTRIM is not 0, then abbreviate
      read -rz zsh_pwd
      case $zsh_pwd in
        \~) print -Pnz $zsh_pwd ;;
        \~/*) print -Pnz "%($(($1 + 2))~|~/.../%${1}~|%~)" ;;
        \~*) print -Pnz "%($(($1 + 2))~|${zsh_pwd%%${zsh_pwd#\~*\/}}.../%${1}~|%~)" ;;
        *) print -Pnz "%($(($1 + 1))/|.../%${1}d|%d)" ;;
      esac
    fi
  else
    local dir dir_count
    case $HOME in
      /) dir=${PWD} ;;
      *) dir=${PWD#$HOME} ;;
    esac

    if (( $1 > 0 )); then   # If AGKOZAK_PROMPT_DIRTRIM is not 0, abbreviate
      # The number of directory elements is the number of slashes in ${PWD#$HOME}
      dir_count=$((${#dir} - ${#${dir//\//}}))

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
  (( var )) && psvar[2]=$output || print $output
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

  [[ -n $branch ]] && printf ' (%s%s)' "$branch" "$(_agkozak_branch_changes)"
}

############################################################
# Display symbols representing changes to the working copy
############################################################
_agkozak_branch_changes() {
  local git_status symbols k

  git_status="$(LC_ALL=C command git status 2>&1)"

  typeset -A messages

  messages=(
              '&*'  'diverged'
              '&'   'behind'
              '*'   'Your branch is ahead of'
              '+'   'new file:'
              'x'   'deleted'
              '!'   'modified:'
              '>'   'renamed:'
              '?'   'Untracked files'
           )

  for k in '&*' '&' '*' '+' 'x' '!' '>' '?'; do
    case $git_status in
      *${messages[$k]}*) symbols+="$k" ;;
    esac
  done

  [[ -n $symbols ]] && printf ' %s' "${symbols}"
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

###########################################################
# ASYNCHRONOUS FUNCTIONS
###########################################################

# Standarized $0 handling, follows:
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
typeset -g AGKOZAK_PROMPT_DIR="${0:A:h}"

###########################################################
# If zsh-async has not already been loaded, try to load it;
# the exit code should indicate success or failure
#
# Globals:
#   AGKOZAK_PROMPT_DEBUG
#   AGKOZAK_PROMPT_DIR
###########################################################
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

###########################################################
# If SIGUSR1 is available and not already in use by
# zsh, use it; otherwise disable asynchronous mode
###########################################################
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

###########################################################
# Force the async method, if set in AGKOZAK_FORCE_ASYNC_METHOD.
# Otherwise, determine the async method from the environment,
# whether or not zsh-async will load successfully, and whether
# or not SIGUSR1 is already taken
#
# Globals:
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_FORCE_ASYNC_METHOD
#   AGKOZAK_TRAPUSR1_FUNCTION
###########################################################
_agkozak_async_init() {

  # If AGKOZAK_FORCE_ASYNC_METHOD is set, force the asynchronous method
  [[ $AGKOZAK_FORCE_ASYNC_METHOD == 'zsh-async' ]] && _agkozak_load_async_lib
  if [[ $AGKOZAK_FORCE_ASYNC_METHOD == (subst-async|zsh-async|usr1|none) ]]; then
    typeset -g AGKOZAK_ASYNC_METHOD=$AGKOZAK_FORCE_ASYNC_METHOD

  # Otherwise, first provide for certain quirky systems
  else

    # WSL should have BG_NICE disabled, since it does not have a Linux kernel
    setopt LOCAL_OPTIONS EXTENDED_GLOB
    if [[ -e /proc/version ]]; then
      if [[ -n ${(M)${(f)"$(</proc/version)"}:#*Microsoft*} ]]; then
        unsetopt BG_NICE
        local WSL=1   # For later reference
      fi
    fi

    if (( WSL )); then
      if _agkozak_load_async_lib; then
        typeset -g AGKOZAK_ASYNC_METHOD='zsh-async'
      elif _agkozak_has_usr1; then
        typeset -g AGKOZAK_ASYNC_METHOD='usr1'
      else
        typeset -g AGKOZAK_ASYNC_METHOD='subst-async'
      fi

    # SIGUSR1 method is still much faster on MSYS2 and Cygwin
    elif [[ $OSTYPE == (msys|cygwin) ]]; then
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

  ##########################################################
  # Process substitution async method
  #
  # Forks a process to fetch the Git status and feed it
  # asynchronously to a file descriptor. Installs a callback
  # handler to process input from the file descriptor.
  #
  # Globals:
  #   AGKOZAK_ASYNC_FD
  ##########################################################
  _agkozak_subst_async() {
    typeset -g AGKOZAK_ASYNC_FD=13371

    # Workaround for buggy behavior in MSYS2, Cygwin, and Solaris
    if [[ $OSTYPE == (msys|cygwin|solaris*) ]]; then
      exec {AGKOZAK_ASYNC_FD}< <( _agkozak_branch_status; command true )
    # Prevent WSL from locking up when using X
    elif (( WSL )) && (( $+DISPLAY )); then
      exec {AGKOZAK_ASYNC_FD}< <( _agkozak_branch_status )
      command sleep 0.01
    else
      exec {AGKOZAK_ASYNC_FD}< <( _agkozak_branch_status )
    fi

    # Bug workaround; see http://www.zsh.org/mla/workers/2018/msg00966.html
    command true

    zle -F "$AGKOZAK_ASYNC_FD" _agkozak_zsh_subst_async_callback
  }

  ##########################################################
  # zle callback handler
  #
  # Reads Git status from file descriptor and sets psvar[3]
  #
  # Arguments:
  #   $1  File descriptor
  ##########################################################
  _agkozak_zsh_subst_async_callback() {
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

      ########################################################
      # Create zsh-async worker
      ########################################################
      _agkozak_zsh_async() {
          async_start_worker agkozak_git_status_worker -n
          async_register_callback agkozak_git_status_worker _agkozak_zsh_async_callback
          async_job agkozak_git_status_worker _agkozak_branch_status
      }

      ########################################################
      # Set RPROMPT and stop worker
      ########################################################
      _agkozak_zsh_async_callback() {
        psvar[3]=$3
        zle && zle reset-prompt
        async_stop_worker agkozak_git_status_worker -n
      }
      ;;

    usr1)

      ########################################################
      # precmd uses this function to launch async workers to
      # calculate the Git status. It can tell if anything has
      # redefined the TRAPUSR1 function that actually
      # displays the status; if so, it will drop the prompt
      # down into non-asynchronous mode.
      #
      # Globals:
      #   AGKOZAK_TRAPUSR1_FUNCTION
      #   AGKOZAK_USR1_ASYNC_WORKER
      #   AGKOZAK_ASYNC_METHOD
      ########################################################
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

      ########################################################
      # Asynchronous Git branch status using SIGUSR1
      #
      # Globals:
      #   AGKOZAK_PROMPT_DEBUG
      ########################################################
      _agkozak_usr1_async_worker() {
        # Save Git branch status to temporary file
        setopt LOCAL_OPTIONS CLOBBER
        _agkozak_branch_status > /tmp/agkozak_zsh_prompt_$$

        # Signal parent process
        if (( AGKOZAK_PROMPT_DEBUG )); then
          kill -s USR1 $$
        else
          kill -s USR1 $$ &> /dev/null
        fi
      }

      ########################################################
      # On SIGUSR1, redraw prompt
      #
      # Globals:
      #   AGKOZAK_USR1_ASYNC_WORKER
      ########################################################
      TRAPUSR1() {
        # read from temp file
        psvar[3]=$(cat /tmp/agkozak_zsh_prompt_$$)

        # Reset asynchronous process number
        typeset -g AGKOZAK_USR1_ASYNC_WORKER=0

        # Redraw the prompt
        zle && zle reset-prompt
      }

      typeset -g AGKOZAK_TRAPUSR1_FUNCTION="$(builtin which TRAPUSR1)"
      ;;
  esac
}

############################################################
# THE PROMPT
############################################################

#########################################################
# Strip color codes from a prompt string
#
# Arguments:
#   $1 The prompt string
#########################################################
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
        print -n "${prompt:0:1}"
        prompt=${prompt#?}
        ;;
    esac
  done
}

############################################################
# Runs right before the prompt is displayed
#
# 1) Imitates bash's PROMPT_DIRTRIM behavior
# 2) Calculates working branch and working copy status
# 3) If AGKOZAK_BLANK_LINES=1, prints blank line between prompts
#
# Globals:
#   AGKOZAK_PROMPT_DIRTRIM
#   AGKOZAK_OLD_PROMPT_DIRTRIM
#   AGKOZAK_NAMED_DIRS
#   AGKOZAK_OLD_NAMED_DIRS
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_MULTILINE
#   AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_BLANK_LINES
#   AGKOZAK_FIRST_PROMPT_PRINTED
#   AGKOZAK_CUSTOM_PROMPT
#   AGKOZAK_CURRENT_CUSTOM_PROMPT
#   AGKOZAK_CUSTOM_RPROMPT
#   AGKOZAK_CURRENT_CUSTOM_RPROMPT
############################################################
_agkozak_precmd() {
  # Update displayed directory when AGKOZAK_PROMPT_DIRTRIM or AGKOZAK_NAMED_DIRS
  # changes or when first sourcing this script
  if (( AGKOZAK_PROMPT_DIRTRIM != AGKOZAK_OLD_PROMPT_DIRTRIM )) \
    || (( AGKOZAK_NAMED_DIRS != AGKOZAK_OLD_NAMED_DIRS )) \
    || (( ! $+psvar[2] )); then
    _agkozak_prompt_dirtrim -v $AGKOZAK_PROMPT_DIRTRIM
    typeset -g AGKOZAK_OLD_PROMPT_DIRTRIM=$AGKOZAK_PROMPT_DIRTRIM
    typeset -g AGKOZAK_OLD_NAMED_DIRS=$AGKOZAK_NAMED_DIRS
  fi

  psvar[3]=''
  psvar[4]=''

  case $AGKOZAK_ASYNC_METHOD in
    'subst-async') _agkozak_subst_async ;;
    'zsh-async') _agkozak_zsh_async ;;
    'usr1') _agkozak_usr1_async ;;
    *) psvar[3]="$(_agkozak_branch_status)" ;;
  esac

  if (( AGKOZAK_MULTILINE == 0 )) && [[ -z $INSIDE_EMACS ]]; then
    typeset -g AGKOZAK_PROMPT_WHITESPACE=' '
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
# Prompt setup
#
# Globals:
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_USR1_ASYNC_WORKER
#   AGKOZAK_CUSTOM_PROMPT
#   AGKOZAK_CURRENT_CUSTOM_PROMPT
#   AGKOZAK_CUSTOM_RPROMPT
#   AGKOZAK_CURRENT_CUSTOM_RPROMPT
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

    ########################################################
    # Update the displayed directory when the PWD changes
    ########################################################
    _agkozak_chpwd() {
      _agkozak_prompt_dirtrim -v $AGKOZAK_PROMPT_DIRTRIM
    }

    add-zsh-hook chpwd _agkozak_chpwd
  fi

  # Only display the HOSTNAME for an ssh connection or for a superuser
  if _agkozak_is_ssh || (( EUID == 0 )); then
    psvar[1]="@${HOST%%.*}"
  else
    psvar[1]=''
  fi

  # The DragonFly BSD console and Emacs shell can't handle bracketed paste.
  # Let's avoid the ugly ^[[?2004 control sequence.
  if [[ $TERM == 'cons25' ]] || [[ $TERM == 'dumb' ]]; then
    unset zle_bracketed_paste
  fi

  # The Emacs shell has only limited support for some ZSH features, so we use a
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

    if (( $+AGKOZAK_CUSTOM_PROMPT )); then
      PROMPT=${AGKOZAK_CUSTOM_PROMPT}
    else
      # The color left prompt
      PROMPT='%(?..%B%F{${AGKOZAK_COLORS_EXIT_STATUS}}(%?%)%f%b )'
      PROMPT+='%(!.%S%B.%B%F{${AGKOZAK_COLORS_USER_HOST}})%n%1v%(!.%b%s.%f%b) '
      PROMPT+=$'%B%F{${AGKOZAK_COLORS_PATH}}%2v%f%b${AGKOZAK_PROMPT_WHITESPACE}'
      PROMPT+='%(4V.:.%#) '

      typeset -g AGKOZAK_CUSTOM_PROMPT=${PROMPT}
      typeset -g AGKOZAK_CURRENT_CUSTOM_PROMPT=${AGKOZAK_CUSTOM_PROMPT}
    fi

    if (( $+AGKOZAK_CUSTOM_RPROMPT )); then
      RPROMPT=${AGKOZAK_CUSTOM_RPROMPT}
    else
      # The color right prompt
      typeset -g RPROMPT='%(3V.%F{${AGKOZAK_COLORS_BRANCH_STATUS}}%3v%f.)'

      typeset -g AGKOZAK_CUSTOM_RPROMPT=${RPROMPT}
      typeset -g AGKOZAK_CURRENT_CUSTOM_RPROMPT=${RPROMPT}
    fi

    if ! _agkozak_has_colors; then
      PROMPT=$(_agkozak_strip_colors "$PROMPT")
      RPROMPT=$(_agkozak_strip_colors "$RPROMPT")
    fi

  fi

  _agkozak_debug_print "Using async method: $AGKOZAK_ASYNC_METHOD"
}

# Clean up environment
unfunction _agkozak_load_async_lib _agkozak_has_usr1 _agkozak_is_ssh \
  _agkozak_async_init _agkozak_has_colors _agkozak_strip_colors

# vim: ts=2:et:sts=2:sw=2:
