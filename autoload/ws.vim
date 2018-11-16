scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim


let g:ws#path = get(g:, 'ws#path', '~/.ws')
let g:ws#open_command = get(g:, 'ws#open_command', 'new')
let g:ws#edit_command = get(g:, 'ws#edit_command', 'vsplit')
let g:ws#script_template = get(g:, 'ws#script_template', ['tabedit', 'lcd {{dir}}'])


function! ws#save(dir) abort
  let dir = a:dir ==# '' ? getcwd() : a:dir
  let dir = s:remove_trail_slashes(dir)
  if !isdirectory(dir)
    echohl ErrorMsg
    echomsg printf("ws: '%s' is not directory", dir)
    echohl None
    return
  endif
  " Show error if a script is already created
  let ws = s:fullpath(dir)
  let path = s:get_script_path(ws)
  if filereadable(path)
    echohl ErrorMsg
    echomsg printf("ws: already created '%s'", ws)
    echohl None
    return
  endif
  " Create a script under wspath
  call s:mkpath(s:parent_dir(path))
  call writefile(s:generate_script(dir), path)
  echom "ws: saved '" . ws . "'"
  " Update ws buffer if it is already opened
  call s:update_ws_buffer()
endfunction

" e.g.)
" ws = '/home/tyru/.vimrc'
" it returns '~/.ws/home/tyru/.vimrc'
function! s:get_script_path(ws) abort
  return expand(s:path_join(g:ws#path, a:ws . '.vim'))
endfunction

let s:pathsep = fnamemodify('.', ':p')[-1 :]

function! s:path_join(dir, basename) abort
  let dir = substitute(a:dir, '[/\\]\+$', '', '')
  let basename = substitute(a:basename, '^[/\\]\+', '', '')
  return dir . s:pathsep . basename
endfunction

function! s:generate_script(dir) abort
  let param = {'dir': a:dir}
  return map(deepcopy(g:ws#script_template), {
  \ _,line -> substitute(
  \   line, '{{\(\w\+\)}}', '\=get(' . string(param) . ', submatch(1), submatch(1))', 'g'
  \ )
  \})
endfunction

function! ws#open(dir) abort
  " If no arguments are supplied, list saved dirs in buffer
  if a:dir ==# ''
    call s:create_ws_buffer()
    return
  endif
  " Or open given workspace
  call s:open_workspace(s:fullpath(a:dir))
endfunction

function! ws#edit(dir) abort
  execute g:ws#edit_command s:get_script_path(s:fullpath(a:dir))
endfunction

function! s:open_workspace(ws) abort
  let path = s:get_script_path(a:ws)
  if !filereadable(path)
      echohl ErrorMsg
      echomsg printf("ws: no such workspace '%s'", path)
      echohl None
      return
  endif
  call s:close_ws_buffer()
  source `=path`
endfunction

function! s:get_saved_workspaces() abort
  let wslist = []
  let wspath = expand(g:ws#path)
  for path in glob(wspath . '/**/*.vim', 1, 1)
    if !filereadable(path)
      continue
    endif
    let path = substitute(path, '^\V' . wspath, '', '')
    let path = substitute(path, '\.vim$', '', '')
    call add(wslist, path)
  endfor
  return wslist
endfunction

function! s:create_ws_buffer() abort
  let winnr = s:find_ws_buffer().winnr
  if winnr !=# 0
    call win_gotoid(win_getid(winnr))
    echohl WarningMsg
    echomsg 'ws: buffer is already opened'
    echohl None
    return
  endif
  let wslist = s:get_saved_workspaces()
  if empty(wslist)
    echohl ErrorMsg
    echomsg 'ws: no workspaces are saved'
    echohl None
    return
  endif
  execute g:ws#open_command
  call setline(1, wslist)
  nnoremap <buffer><nowait> d    :<C-u>call <SID>delete_script(getline('.'))<CR>
  nnoremap <buffer><nowait> <CR> :<C-u>call <SID>open_workspace(getline('.'))<CR>
  setlocal buftype=nofile readonly nomodifiable
  setlocal filetype=ws-buffer
endfunction

function! s:delete_script(ws) abort
  let path = s:get_script_path(a:ws)
  if !filereadable(path)
    echohl ErrorMsg
    echomsg printf("ws: no such script '%s'", path)
    echohl None
    return
  endif
  let msg = printf("Really delete workspace '%s'? [y/n]: ", a:ws)
  if input(msg) !~? '^y'
    redraw
    echon ''
    return
  endif
  " Delete a script file and parent empty dirs
  if delete(path) ==# 0
    call s:rmpath(path)
    redraw
    echomsg printf("ws: deleted workspace '%s'", path)
  endif
  call s:update_ws_buffer()
endfunction

" Find ws buffer in current tab page
function! s:find_ws_buffer() abort
  for winnr in range(1, winnr('$'))
    if getwinvar(winnr, '&filetype') ==# 'ws-buffer'
      return {'winnr': winnr, 'bufnr': winbufnr(winnr)}
    endif
  endfor
  return {'winnr': 0, 'bufnr': 0}
endfunction

function! s:update_ws_buffer() abort
  " Find ws buffer in tab page
  let bufnr = s:find_ws_buffer().bufnr
  if bufnr ==# 0
    return
  endif
  " If no saved workspaces, show error and close ws buffer
  let wslist = s:get_saved_workspaces()
  if empty(wslist)
    echohl ErrorMsg
    echomsg 'ws: no workspaces are saved'
    echohl None
    call s:close_ws_buffer()
    return
  endif
  " Update lines
  setlocal noreadonly modifiable
  silent %delete _
  call setbufline(bufnr, 1, wslist)
  setlocal readonly nomodifiable
endfunction

function! s:close_ws_buffer() abort
  let winid = win_getid(s:find_ws_buffer().winnr)
  if winid ==# 0
    return 0
  endif
  let last = win_getid()
  try
    if win_gotoid(winid)
      close
    endif
    return 1
  finally
    call win_gotoid(last)
  endtry
endfunction

function! s:update_ws_buffer() abort
  " Find ws buffer
  let bufnr = s:find_ws_buffer().bufnr
  if bufnr ==# 0
    return
  endif
  " If no saved workspaces, show error and close ws buffer
  let wslist = s:get_saved_workspaces()
  if empty(wslist)
    echohl ErrorMsg
    echomsg 'ws: no workspaces are saved'
    echohl None
    let last = win_getid()
    try
      close
    finally
      call win_gotoid(last)
    endtry
    return
  endif
  " Update lines
  setlocal noreadonly modifiable
  silent %delete _
  call setbufline(bufnr, 1, wslist)
  setlocal readonly nomodifiable
endfunction

function! ws#complete(arglead, cmdline, pos) abort
  let pattern = substitute(a:cmdline, '\v^\s*WS(Open|Edit)\s*', '', '')
  let wslist = s:get_saved_workspaces()
  if pattern ==# ''
    return wslist
  endif
  return filter(wslist, {_,ws -> ws =~# pattern})
endfunction


if has('patch-8.0.1708')
  function! s:mkpath(path) abort
    call mkdir(a:path, 'p')
  endfunction
else
  function! s:mkpath(path) abort
    silent! call mkdir(a:path, 'p')
  endfunction
endif

function! s:rmpath(path) abort
  return empty(glob(a:path . '/*', 1, 1)) &&
  \      delete(a:path, 'd') ==# 0 &&
  \      s:rmpath(s:parent_dir(a:path))
endfunction

function! s:fullpath(path) abort
  return s:remove_trail_slashes(fnamemodify(a:path, ':p'))
endfunction

function! s:parent_dir(path) abort
  return fnamemodify(s:remove_trail_slashes(a:path), ':h')
endfunction

function! s:remove_trail_slashes(path) abort
  return substitute(a:path, '[/\\]\+$', '', '')
endfunction

let &cpo = s:save_cpo
