# Shim (agkozak-zsh-prompt used to be agkozak-zsh-theme)
#
# https://github.com/agkozak/agkozak-zsh-prompt

# shellcheck disable=SC2148

# Compile agkozak-zsh-prompt.plugin.zsh with zcompile when necessary
if [[ ${0:A:h}/agkozak-zsh-prompt.plugin.zsh -nt ${0:A:h}/agkozak-zsh-prompt.plugin.zsh.zwc ]] \
  || [[ ! -e ${0:A:h}/agkozak-zsh-prompt.plugin.zsh.zwc ]]; then
  zcompile "${0:A:h}/agkozak-zsh-prompt.plugin.zsh"
fi

#shellcheck source=/dev/null
source "${0:A:h}/agkozak-zsh-prompt.plugin.zsh"
