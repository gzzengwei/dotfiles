# Setup fzf
# ---------
if [[ ! "$PATH" == */Users/wei/.fzf/bin* ]]; then
  export PATH="$PATH:/Users/wei/.fzf/bin"
fi

# Auto-completion
# ---------------
[[ $- == *i* ]] && source "/Users/wei/.fzf/shell/completion.zsh" 2> /dev/null

# Key bindings
# ------------
source "/Users/wei/.fzf/shell/key-bindings.zsh"

