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
AGKOZAK_THEME_DEBUG=${AGKOZAK_THEME_DEBUG:-0}

(( AGKOZAK_THEME_DEBUG )) && setopt WARN_CREATE_GLOBAL WARN_NESTED_VAR

# Decide if the prompt should be displayed in color
(( $(tput colors) >= 8 )) && typeset -g AGKOZAK_HAS_COLORS=1

# Set $AGKOZAK_MULTILINE to 0 to enable the legacy, single-line prompt
typeset -g AGKOZAK_MULTILINE=${AGKOZAK_MULTILINE:-1}

# Set $AGKOZAK_COLORS_* variables to any valid color
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
#   $1 Number of directory elements to display
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
  [[ -n $branch ]] && printf ' (%s%s)' "$branch" "$(_agkozak_branch_changes)"
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

typeset -g AGKOZAK_THEME_DIR=${0:A:h}

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
# Force the async method, if set in $AGKOZAK_FORCE_ASYNC_METHOD.
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

  case $AGKOZAK_FORCE_ASYNC_METHOD in
    zsh-async)
      _agkozak_load_async_lib
      typeset -g AGKOZAK_ASYNC_METHOD=$AGKOZAK_FORCE_ASYNC_METHOD
      ;;
    usr1|none)
      typeset -g AGKOZAK_ASYNC_METHOD=$AGKOZAK_FORCE_ASYNC_METHOD
      ;;
    *)
      # Avoid trying to load zsh-async on systems where it is known not to work
      #
      # MSYS2) it doesn't load successfully
      # Cygwin) it loads but doesn't work (see
      #   https://github.com/sindresorhus/pure/issues/141)
      # TODO: WSL seems to work perfectly now with zsh-async, but it may not
      #   have in the past
      local sysinfo="$(uname -a)"

      case $sysinfo in
        # On MSYS2, zsh-async won't load; on Cygwin, it loads but does not work.
        *Msys|*Cygwin) typeset -g AGKOZAK_ASYNC_METHOD='usr1' ;;
        *)
          # Avoid loading zsh-async on zsh v5.0.2
          # See https://github.com/mafredri/zsh-async/issues/12
          # The theme appears to work properly now with zsh-async and zsh v5.0.8
          case $ZSH_VERSION in
            '5.0.2')
              if _agkozak_has_usr1; then
                typeset -g AGKOZAK_ASYNC_METHOD='usr1';
              else
                typeset -g AGKOZAK_ASYNC_METHOD='none'
              fi
              ;;
            *)

              # Avoid problems with Emacs exec-path-from-shell-printf
              if [[ $TERM = 'dumb' ]]; then
                AGKOZAK_ASYNC_METHOD='none'

              # Having exhausted known problematic systems, try to load
              # zsh-async; in case that doesn't work, try the SIGUSR1 method if
              # SIGUSR1 is available and TRAPUSR1() hasn't been defined; failing
              # that, switch off asynchronous mode
              elif _agkozak_load_async_lib; then
                typeset -g AGKOZAK_ASYNC_METHOD='zsh-async'
              else
                if _agkozak_has_usr1; then
                  case $sysinfo in
                    *Microsoft*Linux)
                      unsetopt BG_NICE                # nice doesn't work on WSL
                      typeset -g AGKOZAK_ASYNC_METHOD='usr1'
                      ;;
                    # TODO: the SIGUSR1 method doesn't work on Solaris 11 yet
                    # but it does work on OpenIndiana
                    # SIGUSR2 works on Solaris 11
                    *solaris*) typeset -g AGKOZAK_ASYNC_METHOD='none' ;;
                    *) typeset -g AGKOZAK_ASYNC_METHOD='usr1' ;;
                  esac
                else
                  typeset -g AGKOZAK_ASYNC_METHOD='none'
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
              kill -s HUP $AGKOZAK_USR1_ASYNC_WORKER &> /dev/null || :
          fi

          # Start background computation of Git status
          _agkozak_usr1_async_worker &!
          typeset -g AGKOZAK_USR1_ASYNC_WORKER=$!
        else
          echo 'agkozak-zsh-theme: TRAPUSR1() has been redefined. Disabling asynchronous mode.' >&2
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
        psvar[3]="$(cat /tmp/agkozak_zsh_theme_$$)"

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

############################################################
# Runs right before the prompt is displayed
#
# 1) Imitates bash's PROMPT_DIRTRIM behavior
# 2) Calculates working branch and working copy status
# 3) If AGKOZAK_BLANK_LINES=1, prints blank line between prompts
#
# Globals:
#   AGKOZAK_PROMPT_DIRTRIM
#   AGKOZAK_ASYNC_METHOD
#   AGKOZAK_MULTILINE
#   AGKOZAK_PROMPT_WHITESPACE
#   AGKOZAK_BLANK_LINES
#   AGKOZAK_FIRST_PROMPT_PRINTED
############################################################
_agkozak_precmd() {
  psvar[2]="$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")"
  psvar[3]=''

  case $AGKOZAK_ASYNC_METHOD in
    'zsh-async') _agkozak_zsh_async ;;
    'usr1') _agkozak_usr1_async ;;
    *) psvar[3]="$(_agkozak_branch_status)" ;;
  esac

  if (( AGKOZAK_MULTILINE == 0 )); then
    typeset -g AGKOZAK_PROMPT_WHITESPACE=' '
  else
    typeset -g AGKOZAK_PROMPT_WHITESPACE=$'\n'
  fi

  if (( AGKOZAK_BLANK_LINES )); then
    if (( AGKOZAK_FIRST_PROMPT_PRINTED )); then
      echo
    fi
    typeset -g AGKOZAK_FIRST_PROMPT_PRINTED=1
  fi
}

############################################################
# The agkozak-zsh-theme ZSH Prompt Macro Language
############################################################

# An extensible associative array containing macros
typeset -gA AGKOZAK_ZPML_MACROS=(
  exit_status       '(%?%)'
  user_host         '%n%1v'
  pwd               '%2v'
  vi_mode_indicator '$(_agkozak_vi_mode_indicator)'
  git_branch_status '%3v'
)

############################################################
# Set a macro
#
# Globals:
#   AGKOZAK_ZPML_MACROS
#
# Arguments:
#   $1 Macro name
#   $2 Macro (preferably quoted)
############################################################
set_macro() {
  AGKOZAK_ZPML_MACROS[$1]="$2"
}

############################################################
# For printing parser errors
#
# Globals:
#   AGKOZAK_HAS_COLORS
#
# Arguments:
#   $1 Error text
############################################################
_agkozak_parser_error() {
  (( AGKOZAK_HAS_COLORS )) && print -Pn "%F{red}" >&2
  print
  print -n "agkozak-zsh-theme: $1" >&2
  (( AGKOZAK_HAS_COLORS )) && print -P "%f" >&2
}

############################################################
# Parse an array and output a prompt
#
# Globals:
#   AGKOZAK_HAS_COLORS
#   AGKOZAK_ZPML_MACROS
#
# Arguments:
#   $1 Name of prompt to be constructed
############################################################
_agkozak_construct_prompt() {
  local i ternary_stack literal color_stack

  local -A styles
  styles=(
    bold      '%B'
    unbold    '%b'
    reverse   '%S'
    unreverse '%s'
    unfg      '%f'
    unbg      '%b' 
  )

  for i in $(eval echo -n "\$$1"); do
    if (( literal )); then
      echo -n "$i"
      literal=0
    elif [[ $i == 'literal' ]]; then
      literal=1
    elif [[ $ternary_stack == 'if' ]]; then
      case $i in
        is_exit_*)
          if [[ ${i#is_exit_} == '0' ]]; then
            echo -n '?'
          else
            echo -n "${i#is_exit_}?"
          fi
          ;;
        is_superuser)
          echo -n '!'
          ;;
        *) _agkozak_parser_error 'Unsupported condition.' && return
          ;;
      esac
      ternary_stack+='cond'
    else
      case $i in
        if)
          if [[ $ternary_stack != '' ]]; then
            _agkozak_parser_error $'Missing \'fi\'.' && return
          else
            echo -n '%('
            ternary_stack+='if'
          fi
          ;;
        then)
          if [[ $ternary_stack != 'ifcond' ]]; then
            _agkozak_parser_error $'Missing \`if\' or condition.' && return
          else
            echo -n '.'           # TODO: a period may be incorrect, depending on
            ternary_stack+="$i"   # what the ternary is supposed to print.
          fi
          ;;
        else)
          if [[ $ternary_stack != 'ifcondthen' ]]; then
            _agkozak_parser_error $'Missing \`if\', condition, or \`then\'.' \
              && return
          else
            echo -n '.'           # TODO: ditto.
            ternary_stack+="$i"
          fi
          ;;
        fi)
          if [[ $ternary_stack == 'ifcondthenelse' ]]; then
            echo -n ')'
          # When `else' is implicit
          elif [[ $ternary_stack == 'ifcondthen' ]]; then
            echo -n '.)'          # TODO: see above.
          else
            _agkozak_parser_error $'Missing \`if\', condition, or \`then\'.' \
              && return
          fi
          ternary_stack=''
          ;;
        bold|reverse)
          echo -n $styles[$i]
          color_stack+="$i"
          ;;
        fg_*)
          (( AGKOZAK_HAS_COLORS )) && {
            echo -n "%F{${i#fg_}}"
            color_stack+="fg"
          }
          ;;
        bg_*)
          (( AGKOZAK_HAS_COLORS )) && {
            echo -n "%K{${i#bg_}}"
            color_stack+="bg"
          }
          ;;
        unfg|unbg)
          (( AGKOZAK_HAS_COLORS )) && {
            echo -n $styles[$i]
            color_stack="${color_stack/${i#un}}"
          }
          ;;
        unbold|unreverse)
          echo -n $styles[$i]
          color_stack="${color_stack/${i#un}}"
          ;;
        space) echo -n ' ' ;;
        newline) echo -n $'\n' ;;
        *)
          [[ -n ${AGKOZAK_ZPML_MACROS[$i]} ]] && echo -n ${AGKOZAK_ZPML_MACROS[$i]}
          ;;
      esac
    fi
  done

  if [[ $ternary_stack != '' ]]; then
    _agkozak_parser_error "Invalid condition in $1."
  fi

  if [[ $color_stack != '' ]]; then
    echo $color_stack
    _agkozak_parser_error "You probably forgot to 'unbold', 'un_fg', 'un_bg' or 'unreverse' something in $1."
  fi
}

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
  if [[ -z $INSIDE_EMACS ]] && [[ $TERM != dumb ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _agkozak_precmd
  fi

  # Only display the $HOSTNAME for an ssh connection or for a superuser
  if _agkozak_is_ssh || (( EUID == 0 )); then
    psvar[1]="$(print -Pn "@%m")"
  else
    psvar[1]=''
  fi

  # The Emacs shell has only limited support for some zsh features
  if [[ -n $INSIDE_EMACS ]] && [[ $TERM = 'dumb' ]]; then
    set_macro emacs_pwd '$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")'
    set_macro sync_git_branch_status '$(_agkozak_branch_status)'
    set_macro prompt_char '%#'

    typeset -g AGKOZAK_ZPML_PROMPT=(
      if is_exit_0 then
      else
        exit_status space
      fi

      user_host space

      emacs_pwd
      sync_git_branch_status space
      prompt_char space
    )

    PROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_PROMPT)"

    # The prompt produced is:
    #
    # PROMPT='%(?..(%?%) )'
    # PROMPT+='%n%1v '
    # PROMPT+='$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")'
    # PROMPT+='$(_agkozak_branch_status) '
    # PROMPT+='%# '

    # TODO: The following really belongs in the user's .zshrc; it is unrelated
    # to this theme
    unset zle_bracketed_paste

  # Dogfooding: We'll construct the prompt from ZPML
  else
    [[ -z "${AGKOZAK_ZPML_PROMPT}${AGKOZAK_ZPML_RPROMPT}" ]] && {

      # Left prompt
      set_macro custom_whitespace $'${AGKOZAK_PROMPT_WHITESPACE}'

      typeset -g AGKOZAK_ZPML_PROMPT=(
        if is_exit_0 then
        else                                                 # Default: red
          bold fg_${AGKOZAK_COLORS_EXIT_STATUS} exit_status unfg unbold space
        fi

        # When the user is a superuser, the username and hostname are
        # displayed in reverse video

        if is_superuser then
          reverse bold
        else
          bold fg_${AGKOZAK_COLORS_USER_HOST}                # Default: green
        fi

        user_host

        if is_superuser then
          unbold unreverse
        else
          unfg unbold
        fi

        space
        bold fg_${AGKOZAK_COLORS_PATH} pwd unfg unbold       # Default: blue
        custom_whitespace                                    # Default: newline

        vi_mode_indicator space
      )

      # Right prompt
      typeset -g AGKOZAK_ZPML_RPROMPT=(                      # Default: yellow
        fg_${AGKOZAK_COLORS_BRANCH_STATUS} git_branch_status unfg
      )

    }

    PROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_PROMPT)"
    RPROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_RPROMPT)"

    # The color prompts produced are:
    #
    # PROMPT='%(?..%B%F{${AGKOZAK_COLORS_EXIT_STATUS}}(%?%)%f%b )'
    # PROMPT+='%(!.%S%B.%B%F{${AGKOZAK_COLORS_USER_HOST}})%n%1v%(!.%b%s.%f%b) '
    # PROMPT+=$'%B%F{${AGKOZAK_COLORS_PATH}}%2v%f%b${AGKOZAK_PROMPT_WHITESPACE}'
    # PROMPT+='$(_agkozak_vi_mode_indicator) '

    # The color right prompt
    # RPROMPT='%F{${AGKOZAK_COLORS_BRANCH_STATUS}}%3v%f'

  fi

  if (( AGKOZAK_THEME_DEBUG )); then
    echo "agkozak-zsh-theme: using async method: $AGKOZAK_ASYNC_METHOD" >&2
  fi
}

agkozak_zsh_theme

# Clean up environment
unset AGKOZAK_THEME_DIR
unfunction _agkozak_load_async_lib _agkozak_has_usr1

# vim: ts=2:et:sts=2:sw=2:
