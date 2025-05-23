" Helper function to get all available colorschemes
function! s:GetAllColorschemes()
  let colors = []
  let checked_paths = {}

  " Get colorschemes from all runtimepath directories
  for rtp_dir in split(&runtimepath, ',')
    let colors_dir = rtp_dir . '/colors'
    if isdirectory(colors_dir)
      let abs_colors_dir = resolve(fnamemodify(colors_dir, ':p'))
      if !has_key(checked_paths, abs_colors_dir)
        let checked_paths[abs_colors_dir] = 1
        
        " Use glob() instead of globpath() for better reliability
        let scheme_files = glob(colors_dir . '/*.vim', 0, 1)
        for fpath in scheme_files
          if filereadable(fpath)
            let scheme_name = fnamemodify(fpath, ':t:r')
            " Only add non-empty names
            if !empty(scheme_name) && scheme_name !~ '^\s*$'
              call add(colors, scheme_name)
            endif
          endif
        endfor
      endif
    endif
  endfor

  " Remove duplicates and sort
  if !empty(colors)
    " Convert to dictionary to remove duplicates efficiently
    let unique_colors = {}
    for color in colors
      let unique_colors[color] = 1
    endfor
    let final_colors = sort(keys(unique_colors))
  else
    let final_colors = []
  endif
  
  " Debug output (uncomment to see what was found)
  " echomsg "Found " . len(final_colors) . " colorschemes: " . string(final_colors[:9]) . (len(final_colors) > 10 ? "..." : "")
  
  return final_colors
endfunction

" Test if a colorscheme can be loaded
function! s:CanLoadColorscheme(name)
  if empty(a:name)
    return 0
  endif
  
  " Save current state
  let saved_colors_name = get(g:, 'colors_name', '')
  let saved_background = &background
  
  try
    " Attempt to load the colorscheme silently
    execute 'silent! colorscheme' a:name
    let success = (get(g:, 'colors_name', '') ==# a:name)
    
    " Restore previous colorscheme if the test failed
    if !success && !empty(saved_colors_name)
      execute 'silent! colorscheme' saved_colors_name
    endif
    let &background = saved_background
    
    return success
  catch
    " Restore on any error
    if !empty(saved_colors_name)
      try
        execute 'silent! colorscheme' saved_colors_name
        let &background = saved_background
      catch
        " If we can't restore, at least reset colors_name
        let g:colors_name = saved_colors_name
      endtry
    endif
    return 0
  endtry
endfunction

function! CycleColorschemes()
  let colorschemes = s:GetAllColorschemes()

  if empty(colorschemes)
    echohl ErrorMsg
    echomsg "No colorschemes found! Check your runtimepath."
    echohl None
    return
  endif

  let current_name = get(g:, 'colors_name', '')
  let current_idx = index(colorschemes, current_name)
  
  " Start from next position
  let start_idx = current_idx >= 0 ? (current_idx + 1) % len(colorschemes) : 0
  let tried_count = 0
  let max_tries = len(colorschemes)
  
  " Try to find a working colorscheme
  let idx = start_idx
  while tried_count < max_tries
    let scheme_name = colorschemes[idx]
    
    if s:CanLoadColorscheme(scheme_name)
      try
        execute 'colorscheme' scheme_name
        redraw
        echohl MoreMsg
        echomsg "Colorscheme: " . scheme_name . " (" . (idx + 1) . "/" . len(colorschemes) . ")"
        echohl None
        return
      catch
        " Continue to next if this one fails
      endtry
    endif
    
    let idx = (idx + 1) % len(colorschemes)
    let tried_count += 1
  endwhile
  
  echohl WarningMsg
  echomsg "Could not load any colorscheme from " . len(colorschemes) . " available schemes"
  echohl None
endfunction

function! CycleColorschemesBackwards()
  let colorschemes = s:GetAllColorschemes()

  if empty(colorschemes)
    echohl ErrorMsg
    echomsg "No colorschemes found! Check your runtimepath."
    echohl None
    return
  endif

  let current_name = get(g:, 'colors_name', '')
  let current_idx = index(colorschemes, current_name)
  
  " Start from previous position
  let start_idx = current_idx >= 0 ? (current_idx - 1 + len(colorschemes)) % len(colorschemes) : len(colorschemes) - 1
  let tried_count = 0
  let max_tries = len(colorschemes)
  
  " Try to find a working colorscheme
  let idx = start_idx
  while tried_count < max_tries
    let scheme_name = colorschemes[idx]
    
    if s:CanLoadColorscheme(scheme_name)
      try
        execute 'colorscheme' scheme_name
        redraw
        echohl MoreMsg
        echomsg "Colorscheme: " . scheme_name . " (" . (idx + 1) . "/" . len(colorschemes) . ")"
        echohl None
        return
      catch
        " Continue to next if this one fails
      endtry
    endif
    
    let idx = (idx - 1 + len(colorschemes)) % len(colorschemes)
    let tried_count += 1
  endwhile
  
  echohl WarningMsg
  echomsg "Could not load any colorscheme from " . len(colorschemes) . " available schemes"
  echohl None
endfunction

" Key mappings
nnoremap <silent> <C-F10> :call CycleColorschemes()<CR>
nnoremap <silent> <C-F9> :call CycleColorschemesBackwards()<CR>

" Optional: Command to list all available colorschemes
command! ListColorschemes echo join(s:GetAllColorschemes(), ', ')

" Optional: Command to test if current colorscheme loads properly
command! TestCurrentColorscheme echo s:CanLoadColorscheme(get(g:, 'colors_name', '')) ? 'Current colorscheme loads OK' : 'Current colorscheme has issues'
