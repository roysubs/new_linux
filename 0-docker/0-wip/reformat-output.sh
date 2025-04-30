# This script reformats text copied from web lists.
# It removes the blank line immediately following a title line (defined as a single word on a line)
# and inserts a blank line before the title line (if it's not the very first item).
# Other blank lines (like separators between items) are preserved.

# State definitions:
# NORMAL: Processing regular lines (headers, details, separator blanks).
# SAW_TITLE: Just saw a line that looks like a title (it's buffered). Expecting a blank line or a detail next.
# SAW_BLANK_AFTER_TITLE: Just saw a blank line immediately after a line that looked like a title. Expecting details next.

BEGIN { state = "NORMAL" }

{
    current_line = $0 # Store the current line

    # Define a title line: a non-blank line consisting ONLY of letters, numbers, hyphens, and underscores.
    is_title = (current_line ~ /^[a-zA-Z0-9_-]+$/)

    # Check if the current line is blank
    is_blank = (current_line ~ /^\s*$/)

    # --- Rule Evaluation based on Current State ---

    if (state == "NORMAL") {
        if (is_title) {
            # Found a Title line. Buffer it and change state.
            buffered_title = current_line # Store the title line
            title_nr = NR # Store the original line number of the title
            state = "SAW_TITLE"
            next # Do not print the title line yet
        } else {
            # Not a Title line (initial header, detail, separator blank, etc.). Print it and stay in NORMAL state.
            print current_line
            state = "NORMAL" # Stay normal
            next
        }
    } else if (state == "SAW_TITLE") {
        # Just saw a Title line (it's in buffered_title). Expecting the line immediately after it.
        if (is_blank) {
            # Saw Title \n Blank. This is the sequence to transform (suppress the blank).
            state = "SAW_BLANK_AFTER_TITLE" # Move to the next state
            next # Suppress printing the current blank line
        } else {
            # Saw Title \n Non-blank (e.g., a detail line immediately followed the title, or two titles in a row).
            # This means the blank line after the title was missing.
            # Print the buffered title (with leading blank if needed).
            # Print blank before the buffered title if it was not the very first line of the file (check its original NR).
            if (title_nr > 1) { print "" }
            print buffered_title
            # Now process the current line (which is non-blank) by re-evaluating it in NORMAL state.
            state = "NORMAL"
            # Fall through to the NORMAL state logic using the current line ($0).
            # The 'next' is removed here to allow the current line to be processed by the next block.
        }
    } else if (state == "SAW_BLANK_AFTER_TITLE") {
        # Just saw a blank line immediately after a Title (Title was in buffered_title).
        # The current line is what follows the suppressed blank (should be details or the next item).
        # Print the buffered title (with leading blank if needed).
        if (title_nr > 1) { print "" }
        print buffered_title

        # Now process the current line (which is after the suppressed blank) by re-evaluating it in NORMAL state.
        state = "NORMAL"
        # Fall through to the NORMAL state logic using the current line ($0).
        # The 'next' is removed here to allow the current line to be processed by the next block.
    }

    # If we fall through from SAW_TITLE or SAW_BLANK_AFTER_TITLE,
    # the current line ($0) needs to be processed in NORMAL state.
    # This happens if the state was changed to "NORMAL" and 'next' was not called.
    # If the state was NORMAL and 'next' was called, this block isn't reached for this line.
    # If the state was SAW_TITLE or SAW_BLANK_AFTER_TITLE and 'next' was NOT called,
    # the current line needs processing here based on the state becoming NORMAL.

    # Check if the current line looks like a Title *after* potential state changes
    is_title_after = ($0 !~ /^\s*$/ && $0 ~ /^[a-zA-Z0-9_-]+$/) # Check the raw $0 again if needed, or rely on state.

    # A simpler way in awk after a fallthrough is to jump back or explicitly process.
    # Let's use the 'next' strategically to avoid fallthrough complications.

    # Revised State transitions with explicit printing:

    # State 0: Normal.
    #   If current is Title: Buffer title, go to 1. Next.
    #   Else: Print current. Stay 0. Next.
    # State 1: Saw Title (in buffer).
    #   If current is Blank: Go to 2. Next.
    #   Else: Print buffered title (with blank if needed). Go to 0. Process current line in 0 state.
    # State 2: Saw Blank after Title.
    #   Print buffered title (with blank if needed). Go to 0. Process current line in 0 state.

    # Implementation refined:

    if (state == "NORMAL") {
        if (is_title) {
            buffered_title = current_line; title_nr = NR; state = "SAW_TITLE"; next;
        } else {
            print current_line; state = "NORMAL"; next;
        }
    } else if (state == "SAW_TITLE") {
        if (is_blank) {
            state = "SAW_BLANK_AFTER_TITLE"; next; # Suppress blank
        } else {
            # Title \n Non-blank. Print buffered title (with blank if needed)
            if (title_nr > 1) { print "" }
            print buffered_title
            # Fall through to process current_line in NORMAL state
            state = "NORMAL"; # Set state for fallthrough
            # (Do not next)
        }
    } else if (state == "SAW_BLANK_AFTER_TITLE") {
        # Saw Title \n Blank. Print buffered title (with blank if needed)
        if (title_nr > 1) { print "" }
        print buffered_title
        # Fall through to process current_line in NORMAL state
        state = "NORMAL"; # Set state for fallthrough
        # (Do not next)
    }

    # --- Process current line after fallthrough from SAW_TITLE or SAW_BLANK_AFTER_TITLE ---
    # This block is only reached if 'next' was NOT called in the state transitions above.
    # This happens when state transitions from SAW_TITLE or SAW_BLANK_AFTER_TITLE to NORMAL,
    # and the current line ($0) needs to be printed *after* the buffered title.

    if (state == "NORMAL") { # Check state is indeed NORMAL (should be after fallthrough)
        # Process the current line ($0) as if it were just read in NORMAL state.
        # This means if *this* current line ($0) is a Title, it should start a new sequence.
        # But since we just printed the previous buffered title, the context is different.
        # The previous line *printed* was the buffered title.
        # The current line is $0.

        # Let's simplify the fallthrough logic. If we fall through, we print the current line.
        # If that current line *itself* is a title, it will be buffered in the *next* iteration.
        print $0
        # State is already set to NORMAL
        # (No next here)
    }
    # Note: If state is SAW_TITLE or SAW_BLANK_AFTER_TITLE here, it means the logic above didn't work as expected.
    # The transitions and 'next' calls should prevent reaching here if the state is not NORMAL.
}

# --- END block ---
END {
    # If we finished the file in SAW_TITLE state (last line was a title not followed by blank)
    if (state == "SAW_TITLE") {
        # Print the last buffered title (with leading blank if needed).
        if (title_nr > 1) { print "" }
        print buffered_title
    }
    # If we finished in SAW_BLANK_AFTER_TITLE state (last lines were Title\nBlank)
    # Print the buffered title (with leading blank if needed).
    if (state == "SAW_BLANK_AFTER_TITLE") {
         if (title_nr > 1) { print "" }
         print buffered_title
    }
}
