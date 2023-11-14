# clean-mode.el
A Concurrent Clean (or just Clean) language mode for GNU Emacs.
# Usage
Insert the following into your `init.el`:
```elisp
(require 'clean-mode)
(add-to-list 'auto-mode-alist '(".icl" . clean-mode))
(add-to-list 'auto-mode-alist '(".dcl" . clean-mode))
```

# Feature list (work in progress)
- [x] function signatures
- [x] constants, string literals, numbers
- [x] select keywords to not highlight *too much*
- [x] basic types, tuple types (see note 1), list types.
- [x] function types (`a -> a` in a signature)
- [x] by-case function definitions with variable highlighting
- [x] until-end-of-line lambda functions
- [ ] algebraic data types
- [ ] bracketed lambda functions (`(\x -> ...)`)
- [ ] List comprehensions (do we really need this?)
- [ ] Anything not already listed here, basically...

(*note 1*) Tuple types work, but both the types and tuple
values are capped at a maximum of 3 tuples, on a maximum of
3 levels of nesting, for now.
