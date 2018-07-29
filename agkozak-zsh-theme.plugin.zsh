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

# Set AGKOZAK_THEME_DEBUG to 1 to see debugging information
AGKOZAK_THEME_DEBUG=${AGKOZAK_THEME_DEBUG:-0}

if (( AGKOZAK_THEME_DEBUG )); then
  autoload -Uz is-at-least

  setopt WARN_CREATE_GLOBAL

  if is-at-least 5.4.0; then
    setopt WARN_NESTED_VAR
  fi
fi

# Decide if the prompt should be displayed in color
(( $(tput colors) >= 8 )) && typeset -g AGKOZAK_HAS_COLORS=1

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
# Arguments:
#   $1 Number of directory elements to display (default: 2)
############################################################
_agkozak_prompt_dirtrim() {
  [[ $1 -ge 1 ]] || set 2
  case $PWD in
    $HOME) print -n '~' ;;  # Or TrueOS will print ~/.../~
    $HOME*)
      print -Pn "%($(($1 + 2))~|~/.../%${1}~|%~)"
      ;;
    *)
      print -Pn "%($(($1 + 1))/|.../%${1}d|%d)"
      ;;
  esac
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
  [[ -n $branch ]] && printf '%s %s' "$branch" "$(_agkozak_branch_changes)"
}

# Default Git symbols to use if themes do not override them
typeset -gA ZPML_GIT_SYMBOLS
ZPML_GIT_SYMBOLS=(
  renamed   '>'
  ahead     '*'
  new       '+'
  untracked '?'
  deleted   'x'
  modified  '!'
  behind    '&'
  diverged  '&*'
)

############################################################
# Display symbols representing changes to the working copy
#
# Globals:
#   ZPML_GIT_SYMBOLS
############################################################
_agkozak_branch_changes() {
  local git_status symbols k

  git_status="$(LC_ALL=C command git status 2>&1)"

  typeset -A messages

  messages=(
              'renamed:'                "${ZPML_GIT_SYMBOLS[renamed]}"
              'Your branch is ahead of' "${ZPML_GIT_SYMBOLS[ahead]}"
              'new file:'               "${ZPML_GIT_SYMBOLS[new]}"
              'Untracked files'         "${ZPML_GIT_SYMBOLS[untracked]}"
              'deleted'                 "${ZPML_GIT_SYMBOLS[deleted]}"
              'modified:'               "${ZPML_GIT_SYMBOLS[modified]}"
              'behind'                  "${ZPML_GIT_SYMBOLS[behind]}"
              'diverged'                "${ZPML_GIT_SYMBOLS[diverged]}"
           )

  for k in ${(@k)messages}; do
    case $git_status in
      *${k}*) symbols="${messages[$k]}${symbols}" ;;
    esac
  done

  [[ -n $symbols ]] && printf '%s' "$symbols"
}

############################################################
# Populate psvar[3] and psvar[4] with Git branch and changes
#
# Arguments;
#   $1 String produced by _agkozak_branch_status
############################################################
_agkozak_populate_git_vars() {
  local branch_and_changes="$1"
  psvar[3]="${branch_and_changes% *}"
  if [[ ${branch_and_changes#* } != "${psvar[3]}" ]]; then
    psvar[4]="${branch_and_changes#* }"
  else
    psvar[4]=''
  fi
}



############################################################
# When the user enters vi command mode, the % or # in the
# prompt changes into a colon
#
# Arguments:
#   $1 Insert mode indicator
#   $2) Command mode indicator
#   $3) What to show when in emacs mode
############################################################
_agkozak_vi_mode_indicator() {
  [[ -z $1 ]] && set '%%' ':' '%%'  # Settings for default prompt
  if [[ -o emacs ]]; then
    print -n "$3"
  else
    case $KEYMAP in
      vicmd) print -n "$2" ;;
      *) print -n "$1" ;;
    esac
  fi
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

typeset -g AGKOZAK_THEME_DIR=${0:A:h}

###########################################################
# Autoload the ZPML library
#
###########################################################
fpath+=( "${AGKOZAK_THEME_DIR}/lib/zpml" )
autoload -Uz zpml

typeset -g ZPML_THEME_DIR=${AGKOZAK_THEME_DIR}/themes

###########################################################
# If zsh-async has not already been loaded, try to load it;
# the exit code should indicate success or failure
#
# Globals:
#   AGKOZAK_THEME_DEBUG
#   AGKOZAK_THEME_DIR
###########################################################
_agkozak_load_async_lib() {
  if ! whence -w async_init &> /dev/null; then      # Don't load zsh-async twice
    if (( AGKOZAK_THEME_DEBUG )); then
      source "${AGKOZAK_THEME_DIR}/lib/zsh-async/async.zsh"
    else
      source "${AGKOZAK_THEME_DIR}/lib/zsh-async/async.zsh" &> /dev/null
    fi
    local success=$?
    return $success
  fi
}

###########################################################
# If SIGUSR1 is available and not already in use by
# zsh, use it; otherwise disable asynchronous mode
#
# Globals:
#   AGKOZAK_THEME_DEBUG
###########################################################
_agkozak_has_usr1() {
  if whence -w TRAPUSR1 &> /dev/null; then
    (( AGKOZAK_THEME_DEBUG )) && echo 'agkozak-zsh-theme: TRAPUSR1() already defined.' >&2
    false
  else
    case $signals in    # Array containing names of available signals
      *USR1*) true ;;
      *)
        (( AGKOZAK_THEME_DEBUG )) && echo 'agkozak-zsh-theme: SIGUSR1 not available.' >&2
        false
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
  if [[ $AGKOZAK_FORCE_ASYNC_METHOD =~ "(zsh-async|usr1|none)" ]]; then
    typeset -g AGKOZAK_ASYNC_METHOD=$AGKOZAK_FORCE_ASYNC_METHOD

  # Otherwise, first provide for certain quirky systems
  else
    local sysinfo
    sysinfo="$(uname -a)"

    # WSL should have BG_NICE disabled, as it does not have a Linux kernel
    #
    # TODO: zsh-async works perfectly on recent versions of WSL, but it might
    # be worth knowing if it has always done so in the past
    [[ $sysinfo =~ .*Microsoft.*Linux$ ]] && unsetopt BG_NICE

    # On MSYS2, zsh-async won't load; on Cygwin it loads but doesn't work
    # (see https://github.com/sindresorhus/pure/issues/141)
    if [[ $sysinfo =~ ".*Msys$" ]] || [[ $sysinfo =~ ".*Cygwin$" ]]; then
      typeset -g AGKOZAK_ASYNC_METHOD='usr1'

    # Avoid loading zsh-async on zsh v5.0.2
    # (see https://github.com/mafredri/zsh-async/issues/12)
    elif [[ $ZSH_VERSION == '5.0.2' ]]; then
      if _agkozak_has_usr1; then
        typeset -g AGKOZAK_ASYNC_METHOD='usr1'
      else
        typeset -g AGKOZAK_ASYNC_METHOD='none'
      fi

    # Asynchronous methods don't work in Emacs shell mode (but they do in term
    # and ansi-term)
    elif [[ $TERM == 'dumb' ]]; then
      typeset -g AGKOZAK_ASYNC_METHOD='none'

    # After all the preceding considerations, try loading zsh-async
    elif _agkozak_load_async_lib; then
      typeset -g AGKOZAK_ASYNC_METHOD='zsh-async'

    # If, for some reason, zsh-async will not load
    else

      # Try usr1
      if _agkozak_has_usr1; then
          typeset -g AGKOZAK_ASYNC_METHOD='usr1'

      # Failing all else, fall back to synchronous mode
      else
        typeset -g AGKOZAK_ASYNC_METHOD='none'
      fi
    fi
  fi

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
      # Set RPROMPT and stop worker
      ########################################################
      _agkozak_zsh_async_callback() {
        local branch_status
        _agkozak_populate_git_vars "$(_agkozak_branch_status)"
        zle && zle reset-prompt
        async_stop_worker agkozak_git_status_worker -n
      }
      ;;

    usr1)

      ########################################################
      # precmd uses this function to launch async workers to
      # calculate the Git status. It can tell if anything has
      # redefined the TRAPUSR1 function that actually displays
      # the status; if so, it will drop the theme down into
      # non-asynchronous mode.
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
          echo 'agkozak-zsh-theme: TRAPUSR1 has been redefined. Disabling asynchronous mode.' >&2
          typeset -g AGKOZAK_ASYNC_METHOD='none'
        fi
      }

      ########################################################
      # Asynchronous Git branch status using SIGUSR1
      #
      # Globals:
      #   AGKOZAK_THEME_DEBUG
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
      #
      # Globals:
      #   AGKOZAK_USR1_ASYNC_WORKER
      ########################################################
      TRAPUSR1() {
        # read from temp file
        local branch_status
        _agkozak_populate_git_vars "$(cat /tmp/agkozak_zsh_theme_$$)"

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
        while (( open_braces != 0 )); do
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
# 1) Loads new themes on the fly
# 2) Imitates bash's PROMPT_DIRTRIM behavior
# 3) Calculates working branch and working copy status
# 4) If AGKOZAK_BLANK_LINES=1, prints blank line between prompts
#
# Globals:
#   ZPML_PROMPT
#   AGKOZAK_CURRENT_ZPML_PROMPT
#   ZPML_RPROMPT
#   AGKOZAK_CURRENT_ZPML_RPROMPT
#   AGKOZAK_PROMPT_DIRTRIM
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_MULTILINE
#   AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_BLANK_LINES
#   AGKOZAK_FIRST_PROMPT_PRINTED
############################################################
_agkozak_precmd() {

  # Keep a copy of each ZPML prompt cached; when either changes, cache the new
  # one and then compile it
  if [[ $ZPML_PROMPT != "$AGKOZAK_CURRENT_ZPML_PROMPT" ]]; then
    typeset -g AGKOZAK_CURRENT_ZPML_PROMPT
    AGKOZAK_CURRENT_ZPML_PROMPT=$ZPML_PROMPT
    zpml && PROMPT="$(zpml compile ZPML_PROMPT)"
  fi

  if [[ $ZPML_RPROMPT != "$AGKOZAK_CURRENT_ZPML_RPROMPT" ]]; then
    typeset -g AGKOZAK_CURRENT_ZPML_RPROMPT
    AGKOZAK_CURRENT_ZPML_RPROMPT=$ZPML_RPROMPT
    zpml && RPROMPT="$(zpml compile ZPML_RPROMPT)"
  fi

  psvar[2]="$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")"
  psvar[3]=''
  psvar[4]=''

  case $AGKOZAK_ASYNC_METHOD in
    'zsh-async') _agkozak_zsh_async ;;
    'usr1') _agkozak_usr1_async ;;
    *)
      _agkozak_populate_git_vars "$(_agkozak_branch_status)"
      ;;
  esac

  if (( AGKOZAK_MULTILINE == 0 )); then
    typeset -g AGKOZAK_PROMPT_WHITESPACE=' '
  else
    typeset -g AGKOZAK_PROMPT_WHITESPACE=$'\n'
  fi

  if [[ -z ${ZPML_THEME} ]] || [[ ${ZPML_THEME} == 'agkozak' ]]; then
    if (( AGKOZAK_BLANK_LINES )); then
      if (( AGKOZAK_FIRST_PROMPT_PRINTED )); then
        echo
      fi
      typeset -g AGKOZAK_FIRST_PROMPT_PRINTED=1
    fi
  fi

  # If AGKOZAK_CUSTOM_PROMPT or AGKOZAK_CUSTOM_RPROMPT changes, the
  # corresponding prompt is updated

  if [[ ${AGKOZAK_CUSTOM_PROMPT} != "${AGKOZAK_CURRENT_CUSTOM_PROMPT}" ]]; then
    typeset -g AGKOZAK_CURRENT_CUSTOM_PROMPT=${AGKOZAK_CUSTOM_PROMPT}
    PROMPT=${AGKOZAK_CUSTOM_PROMPT}
    if (( AGKOZAK_HAS_COLORS != 1 )); then
      PROMPT=$(_agkozak_strip_colors "${PROMPT}")
    fi
  fi

  if [[ ${AGKOZAK_CUSTOM_RPROMPT} != "${AGKOZAK_CURRENT_CUSTOM_RPROMPT}" ]]; then
    typeset -g AGKOZAK_CURRENT_CUSTOM_RPROMPT=${AGKOZAK_CUSTOM_RPROMPT}
    RPROMPT=${AGKOZAK_CUSTOM_RPROMPT}
    if (( AGKOZAK_HAS_COLORS != 1 )); then
      RPROMPT=$(_agkozak_strip_colors "${RPROMPT}")
    fi
  fi
}

############################################################
# The agkozak-zsh-theme ZSH Prompt Macro Language
############################################################

# An extensible associative array containing macros
typeset -gA ZPML_MACROS
ZPML_MACROS=(
  exit_status       '(%?%)'
  user_host         '%n%1v'
  pwd               '%2v'
  vi_mode_indicator '$(_agkozak_vi_mode_indicator)'
  git_branch        '%3v'
  git_status        '%(4V. %4v.)'
)

############################################################
# Theme setup
#
# Globals:
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_USR1_ASYNC_WORKER
#   AGKOZAK_THEME_DEBUG
#   AGKOZAK_THEME_DIR
#   AGKOZAK_PROMPT_DIRTRIM
#   AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_COLORS_EXIT_STATUS
#   AGKOZAK_COLORS_USER_HOST
#   AGKOZAK_COLORS_PATH
#   AGKOZAK_COLORS_BRANCH_STATUS
#   AGKOZAK_HAS_COLORS
############################################################
agkozak_zsh_theme() {

  _agkozak_async_init

  case $AGKOZAK_ASYNC_METHOD in
    'zsh-async')
      async_init
      ;;
    'usr1')
      typeset -g AGKOZAK_USR1_ASYNC_WORKER=0
      ;;
  esac

  zle -N zle-keymap-select

  # Don't use ZSH hooks in Emacs classic shell
  if [[ -n $INSIDE_EMACS ]] && [[ $TERM == 'dumb' ]]; then
    :
  else
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _agkozak_precmd
  fi

  # Only display the HOSTNAME for an ssh connection or for a superuser
  if _agkozak_is_ssh || (( EUID == 0 )); then
    psvar[1]="$(print -Pn "@%m")"
  else
    psvar[1]=''
  fi

  # The Emacs shell has only limited support for some ZSH features
  if [[ $TERM = 'dumb' ]]; then

    # Avoid the ugly ^[[?2004h control sequence
    unset zle_bracketed_paste

    emacs_git_branch_status() {
      local branch
      branch="$(_agkozak_branch_status)"
      [[ -n $branch ]] && print " (${branch% })"
    }

    zpml

    set_macro emacs_pwd '$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")'
    set_macro emacs_git_branch_status '$(emacs_git_branch_status)'
    set_macro prompt_char '%#'

    typeset -g ZPML_PROMPT=(
      if is_exit_0 then
      else
        exit_status space
      fi

      user_host space

      emacs_pwd
      emacs_git_branch_status space
      prompt_char space
    )

    PROMPT="$(zpml compile ZPML_PROMPT)"

    # The prompt produced is:
    #
    # PROMPT='%(?..(%?%) )'
    # PROMPT+='%n%1v '
    # PROMPT+='$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")'
    # PROMPT+=' $(emacs_git_branch_status) '
    # PROMPT+='%# '

  else

    # Avoid continuation lines in Emacs term and ansi-term
    [[ -n $INSIDE_EMACS ]] && ZLE_RPROMPT_INDENT=2


    if [[ -n ${ZPML_THEME} ]]; then

      # Let themes persist from shell to shell
      zpml && zpml load "${ZPML_THEME}"

    else

      # When using the default theme, it is faster (particularly in MSYS2/Cywgin)
      # not to have to load and compile it

      if (( ${+AGKOZAK_CUSTOM_PROMPT} )); then
        PROMPT="${AGKOZAK_CUSTOM_PROMPT}"
      else
        # The color left prompt
        PROMPT='%(?..%B%F{${AGKOZAK_COLORS_EXIT_STATUS}}(%?%)%f%b )'
        PROMPT+='%(!.%S%B.%B%F{${AGKOZAK_COLORS_USER_HOST}})%n%1v%(!.%b%s.%f%b) '
        PROMPT+=$'%B%F{${AGKOZAK_COLORS_PATH}}%2v%f%b${AGKOZAK_PROMPT_WHITESPACE}'
        PROMPT+='$(_agkozak_vi_mode_indicator) '
      fi

      if (( ${+AGKOZAK_CUSTOM_RPROMPT} )); then
        RPROMPT="${AGKOZAK_CUSTOM_RPROMPT}"
      else
        # The color right prompt
        typeset -g RPROMPT='%(3V.%F{${AGKOZAK_COLORS_BRANCH_STATUS}} (%3v%(4V. %4v.)%)%f.)'
      fi

      (( AGKOZAK_HAS_COLORS != 1 )) && {
        PROMPT="$(_agkozak_strip_colors "$PROMPT")"
        RPROMPT="$(_agkozak_strip_colors "$RPROMPT")"
      }

    fi
  fi

  if (( AGKOZAK_THEME_DEBUG )); then
    echo "agkozak-zsh-theme: using async method: $AGKOZAK_ASYNC_METHOD" >&2
  fi
}

agkozak_zsh_theme

# Clean up environment
unfunction _agkozak_load_async_lib _agkozak_has_usr1

# vim: ts=2:et:sts=2:sw=2
