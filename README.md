![agkozak-zsh-theme Logo](img/logo.png)

# agkozak-zsh-theme

[![License](https://img.shields.io/github/license/agkozak/agkozak-zsh-theme.svg)](https://opensource.org/licenses/MIT)
[![GitHub Stars](https://img.shields.io/github/stars/agkozak/agkozak-zsh-theme.svg)](https://github.com/agkozak/agkozak-zsh-theme/stargazers)
![zsh version 4.3.11 and higher](https://img.shields.io/badge/zsh-4.3.11%2B-red.svg)

**agkozak-zsh-theme** is a dynamic color Git prompt for `zsh` that uses basic ASCII symbols to show:

* the username
* whether a session is local or remote over SSH
* an abbreviated path
* the Git branch and status
* the exit status of the last command, if it was not zero
* if `vi` line editing is enabled, whether insert or command mode is active

![agkozak-zsh-theme](img/agkozak-zsh-theme.png)

agkozak-zsh-theme can be simply sourced from your `.zshrc` file:

    source /path/to/agkozak-zsh-theme.plugin.zsh

It can also be used in coordination with a `zsh` framework. I use [zplugin](https://github.com/zdharma/zplugin), so my `.zshrc` has the line

    zplugin load agkozak/agkozak-zsh-theme

*Note: agkozak-zsh-theme is a subset of my [Polyglot Prompt](https://github.com/agkozak/polyglot), which also works in `bash`, `ksh93`, `mksh`, `pdksh`, `dash`, and `busybox sh`.*

## Local and Remote Sessions

When a session is local, only the username is shown; when it is remote over SSH (or `mosh`), the hostname is also shown:

![Local and remote sessions](img/local-and-remote-sessions.png)

## Abbreviated Paths

By default agkozak-zsh-theme emulates the behavior that `bash` uses when `PROMPT_DIRTRIM` is set to `2`: a tilde (`~`) is prepended if the working directory is under the user's home directory, and then if more than two directory elements need to be shown, only the last two are displayed, along with an ellipsis, so that

    /home/pi/src/neovim/config

is displayed as

![~/.../neovim/config](img/abbreviated_paths_1.png)

whereas

    /usr/src/sense-hat/examples

is displayed as

![.../sense-hat/examples](img/abbreviated_paths_2.png)

that is, without a tilde.

If you would like to display a different number of directory elements, set the environment variable `$AGKOZAK_PROMPT_DIRTRIM` in your `.zshrc` file thus:

    AGKOZAK_PROMPT_DIRTRIM=4     # Or whatever number you like

## Git Branch and Status

If the current directory contains a Git repository, agkozak-zsh-theme displays the name of the working branch, along with some symbols to show changes to its status:

![Git examples](img/git-examples.png)

Git Status | Symbol
--- | ---
Modified | !
Deleted | x
Untracked | ?
New file(s) | +
Ahead | \*
Renamed | >

## Exit Status

If the exit status of the most recently executed command is other than zero (zero indicating success), the exit status will be displayed in the right prompt:

![Exit status](img/exit-status.png)

# `vi` Editing Mode

agkozak-zsh-theme indicates when the user has switched from `vi` insert mode to command mode by turning the `%` or `#` of the prompt into a colon:

![`zsh` line editing](img/zsh-line-editing.png)

agkozak-zsh-theme does not enable `vi` editing mode for you. To do so, add

    bindkey -v

to your `.zshrc`.
