;;; clean-mode.el --- Major mode for editing clean language files.;; -*- lexical-binding: t -*-

;; Copyright 2023, Sofia Cerasuoli

;; Author: Sofia Cerasuoli (sofiacerasuoli@gmail.com)
;; Version: 0.1
;; Created: 12/11/2023 (dd/mm/yyyy)
;; Keywords: languages, clean
;; Homepage: https://github.com/switchaxe/clean-mode.el

;; You can redistribute this program and/or modify it
;; under the terms of the GNU General Public License version 3.

;;; Description:
;;
;; This mode adds support to Emacs for writing software using
;; the Clean programming language, available at:
;;
;;     https://clean-lang.org
;;
;;

(require 'cl-lib)
(eval-when-compile
  (require 'rx))
(defconst clean-mode-version-number "0.1"
  "Clean Mode version number.")

;; define several category of keywords
(defconst clean-constants
  `("False" "True" "0"
    "1" "2" "3" "4" "5"
    "6" "7" "8" "9"))
(defconst clean-preprocessors '("include"))

(defconst clean-keywords '("if" "then" "else" "return"
			   "in" "let" "do" "otherwise"
			   "where" "from" "definition"
			   "implementation" "foreign"
			   "import" "module" "system"
			   "case" "code" "of" "with"
			   "infixr" "export" "infix"
			   "class" "derive" "special"
			   "instance" "infixl"))


;; some regexes to aid in highlighting
(defconst clean-id-sig
  '(+ (| ?_ ?` (syntax w) (any "0-9"))))

(defconst clean-number-sig
  '(: symbol-start "-" (+ (any "0-9")) symbol-end))

(defconst clean-types '("String" "Int" "Real"
			"Bool" "Char" "World"))


;; shamelessly copied from the emacs wiki
(defun n-tuple-rx (n element)
  `(:
    "("
    ,element
    ,@(mapcar (lambda (_) `(: ?,
			      (* (any space))
			      ,element))
              (number-sequence 1 (- n 1)))
    ")"))

;; tuples can consist of 2 or 3 elements on 2 levels of nesting.
;; This is a regex limitation, since by how we do it, any inner
;; nesting level added is going to add WAY more nodes to the regex.
;; This is NOT ideal, and in any case this should be good for most
;; use-cases.

(rx-define n-tuple-3 (element)
  (| (eval (n-tuple-rx 2 'element))
     (eval (n-tuple-rx 3 'element))))

(defconst clean-tuple-type-sig
  `(n-tuple-3 (| ,clean-id-sig
		 (n-tuple-3 (| ,clean-id-sig
			       (n-tuple-3 ,clean-id-sig))))))

(defconst clean-list-type-sig
  `(: "[" ,clean-id-sig "]"))

;; type signature of Clean function types as parameters.
;; F :: (Int -> Int) -> Bool
;;      ^          ^
;;fun start      fun end
(defconst clean-function-type-sig
  `(: "("
      (* (any space))
      ,clean-id-sig
      (* (any space))
      "->"
      (* (any space))
      ,clean-id-sig
      (* (any space))
      ")"))

(defconst clean-tuple-of-lists-type-sig
  `(n-tuple-3 (| ,clean-id-sig ,clean-list-type-sig)))


(defconst clean-tuple-list-type-sig
  `(: "[" ,clean-tuple-type-sig "]"))

(defconst clean-tuple-values
  `(n-tuple-3 (| ,clean-id-sig
		 (n-tuple-3 (| ,clean-id-sig
			       (n-tuple-3 ,clean-id-sig))))))


(defconst clean-list-values
  `(: "["
      (? (| (: (| ,clean-tuple-values
		  (group-n 1 ,clean-id-sig))
	       (* (any blank))
	       (? (: ?:
		     (* (any blank))
		     (group-n 2 ,clean-id-sig))))
	    (group-n 3 ,clean-id-sig)))
      "]"))

(defconst clean-values-sig
  `(+ (| ,clean-list-values
	 ,clean-tuple-values
	 ,clean-id-sig)))

(defconst clean-adt-type-sig
  `(: "("
    (* (any space))
    ,clean-id-sig
    (* (any space))
    ,clean-id-sig
    (* (any space))
    ")"))

(defconst clean-type-sig
  `(| ,clean-id-sig ,clean-tuple-type-sig ,clean-list-type-sig ,clean-adt-type-sig))

(defconst clean-comp-type-sig
  `(| ,clean-tuple-list-type-sig
      ,clean-tuple-of-lists-type-sig
      ,clean-function-type-sig))

(defconst clean-def-by-cases-sig
  `(: bol
      (group-n 9 ,clean-id-sig)
      (* (any space))
      (+ (: ,clean-values-sig
	    (* (any space))))
      (* (any space))
      "="
      (* nonl)
      eol))

(defconst clean-def-no-args
  `(: bol (group-n 1 ,clean-id-sig) (* (any space)) "=" (* nonl) eol))

(defconst clean-lambda-function-eol-sig
  `(: "\\"
      (+ (: ,clean-values-sig
	    (* (any space))))
      (* (any space))
      "->"
      (* (any space))
      (* nonl)))

(defconst clean-inline-comment-sig
  '(: "//" (* nonl)))

;;; TODO: Algebraic types
;;; TODO: lambdas in parentheses
;;; TODO: list comprehensions? any use in
;;;       highlighting them?

(defconst clean--font-lock-defaults
  `((;; inline comments
    (,(rx-to-string clean-inline-comment-sig)
     (0 font-lock-comment-face))
    ;; lambda functions (until eol)
     (,(rx-to-string clean-lambda-function-eol-sig)
      (0 '((t :underline (:color "DarkBlue")))
	 prepend t))
     (,(rx-to-string clean-number-sig)
      0 font-lock-constant-face)
     (,(rx-to-string `(: symbol-start
			 (group (| ,@clean-constants))
			 symbol-end))
      1 'font-lock-constant-face)
     (,(rx-to-string `(: symbol-start
			 (group (| ,@clean-types))
			 symbol-end))
      1 'font-lock-type-face)
     (,(rx-to-string `(: symbol-start
			 (group (| ,@clean-keywords))
			 symbol-end))
      1 'font-lock-keyword-face)
     ;; function names in definitions with no args.
     ;; used for e.g. the Start function.
     (,(rx-to-string clean-def-no-args)
      (1 font-lock-function-name-face))
     ;; function names in "by case" definitions
     (,(rx-to-string clean-def-by-cases-sig)
      (9 font-lock-function-name-face)
      (1 font-lock-variable-name-face nil t)
      (2 font-lock-variable-name-face nil t)
      (3 font-lock-variable-name-face nil t))
     ;; compound/basic input, basic output
     (,(rx-to-string `(: bol
			 (group-n 9 ,clean-id-sig)
			 (* (any space))
			 "::"
			 (* (any space))
			 (+ (: (| ,clean-type-sig
				  ,clean-comp-type-sig)
			       (* (any space))))
			 (* (any space))
			 "->"
			 (* (any space))
			 ,clean-type-sig
			 eol))
      9 'font-lock-function-name-face)
     ;; basic/compound input, compound output
     (,(rx-to-string `(: bol
			 (group-n 9 ,clean-id-sig)
			 (* (any space))
			 "::"
			 (* (any space))
			 (+ (: (| ,clean-type-sig
				  ,clean-comp-type-sig)
			       (* (any space))))
			 (* (any space))
			 "->"
			 (* (any space))
			 ,clean-comp-type-sig
			 eol))
      9 'font-lock-function-name-face))))

(defvar clean-mode-syntax-table nil "Syntax table for `clean-mode'.")


;; the following syntax table is NOT MINE but it's proudly stolen from
;; https://github.com/cleanlang/clean-mode
(setq clean-mode-syntax-table
      (let ( (synTable (make-syntax-table)))
        ;; comment style “/* … */”
        (modify-syntax-entry ?\/ ". 14" synTable)
        (modify-syntax-entry ?* ". 23" synTable)
        synTable))

;;;###autoload
(define-derived-mode clean-mode prog-mode "clean"
  "clean-mode is a major mode for editing clean language files."
  (setq font-lock-defaults clean--font-lock-defaults)

  (set-syntax-table clean-mode-syntax-table)
  (setq-local comment-start "/*")
  (setq-local comment-start-skip "/\\*+[ \t]*")
  (setq-local comment-end "*\/")
  (setq-local comment-end-skip "[ \t]*\\*+/"))

(provide 'clean-mode)

;;; clean-mode.el ends here
