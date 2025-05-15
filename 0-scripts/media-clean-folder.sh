for file in ./*; do
  if [ -f "$file" ]; then  # Check if it's a file (not a directory)
    ./media-clean-file.sh "$file"
  fi
done

