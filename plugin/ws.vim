scriptencoding utf-8
if exists('g:loaded_ws')
  finish
endif
let g:loaded_ws = 1
let s:save_cpo = &cpo
set cpo&vim


command! -bar -nargs=* -complete=file WSSave
\         call ws#save(<q-args>)
command! -bar -nargs=* -complete=customlist,ws#complete WSOpen
\         call ws#open(<q-args>)
command! -bar -nargs=+ -complete=customlist,ws#complete WSEdit
\         call ws#edit(<q-args>)


let &cpo = s:save_cpo
