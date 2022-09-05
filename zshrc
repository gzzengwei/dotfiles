
# Local config
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# finalized with compinit
autoload -Uz compinit && compinit

# bun completions
[ -s "/Users/wei/.bun/_bun" ] && source "/Users/wei/.bun/_bun"

