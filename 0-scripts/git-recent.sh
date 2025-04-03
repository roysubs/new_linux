#!/bin/bash

# Set default number of commits to show (5)
num_commits=${1:-5}

echo "=== Last $num_commits Commits ==="
git log -n $num_commits --pretty=format:"%cd %h - %s" --date=iso
echo

echo "=== Files Modified/New/Deleted in the Last $num_commits Commits ==="
for commit in $(git log -n $num_commits --pretty=format:"%h"); do
    echo "Commit: $commit"
    # Get the diff status of files (new, modified, deleted)
    git show --name-status --pretty=format:"" $commit | while read status file; do
        case $status in
            A)
                echo "N: $file"
                ;;
            M)
                echo "M: $file"
                ;;
            D)
                echo "D: $file"
                ;;
            *)
                echo "Unknown status for: $file"
                ;;
        esac
    done
    echo
done

echo
echo "M(odified), N(ew), D(eleted)"

