#!/bin/bash

# Set default number of commits to show (5)
num_commits=${1:-5}

# Define the directory of the remote Git repository (adjust as needed)
GIT_REPO_PATH="/path/to/your/repository.git/hooks"
POST_RECEIVE_HOOK="$GIT_REPO_PATH/post-receive"

# Check if the post-receive hook exists
if [ -f "$POST_RECEIVE_HOOK" ]; then
    # If the hook exists, check if it is non-empty
    if [ -s "$POST_RECEIVE_HOOK" ]; then
        echo "Git push events are being recorded. Here is the content of the post-receive hook:"
        cat "$POST_RECEIVE_HOOK"
    else
        echo "The post-receive hook exists, but it is empty. No push events are being recorded."
        read -p "Would you like to populate the post-receive hook to record push events? (y/n): " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            # Add a basic logging script to the post-receive hook
            echo "#!/bin/bash" > "$POST_RECEIVE_HOOK"
            echo "echo \"\$(date) - Push received on branch \$(git rev-parse --abbrev-ref HEAD)\" >> /path/to/push_log.txt" >> "$POST_RECEIVE_HOOK"
            chmod +x "$POST_RECEIVE_HOOK"
            echo "The post-receive hook has been populated and is now recording push events."
        else
            echo "The post-receive hook was not modified. Push events will not be recorded."
        fi
    fi
else
    # If the post-receive hook doesn't exist
    echo "No post-receive hook found. Git push events are not being recorded."
    read -p "Would you like to create a post-receive hook to record push events? (y/n): " response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        # Create a new post-receive hook to log push events
        echo "#!/bin/bash" > "$POST_RECEIVE_HOOK"
        echo "echo \"\$(date) - Push received on branch \$(git rev-parse --abbrev-ref HEAD)\" >> /path/to/push_log.txt" >> "$POST_RECEIVE_HOOK"
        chmod +x "$POST_RECEIVE_HOOK"
        echo "The post-receive hook has been created and is now recording push events."
    else
        echo "No post-receive hook was created. Push events will not be recorded."
    fi
fi

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

echo "=== Last $num_commits Push Actions ==="
# Find last n pushes from reflog and show timestamps
git reflog show --date=iso -n $num_commits | grep -i "push" | while read line; do
    # Extract and show the timestamp and reference for each push event
    echo "$line" | sed -E 's/^([0-9-]+ [0-9:]+).*/\1 - push event/'
done

echo
echo "M(odified), N(ew), D(eleted)"

