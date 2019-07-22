# agkozak ZSH Prompt

[![MIT License](img/mit_license.svg)](https://opensource.org/licenses/MIT)
[![GitHub tag](https://img.shields.io/github/tag/agkozak/agkozak-zsh-prompt.svg)](https://GitHub.com/agkozak/agkozak-zsh-prompt/tags/)
![ZSH version 4.3.11 and higher](img/zsh_4.3.11_plus.svg)
[![GitHub stars](https://img.shields.io/github/stars/agkozak/agkozak-zsh-prompt.svg)](https://github.com/agkozak/agkozak-zsh-prompt/stargazers)
[![Chat on Gitter](https://img.shields.io/gitter/room/:user/:repo.svg)](https://gitter.im/agkozak-zsh-prompt/Lobby#)

The agkozak ZSH Prompt is an asynchronous color Git prompt for ZSH that uses basic ASCII symbols to show:

* username
* whether a session is local, or remote over SSH or `mosh`
* an abbreviated path
* Git branch and status
* the exit status of the last command, if it was not zero
* if `vi` line editing is enabled, whether insert or command mode is active

This prompt has been tested on numerous Linux and BSD distributions, as well as on Solaris. It is also fully asynchronous in Windows environments such as MSYS2, Cygwin, and WSL.

![The agkozak ZSH Prompt](img/demo.gif)

## Table of Contents

- [News](#news)
- [Installation](#installation)
- [Local and Remote Sessions](#local-and-remote-sessions)
- [Abbreviated Paths](#abbreviated-paths)
- [Git Branch and Status](#git-branch-and-status)
- [Exit Status](#exit-status)
- [`vi` Editing Mode](#vi-editing-mode)
- [Customization](#customization)
    - [Custom Colors](#custom-colors)
    - [Blank Lines Between Prompts](#blank-lines-between-prompts)
    - [Optional Single-line Prompt](#optional-single-line-prompt)
    - [Optional Left-prompt-only Mode](#optional-left-prompt-only-mode)
    - [Custom Prompt Character](#custom-prompt-character)
    - [Custom Git Symbols](#custom-git-symbols)
    - [Other Settings](#other-settings)
        - [AGKOZAK_USER_HOST_DISPLAY](#agkozak_user_host_display)
        - [AGKOZAK_BRANCH_STATUS_SEPARATOR](#agkozak_branch_status_separator)
    - [Advanced Customization](#advanced-customization)
- [Asynchronous Methods](#asynchronous-methods)
- [Examples of agkozak ZSH Prompt Customization](#examples-of-agkozak-zsh-prompt-customization)
    - [Using Basic Configuration Settings](#using-basic-configuration-settings)
    - [Using AGKOZAK_CUSTOM_PROMPT and AGKOZAK_CUSTOM_RPROMPT](#using-agkozak_custom_prompt-and-agkozak_custom_rprompt)

## News

- v3.3.0 (July 20, 2019)
    - If `AGKOZAK_USER_HOST_DISPLAY=0`, the username and hostname will not be displayed.
- v3.2.2 (July 8, 2019)
    - When the local `git` version is 2.15.0 or greater, `git status` will not run unnecessary optional operations that require locks.
- v3.2.1 (May 6, 2019)
    - For ZSH v5.0.2, `subst-async` now works correctly, but `usr1` will be used as the default async method, as it should be slightly faster.
- v3.2.0 (February 28, 2019)
    - By default, a space precedes the Git branch status indicator. The space can now be eliminated by setting `AGKOZAK_BRANCH_STATUS_SEPARATOR=''`, or changed to another character or characters (e.g. `AGKOZAK_BRANCH_STATUS_SEPARATOR='--'`).
- v3.1.0 (February 5, 2019)
    - The array `AGKOZAK_PROMPT_CHAR` allows the user to specify prompt characters for regular user, superuser, and `vi` command mode.
    - Setting `AGKOZAK_COLORS_PROMPT_CHAR` can change the color of the prompt character.
    - The array `AGKOZAK_CUSTOM_SYMBOLS` contains user-specified symbols for displaying the Git status.
- v3.0.2 (December 26, 2018)
    - The external command `cat` is no longer used.
    - The prompt now uses [the latest commit](https://github.com/mafredri/zsh-async/commit/43de5e0738eaf366dfde4d0a204de655de16f18b) of `zsh-async`.
- v3.0.1 (November 26, 2018)
    - I have restored the `_agkozak_vi_mode_indicator` function as a legacy feature, as many people people use it in custom prompts. The default indicator can be expressed as `'%(4V.:.%#)'`, though, and variations on this will be preferable to `'$(_agkozak_vi_mode_indicator)'`, which entails a subshell.
- v3.0.0 (November 26, 2018)
    - The asynchronous Git status is now available via process substitution in all supported versions of ZSH and on all supported systems (props to @psprint). For reasons of speed, `zsh-async` remains the default asynchronous method in WSL and Solaris, and `usr1` is default in MSYS2/Cygwin.
    - When `AGKOZAK_LEFT_PROMPT_ONLY` is set to `1`, the Git status is displayed in the left prompt, and the right prompt is left blank.
    - The prompt script loads up to 4x faster.
    - The left prompt is displayed ~2x faster.

## Installation

### For users without a framework

The agkozak ZSH prompt requires no framework and can be simply sourced from your `.zshrc` file. Clone the git repo:

    git clone https://github.com/agkozak/agkozak-zsh-prompt

And add the following to your `.zshrc` file:

    source /path/to/agkozak-zsh-prompt.plugin.zsh

### For [antigen](https://github.com/zsh-users/antigen) users

Add the line

    antigen bundle agkozak/agkozak-zsh-prompt

to your `.zshrc`, somewhere before the line that says `antigen apply`. Be sure to use `antigen bundle` and not `antigen theme`.

### For [oh-my-zsh](http://ohmyz.sh) users

Execute the following commands:

    [[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
    git clone https://github.com/agkozak/agkozak-zsh-prompt $ZSH_CUSTOM/themes/agkozak
    ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-prompt.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme

And set `ZSH_THEME=agkozak` in your `.zshrc` file.

### For [zgen](https://github.com/tarjoilija/zgen) users

Add the line

    zgen load agkozak/agkozak-zsh-prompt

to your `.zshrc` somewhere before the line that says `zgen save`.

### For [zplug](https://github.com/zplug/zplug) users

Add the line

    zplug "agkozak/agkozak-zsh-prompt"

to your `.zshrc` somewhere before the line that says `zplug load`.

### For [zplugin](https://github.com/zdharma/zplugin) users

Run the command 

    zplugin load agkozak/agkozak-zsh-prompt

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

Setting `AGKOZAK_PROMPT_DIRTRIM=0` will turn off path abbreviation, with the exception of `~` for `$HOME` and named directories (see immediately below).

By default, [static named directories created with `hash -d`](http://zsh.sourceforge.net/Doc/Release/Expansion.html#Static-named-directories) will be used as base directories in the path the prompt displays. For example,
if you have executed

    hash -d wp-content=/var/www/html/wp-content

then `/var/www/html/wp-content` will appear in the prompt as `wp-content`, and `/var/www/html/wp-content/plugins/redirection/actions` will be represented as `~wp-content/.../redirection/actions`. If you prefer to have named directories displayed just like any others, set `AGKOZAK_NAMED_DIRS=0`.

## Git Branch and Status

If the current directory contains a Git repository, the agkozak ZSH Prompt displays the name of the working branch, along with some symbols to show changes to its status:

![Git examples](img/git-examples.png)

Git Status | Symbol
--- | ---
Diverged | &\*
Behind | &
Ahead | \*
New file(s) | +
Deleted | x
Modified | !
Renamed | >
Untracked | ?

## Exit Status

If the exit status of the most recently executed command is other than zero (zero indicating success), the exit status will be displayed at the beginning of the left prompt:

![Exit status](img/exit-status.png)

## `vi` Editing Mode

The agkozak ZSH Prompt indicates when the user has switched from `vi` insert mode to command mode by turning the `%` or `#` of the prompt into a colon:

![ZSH line editing](img/zsh-line-editing.png)

agkozak does not enable `vi` editing mode for you. To do so, add

    bindkey -v

to your `.zshrc`.

This prompt will work perfectly if you use the default ZSH Emacs editing mode; in that case, the prompt character will not change.

## Customization

In addition to setting `AGKOZAK_PROMPT_DIRTRIM` and `AGKOZAK_NAMED_DIRS` to change how the working directory is displayed ([see above](#abbreviated-paths)), you may use other settings to alter how the prompt is displayed.

### Custom Colors
If you would like to customize the prompt colors, change any of the `AGKOZAK_COLORS_*` variables from their defaults to any valid color and add it to your `.zshrc`. The following are the available color variables and their defaults:

    AGKOZAK_COLORS_EXIT_STATUS=red
    AGKOZAK_COLORS_USER_HOST=green
    AGKOZAK_COLORS_PATH=blue
    AGKOZAK_COLORS_BRANCH_STATUS=yellow
    AGKOZAK_COLORS_PROMPT_CHAR=white

![Custom colors](img/colors.gif)

### Blank Lines Between Prompts

If you prefer to have a little space between instances of the prompt, put `AGKOZAK_BLANK_LINES=1` in your `.zshrc`:

![AGKOZAK_BLANK_LINES](img/blank_lines.png)

### Optional Single-line Prompt

If you prefer a single-line prompt with a right prompt that disappears when it is typed over, put

    AGKOZAK_MULTILINE=0

in your `.zshrc`.

![Single-line prompt](img/single-line_prompt.gif)

### Optional Left-prompt-only Mode

If you would like to have the Git status displayed in the left prompt (with no right prompt -- this is how [`pure`](https://github.com/sindresorhus/pure) does it), set

    AGKOZAK_LEFT_PROMPT_ONLY=1

![Left-prompt-only mode](img/AGKOZAK_LEFT_PROMPT_ONLY.gif)

### Custom Prompt Character

The classic prompt for Bourne-style shells is `$`; for `csh` it is `%`, and ZSH borrows the latter because it inherits features from both types of shell. agkozak-zsh-prompt uses `%` to show where the prompt ends and where input should begin, although a superuser will see `#`, and either sort of user will see `:` when `vi` command mode is active. If you wish to change any or all of these symbols, you may do so using the array `AGKOZAK_PROMPT_CHAR`, whose three elements are 1) the normal prompt character; 2) the superuser prompt character; and 3) the `vi` command mode character. The default behavior of the prompt can be represented as

    AGKOZAK_PROMPT_CHAR=( %# %# : )

If you would like your prompt to look more like a `bash` prompt (i.e. terminating in `$`), you can simply put the following in your `.zshrc`:

    AGKOZAK_PROMPT_CHAR=( $ %# : )

Some people prefer to spruce up their prompts with unicode characters. You could approximate the appearance of the popular [pure](https://github.com/sindresorhus/pure) prompt by using

    AGKOZAK_PROMPT_CHAR=( ❯ ❯ ❮ )

Closer still to pure would be

    AGKOZAK_PROMPT_CHAR=( ❯ ❯ ❮ )
    AGKOZAK_COLORS_PROMPT_CHAR='magenta'

which would be the equivalent of

    AGKOZAK_PROMPT_CHAR=( '%F{magenta}❯%f' '%F{magenta}❯%f' '%F{magenta}❮%f' )

Note that you could change one of those `%F{magenta}...%f` strings to another foreground color for a more striking visual reminder of what you are doing at any given moment.

![AGKOZAK_PROMPT_CHAR demo](img/AGKOZAK_PROMPT_CHAR.gif)

### Custom Git Symbols

If, through the use of another prompt, your muscle memory has been trained to react immediately to a particular set of Git status symbols, or if you have an aesthetic preference for symbols other than the default ASCII ones, you may specify them in the array `AGKOZAK_CUSTOM_SYMBOLS`. The default set is

    AGKOZAK_CUSTOM_SYMBOLS=( '&*' '&' '*' '+' 'x' '!' '>' '?' )

If you prefer the [pure](https://github.com/sindresorhus/pure) symbols for the "diverged," "behind," and "ahead" states, you could use the following settings:

    AGKOZAK_CUSTOM_SYMBOLS=( '⇣⇡' '⇣' '⇡' '+' 'x' '!' '>' '?' )

### Other Settings

#### AGKOZAK_USER_HOST_DISPLAY

![AGKOZAK_USER_HOST_DISPLAY demo](img/AGKOZAK_USER_HOST_DISPLAY.gif)

For a more streamlined prompt, you may choose to suppress the display of the username and hostname by setting

    AGKOZAK_USER_HOST_DISPLAY=0

#### AGKOZAK_BRANCH_STATUS_SEPARATOR

By default, a space precedes the Git branch status indicator, typically right between it and the directory name. You may eliminate the space by setting

    AGKOZAK_BRANCH_STATUS_SEPARATOR=''

Alternatively, you may set `AGKOZAK_BRANCH_STATUS_SEPARATOR` to any other character or characters that you prefer.

### Advanced Customization
If you would like to make further customizations to your prompt, you may use the variables `AGKOZAK_CUSTOM_PROMPT` and `AGKOZAK_CUSTOM_RPROMPT` to specify the exact strings to be used for the left and right prompts. The default prompts, with the default settings, can be expressed as

    AGKOZAK_CUSTOM_PROMPT='%(?..%B%F{red}(%?%)%f%b )'
    AGKOZAK_CUSTOM_PROMPT+='%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
    AGKOZAK_CUSTOM_PROMPT+=$'%B%F{blue}%2v%f%b\n'
    AGKOZAK_CUSTOM_PROMPT+='%(4V.:.%#) '

    AGKOZAK_CUSTOM_RPROMPT='%(3V.%F{yellow}%3v%f.)'

In general, you will not need to change these settings to achieve a custom prompt. If, for example, you would like to move the Git status into the left prompt, you may do so simply with `AGKOZAK_LEFT_PROMPT_ONLY=1`. If you want to make it your favorite shade of grey, you may add `AGKOZAK_COLORS_BRANCH_STATUS=243`.

But if you then wanted to have the (now empty) right prompt display the time, you should add

     AGKOZAK_CUSTOM_RPROMPT='%*'

Both prompts, thus altered, could be expressed as

    AGKOZAK_CUSTOM_PROMPT='%(?..%B%F{red}(%?%)%f%b )'
    AGKOZAK_CUSTOM_PROMPT+='%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
    AGKOZAK_CUSTOM_PROMPT+=$'%B%F{blue}%2v%f%b%(3V.%F{243}%3v%f.)\n'
    AGKOZAK_CUSTOM_PROMPT+='%(4V.:.%#) '

    AGKOZAK_CUSTOM_RPROMPT='%*'

Note that once `AGKOZAK_CUSTOM_PROMPT` or `AGKOZAK_CUSTOM_RPROMPT` is set, it may override the simpler settings such as `AGKOZAK_LEFT_PROMPT_ONLY`.

## Asynchronous Methods

The agkozak ZSH Prompt has three different methods for displaying the Git status asynchronously, thus keeping the prompt swift. One asynchronous method that works on all known platforms and with all supported versions of ZSH is [@psprint](https://github.com/psprint)'s `subst-async` technique, which uses process substitution (`<()`) to fork a background process that fetches the Git status and feeds it to a file descriptor. A `zle -F` callback handler then processes the input from the file descriptor and uses it to update the prompt.

`subst-async` works on Windows environments such as Cygwin, MSYS2, and WSL and on Solaris, but it is comparatively slow. On WSL and Solaris, the default asynchronous method relies on the [`zsh-async`](https://github.com/mafredri/zsh-async) library, which uses the `zsh/zpty` module to spin off pseudo-terminals that can calculate the Git status without blocking the user from continuing to use the terminal.

`zsh/zpty` does not work well with Cygwin or MSYS2. For these environments, the agkozak ZSH Prompt uses a method described by [Anish Athalye](http://www.anishathalye.com/2015/02/07/an-asynchronous-shell-prompt/). This `usr1` method creates and disowns child processes that calculate the Git status and then kill themselves off, triggering SIGUSR1 in the process. The ZSH `TRAPUSR1` trap function then displays that Git status. Since other scripts or the user could conceivably define `TRAPUSR1` either before or after this prompt is loaded, it regularly checks to see if that is the case and, if so, falls back to the slower but entirely reliable `subst-async` method.

If you want to force the agkozak ZSH Prompt to use a specific asynchronous method (or none at all), execute `export AGKOZAK_FORCE_ASYNC_METHOD=subst-async`, `zsh-async`, `usr1`, or `none` before sourcing it. If you want more insight into how the prompt is working in your shell, put `export AGKOZAK_PROMPT_DEBUG=1` in your `.zshrc` before the code loading this prompt.

## Examples of agkozak ZSH Prompt Customization

*Note: If you see your prompt customization here, I may have rewritten it a bit or even simplified it for educational purposes.*

### Using Basic Configuration Settings

#### [downtrip](https://gitlab.com/downtrip/dotfiles-p6/blob/2f4b7ae84f725cda8bbbb8aac157ee387dc279f2/.zshrc#L152)

![downtrip](img/custom_downtrip.png)

```sh
AGKOZAK_COLORS_BRANCH_STATUS=248
AGKOZAK_BLANK_LINES=1
AGKOZAK_LEFT_PROMPT_ONLY=1
# Make the prompt character red when superuser
AGKOZAK_PROMPT_CHAR=( '%F{magenta}❯%f' '%F{red}❯%f' '%F{magenta}❮%f' )
AGKOZAK_CUSTOM_SYMBOLS=( '⇣⇡' '⇣' '⇡' '+' 'x' '!' '>' '?' )
AGKOZAK_USER_HOST_DISPLAY=0
```
#### [borekb](https://github.com/agkozak/agkozak-zsh-prompt/pull/9)

![borekb](img/custom_borekb.png)

```sh
AGKOZAK_COLORS_BRANCH_STATUS=243
AGKOZAK_BLANK_LINES=1
AGKOZAK_LEFT_PROMPT_ONLY=1
# Make the prompt character more like that of bash
AGKOZAK_PROMPT_CHAR=( '$' '#' ':' )
AGKOZAK_USER_HOST_DISPLAY=0
```

#### [donkebap](https://github.com/donkebap/dotfiles/blob/a6fd36382c7f997156316173dd1ce898944bb0ae/dot_zshrc)

![donkebap](img/custom_donkebap.png)

```sh
AGKOZAK_MULTILINE=0
AGKOZAK_PROMPT_CHAR=( ❯ ❯ ❮ )
```

#### [andeee](https://github.com/andeee/dotfiles/blob/ae53603fe69243ae4f3028d80e002af5630f40dd/zsh/.zshrc)

![andeee](img/custom_andeee.png)

```sh
AGKOZAK_COLORS_PROMPT_CHAR='magenta'
AGKOZAK_MULTILINE=0
AGKOZAK_PROMPT_CHAR=( ❯ ❯ ❮ )
AGKOZAK_USER_HOST_DISPLAY=0
```

#### [DFG](https://github.com/tarkin88/DFG/blob/2bad488681cd5ca1ca2e59d9ed9d4409a949c0bb/dots/antigen/zshrc)

![DFG](img/custom_DFG.png)

```sh
AGKOZAK_COLORS_PATH=grey
AGKOZAK_COLORS_BRANCH_STATUS=cyan
AGKOZAK_COLORS_PROMPT_CHAR=white
AGKOZAK_COLORS_PROMPT_CHAR=cyan

AGKOZAK_BLANK_LINES=1

AGKOZAK_PROMPT_CHAR=( ❯ ❯ ❮ )
```

### Using AGKOZAK_CUSTOM_PROMPT and AGKOZAK_CUSTOM_RPROMPT

#### [gnumoksha](https://github.com/gnumoksha/dotfiles/blob/e48d195c58abbedee65976b41d9cdf35a4716c7a/shell/zsh/agkozak-settings.zsh)

![gnumoksha](img/custom_gnumoksha.png)

```sh
AGKOZAK_PROMPT_DIRTRIM=4
AGKOZAK_COLORS_BRANCH_STATUS=243
AGKOZAK_LEFT_PROMPT_ONLY=1
# The prompt character is always $
AGKOZAK_PROMPT_CHAR=( '$' '$' '$'  )

# Display the time in the right prompt
AGKOZAK_CUSTOM_RPROMPT='%*'
```

#### [pjcj](https://github.com/pjcj/base/blob/6138f2310fbabd809b3b10b1e279bbaff4ccbe05/.zshrc)

![pjcj](img/custom_pjcj.png)

```sh
AGKOZAK_PROMPT_DIRTRIM=0
AGKOZAK_CUSTOM_SYMBOLS=( '⇣⇡' '⇣' '⇡' '+' 'x' '!' '>' '?' )

AGKOZAK_CUSTOM_PROMPT='%(?..%B%F{red}(%?%)%f%b )'
AGKOZAK_CUSTOM_PROMPT+='%(!.%S%B.%B%F{32})%n%1v%(!.%b%s.%f%b)'
# Display the current history event number
AGKOZAK_CUSTOM_PROMPT+=' %B%F{13}%h%f%b'
AGKOZAK_CUSTOM_PROMPT+=$'\n%F{13}%(4V.:.%#)%f '

AGKOZAK_CUSTOM_RPROMPT='%(3V.%F{yellow}%3v%f.) '
# Display the path (substituting ~ for $HOME and in named directories)
AGKOZAK_CUSTOM_RPROMPT+='%B%F{blue}%~%f%b '
# Display the time
AGKOZAK_CUSTOM_RPROMPT+='%F{32}%*'
```

#### [ccb012100](https://github.com/ccb012100/linux-configs/blob/f31f11794deb3365dd78427d03bb51284392a35b/.zshrc)

![ccb012100](img/custom_ccb012100.png)

```sh
# Current history event number, time, and date
AGKOZAK_CUSTOM_PROMPT='%F{blue}%h%f%F{yellow} %D{%H:%M:%S}%f%F{cyan} %D{%a %b-%d}%f'
AGKOZAK_CUSTOM_PROMPT+=' %(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
AGKOZAK_CUSTOM_PROMPT+='%B%F{blue}%2v%f%b%(3V.%F{yellow}%3v%f.)'
# Exit status
AGKOZAK_CUSTOM_PROMPT+=' %(?..%B%F{red}(%?%)%f%b)'
AGKOZAK_CUSTOM_PROMPT+='%(4V.:.%#) '

AGKOZAK_RPROMPT=''
```

<p align="center">
  <img src="img/logo.png" alt="agkozak ZSH Prompt Logo">
</p>
