for file in ./*; do
    if [ -f "$file" ]; then  # Check if it's a file (not a directory)
        ./clean-media-file.sh "$file"
    fi
done

