#!/usr/bin/env zsh
#
# Tests for ZPML code
#
# https://github.com/agkozak/agkozak-zsh-theme

results() {
  (( RESULTS++ ))
  if [[ $2 == 'pass' ]]; then
    print -P "%F{green}${RESULTS}. $1 passed.%f"
  else
    print -P "%F{red}${RESULTS}. $1 failed.%f"
  fi
}

# 1. Test production of default prompts

source ../agkozak-zsh-theme.plugin.zsh
AGKOZAK_HAS_COLORS=1

add_macro custom_whitespace '${AGKOZAK_PROMPT_WHITESPACE}'

AGKOZAK_ZPML_PROMPT=(
  if is_exit_0 then
  else
    bold fg_${AGKOZAK_COLORS_EXIT_STATUS} exit_status unfg unbold space
  fi

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

AGKOZAK_ZPML_RPROMPT=(                                # Default: yellow
  fg_${AGKOZAK_COLORS_BRANCH_STATUS} git_branch_status unfg
)

PROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_PROMPT)"
RPROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_RPROMPT)"

if [[ $PROMPT == '%(?..%B%F{red}(%?%)%f%b )%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) %B%F{blue}%2v%f%b${AGKOZAK_PROMPT_WHITESPACE}$(_agkozak_vi_mode_indicator) ' ]] \
  && [[ $RPROMPT == '%F{yellow}%3v%f' ]]; then
  results 'Default prompts' pass
else
  results 'Default prompts' fail
fi

unset AGKOZAK_ZPML_PROMPT AGKOZAK_ZPML_RPROMPT

# 2. Default prompt in documentation

source ../agkozak-zsh-theme.plugin.zsh
AGKOZAK_HAS_COLORS=1

AGKOZAK_ZPML_PROMPT=(
  if is_exit_0 then
  else
    bold fg_red exit_status unfg unbold space
  fi

  if is_superuser then
    reverse bold
  else
    bold fg_green
  fi

  user_host

  if is_superuser then
    unbold unreverse
  else
    unfg unbold
  fi

  space
  bold fg_blue pwd unfg unbold newline

  vi_mode_indicator space
)

AGKOZAK_ZPML_RPROMPT=(
  fg_yellow git_branch_status unfg
)

PROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_PROMPT)"
RPROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_RPROMPT)"

if [[ $PROMPT == $'%(?..%B%F{red}(%?%)%f%b )%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) %B%F{blue}%2v%f%b\n$(_agkozak_vi_mode_indicator) ' ]] \
  && [[ $RPROMPT == '%F{yellow}%3v%f' ]]; then
  results 'Default prompts in documentation' pass
else
  results 'Default prompts in documentation' fail
fi

unset AGKOZAK_ZPML_PROMPT AGKOZAK_ZPML_RPROMPT

# 3. Default Emacs shell prompt

source ../agkozak-zsh-theme.plugin.zsh

add_macro emacs_pwd '$(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")'
add_macro sync_git_branch_status '$(_agkozak_branch_status)'
add_macro prompt_char '%#'

AGKOZAK_ZPML_PROMPT=(
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

if [[ $PROMPT == '%(?..(%?%) )%n%1v $(_agkozak_prompt_dirtrim "$AGKOZAK_PROMPT_DIRTRIM")$(_agkozak_branch_status) %# ' ]]; then
  results 'Default Emacs shell prompt' pass
else
  results 'Default Emacs shell prompt' fail
fi

unset AGKOZAK_ZPML_PROMPT

# 4. @borekb theme

source ../agkozak-zsh-theme.plugin.zsh
AGKOZAK_HAS_COLORS=1

AGKOZAK_ZPML_PROMPT=(
  if is_exit_0 then
  else
    bold fg_red exit_status unfg unbold space
  fi

  bold fg_blue pwd unfg unbold

  fg_243 git_branch_status unfg newline

  if is_superuser then
    literal '#'
  else
    literal '$'
  fi
  space
)

PROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_PROMPT)"

if [[ $PROMPT == $'%(?..%B%F{red}(%?%)%f%b )%B%F{blue}%2v%f%b%F{243}%3v%f\n%(!.#.$) ' ]]; then
  results 'borekb' pass
else
  results 'borekb' fail
fi

unset AGKOZAK_ZPML_PROMPT

# 5. borekb B&@

source ../agkozak-zsh-theme.plugin.zsh
AGKOZAK_HAS_COLORS=0

AGKOZAK_ZPML_PROMPT=(
  if is_exit_0 then
  else
    bold fg_red exit_status unfg unbold space
  fi

  bold fg_blue pwd unfg unbold

  fg_243 git_branch_status unfg newline

  if is_superuser then
    literal '#'
  else
    literal '$'
  fi
  space
)

PROMPT="$(_agkozak_construct_prompt AGKOZAK_ZPML_PROMPT)"

if [[ $PROMPT == $'%(?..(%?%) )%2v%3v\n%(!.#.$) ' ]]; then
  results 'borekb B&W' pass
else
  results 'borekb B&W' fail
fi

unset AGKOZAK_ZPML_PROMPT

# 6. Empty condition

source ../agkozak-zsh-theme.plugin.zsh

FOO=(
  if is_superuser
  then
  else
  fi
)

BAR="$(_agkozak_construct_prompt FOO)"

if [[ $BAR == '%(!..)' ]]; then
  results 'Empty condition' pass
else
  results 'Empty condition' fail
fi

unset FOO BAR

#  7. Missing `if' or condition

source ../agkozak-zsh-theme.plugin.zsh

FOO=( is_superuser then literal '#' else literal '!' )

BAR=( if then literal '#' else literal '!' )

if _agkozak_construct_prompt FOO 1> /dev/null \
  && _agkozak_construct_prompt BAR 1> /dev/null; then
  results "Missing \'if\' or condition" pass
else
  results "Missing \'if\' or condition" fail
fi

unset FOO BAR

# 8. Missing `then'

source ../agkozak-zsh-theme.plugin.zsh

FOO=( if is_superuser literal '#' else literal '!' )

if _agkozak_construct_prompt FOO 1> /dev/null; then
  results "missing \'then\'" pass
else
  results "missing \'then\'" fail
fi

unset FOO

# 9. Missing `fi'

source ../agkozak-zsh-theme.plugin.zsh

FOO=( if is_superuser then literal '#' else literal '!' )

  if _agkozak_construct_prompt FOO 1> /dev/null; then
  results "missing \'fi\'" pass
else
  results "missing \'fi\'" fail
fi

unset FOO
