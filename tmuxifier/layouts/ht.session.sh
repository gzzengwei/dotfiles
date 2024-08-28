# Set a custom session root path. Default is `$HOME`.
# Must be called before `initialize_session`.
session_root "~/Projects/misc/hivetec"

# Create session with specified name if it does not already exist. If no
# argument is given, session name will be based on layout file name.
if initialize_session "ht"; then

	load_window "ht"

	# load_window "ht-ops"
	# tmux rename-window
	#
	# load_window "ht-main"
	# tmux rename-window elixir
	#
	# load_window "ht-4blocks"

	select_window 1
fi

# Finalize session creation and switch/attach to it.
finalize_and_go_to_session
