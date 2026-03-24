;;; genmark-mode.el --- Major mode for Genmark genealogy files -*- lexical-binding: t; -*-

;; Author: Drew Herron
;; URL: https://github.com/drewherron/genmark
;; Version: 0.1.0
;; Keywords: languages, genealogy
;; Package-Requires: ((emacs "25.1"))

;;; Commentary:

;; Major mode for editing Genmark (.gmd) files -- a plain-text genealogy
;; language that compiles to GEDCOM 5.5.1.
;;
;; Features:
;;   - Syntax highlighting for all Genmark constructs
;;   - Block folding with Tab / Shift-Tab (org-mode style)
;;   - Auto-indentation
;;   - Comment support (// and /* */)
;;
;; Installation:
;;
;;   Add to your init file:
;;
;;     (add-to-list 'load-path "/path/to/genmark/editor/emacs")
;;     (require 'genmark-mode)
;;
;;   Or with use-package:
;;
;;     (use-package genmark-mode
;;       :load-path "/path/to/genmark/editor/emacs")

;;; Code:

(require 'outline)

;; --- Customization ---

(defgroup genmark nil
  "Major mode for editing Genmark (.gmd) files."
  :group 'languages
  :prefix "genmark-")

(defcustom genmark-indent-width 2
  "Number of spaces for indentation in Genmark files."
  :type 'integer
  :group 'genmark)

(defcustom genmark-child-indent-width 4
  "Number of spaces for child (>) lines under a marriage."
  :type 'integer
  :group 'genmark)

;; --- Syntax Table ---

(defvar genmark-mode-syntax-table
  (let ((st (make-syntax-table)))
    ;; // comments
    (modify-syntax-entry ?/ ". 124" st)
    (modify-syntax-entry ?* ". 23b" st)
    (modify-syntax-entry ?\n ">" st)
    ;; Brackets are punctuation, not paired
    (modify-syntax-entry ?\[ "(]" st)
    (modify-syntax-entry ?\] ")[" st)
    ;; Underscore is word constituent (for IDs like john_doe)
    (modify-syntax-entry ?_ "w" st)
    st)
  "Syntax table for `genmark-mode'.")

;; --- Syntax Propertize ---

(defun genmark-syntax-propertize (start end)
  "Prevent :// in URLs from being treated as a comment start."
  (goto-char start)
  (while (re-search-forward "://" end t)
    (put-text-property (- (point) 2) (- (point) 1)
                       'syntax-table (string-to-syntax "."))))

;; --- Font Lock (Syntax Highlighting) ---

(defvar genmark-person-field-tags
  '("aka" "sex" "b" "d" "chr" "bap" "bur" "crm"
    "imm" "emi" "nat" "res" "cen" "occ" "mil" "evt"
    "m" "div" "parents" "maybe" "note" "src")
  "Person-level field tags in Genmark.")

(defvar genmark-source-field-tags
  '("title" "author" "pub" "url" "repo" "page" "note")
  "Source definition field tags in Genmark.")

(defvar genmark-all-field-tags
  (append genmark-person-field-tags genmark-source-field-tags)
  "All recognized field tags.")

(defvar genmark-field-tags-regexp
  (concat "^\\s-+\\("
          (regexp-opt genmark-all-field-tags t)
          "\\):")
  "Regexp matching indented field tags.")

(defvar genmark-font-lock-keywords
  `(
    ;; Source definition header: source [id]
    ("^\\(source\\)\\s-+\\(\\[\\w+\\]\\)"
     (1 font-lock-keyword-face)
     (2 font-lock-variable-name-face))

    ;; Standalone union header: [id] + [id]
    ("^\\(\\[\\w+\\]\\)\\s-+\\(\\+\\)\\s-+\\(\\[\\w+\\]\\)"
     (1 font-lock-variable-name-face)
     (2 font-lock-keyword-face)
     (3 font-lock-variable-name-face))

    ;; Person header: Name [id]
    ("^\\([A-Z].*?\\)\\s-+\\(\\[\\w+\\]\\)\\s-*$"
     (1 font-lock-function-name-face)
     (2 font-lock-variable-name-face))

    ;; Field tags (indented)
    (,genmark-field-tags-regexp
     (1 font-lock-keyword-face))

    ;; Child marker >
    ("^\\s-+\\(>\\)" (1 font-lock-builtin-face))

    ;; ID references [word] (not [src: ...])
    ("\\[\\(\\w+\\)\\]" (1 font-lock-variable-name-face))

    ;; Inline source citations [src: ...]
    ("\\(\\[src:[^]]*\\]\\)" (1 font-lock-doc-face))

    ;; @ place separator
    ("\\s-+\\(@\\)\\s-+" (1 font-lock-builtin-face))

    ;; Date modifiers ~ < > and range ..
    ("\\(?:^\\|\\s-\\)\\([~<>]\\)[0-9]" (1 font-lock-type-face))
    ("\\([0-9]+\\.\\.[0-9]+\\)" (1 font-lock-type-face))

    ;; Multi-line note pipe
    ("^\\s-+note:\\s-+\\(|\\)\\s-*$" (1 font-lock-builtin-face))

    ;; d: ? and sex: ? special values
    ("^\\s-+\\(?:d\\|sex\\):\\s-+\\(\\?\\)" (1 font-lock-warning-face))
    )
  "Font-lock keywords for `genmark-mode'.")

;; --- Indentation ---

(defun genmark--previous-nonblank-line-indent ()
  "Return the indentation of the previous non-blank line, or 0."
  (save-excursion
    (forward-line -1)
    (while (and (not (bobp))
                (looking-at-p "^\\s-*$"))
      (forward-line -1))
    (if (looking-at-p "^\\s-*$")
        0
      (current-indentation))))

(defun genmark--previous-nonblank-line-text ()
  "Return the text of the previous non-blank line."
  (save-excursion
    (forward-line -1)
    (while (and (not (bobp))
                (looking-at-p "^\\s-*$"))
      (forward-line -1))
    (buffer-substring-no-properties
     (line-beginning-position) (line-end-position))))

(defun genmark-indent-line ()
  "Indent current line for Genmark mode."
  (interactive)
  (let (indent)
    (save-excursion
      (beginning-of-line)
      (cond
       ;; Top-level constructs stay at column 0
       ((looking-at-p "^\\s-*\\(?:source\\s\\|\\[\\w+\\]\\s-*\\+\\)")
        (setq indent 0))
       ;; Person headers at column 0
       ((looking-at-p "^\\s-*[A-Z].*\\[\\w+\\]")
        (setq indent 0))
       ;; Child lines
       ((looking-at-p "^\\s-*>")
        (setq indent genmark-child-indent-width))
       ;; Blank line: keep at 0
       ((looking-at-p "^\\s-*$")
        (setq indent 0))
       ;; Otherwise: standard field indent
       (t
        (let ((prev-indent (genmark--previous-nonblank-line-indent)))
          (cond
           ;; After a top-level header, indent
           ((= prev-indent 0)
            (let ((prev-text (genmark--previous-nonblank-line-text)))
              (if (or (string-match-p "^source\\s" prev-text)
                      (string-match-p "^\\[\\w+\\]\\s-*\\+" prev-text)
                      (string-match-p "^[A-Z].*\\[\\w+\\]" prev-text))
                  (setq indent genmark-indent-width)
                (setq indent 0))))
           ;; After a marriage line, child lines get extra indent
           (t
            (setq indent prev-indent)))))))
    (when indent
      (let ((offset (- (current-column) (current-indentation))))
        (indent-line-to indent)
        (when (> offset 0)
          (forward-char offset))))))

;; --- Newline behavior ---

(defun genmark-newline ()
  "Insert newline with smart indentation.
After a top-level header or indented field, auto-indent the next line.
On an empty indented line (double Enter), return to column 0."
  (interactive)
  (let ((on-blank-indented (and (looking-at-p "\\s-*$")
                                (save-excursion
                                  (beginning-of-line)
                                  (looking-at-p "^\\s-+$")))))
    (if on-blank-indented
        ;; Double-enter: clear this line and insert newline at col 0
        (progn
          (delete-region (line-beginning-position) (line-end-position))
          (newline))
      ;; Compute indent from current line before inserting newline
      (let* ((line-text (buffer-substring-no-properties
                         (line-beginning-position) (line-end-position)))
             (indent (cond
                      ;; After a top-level header: indent
                      ((string-match-p "^source\\s-" line-text)
                       genmark-indent-width)
                      ((string-match-p "^\\[\\w+\\]\\s-*\\+" line-text)
                       genmark-indent-width)
                      ((string-match-p "^[A-Z].*\\[\\w+\\]" line-text)
                       genmark-indent-width)
                      ;; After an indented line: match its indent
                      ((string-match-p "^\\s-+" line-text)
                       (current-indentation))
                      ;; Default: column 0
                      (t 0))))
        (newline)
        (indent-to indent)))))

;; --- Folding (outline) ---

(defun genmark--outline-level ()
  "Determine outline level for the current line.
Top-level blocks (person, source, union) are level 1."
  1)

(defun genmark-fold-toggle ()
  "Toggle folding of the current top-level block.
If point is not on a heading, fold/unfold the nearest previous heading."
  (interactive)
  (save-excursion
    (beginning-of-line)
    (unless (looking-at-p outline-regexp)
      (outline-previous-heading))
    (if (save-excursion
          (outline-end-of-heading)
          (not (outline-invisible-p (line-end-position))))
        (outline-hide-subtree)
      (outline-show-subtree))))

(defun genmark-fold-all ()
  "Toggle folding of all top-level blocks.
If any block is expanded, collapse all.  Otherwise, expand all."
  (interactive)
  (let ((any-visible nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward outline-regexp nil t)
        (save-excursion
          (outline-end-of-heading)
          (when (not (outline-invisible-p (line-end-position)))
            ;; Check if there is content after the heading
            (forward-line 1)
            (unless (or (eobp)
                        (looking-at-p outline-regexp)
                        (looking-at-p "^\\s-*$"))
              (setq any-visible t))))))
    (if any-visible
        (outline-hide-body)
      (outline-show-all))))

;; --- Block Movement ---

(defun genmark--block-bounds ()
  "Return (BEG . END) of the current top-level block.
A block runs from a header line to just before the next header."
  (save-excursion
    (let (beg end)
      (beginning-of-line)
      (unless (looking-at-p outline-regexp)
        (unless (re-search-backward outline-regexp nil t)
          (user-error "Not inside a block")))
      (setq beg (point))
      (forward-line 1)
      (if (re-search-forward outline-regexp nil t)
          (progn (beginning-of-line) (setq end (point)))
        (setq end (point-max)))
      (cons beg end))))

(defun genmark--block-folded-p (pos)
  "Return non-nil if the block starting at POS is folded."
  (save-excursion
    (goto-char pos)
    (end-of-line)
    (and (< (point) (point-max))
         (outline-invisible-p (1+ (point))))))

(defun genmark-move-block-up ()
  "Move the current top-level block above the previous one."
  (interactive)
  (let* ((cur (genmark--block-bounds))
         (cur-beg (car cur))
         (cur-end (cdr cur))
         (cur-folded (genmark--block-folded-p cur-beg))
         (cur-text (buffer-substring cur-beg cur-end)))
    (save-excursion
      (goto-char cur-beg)
      (unless (re-search-backward outline-regexp nil t)
        (user-error "No block above")))
    (let* ((prev (save-excursion
                   (goto-char cur-beg)
                   (re-search-backward outline-regexp nil t)
                   (genmark--block-bounds)))
           (prev-beg (car prev))
           (prev-folded (genmark--block-folded-p prev-beg))
           (prev-text (buffer-substring prev-beg cur-beg)))
      (delete-region prev-beg cur-end)
      (goto-char prev-beg)
      (insert cur-text prev-text)
      (when cur-folded
        (save-excursion
          (goto-char prev-beg)
          (outline-hide-subtree)))
      (when prev-folded
        (save-excursion
          (goto-char (+ prev-beg (length cur-text)))
          (outline-hide-subtree)))
      (goto-char prev-beg))))

(defun genmark-move-block-down ()
  "Move the current top-level block below the next one."
  (interactive)
  (let* ((cur (genmark--block-bounds))
         (cur-beg (car cur))
         (cur-end (cdr cur))
         (cur-folded (genmark--block-folded-p cur-beg))
         (cur-text (buffer-substring cur-beg cur-end)))
    (unless (save-excursion
              (goto-char cur-end)
              (looking-at-p outline-regexp))
      (user-error "No block below"))
    (let* ((next-beg cur-end)
           (next-folded (genmark--block-folded-p next-beg))
           (next (save-excursion
                   (goto-char next-beg)
                   (genmark--block-bounds)))
           (next-end (cdr next))
           (next-text (buffer-substring next-beg next-end)))
      (delete-region cur-beg next-end)
      (goto-char cur-beg)
      (insert next-text cur-text)
      (when next-folded
        (save-excursion
          (goto-char cur-beg)
          (outline-hide-subtree)))
      (when cur-folded
        (save-excursion
          (goto-char (+ cur-beg (length next-text)))
          (outline-hide-subtree)))
      (goto-char (+ cur-beg (length next-text))))))

;; --- Block Sorting ---

(defun genmark--block-type (text)
  "Return the type of a block: \\='person, \\='source, or \\='union."
  (cond
   ((string-match-p "^source[ \t]" text) 'source)
   ((string-match-p "^\\[\\w+\\][ \t]*\\+" text) 'union)
   (t 'person)))

(defun genmark--collect-blocks ()
  "Collect all blocks in the buffer.
Returns (PREAMBLE . BLOCKS) where PREAMBLE is text before the first
header and BLOCKS is a list of (TYPE TEXT FOLDED) elements."
  (save-excursion
    (goto-char (point-min))
    (let (preamble blocks)
      (if (re-search-forward outline-regexp nil t)
          (progn
            (beginning-of-line)
            (setq preamble (buffer-substring-no-properties
                            (point-min) (point))))
        (setq preamble (buffer-substring-no-properties
                        (point-min) (point-max))))
      (while (and (not (eobp)) (looking-at-p outline-regexp))
        (let ((beg (point)) end text folded)
          (setq folded (genmark--block-folded-p (point)))
          (forward-line 1)
          (if (re-search-forward outline-regexp nil t)
              (progn (beginning-of-line) (setq end (point)))
            (setq end (point-max)))
          (setq text (buffer-substring-no-properties beg end))
          (push (list (genmark--block-type text) text folded) blocks)
          (goto-char end)))
      (cons preamble (nreverse blocks)))))

(defun genmark--extract-birth-date (text)
  "Extract a sortable birth date string from block TEXT.
Returns \"9999\" for blocks with no birth date, sorting them to the end."
  (if (string-match "^[ \t]+b:[ \t]*\\([^\n]*\\)" text)
      (let ((val (string-trim (match-string 1 text))))
        (if (string= val "?")
            "9999"
          ;; Strip source citations and place
          (when (string-match "\\[src:" val)
            (setq val (substring val 0 (match-beginning 0))))
          (when (string-match "@" val)
            (setq val (substring val 0 (match-beginning 0))))
          (setq val (string-trim val))
          ;; Strip date modifiers
          (setq val (replace-regexp-in-string "\\`[~<>]" "" val))
          ;; Ranges: use start date
          (when (string-match "\\.\\." val)
            (setq val (substring val 0 (match-beginning 0))))
          (string-trim val)))
    "9999"))

(defun genmark--extract-name (text)
  "Extract the display name from block TEXT for sorting."
  (if (string-match "^\\(.*?\\)[ \t]+\\[\\w+\\]" text)
      (downcase (string-trim (match-string 1 text)))
    "zzz"))

(defun genmark--collect-blocks-in-region (beg end)
  "Collect blocks between BEG and END.
Returns a list of (TYPE TEXT FOLDED) elements."
  (save-excursion
    (goto-char beg)
    (let (blocks)
      (while (and (< (point) end) (looking-at-p outline-regexp))
        (let ((block-beg (point)) block-end text folded)
          (setq folded (genmark--block-folded-p (point)))
          (forward-line 1)
          (if (re-search-forward outline-regexp nil t)
              (progn (beginning-of-line)
                     (setq block-end (min (point) end)))
            (setq block-end end))
          (setq text (buffer-substring-no-properties block-beg block-end))
          (push (list (genmark--block-type text) text folded) blocks)
          (goto-char block-end)))
      (nreverse blocks))))

(defun genmark--sort-blocks (key-fn)
  "Sort person blocks using KEY-FN to extract sort keys.
With an active region, sort only the blocks within it.
Without a region, sort the entire buffer.
Source and union blocks are kept in their original order."
  (if (use-region-p)
      (genmark--sort-region key-fn)
    (genmark--sort-buffer key-fn)))

(defun genmark--insert-blocks (blocks)
  "Insert BLOCKS and restore their fold state.
Each element is (TYPE TEXT FOLDED)."
  (dolist (block blocks)
    (let ((pos (point)))
      (insert (nth 1 block))
      (when (nth 2 block)
        (save-excursion
          (goto-char pos)
          (outline-hide-subtree))))))

(defun genmark--sort-buffer (key-fn)
  "Sort all person blocks in the buffer using KEY-FN."
  (let* ((collected (genmark--collect-blocks))
         (preamble (car collected))
         (blocks (cdr collected))
         (persons (seq-filter (lambda (b) (eq (car b) 'person)) blocks))
         (others (seq-filter (lambda (b) (not (eq (car b) 'person))) blocks))
         (sorted (sort persons
                       (lambda (a b)
                         (string< (funcall key-fn (nth 1 a))
                                  (funcall key-fn (nth 1 b)))))))
    (erase-buffer)
    (insert preamble)
    (genmark--insert-blocks sorted)
    (genmark--insert-blocks others)
    (goto-char (point-min))))

(defun genmark--sort-region (key-fn)
  "Sort person blocks within the active region using KEY-FN."
  (let ((rbeg (region-beginning))
        (rend (region-end))
        sort-beg sort-end)
    ;; Expand to block boundaries
    (save-excursion
      ;; Start: find the block containing region start
      (goto-char rbeg)
      (beginning-of-line)
      (if (looking-at-p outline-regexp)
          (setq sort-beg (point))
        (if (re-search-backward outline-regexp nil t)
            (setq sort-beg (point))
          (user-error "No blocks in region")))
      ;; End: find the end of the block containing region end
      (goto-char rend)
      (beginning-of-line)
      (if (and (looking-at-p outline-regexp) (> (point) sort-beg))
          ;; Region ends exactly at next header — don't include it
          (setq sort-end (point))
        (if (re-search-forward outline-regexp nil t)
            (progn (beginning-of-line) (setq sort-end (point)))
          (setq sort-end (point-max)))))
    (let* ((blocks (genmark--collect-blocks-in-region sort-beg sort-end))
           (persons (seq-filter (lambda (b) (eq (car b) 'person)) blocks))
           (others (seq-filter (lambda (b) (not (eq (car b) 'person))) blocks))
           (sorted (sort persons
                         (lambda (a b)
                           (string< (funcall key-fn (nth 1 a))
                                    (funcall key-fn (nth 1 b)))))))
      (delete-region sort-beg sort-end)
      (goto-char sort-beg)
      (genmark--insert-blocks sorted)
      (genmark--insert-blocks others)
      (goto-char sort-beg)
      (deactivate-mark))))

(defun genmark-sort ()
  "Sort top-level blocks in the buffer.
Person blocks are sorted by the chosen key.  Source and union blocks
are moved to the end in their original order."
  (interactive)
  (let ((key (read-char-choice
              "Sort by: [b]irth date  [n]ame  [q]uit "
              '(?b ?n ?q))))
    (pcase key
      (?b (genmark--sort-blocks #'genmark--extract-birth-date)
          (message "Sorted by birth date"))
      (?n (genmark--sort-blocks #'genmark--extract-name)
          (message "Sorted by name"))
      (?q (message "Cancelled")))))

;; --- Keymap ---

(defvar genmark-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'genmark-tab)
    (define-key map (kbd "<backtab>") #'genmark-fold-all)
    (define-key map (kbd "RET") #'genmark-newline)
    (define-key map (kbd "M-;") #'comment-line)
    (define-key map (kbd "M-<up>") #'genmark-move-block-up)
    (define-key map (kbd "M-<down>") #'genmark-move-block-down)
    (define-key map (kbd "C-c ^") #'genmark-sort)
    map)
  "Keymap for `genmark-mode'.")

(defun genmark-tab ()
  "Context-sensitive Tab key.
On a top-level heading, toggle fold.  Otherwise, indent the line."
  (interactive)
  (if (save-excursion
        (beginning-of-line)
        (looking-at-p outline-regexp))
      (genmark-fold-toggle)
    (genmark-indent-line)))

;; --- Mode Definition ---

;;;###autoload
(define-derived-mode genmark-mode prog-mode "Genmark"
  "Major mode for editing Genmark (.gmd) genealogy files.

Genmark is a plain-text language that compiles to GEDCOM 5.5.1.

\\<genmark-mode-map>
Key bindings:
  TAB           Fold/unfold block on headings, indent on field lines
  S-TAB         Fold/unfold all blocks
  RET           Newline with auto-indent (double RET returns to column 0)
  M-;           Toggle // comment on current line
  M-<up>        Move block up
  M-<down>      Move block down
  C-c ^         Sort blocks (by birth date or name)

\\{genmark-mode-map}"

  ;; Font lock
  (setq font-lock-defaults '(genmark-font-lock-keywords nil nil nil nil))

  ;; Comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "//+\\s-*")

  ;; Prevent :// in URLs from triggering comment highlighting
  (setq-local syntax-propertize-function #'genmark-syntax-propertize)

  ;; Indentation
  (setq-local indent-line-function #'genmark-indent-line)
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width genmark-indent-width)

  ;; Outline for folding
  (setq-local outline-regexp "^[A-Za-z].*\\[\\w+\\]\\|^source\\s-+\\[\\w+\\]\\|^\\[\\w+\\]\\s-*\\+")
  (setq-local outline-level #'genmark--outline-level)
  (outline-minor-mode 1)

  ;; Disable electric indent so our RET binding handles indentation
  (electric-indent-local-mode -1))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.gmd\\'" . genmark-mode))

(provide 'genmark-mode)

;;; genmark-mode.el ends here
