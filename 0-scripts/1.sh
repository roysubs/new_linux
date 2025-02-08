#!/bin/bash

# Your script logic here...

# Append the desired text to the next prompt
printf "\n"  # Ensure a clean newline
PROMPT_COMMAND='printf "# . ~/.bashrc"; PROMPT_COMMAND=""'

