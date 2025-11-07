-record(state, {tty :: tty() | undefined,
                reader :: {pid(), reference()} | undefined,
                writer :: {pid(), reference()} | undefined,
                options,
                unicode = true :: boolean(),
                lines_before = [],   %% All lines before the current line in reverse order
                lines_after = [],    %% All lines after the current line.
                buffer_before = [],  %% Current line before cursor in reverse
                buffer_after = [],   %% Current line after  cursor not in reverse
                buffer_expand,       %% Characters in expand buffer
                buffer_expand_row = 1,
                buffer_expand_limit = 0 :: non_neg_integer(),
                cols = 80,
                rows = 24,
                xn = false,
                clear = <<"\e[H\e[2J">>,
                up = <<"\e[A">>,
                down = <<"\n">>,
                left = <<"\b">>,
                right = <<"\e[C">>,
                %% Tab to next 8 column windows is "\e[1I", for unix "ta" termcap
                tab = <<"\e[1I">>,
                delete_after_cursor = <<"\e[J">>,
                insert = false, %% Not used
                delete = false, %% Not used
                position = <<"\e[6n">>, %% "u7" on my Linux, Not used
                position_reply = <<"\e\\[([0-9]+);([0-9]+)R">>, %% Not used
                ansi_regexp
               }).
