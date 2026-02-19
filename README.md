# television.yazi

A customizable [television](https://alexpasmantier.github.io/television/) plugin for [yazi](https://yazi-rs.github.io/).

Support custom regex pattern parsing output with the `--pattern` parameter and a comma-separated list of capture variable names using the `--pattern-keys` parameter to accommodate various channel outputs. Also provide a `--cd` parameter for entering directories, or use the `--shell` parameter to execute a given script, and use the `--reveal` parameter to position the cursor on a file or directory. Except for `--cd`, which can be either a flag parameter or a string parameter, all other parameters must be string parameters. `--cd`, `--shell`, and `--reveal` can be templates that reference variable names captured in `--pattern-keys`, and there are two convenient optional flag markers, `$` and `%` that can be used. `%` indicates expanding the filename to an absolute path, while `$` indicates using `ya.quote()` to make the name safe for use in the shell. However, `$` must come before `%` to imply their order requirement.

Just install it via:

```sh
ya pkg add moxuze/television
```

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = "e"
run = """plugin television -- text --text"""
# Equivalent to:
#run = """plugin television -- text --pattern='^(.+):(%d+)$' --pattern-keys='file,line' --reveal='{{%file}}' --shell='"$EDITOR" {{$%file}}'"""
# Or:
#run = """plugin television -- text --pattern='^(.+):(%d+)$' --pattern-keys='file,line' --reveal='{{%file}}' --shell='hx {{$%file}}:{{line}}'"""
#run = """plugin television -- text --pattern='^(.+):(%d+)$' --pattern-keys='file,line' --reveal='{{%file}}' --shell='nvim {{$%file}} +:{{line}}'"""
desc = "Edit a file via television"

[[mgr.prepend_keymap]]
on = "z"
run = "plugin television -- zoxide-query --cd"
desc = "Jump to a file via zoxide in television"

[[mgr.prepend_keymap]]
on = "Z"
run = "plugin television -- files"
desc = "Jump to a file via television"
```

Then add this to your `~/.config/television/cable/zoxide-query.toml` (optional):

```toml
[metadata]
name = "zoxide-query"
description = "Query zoxide directory history"
requirements = ["zoxide"]

[source]
command = "zoxide query -l"
no_sort = true
frecency = false

[preview]
command = "ls -la --color=always '{}'"
```

ENJOY IT.