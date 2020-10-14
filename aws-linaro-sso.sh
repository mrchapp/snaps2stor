function assume-role {
    eval "$(aws2-wrap --profile $1 --export)" && \
    PS1="(\[\033[31m\]$1\[\033[0m\]) ${PS1}"
}

alias linaro-sso-login='aws sso login --profile=lkft-admin'
alias assume-lkft-admin='assume-role lkft-admin'
