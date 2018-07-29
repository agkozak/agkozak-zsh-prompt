# agkozak ZSH Prompt

[![MIT License](img/mit_license.svg)](https://opensource.org/licenses/MIT)
[![GitHub tag](https://img.shields.io/github/tag/agkozak/agkozak-zsh-theme.svg)](https://GitHub.com/agkozak/agkozak-zsh-theme/tags/)
![zsh version 4.3.11 and higher](img/zsh_4.3.11_plus.svg)
[![GitHub Stars](https://img.shields.io/github/stars/agkozak/agkozak-zsh-theme.svg)](https://github.com/agkozak/agkozak-zsh-theme/stargazers)

The agkozak ZSH Prompt is an asynchronous, dynamic color Git prompt for `zsh` that uses basic ASCII symbols to show:

* the username
* whether a session is local or remote over SSH
* an abbreviated path
* the Git branch and status
* the exit status of the last command, if it was not zero
* if `vi` line editing is enabled, whether insert or command mode is active

This prompt has been tested on numerous Linux and BSD distributions, as well as on Solaris 11.3. It also has full asynchronous functionality in Windows environments such as MSYS2, Cygwin, and WSL.

![agkozak-zsh-theme](img/demo.gif)

## Table of Contents

- [Installation](#installation)
- [Local and Remote Sessions](#local-and-remote-sessions)
- [Abbreviated Paths](#abbreviated-paths)
- [Git Branch and Status](#git-branch-and-status)
- [Exit Status](#exit-status)
- [`vi` Editing Mode](#vi-editing-mode)
- [Blank Lines Between Prompts](#blank-lines-between-prompts)
- [Optional Single-Line Prompt](#optional-single-line-prompt)
- [Custom Colors](#custom-colors)
- [Custom Prompts](#custom-prompts)
- [Asynchronous Methods](#asynchronous-methods)

## Installation

### For users without a framework

The agkozak ZSH prompt requires no framework and can be simply sourced from your `.zshrc` file. Clone the git repo:

    git clone https://github.com/agkozak/agkozak-zsh-theme

And add the following to your `.zshrc` file:

    source /path/to/agkozak-zsh-theme.plugin.zsh

### For [antigen](https://github.com/zsh-users/antigen) users

Add the line

    antigen bundle agkozak/agkozak-zsh-theme

to your `.zshrc`, somewhere before the line that says `antigen apply`.

*Note: use `antigen bundle`, not `antigen theme`; the latter can result in a broken prompt when `.zshrc` is sourced a second time or whenever `antigen theme` is run again. [This problem is expected to be fixed in antigen version 2.2.3.](https://github.com/zsh-users/antigen/issues/652)*

### For [oh-my-zsh](http://ohmyz.sh) users

Execute the following commands:

    [[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
    git clone https://github.com/agkozak/agkozak-zsh-theme $ZSH_CUSTOM/themes/agkozak
    ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-theme.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme

And set `ZSH_THEME=agkozak` in your `.zshrc` file.

### For [zgen](https://github.com/tarjoilija/zgen) users

Add the line

    zgen load agkozak/agkozak-zsh-theme

to your `.zshrc` somewhere before the line that says `zgen save`.

### For [zplug](https://github.com/zplug/zplug) users

Add the line

    zplug "agkozak/agkozak-zsh-theme"

to your `.zshrc` somewhere before the line that says `zplug load`.

### For [zplugin](https://github.com/zdharma/zplugin) users

Run the command 

    zplugin load agkozak/agkozak-zsh-theme

to try out the prompt; add the same command to your `.zshrc` to load it automatically.

## Local and Remote Sessions

When a session is local, only the username is shown; when it is remote over SSH (or `mosh`), the hostname is also shown:

![Local and remote sessions](img/local-and-remote-sessions.png)

*Note: It is exceedingly difficult to determine with accuracy whether a superuser is connected over SSH or not. In the interests of providing useful and not misleading information, this prompt always displays both username and hostname for a superuser in reverse video.*

## Abbreviated Paths

By default the agkozak ZSH Prompt emulates the behavior that `bash` uses when `PROMPT_DIRTRIM` is set to `2`: a tilde (`~`) is prepended if the working directory is under the user's home directory, and then if more than two directory elements need to be shown, only the last two are displayed, along with an ellipsis, so that

    /home/pi/src/neovim/config

is displayed as

![~/.../neovim/config](img/abbreviated_paths_1.png)

whereas

    /usr/src/sense-hat/examples

is displayed as

![.../sense-hat/examples](img/abbreviated_paths_2.png)

that is, without a tilde.

If you would like to display a different number of directory elements, set the environment variable `AGKOZAK_PROMPT_DIRTRIM` in your `.zshrc` file thus (as in the example below):

    AGKOZAK_PROMPT_DIRTRIM=4     # Or whatever number you like

![AGKOZAK_PROMPT_DIRTRIM](img/AGKOZAK_PROMPT_DIRTRIM.png)

## Git Branch and Status

If the current directory contains a Git repository, the agkozak ZSH Prompt displays the name of the working branch, along with some symbols to show changes to its status:

![Git examples](img/git-examples.png)

Git Status | Symbol
--- | ---
Modified | !
Deleted | x
Untracked | ?
New file(s) | +
Ahead | \*
Renamed | >
Behind | &
Diverged | &*

## Exit Status

If the exit status of the most recently executed command is other than zero (zero indicating success), the exit status will be displayed at the beginning of the left prompt:

![Exit status](img/exit-status.png)

## `vi` Editing Mode

The agkozak ZSH Prompt indicates when the user has switched from `vi` insert mode to command mode by turning the `%` or `#` of the prompt into a colon:

![`zsh` line editing](img/zsh-line-editing.png)

agkozak does not enable `vi` editing mode for you. To do so, add

    bindkey -v

to your `.zshrc`.

## Blank Lines Between Prompts

If you prefer to have a little space between instances of the prompt, put `AGKOZAK_BLANK_LINES=1` in your `.zshrc`:

![AGKOZAK_BLANK_LINES](img/blank_lines.png)

## Optional Single-Line Prompt

Older versions of the agkozak ZSH Prompt provided a single-line prompt. [Because of changes made in ZSH 5.5](https://github.com/agkozak/agkozak-zsh-theme/issues/6) that affect the calculation of cursor position when the prompt wraps, it has become difficult to ensure that in that situation the cursor will land where it is supposed to, i.e. two positions after the `%` or `#` and not on top of the left prompt or after the right prompt. I have made the default prompt two-line, which fixes the problem entirely, but if you prefer a single-line prompt and are willing to put up with the occasional glitch, put

    AGKOZAK_MULTILINE=0

in your `.zshrc` before you source agkozak-zsh-theme.

Demo:

[![agkozak-zsh-theme (Singe-Line)](https://asciinema.org/a/155904.png)](https://asciinema.org/a/155904)

## Custom Colors
If you would like to customize the prompt colors, change any of the `AGKOZAK_COLORS_*` variables from their defaults to any valid color and add it to your `.zshrc`. The following are the available color variables and their defaults:

    AGKOZAK_COLORS_EXIT_STATUS=red
    AGKOZAK_COLORS_USER_HOST=green
    AGKOZAK_COLORS_PATH=blue
    AGKOZAK_COLORS_BRANCH_STATUS=yellow

## Custom Prompts
If you would like to make further customizations to your prompt, you may use the variables `AGKOZAK_CUSTOM_PROMPT` and `AGKOZAK_CUSTOM_RPROMPT` to specify the exact strings to be used for the left and right prompts. The default prompts, with the default colors, are

    PROMPT='%(?..%B%F{red}(%?%)%f%b )'
    PROMPT+='%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
    PROMPT+=$'%B%F{blue}%2v%f%b\n'
    PROMPT+='$(_agkozak_vi_mode_indicator) '
          
    RPROMPT='%F{yellow}%3v%f'

If, for example, you would like to move the Git information into the left prompt (eliminating the right prompt entirely) and to make the Git information your favorite shade of grey, you may include the following in your `.zshrc`:

    AGKOZAK_CUSTOM_PROMPT='%(?..%B%F{red}(%?%)%f%b )'
    AGKOZAK_CUSTOM_PROMPT+='%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
    AGKOZAK_CUSTOM_PROMPT+=$'%B%F{blue}%2v%f%b%(3V.%F{243}%3v%f.)\n'
    AGKOZAK_CUSTOM_PROMPT+='$(_agkozak_vi_mode_indicator) '
          
    AGKOZAK_CUSTOM_RPROMPT=''

## Asynchronous Methods

The agkozak ZSH Prompt has two different ways of displaying its Git status asynchronously and thereby of keeping the prompt swift: it uses the [`zsh-async`](https://github.com/mafredri/zsh-async) library when possible, falling back when necessary on a method described by [Anish Athalye](http://www.anishathalye.com/2015/02/07/an-asynchronous-shell-prompt/).

The `zsh-async`-based method uses the `zsh/zpty` library to spin off pseudo-terminals that can calculate the Git status without blocking the user from continuing to use the terminal. Unfortunately, `zsh/zpty` does not work well or at all on many systems: Cygwin and MSYS2 are notable examples, but even some installations of BSD or Linux or certain point releases of `zsh` do not support using `zsh/zpty` for the present purpose.

The second method is quite similar to the first; it involves creating and disowning child processes that calculate the Git status and then kill themselves off, triggering SIGUSR1 in the process. The `zsh` `TRAPUSR1` function then displays the Git status in the right prompt.  The problem with this method is that other `zsh` scripts might choose to use `TRAPUSR1`, so the agkozak ZSH Prompt takes the precaution of checking to see if that function has been defined already -- if it has, the theme switches off asynchronous mode entirely. It also routinely checks to see if some other script or the user has redefined `TRAPUSR1` and switches off asynchronous mode out of precaution.

If you want to force the agkozak ZSH Prompt to use a specific asynchronous mode (or none at all), execute `export AGKOZAK_FORCE_ASYNC_METHOD=zsh-async`, `usr1`, or `none` before sourcing it. If you want more insight into how the theme is working in your shell, put `export AGKOZAK_THEME_DEBUG=1` in your `.zshrc`.


<p align="center">
  <img src="img/logo.png" alt="agkozak-zsh-theme Logo">
</p>
