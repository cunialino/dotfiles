let carapace_completer = {|spans|
  # if the current command is an alias, get it's expansion
  let expanded_alias = (scope aliases | where name == $spans.0 | get -i 0 | get -i expansion)

  # overwrite
  let spans = (if $expanded_alias != null  {
    # put the first word of the expanded alias first in the span
    $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
  } else {
    $spans
  })

  carapace $spans.0 nushell $spans
  | from json
}

$env.config = {
    show_banner: false # true or false to enable or disable the welcome banner at startup

    ls: {
        use_ls_colors: true # use the LS_COLORS environment variable to colorize output
        clickable_links: true # enable or disable clickable links. Your terminal has to support links.
    }

    rm: {
        always_trash: false # always act as if -t was given. Can be overridden with -p
    }

    table: {
        mode: rounded # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
        index_mode: always # "always" show indexes, "never" show indexes, "auto" = show indexes when a table has "index" column
        show_empty: true # show 'empty list' and 'empty record' placeholders for command output
        padding: { left: 1, right: 1 } # a left right padding of each column in a table
        trim: {
            methodology: wrapping # wrapping or truncating
            wrapping_try_keep_words: true # A strategy used by the 'wrapping' methodology
            truncating_suffix: "..." # A suffix used by the 'truncating' methodology
        }
        header_on_separator: false # show header text on separator/border line
        # abbreviated_row_count: 10 # limit data rows from top and bottom after reaching a set point
    }

    error_style: "fancy" # "fancy" or "plain" for screen reader-friendly error messages

    # datetime_format determines what a datetime rendered in the shell would look like.
    # Behavior without this configuration point will be to "humanize" the datetime display,
    # showing something like "a day ago."
    datetime_format: {
        # normal: '%a, %d %b %Y %H:%M:%S %z'    # shows up in displays of variables or other datetime's outside of tables
        # table: '%m/%d/%y %I:%M:%S%p'          # generally shows up in tabular outputs such as ls. commenting this out will change it to the default human readable datetime format
    }

    explore: {
        status_bar_background: {fg: "#1D1F21", bg: "#C4C9C6"},
        command_bar_text: {fg: "#C4C9C6"},
        highlight: {fg: "black", bg: "yellow"},
        status: {
            error: {fg: "white", bg: "red"},
            warn: {}
            info: {}
        },
        table: {
            split_line: {fg: "#404040"},
            selected_cell: {bg: light_blue},
            selected_row: {},
            selected_column: {},
        },
    }

    history: {
        max_size: 100_000 # Session has to be reloaded for this to take effect
        sync_on_enter: true # Enable to share history between multiple sessions, else you have to close the session to write history to file
        file_format: "plaintext" # "sqlite" or "plaintext"
        isolation: false # only available with sqlite file_format. true enables history isolation, false disables it. true will allow the history to be isolated to the current session using up/down arrows. false will allow the history to be shared across all sessions.
    }

    filesize: {
        metric: false # true => KB, MB, GB (ISO standard), false => KiB, MiB, GiB (Windows standard)
        format: "auto" # b, kb, kib, mb, mib, gb, gib, tb, tib, pb, pib, eb, eib, auto
    }

    cursor_shape: {
        emacs: line # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (line is the default)
        vi_insert: block # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (block is the default)
        vi_normal: underscore # block, underscore, line, blink_block, blink_underscore, blink_line, inherit to skip setting cursor shape (underscore is the default)
    }

    use_grid_icons: true
    footer_mode: "25" # always, never, number_of_rows, auto
    float_precision: 2 # the precision for displaying floats in tables
    buffer_editor: "" # command that will be used to edit the current line buffer with ctrl+o, if unset fallback to $env.EDITOR and $env.VISUAL
    bracketed_paste: true # enable bracketed paste, currently useless on windows
    edit_mode: emacs
    shell_integration: false # enables terminal shell integration. Off by default, as some terminals have issues with this.
    highlight_resolved_externals: true # true enables highlighting of external commands in the repl resolved by which.

    hooks: {
        pre_prompt: [{ null }] # run before the prompt is shown
        pre_execution: [{ null }] # run before the repl input is run
        env_change: {
            PWD: [
              {
                condition: {|before, after| $after ++ /.git | path exists }
                code: {|before, after| 
                  hide-env GIT_DIR
                  hide-env GIT_WORK_TREE
                }
              }
              {
                condition: {|before, after| not ( $after ++ /.git | path exists  )}
                code: {|before, after| 
                  $env.GIT_DIR = $env.HOME ++ /builds/dotfiles
                  $env.GIT_WORK_TREE = $env.HOME 
                }
              }
            ]
        }
        display_output: "if (term size).columns >= 100 { table -e } else { table }" # run to display the output of a pipeline
        command_not_found: { null } # return an error message when a command is not found
    }

    menus: [
        {
            name: fzf_menu_nu_ui
            only_buffer_difference: false
            marker: "# "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: "#66ff66"
                selected_text: { fg: "#66ff66" attr: r }
                description_text: yellow
            }
            source: { |buffer, position|
                open -r $nu.history-path
                | fzf -f $buffer
                | lines
                | each { |v| {value: ($v | str trim) } }
            }
        }
        {
            name: fzf_cd_nu_ui
            only_buffer_difference: false
            marker: "# "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: "#66ff66"
                selected_text: { fg: "#66ff66" attr: r }
                description_text: yellow
            }
            source: { |buffer, position|
                fd . -t d -H -d 7
                | fzf -f $buffer
                | lines
                | each { |v| {value: ([cd, ( $v | str trim )] | str join " ") } }
            }
        }
        {
            name: fzf_files_nu_ui
            only_buffer_difference: true
            marker: "# "
            type: {
                layout: list
                page_size: 10
            }
            style: {
                text: "#66ff66"
                selected_text: { fg: "#66ff66" attr: r }
                description_text: yellow
            }
            source: { |buffer, position|
                fd . -t f -H -d 7
                | fzf -f $buffer
                | lines
                | each { |v| { value: (($v | str trim) ) } }
            }
        }
        {
            name: completion_menu
            only_buffer_difference: false
            marker: "| "
            type: {
                layout: columnar
                columns: 4
                col_width: 20     # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
        {
            name: help_menu
            only_buffer_difference: true
            marker: "? "
            type: {
                layout: description
                columns: 4
                col_width: 20     # Optional value. If missing all the screen width is used to calculate column width
                col_padding: 2
                selection_rows: 4
                description_rows: 10
            }
            style: {
                text: green
                selected_text: green_reverse
                description_text: yellow
            }
        }
    ]

    keybindings: [
        {
          name: fzf_cd_nu_ui
          modifier: alt
          keycode: char_c
          mode: [emacs, vi_normal, vi_insert]
          event: { send: menu name: fzf_cd_nu_ui }
        }
        {
          name: fzf_files_nu_ui
          modifier: control
          keycode: char_f
          mode: [emacs, vi_normal, vi_insert]
          event: { send: menu name: fzf_files_nu_ui }
        }

        {
          name: fzf_menu_nu_ui
          modifier: control
          keycode: char_r
          mode: [emacs, vi_normal, vi_insert]
          event: { send: menu name: fzf_menu_nu_ui }
        }
        {
            name: completion_menu
            modifier: none
            keycode: tab
            mode: [emacs vi_normal vi_insert]
            event: {
                until: [
                    { send: menu name: completion_menu }
                    { send: menunext }
                    { edit: complete }
                ]
            }
        }
        {
            name: help_menu
            modifier: none
            keycode: f1
            mode: [emacs, vi_insert, vi_normal]
            event: { send: menu name: help_menu }
        }
        {
            name: completion_previous_menu
            modifier: control
            keycode: char_k
            mode: [emacs, vi_normal, vi_insert]
            event: { send: menuprevious }
        }
        {
            name: completion_next_menu
            modifier: control
            keycode: char_j
            mode: [emacs, vi_normal, vi_insert]
            event: { send: menunext }
        }
        {
            name: escape
            modifier: none
            keycode: escape
            mode: [emacs, vi_normal, vi_insert]
            event: { send: esc }    # NOTE: does not appear to work
        }
        {
            name: cancel_command
            modifier: control
            keycode: char_c
            mode: [emacs, vi_normal, vi_insert]
            event: { send: ctrlc }
        }
        {
            name: clear_screen
            modifier: control
            keycode: char_l
            mode: [emacs, vi_normal, vi_insert]
            event: { send: clearscreen }
        }
    ]
}


$env.EDITOR = nvim

alias grep = rg
alias cat = bat
alias diff = delta
alias find = fd

use ~/.config/nushell/nu_scripts/themes/nu-themes/catppuccin-mocha.nu
$env.config = ($env.config | merge {color_config: (catppuccin-mocha)})

use starship.nu

source carapace.nu
