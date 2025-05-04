#!/usr/bin/env bash

# Quick Shell Compatibility Checker
echo "Detected shell: $SHELL"
shell_name=$(basename "$SHELL")

# Try to detect actual shell (helpful if launched via symlink)
detect_shell() {
    if [ -n "$BASH_VERSION" ]; then
        echo "Shell detected: bash $BASH_VERSION"
    elif [ -n "$ZSH_VERSION" ]; then
        echo "Shell detected: zsh $ZSH_VERSION"
    elif [ -n "$KSH_VERSION" ]; then
        echo "Shell detected: ksh $KSH_VERSION"
    elif [ -n "$FISH_VERSION" ]; then
        echo "Shell detected: fish $FISH_VERSION (not POSIX-compliant)"
    else
        echo "Unknown or unsupported shell"
    fi
}
detect_shell

# Feature checks
echo
echo "Checking feature support..."

# Check associative arrays
if (echo 'declare -A arr=(); arr[key]=value' | bash 2>/dev/null); then
    echo "✔ Associative arrays supported"
else
    echo "✘ Associative arrays NOT supported"
fi

# Check [[ operator
if (echo '[[ 1 -eq 1 ]] && echo ok' | bash &>/dev/null); then
    echo "✔ [[ operator supported"
else
    echo "✘ [[ operator NOT supported"
fi

# Check process substitution
if (echo 'diff <(echo a) <(echo b)' | bash &>/dev/null); then
    echo "✔ Process substitution supported"
else
    echo "✘ Process substitution NOT supported"
fi

# Check arithmetic evaluation
if (echo '$((1 + 2))' | bash &>/dev/null); then
    echo "✔ Arithmetic expansion supported"
else
    echo "✘ Arithmetic expansion NOT supported"
fi

# Summary
echo
echo "If any feature is missing, scripts using modern Bash may not work reliably."

