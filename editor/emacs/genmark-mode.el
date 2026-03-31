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
;;   - Block folding with Tab / Shift-Tab
;;   - Block movement with M-<up> / M-<down>
;;   - Auto-indentation
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

(require 'cl-lib)

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
    ;; Underscore is word constituent (e.g. in person IDs)
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

;; --- Header Detection ---

(defvar genmark--header-regexp
  "^\\(?:[A-Za-z].*\\[\\w+\\]\\|source[ \t]+\\[\\w+\\]\\|\\[\\w+\\][ \t]*\\+\\)"
  "Regexp matching top-level block headers.")

;; --- Block Bounds ---

(defun genmark--leading-start ()
  "Return start of leading comments for the header at point.
Walks backward over non-blank lines until a blank line or BOB.
Returns the header position if there are no leading comments."
  (save-excursion
    (let ((beg (line-beginning-position)))
      (forward-line -1)
      (while (and (not (bobp))
                  (not (looking-at-p "^[ \t]*$")))
        (setq beg (line-beginning-position))
        (forward-line -1))
      (when (and (bobp) (not (looking-at-p "^[ \t]*$")))
        (setq beg (point)))
      beg)))

(defun genmark--body-end ()
  "Return position after the last line of the block body at point.
Point must be on the header line.  Body = indented lines below;
internal blank lines are included, trailing blank lines are not."
  (save-excursion
    (let ((end (line-beginning-position 2)))
      (forward-line 1)
      (while (not (eobp))
        (cond
         ;; Indented line: part of body
         ((looking-at-p "^[ \t]+[^ \t\n]")
          (setq end (line-beginning-position 2))
          (forward-line 1))
         ;; Blank line: skip, might be internal
         ((looking-at-p "^[ \t]*$")
          (forward-line 1))
         ;; Non-indented non-blank: body ended
         (t (goto-char (point-max)))))
      end)))

(defun genmark--find-header ()
  "Find the header line for the block at point.
Returns the position, or signals an error."
  (save-excursion
    (beginning-of-line)
    (cond
     ;; On a header
     ((looking-at-p genmark--header-regexp)
      (point))
     ;; On an indented line or blank line: search backward
     ((or (looking-at-p "^[ \t]+[^ \t\n]")
          (looking-at-p "^[ \t]*$"))
      (if (re-search-backward genmark--header-regexp nil t)
          (point)
        (user-error "Not inside a block")))
     ;; Non-indented non-blank (comment): check if leading comment
     (t
      (save-excursion
        (let ((start (point)))
          (forward-line 1)
          (while (and (not (eobp))
                      (not (looking-at-p "^[ \t]*$"))
                      (not (looking-at-p genmark--header-regexp)))
            (forward-line 1))
          (if (and (not (eobp)) (looking-at-p genmark--header-regexp))
              (point)
            (user-error "Not inside a block"))))))))

(defun genmark--block-bounds ()
  "Return (BEG . END) of the current top-level block.
Includes leading comments (up to the first blank line above the
header) and the indented body below."
  (save-excursion
    (let ((header (genmark--find-header)))
      (goto-char header)
      (cons (genmark--leading-start) (genmark--body-end)))))

(defun genmark--comment-group-bounds ()
  "Return (BEG . END) of the standalone comment group at point.
Point must be on a non-indented, non-blank, non-header line."
  (save-excursion
    (beginning-of-line)
    ;; Walk backward to find the start
    (let ((beg (line-beginning-position)))
      (save-excursion
        (forward-line -1)
        (while (and (not (bobp))
                    (not (looking-at-p "^[ \t]*$"))
                    (not (looking-at-p genmark--header-regexp)))
          (setq beg (line-beginning-position))
          (forward-line -1))
        (when (and (bobp)
                   (not (looking-at-p "^[ \t]*$"))
                   (not (looking-at-p genmark--header-regexp)))
          (setq beg (point))))
      ;; Walk forward to find the end
      (goto-char beg)
      (while (and (not (eobp))
                  (not (looking-at-p "^[ \t]*$"))
                  (not (looking-at-p genmark--header-regexp)))
        (forward-line 1))
      (cons beg (point)))))

(defun genmark--entity-at-point ()
  "Return (BEG END TYPE) for the entity at point.
TYPE is `block' for a header block or `comment' for a standalone
comment group.  Signals an error if point is on a blank line."
  (save-excursion
    (beginning-of-line)
    (cond
     ;; On a header line
     ((looking-at-p genmark--header-regexp)
      (list (genmark--leading-start) (genmark--body-end) 'block))
     ;; On an indented line: part of a header block's body
     ((looking-at-p "^[ \t]+[^ \t\n]")
      (if (re-search-backward genmark--header-regexp nil t)
          (list (genmark--leading-start) (genmark--body-end) 'block)
        (user-error "Not inside a block")))
     ;; On a blank line
     ((looking-at-p "^[ \t]*$")
      (user-error "Not inside a block"))
     ;; Non-indented non-blank non-header: comment line
     (t
      (let ((group (genmark--comment-group-bounds)))
        ;; Check if this comment group directly precedes a header
        ;; (no blank line between) — if so it's a leading comment
        (save-excursion
          (goto-char (cdr group))
          (if (and (not (eobp)) (looking-at-p genmark--header-regexp))
              ;; Leading comment for the next header — return block bounds
              (list (car group) (genmark--body-end) 'block)
            ;; Standalone comment
            (list (car group) (cdr group) 'comment))))))))

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

;; --- Folding (overlays) ---

(defun genmark--block-folded-p (header-pos)
  "Return non-nil if the block at HEADER-POS is folded."
  (save-excursion
    (goto-char header-pos)
    (let ((leading (genmark--leading-start))
          (body-end (genmark--body-end)))
      (cl-some (lambda (ov) (overlay-get ov 'genmark-fold))
               (overlays-in leading body-end)))))

(defun genmark--fold-block (header-pos)
  "Fold the block whose header is at HEADER-POS.
Hides leading comments above and body below, leaving only the
header line visible."
  (save-excursion
    (goto-char header-pos)
    (let ((leading-start (genmark--leading-start))
          (header-start (line-beginning-position))
          (header-end (line-end-position))
          (body-end (genmark--body-end)))
      ;; Hide leading comments (if any)
      (when (< leading-start header-start)
        (let ((ov (make-overlay leading-start header-start)))
          (overlay-put ov 'genmark-fold t)
          (overlay-put ov 'invisible t)
          (overlay-put ov 'evaporate t)))
      ;; Hide body (if any content beyond the header line)
      (when (> body-end (min (1+ header-end) (point-max)))
        (let ((ov (make-overlay header-end (1- body-end))))
          (overlay-put ov 'genmark-fold t)
          (overlay-put ov 'invisible t)
          (overlay-put ov 'after-string
                       (propertize " ..." 'face 'font-lock-comment-face))
          (overlay-put ov 'evaporate t))))))

(defun genmark--unfold-block (header-pos)
  "Unfold the block whose header is at HEADER-POS."
  (save-excursion
    (goto-char header-pos)
    (let ((leading-start (genmark--leading-start))
          (body-end (genmark--body-end)))
      (dolist (ov (overlays-in leading-start body-end))
        (when (overlay-get ov 'genmark-fold)
          (delete-overlay ov))))))

(defun genmark-fold-toggle ()
  "Toggle folding of the current block.
If point is not on a header, find the enclosing block's header."
  (interactive)
  (let ((header (genmark--find-header)))
    (if (genmark--block-folded-p header)
        (genmark--unfold-block header)
      (genmark--fold-block header))))

(defun genmark-fold-all ()
  "Toggle folding of all blocks.
If any block with content is unfolded, fold all.  Otherwise, unfold all."
  (interactive)
  (let ((headers nil)
        (any-unfolded nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward genmark--header-regexp nil t)
        (push (line-beginning-position) headers)))
    (setq headers (nreverse headers))
    ;; Check if any block with foldable content is unfolded
    (dolist (h headers)
      (unless (genmark--block-folded-p h)
        (save-excursion
          (goto-char h)
          (let ((leading (genmark--leading-start))
                (body-end (genmark--body-end)))
            (when (or (< leading (line-beginning-position))
                      (> body-end (line-beginning-position 2)))
              (setq any-unfolded t))))))
    (if any-unfolded
        (dolist (h headers)
          (unless (genmark--block-folded-p h)
            (genmark--fold-block h)))
      (dolist (h headers)
        (when (genmark--block-folded-p h)
          (genmark--unfold-block h))))))

;; --- Block Movement ---

(defun genmark--adjacent-entity (pos direction)
  "Find the entity adjacent to POS in DIRECTION (`up' or `down').
Skips blank lines, then returns the entity found via
`genmark--entity-at-point'.  Signals an error if none exists."
  (save-excursion
    (goto-char pos)
    (if (eq direction 'down)
        (progn
          (while (and (not (eobp)) (looking-at-p "^[ \t]*$"))
            (forward-line 1))
          (if (eobp)
              (user-error "No block below")
            (genmark--entity-at-point)))
      ;; up
      (forward-line -1)
      (while (and (not (bobp)) (looking-at-p "^[ \t]*$"))
        (forward-line -1))
      (if (and (bobp) (looking-at-p "^[ \t]*$"))
          (user-error "No block above")
        (genmark--entity-at-point)))))

(defun genmark-move-block-up ()
  "Move the current entity above the previous one.
An entity is a header block (with leading comments and body)
or a standalone comment group.  Blank lines between entities
stay in place as separators."
  (interactive)
  (let* ((cur (genmark--entity-at-point))
         (cur-beg (nth 0 cur))
         (cur-end (nth 1 cur))
         (cur-type (nth 2 cur))
         (cur-header (when (eq cur-type 'block)
                       (save-excursion
                         (goto-char cur-beg)
                         (when (re-search-forward genmark--header-regexp
                                                  cur-end t)
                           (line-beginning-position)))))
         (cur-folded (when cur-header
                       (genmark--block-folded-p cur-header))))
    (let* ((prev (genmark--adjacent-entity cur-beg 'up))
           (prev-beg (nth 0 prev))
           (prev-end (nth 1 prev))
           (prev-type (nth 2 prev))
           (prev-header (when (eq prev-type 'block)
                          (save-excursion
                            (goto-char prev-beg)
                            (when (re-search-forward genmark--header-regexp
                                                     prev-end t)
                              (line-beginning-position)))))
           (prev-folded (when prev-header
                          (genmark--block-folded-p prev-header)))
           (prev-text (buffer-substring prev-beg prev-end))
           (separator (buffer-substring prev-end cur-beg))
           (cur-text (buffer-substring cur-beg cur-end)))
      ;; Remove fold overlays in the affected region
      (dolist (ov (overlays-in prev-beg cur-end))
        (when (overlay-get ov 'genmark-fold)
          (delete-overlay ov)))
      ;; Swap: cur + separator + prev
      (delete-region prev-beg cur-end)
      (goto-char prev-beg)
      (insert cur-text separator prev-text)
      ;; Restore fold state
      (when cur-folded
        (save-excursion
          (goto-char prev-beg)
          (when (re-search-forward genmark--header-regexp
                                   (+ prev-beg (length cur-text)) t)
            (genmark--fold-block (line-beginning-position)))))
      (when prev-folded
        (save-excursion
          (goto-char (+ prev-beg (length cur-text) (length separator)))
          (when (re-search-forward genmark--header-regexp
                                   (+ prev-beg (length cur-text)
                                      (length separator)
                                      (length prev-text)) t)
            (genmark--fold-block (line-beginning-position)))))
      ;; Position cursor on the moved entity's header (or first line)
      (goto-char prev-beg)
      (when (and (eq cur-type 'block)
                 (re-search-forward genmark--header-regexp
                                    (+ prev-beg (length cur-text)) t))
        (beginning-of-line)))))

(defun genmark-move-block-down ()
  "Move the current entity below the next one.
An entity is a header block (with leading comments and body)
or a standalone comment group.  Blank lines between entities
stay in place as separators."
  (interactive)
  (let* ((cur (genmark--entity-at-point))
         (cur-beg (nth 0 cur))
         (cur-end (nth 1 cur))
         (cur-type (nth 2 cur))
         (cur-header (when (eq cur-type 'block)
                       (save-excursion
                         (goto-char cur-beg)
                         (when (re-search-forward genmark--header-regexp
                                                  cur-end t)
                           (line-beginning-position)))))
         (cur-folded (when cur-header
                       (genmark--block-folded-p cur-header))))
    (let* ((next (genmark--adjacent-entity cur-end 'down))
           (next-beg (nth 0 next))
           (next-end (nth 1 next))
           (next-type (nth 2 next))
           (next-header (when (eq next-type 'block)
                          (save-excursion
                            (goto-char next-beg)
                            (when (re-search-forward genmark--header-regexp
                                                     next-end t)
                              (line-beginning-position)))))
           (next-folded (when next-header
                          (genmark--block-folded-p next-header)))
           (cur-text (buffer-substring cur-beg cur-end))
           (separator (buffer-substring cur-end next-beg))
           (next-text (buffer-substring next-beg next-end)))
      ;; Remove fold overlays in the affected region
      (dolist (ov (overlays-in cur-beg next-end))
        (when (overlay-get ov 'genmark-fold)
          (delete-overlay ov)))
      ;; Swap: next + separator + cur
      (delete-region cur-beg next-end)
      (goto-char cur-beg)
      (insert next-text separator cur-text)
      ;; Restore fold state
      (when next-folded
        (save-excursion
          (goto-char cur-beg)
          (when (re-search-forward genmark--header-regexp
                                   (+ cur-beg (length next-text)) t)
            (genmark--fold-block (line-beginning-position)))))
      (when cur-folded
        (save-excursion
          (goto-char (+ cur-beg (length next-text) (length separator)))
          (when (re-search-forward genmark--header-regexp
                                   (+ cur-beg (length next-text)
                                      (length separator)
                                      (length cur-text)) t)
            (genmark--fold-block (line-beginning-position)))))
      ;; Position cursor on the moved entity's header (or first line)
      (goto-char (+ cur-beg (length next-text) (length separator)))
      (when (and (eq cur-type 'block)
                 (re-search-forward genmark--header-regexp
                                    (+ cur-beg (length next-text)
                                       (length separator)
                                       (length cur-text)) t))
        (beginning-of-line)))))

;; --- Block Sorting ---

(defun genmark--block-type (text)
  "Return the type of a block: \\='person, \\='source, or \\='union."
  (let ((header (if (string-match "\n" text)
                    ;; Find the header line (skip leading comments)
                    (with-temp-buffer
                      (insert text)
                      (goto-char (point-min))
                      (while (and (not (eobp))
                                  (not (looking-at-p genmark--header-regexp)))
                        (forward-line 1))
                      (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position)))
                  text)))
    (cond
     ((string-match-p "^source[ \t]" header) 'source)
     ((string-match-p "^\\[\\w+\\][ \t]*\\+" header) 'union)
     (t 'person))))

(defun genmark--collect-blocks ()
  "Collect all blocks in the buffer.
Returns (PREAMBLE . BLOCKS) where PREAMBLE is text before the first
block (including its leading comments) and BLOCKS is a list of
\(TYPE TEXT FOLDED) elements.  Each block's text includes its leading
comments.  Inter-block gaps (standalone comments, blank lines) are
appended to the preceding block's text."
  (save-excursion
    (goto-char (point-min))
    (let (preamble blocks headers)
      ;; Collect all header positions
      (while (re-search-forward genmark--header-regexp nil t)
        (push (line-beginning-position) headers))
      (setq headers (nreverse headers))
      (if (null headers)
          (setq preamble (buffer-substring-no-properties
                          (point-min) (point-max)))
        ;; Preamble: everything before the first block's leading comments
        (goto-char (car headers))
        (let ((first-beg (genmark--leading-start)))
          (setq preamble (buffer-substring-no-properties
                          (point-min) first-beg)))
        ;; Collect blocks: each block runs from its leading-start to the
        ;; next block's leading-start (or EOB for the last block)
        (let ((hlist headers))
          (while hlist
            (let* ((header (car hlist))
                   (folded (genmark--block-folded-p header))
                   (beg (save-excursion (goto-char header)
                                        (genmark--leading-start)))
                   (end (if (cdr hlist)
                            (save-excursion (goto-char (cadr hlist))
                                            (genmark--leading-start))
                          (point-max)))
                   (text (buffer-substring-no-properties beg end)))
              (push (list (genmark--block-type text) text folded) blocks))
            (setq hlist (cdr hlist)))))
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
    (let (blocks headers)
      ;; Collect headers in region
      (while (and (< (point) end)
                  (re-search-forward genmark--header-regexp end t))
        (push (line-beginning-position) headers))
      (setq headers (nreverse headers))
      (let ((hlist headers))
        (while hlist
          (let* ((header (car hlist))
                 (folded (genmark--block-folded-p header))
                 (block-beg (save-excursion (goto-char header)
                                            (genmark--leading-start)))
                 (block-end (if (cdr hlist)
                                (save-excursion (goto-char (cadr hlist))
                                                (genmark--leading-start))
                              end))
                 (text (buffer-substring-no-properties
                        (max block-beg beg) block-end)))
            (push (list (genmark--block-type text) text folded) blocks))
          (setq hlist (cdr hlist))))
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
          (when (re-search-forward genmark--header-regexp
                                   (+ pos (length (nth 1 block))) t)
            (genmark--fold-block (line-beginning-position))))))))

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
      (if (looking-at-p genmark--header-regexp)
          (setq sort-beg (point))
        (if (re-search-backward genmark--header-regexp nil t)
            (setq sort-beg (point))
          (user-error "No blocks in region")))
      ;; End: find the end of the block containing region end
      (goto-char rend)
      (beginning-of-line)
      (if (and (looking-at-p genmark--header-regexp) (> (point) sort-beg))
          ;; Region ends exactly at next header — don't include it
          (setq sort-end (point))
        (if (re-search-forward genmark--header-regexp nil t)
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
        (looking-at-p genmark--header-regexp))
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

  ;; Disable electric indent so our RET binding handles indentation
  (electric-indent-local-mode -1))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.gmd\\'" . genmark-mode))

(provide 'genmark-mode)

;;; genmark-mode.el ends here
