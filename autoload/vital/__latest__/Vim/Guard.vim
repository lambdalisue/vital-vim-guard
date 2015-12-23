let s:save_cpo = &cpo
set cpo&vim

" Use a Funcref as a special term UNDEFINED
function! s:undefined() abort
  return 'undefined'
endfunction
let s:UNDEFINED = function('s:undefined')

function! s:_vital_loaded(V) abort " {{{
endfunction " }}}
function! s:_vital_depends() abort " {{{
  return []
endfunction " }}}

function! s:_throw(msg) abort " {{{
  throw printf('vital: Vim.Guard: %s', a:msg)
endfunction " }}}

let s:option = {}
function! s:_new_option(name) abort " {{{
  if a:name !~# '^&'
    call s:_throw(printf(
          \'An option name "%s" requires to be started from "&"', a:name
          \))
  elseif !exists(a:name)
    call s:_throw(printf(
          \'An option name "%s" does not exist', a:name
          \))
  endif
  let option = copy(s:option)
  let option.name = a:name
  let option.value = eval(a:name)
  lockvar option.name
  lockvar option.value
  return option
endfunction " }}}
function! s:option.restore() abort " {{{
  execute printf('let %s = %s', self.name, string(self.value))
endfunction " }}}

let s:variable = {}
function! s:_new_variable(name, ...) abort " {{{
  if a:0 == 0
    let m = matchlist(a:name, '^\([bwtg]:\)\(.*\)$')
    if empty(m)
      call s:_throw(printf(
            \ join([
            \   'An variable name "%s" requires to start from b:, w:, t:, or g:',
            \   'while no {namespace} is specified',
            \ ]),
            \ a:name,
            \))
    endif
    let [prefix, name] = m[1 : 2]
    let namespace = eval(prefix)
  else
    let name = a:name
    let namespace = a:1
  endif
  let variable = copy(s:variable)
  let variable.name = name
  let variable.value = get(namespace, name, s:UNDEFINED)
  let variable._namespace = namespace
  lockvar variable.name
  lockvar variable.value
  return variable
endfunction " }}}
function! s:variable.restore() abort " {{{
  " unlet the variable to prevent variable type mis-match in case
  silent! unlet! self._namespace[self.name]
  if type(self.value) == type(s:UNDEFINED) && self.value == s:UNDEFINED
    " do nothing, leave the variable as undefined
  else
    let self._namespace[self.name] = self.value
  endif
endfunction " }}}

let s:guard = {}
function! s:new(...) abort " {{{
  let resources = []
  for meta in a:000
    if type(meta) == type([])
      call add(resources, call('s:_new_variable', meta))
    elseif type(meta) == type('')
      if meta =~# '^[bwtgls]:'
        call add(resources, s:_new_variable(meta))
      elseif meta =~# '^&'
        call add(resources, s:_new_option(meta))
      else
        call add(resources, s:_new_option('&' . meta))
      endif
    endif
    unlet meta
  endfor
  let guard = copy(s:guard)
  let guard._resources = resources
  return guard
endfunction " }}}
function! s:guard.restore() abort " {{{
  for resource in self._resources
    call resource.restore()
  endfor
endfunction " }}}

let &cpo = s:save_cpo
unlet! s:save_cpo
" vim:set et ts=2 sts=2 sw=2 tw=0 fdm=marker:
