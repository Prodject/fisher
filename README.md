# Fisher

[![Build Status](https://img.shields.io/travis/jorgebucaran/fisher.svg)](https://travis-ci.org/jorgebucaran/fisher)
[![Releases](https://img.shields.io/github/release/jorgebucaran/fisher.svg?label=latest)](https://github.com/jorgebucaran/fisher/releases)

Fisher is a package manager for the [fish shell](https://fishshell.com). It defines a common interface for package authors to build and distribute their shell scripts in a portable way. You can use it to extend your shell capabilities, change the look of your prompt and create repeatable configurations across different systems effortlessly.

## Features

- High speed concurrent package downloads~!
- No configuration or cost to your shell startup
- Add, update and remove functions, completions, keybindings and configuration snippets from a variety of sources using the command line or editing your [fishfile](#using-the-fishfile)
- All things cached—if you've installed a package before, then it can be installed again offline

## Installation

Download fisher to your fish functions directory or any directory in your $fish_function_path. Notice this isn't a curlpipe, we're just copying a file to a directory—there is no implicit code running behind the scenes.

```fish
curl https://git.io/fisher --create-dirs -sLo ~/.config/fish/functions/fisher.fish
```

If the [XDG_CONFIG_HOME](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html#variables) environment variable is defined on your system, use $XDG_CONFIG_HOME/fish to resolve the path to your fish configuration directory, otherwise use the default value ~/.config/fish as shown above.

### System requirements

- [fish](https://github.com/fish-shell/fish-shell) ≥2.2 (prefer ≥2.3; see [loading configuration snippets](#loading-configuration-snippets))
- [curl](https://github.com/curl/curl) ≥7.10.3
- [git](https://github.com/git/git) ≥1.7.12

### Bootstrap installation

To automate installing fisher on a new system, add the following code to your ~/.config/fish/config.fish. This will download fisher and install all the packages listed in your [fishfile](#using-the-fishfile).

```fish
if not functions -q fisher
    echo "Installing fisher for the first time..." >&2
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fisher
end
```

### Changing the installation prefix

Use the [$fisher_path]() environment variable to customize the prefix location where functions, completions and configuration snippets will be copied to when a package is installed. The default location is where fisher itself is installed. If you followed the installation instructions above, this will be your default fish configuration directory in ~/.config/fish.

Make sure to add your prefix functions and completions directories to the [$fish_function_path]() and [$fish_complete_path]() environment variables so that they can be autoloaded by fish in future sessions and to source every `*.fish` file inside your conf.d directory to load configuration snippets on startup.

Here is a boilerplate configuration you can add to your ~/.config/fish/config.fish to get you started.

```fish
set -g fisher_path ~/another/path

set fish_function_path $fish_function_path $fisher_path/functions
set fish_complete_path $fish_complete_path $fisher_path/completions

for file in $fisher_path/conf.d/*.fish
    builtin source $file 2> /dev/null
end
```

### Loading configuration snippets

Stuck in fish 2.2 and still can't upgrade your shell? You can use fisher, but you'll have to load configuration snippets the manual way. Open your ~/.config/fish/config.fish and prepend this code to the file.

```fish
set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
for file in $XDG_CONFIG_HOME/conf.d/*.fish
    builtin source $file 2> /dev/null
end
```

## Usage

You've found an interesting utility you'd like to try. Or perhaps you've [created a package](#creating-packages) yourself. How do you install it on your system? You may want to update or remove it later. How do you do that?

You can use fisher to add, update and remove packages interactively, taking advantage of tab completions and syntax highlighting. Or you may choose to do so by editing your [fishfile](#using-the-fishfile) and then commiting your changes. Do you prefer a CLI-centered approach, a text-based approach? Why not both?

### Adding packages

Install one or more packages.

```
fisher jethrokuan/z rafaelrinaldi/pure
```

Packages will be downloaded from GitHub if the name of the host is not specified. To install a package hosted anywhere else use the address of the remote server and the path to the repository.

```
fisher gitlab.com/owner/foobar bitbucket.org/owner/fumbam
```

Install a package from a tag or a branch.

```
fisher jethrokuan/z@pre27
```

Install a package from a local directory. Local packages are managed through soft links, so you can edit and use them at the same time. In addition, the tilde at the start of a package specifier will be expanded to your $HOME directory.

```
fisher ~/myfish/mypkg
```

### Listing packages

List everything currently installed (including package dependencies) using the `ls` command.

```
jethrokuan/z@pre27
rafaelrinaldi/pure
~/myfish/mypkg
gitlab.com/owner/foobar
bitbucket.org/owner/fumbam
```

### Removing packages

Remove packages using the `rm` command.

```
fisher rm rafaelrinaldi/pure
```

You can remove every package installed in one sweep using using this pipeline.

```
fisher ls | fisher rm
```

### Updating packages

There is no dedicated update command. Just run `fisher` without any arguments to update everything (including fisher itself). Adding or removing packages are

```
fisher
```

### Other commands

If you're at the terminal and need help use the `help` command.

```
fisher help
```

Last but not least use the `version` command to show version information.

```
fisher version
```

### Using the fishfile

Whenever you add or remove a package from the command line we'll create a text file in ~/.config/fish/fishfile. This is your fishfile. It lists every package currently installed on your system. You should add this file to your dotfiles or version control if you want to reproduce your configuration on a different system.

You can edit this file to add, update or remove packages and then run `fisher` to commit your changes. Only the packages listed in the file will be installed after fisher returns. Empty lines and comments (everything after a `#`) will be ignored.

```fish
vi ~/.config/fish/fishfile
```

```fish
rafaelrinaldi/pure
jethrokuan/z@pre27

# my local packages
~/myfish/mypkg
```

```
fisher
```

## Creating packages

- Describe the architecture of a package.

```
package-name
  functions
    {package-name}.fish
  completions
    {package-name}.fish
  conf.d
    {package-name}.fish
```

- Fisher is not a package registry and there isn't a built-in mechanism to publish packages to a centralized database. Its function is to put fish scripts in place so that your shell can find them, managing dependency conflicts intelligently.
- configuration snippets: Configuration snippets are `*.fish` files located in your ~/.config/fish/cond.d directory. They are evaluated by fish on [startup](http://fishshell.com/docs/current/index.html#initialization) and are used to run code at the start of the shell, set environment variables, create key bindings, and run other initialization tasks.
- Removing a package will erase autoloaded functions and completions in the same shell. For configuration snippets we'll emit an uninstall event that can be used to clear keybindings, environment variables, etc.
- Fisher is compatible with some Oh My Fish! packages.

1.  a directory or git repo with one or more .fish functions either at the root level of the project or
    inside a functions directory

2.  a theme or prompt, i.e, a fish_prompt.fish, fish_right_prompt.fish or both files

3.  a snippet, i.e, one or more .fish files inside a directory named conf.d, evaluated by fish at the start
    of the session

<!-- ## Code of Conduct

This project has adopted the Microsoft Open Source Code of Conduct. For more information see the Code of Conduct FAQ or contact opencode@microsoft.com with any additional questions or comments. -->

## License

Fisher is MIT licensed. See [LICENSE](LICENSE.md).
