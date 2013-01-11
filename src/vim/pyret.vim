" Vim syntax file
" Language: Pyret
" Maintainer: Joe Gibbs Politz (joe@cs.brown.edu)
" Latest Revision: 10 January 2012

if exists("b:current_syntax")
  finish
endif

syn keyword basic def fun end cond with sharing data do
syn match op '|'
syn match op ':'
syn match op '->'
syn match op '=>'

syn match comment '\#.*$'

hi def link comment Comment
hi def link op PreProc
hi def link basic Label

