# window bridge
window_root "~/Projects/misc/hivetec/bridge"

new_window "bridge"

split_h 50

split_v 30

select_pane 1

# window ops
window_root "~/Projects/misc/hivetec/create-cluster"

new_window "ops"

split_v 80

select_pane 1

split_h 10

select_pane 1

# window repos
window_root "~/Projects/misc/hivetec"

new_window "repos"

tmux rename-window repos

# window misc
new_window "misc"

split_h 50

split_v 50

select_pane 1

split_v 50

select_pane 1
