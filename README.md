
# `agkozak-zsh-theme`
![screenshot](https://github.com/agkozak/agkozak-zsh-theme/raw/master/img/agkozak-zsh-theme.jpg)


`agkozak-zsh-theme` is a `zsh` theme that displays git branch and status in the main prompt and also displays non-zero exit codes in `zsh`'s right prompt. It uses color but avoids the non-ASCII glyphs so common in other zsh themes and is thus suitable for use with fonts that have a limited set of symbols. The git status symbols that it does use are as follows:

Git Status | Symbol
--- | ---
Modified | !
Deleted | x
Untracked | ?
New file(s) | +
Ahead | \*
Renamed | >

`agkozak-zsh-theme` works indepedently of any `zsh` framework; in the absense of a framework, it can be loaded thus:

     source /path/to/agkozak-zsh-theme/agkozak-zsh-theme.zsh

`agkozak-zsh-theme`'s prompt changes when one switches from insert mode to command mode and back.

Individual frameworks have different ways of loading plugins from git repositories. I use [zplugin](https://github.com/zdharma/zplugin), so my `.zshrc` has the line

    zplugin load agkozak/agkozak-zsh-theme
