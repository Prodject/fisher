set -g fisher_version 3.0.0

complete -c fisher -l help -s h -d "Show usage help"
complete -c fisher -l version -s v -d "Show version information"

if type -q perl
    function _fisher_now -a offset
        command perl -MTime::HiRes -e 'printf("%.0f\n", (Time::HiRes::time()*1000)-$ARGV[0])' $offset
    end
else
    function _fisher_now -a offset
        command date "+%s%3N" | command awk "{ sub(/3N\$/,\"000\"); print \$0-0$offset }"
    end
end

function fisher -a cmd -d "fish plugin manager"
    switch "$version"
        case 2.{0,1}\*
            echo "fish >=2.3.0 is required to use fisher -- please upgrade your shell" >&2
            return 1
    end

    if not type -q curl
        echo "curl is required to use fisher -- install curl and try again" >&2
        return 1
    end

    test -z "$XDG_CACHE_HOME"; and set XDG_CACHE_HOME ~/.cache
    test -z "$XDG_CONFIG_HOME"; and set XDG_CONFIG_HOME ~/.config

    set -g fish_config $XDG_CONFIG_HOME/fish
    set -g fisher_cache $XDG_CACHE_HOME/fisher
    set -g fisher_config $XDG_CONFIG_HOME/fisher

    test -z "$fisher_path"; and set -g fisher_path $fish_config

    switch "$cmd"
        case ""
        case -v --version
            _fisher_version (status -f)
            return
        case -h --help
            _fisher_help
            return
        case self-uninstall
            _fisher_self_uninstall
            return 1
        case \*
            echo "unknown flag or command \"$cmd\" -- enter fisher -h for usage instructions" >&2
            return 1
    end

    if not command mkdir -p {$fish_config,$fisher_path}/{functions,completions,conf.d} $fisher_cache
        echo "cannot create configuration files:" (
            printf "%s\n" $fish_config $fisher_path $fisher_cache | command sort -u
        ), | command sed "s|$HOME|~|g;s|.\$||" >&2
        return 1
    end

    set -l elapsed (_fisher_now)

    _fisher_self_update (status -f)

    set -l fishfile $fisher_path/fishfile
    if test ! -e "$fishfile"
        echo "fishfile not found -- need help? enter fisher -h for usage instructions" | command sed "s|$HOME|~|" >&2
        return 1
    end

    _fisher_fishfile_indent < $fishfile > $fishfile@
    command mv -f $fishfile@ $fishfile
    command rm -f $fishfile@

    set -l removed (_fisher_plugin_remove_all $fisher_config/*/*/*)
    command rm -rf $fisher_config
    command mkdir -p $fisher_config

    set -l added (_fisher_plugin_fetch_all (_fisher_fishfile_load < $fishfile))
    set -l updated (
        for plugin in $removed
            set plugin (echo $plugin | command sed "s|$fisher_config/||")
            if contains -- $plugin $added
                echo $plugin
            end
        end)

    echo (count $added) (count $updated) (count $removed) (_fisher_now $elapsed) | _fisher_print_status_report >&2
end

function _fisher_help
    echo "WIP"
end

function _fisher_version -a file
    echo "fisher version $fisher_version $file" | command sed "s|$HOME|~|"
end

function _fisher_self_uninstall
    echo "WIP"
end

function _fisher_self_update -a file
    if type -q perl; and test (perl -e "printf(\"%s\n\", time - (stat ('$file'))[9])") -lt 3600
        # return
    end
    echo -n "updating fisher to latest" >&2
    # curl -s "https://raw.githubusercontent.com/jorgebucaran/fisher/master/fisher.fish?nocache" >"$file@"
    if test -s "$file@"
        # command mv -f "$file@" "$file"
        set -l last_version $fisher_version
        source $file
        if test $last_version = $fisher_version
            echo " -- already up-to-date" >&2
        else
            echo " -- updated to $fisher_version" >&2
        end
    else
        echo " -- cannot update, are you offline?" >&2
    end
    # command rm -f "$file@"
end

function _fisher_plugin_remove_all
    if test ! -z "$argv"
        for plugin in $argv
            echo $plugin
            _fisher_plugin_uninstall $plugin
        end
    end
end

function _fisher_plugin_fetch_all
    set -l all_jobs
    set -l local_plugins
    set -l actual_plugins
    set -l expected_plugins

    for name in $argv
        switch $name
            case \~\* .\* /\*
                set -l path (echo "$name" | command sed "s|~|$HOME|;s|^[.]/|$fisher_path/|")
                if test -e "$path"
                    set local_plugins $local_plugins $path
                else
                    echo "cannot install $name -- is this a valid file?" >&2
                end
                continue

            case gitlab.com/\* bitbucket.org/\*
            case \?\*/\?\*
                set name "github.com/$name"
        end

        echo $name | command awk '{
            split($0, data, /[@#:]/)
            print data[1] "\t" (data[2] ? data[2] : "master")
        }' | read -l plugin tag

        switch $plugin
            case github.com\*
                echo "https://codeload.$plugin/tar.gz/$tag"
            case gitlab.com\*
                echo "https://$plugin/-/archive/$tag/"(echo $plugin | command sed 's|^.*/||')"-$tag.tar.gz"
            case bitbucket.org\*
                echo "https://$plugin/get/$tag.tar.gz"
        end | read -l url

        fish -l -c "
            echo fetching \"$url\" >&2
            command mkdir -p \"$fisher_config/$plugin\"

            if curl -Ss \"$url\" 2>&1 | tar -xzf- -C \"$fisher_config/$plugin\" --strip-components=1 2>/dev/null
                command mkdir -p \"$fisher_cache/$plugin\"
                command cp -Rf \"$fisher_config/$plugin\" \"$fisher_cache/$plugin/..\"
            else if test -d \"$fisher_cache/$plugin\"
                echo cannot connect to server -- using stale data from \"$fisher_cache/$plugin\" | command sed 's|$HOME|~|' >&2
                command cp -Rf \"$fisher_cache/$plugin\" \"$fisher_config/$plugin/..\"
            else
                command rm -rf \"$fisher_config/$plugin\"
                echo cannot install \"$plugin\" -- are you offline\? >&2
            end
        " >/dev/null &

        set all_jobs $all_jobs (_fisher_jobs --last)
        set expected_plugins $expected_plugins "$plugin"
    end

    if test ! -z "$all_jobs"
        _fisher_wait $all_jobs
        for plugin in $expected_plugins
            if test -d "$fisher_config/$plugin"
                set actual_plugins $actual_plugins $plugin
                _fisher_plugin_install $fisher_config/$plugin
            end
        end
    end

    for plugin in $local_plugins
        set -l path "local/$USER"
        set -l name (echo "$plugin" | command sed 's|^.*/||')

        command mkdir -p $fisher_config/$path
        command ln -sf $plugin $fisher_config/$path

        set actual_plugins $actual_plugins $path/$name
        _fisher_plugin_install $fisher_config/$path/$name
    end

    if test ! -z "$actual_plugins"
        printf "%s\n" $actual_plugins
        _fisher_plugin_fetch_all (_fisher_plugin_find_dependencies $actual_plugins | command sort -u)
    end
end

function _fisher_plugin_find_dependencies
    for plugin in $argv
        set -l path $fisher_config/$plugin
        if test ! -d "$path"
            echo $plugin
        else if test -s "$path/fishfile"
            _fisher_plugin_find_dependencies (_fisher_fishfile_indent < $path/fishfile | _fisher_fishfile_load)
        end
    end
end

function _fisher_plugin_install -a plugin
    for source in $plugin/{,functions,completions,conf.d}/*.fish
        set -l target (echo "$source" | command sed 's|^.*/||')
        switch $source
            case $plugin/conf.d\*
                set target $fisher_path/conf.d/$target
            case $plugin/completions\*
                set target $fisher_path/completions/$target
            case $plugin/{functions,}\*
                set target $fisher_path/functions/$target
        end
        echo "linking $target" | command sed "s|$HOME|~|" >&2
        command ln -f $source $target
        source $target >/dev/null 2>/dev/null
    end
end

function _fisher_plugin_uninstall -a plugin
    for source in $plugin/{conf.d,completions,functions,}/*.fish
        set -l target (echo "$source" | command sed 's|^.*/||')
        set -l name (echo "$target" | command sed 's|.fish||')
        switch $source
            case $plugin/conf.d\*
                emit {$name}_uninstall
                command rm -f $fisher_path/conf.d/$target
            case $plugin/completions\*
                command rm -f $fisher_path/completions/$target
                complete -ec $name
            case $plugin/{functions,}\*
                command rm -f $fisher_path/functions/$target
                functions -e $name
        end
    end
    if not functions -q fish_prompt
        source "$__fish_datadir/functions/fish_prompt.fish"
    end
end

function _fisher_fishfile_indent
    command awk '
        BEGIN { true = 1 } {
            if (NF == 0) newline = skip
            else {
                gsub(/\.git$|^[ \t]*|[ \t]*$|https?:\/\/|github\.com\//, "")
                if (!seen[$0]++ || /^#/) print (newline ? "\n" : "")$0
                newline = !(skip = true)
            }
        }
    '
end

function _fisher_fishfile_load
    command awk '!/^#/ && NF != 0 { print $1 }'
end

function _fisher_print_status_report
    command awk '
        function msg(res, str, n) {
            return (res ? res ", " : "") str " " n " plugin" (n > 1 ? "s" : "")
        }

        $1=$1-$2 { res = msg(res, "added", $1) }
            $2 { res = msg(res, "updated", $2) }
        $3=$3-$2 { res = msg(res, "removed", $3) }

        { printf((res ? res : "Done") " in %.2fs\n", ($4 / 1000)) }
    '
end

function _fisher_jobs
    jobs $argv | command awk -v FS=\t '
        /[0-9]+\t/ { jobs[++n] = $1 } END {
            for (i in jobs) print(jobs[i])
            exit n == 0
        }
    '
end

function _fisher_wait
    while true
        set -l done
        set -l all_jobs (_fisher_jobs); or break
        for job in $argv
            if contains -- $job $all_jobs
                set -e done
                break
            end
        end
        if set -q done
            break
        end
    end
end
