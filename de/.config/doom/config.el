;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")
 
(after! treemacs
  (define-key evil-treemacs-state-map (kbd "H") #'treemacs-root-up)
  (define-key evil-treemacs-state-map (kbd "L") #'treemacs-root-down))


(setq select-enable-primary nil
      select-enable-clipboard t
      x-select-enable-clipboard-manager nil)  ; don't block frame close on X clipboard-manager handoff

;; Long-line safety. `line-move-1' (via evil-next-line) spins at 100% CPU when
;; moving the cursor through a very long line (e.g. a pasted base64 image blob
;; or a 2000-char hash) because visual line-move calls `vertical-motion' across
;; the whole line. Move by logical lines instead, and let so-long neuter buffers
;; that still contain pathologically long lines.
(setq-default line-move-visual nil)
(global-so-long-mode 1)

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:

;; This determines the style of line numbers in effect. If set to `nil', line
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 20))

;; No GTK client-side title bar (pgtk draws one by default under Wayland).
(add-to-list 'default-frame-alist '(undecorated . t))
(add-to-list 'initial-frame-alist '(undecorated . t))

(after! markdown-mode
  ;; Variable-height headers: each level (h1..h6) gets a distinct :height
  ;; multiplier relative to body text, so all six are visually distinguishable.
  ;; NOTE: use `setq!' (not `setq') — these are defcustoms whose :set handler
  ;; re-renders the header faces. Plain `setq' changes the value but never
  ;; updates the faces, so the sizes appear unchanged.
  (setq! markdown-header-scaling t
         markdown-header-scaling-values '(2.0 1.7 1.5 1.3 1.15 1.0))
  (setq markdown-hide-markup t
        markdown-max-image-size '(600 . 600)))   ; max (width . height) in px
;; NOTE: auto-rendering inline images on file open was removed — it spins at
;; 100% CPU when opening/scrolling .md files that contain images. Toggle images
;; on demand instead with `C-c C-x C-i' (markdown-toggle-inline-images).

;; GUI-freeze fix: markdown-mode (markdown-display-inline-images) scales inline
;; images through ImageMagick whenever it's available *and* `markdown-max-image-
;; size' is set (see markdown-mode.el `create-image ... 'imagemagick'). This Emacs
;; is built with USE=imagemagick, so that branch always wins — and ImageMagick
;; decodes synchronously on the single UI thread, hard-freezing the GUI on large
;; images (hence "renders one, then hangs"). The very next branch does the same
;; scaling via native image transforms (this build is +cairo/pgtk, so native
;; :max-width/:max-height scaling works). Force that branch by hiding ImageMagick
;; only for the duration of inline-image display; the size cap is preserved.
(defadvice! +markdown--native-image-scaling-a (fn &rest args)
  "Use native image scaling (not ImageMagick) for markdown inline images.
ImageMagick blocks Emacs' single UI thread and freezes the GUI on large
images; native transforms honor the same `markdown-max-image-size' cap."
  :around #'markdown-display-inline-images
  (let ((orig (symbol-function 'image-type-available-p)))
    (cl-letf (((symbol-function 'image-type-available-p)
               (lambda (type)
                 (and (not (eq type 'imagemagick))
                      (funcall orig type)))))
      (apply fn args))))

(defun +markdown/paste-image ()
  "Save the image in the Wayland clipboard next to the current Markdown file.

Writes it into an `images/' subdir (created if needed) under the buffer's
directory with a timestamped name, then inserts a relative `![](path)' link
at point.  Uses `wl-paste' (Wayland)."
  (interactive)
  (unless (buffer-file-name)
    (user-error "Save the buffer to a file first"))
  (let* ((types (split-string (shell-command-to-string "wl-paste --list-types") "\n" t))
         (mime  (cond ((member "image/png"  types) "image/png")
                      ((member "image/jpeg" types) "image/jpeg")
                      ((seq-find (lambda (s) (string-prefix-p "image/" s)) types)))))
    (unless mime
      (user-error "No image in clipboard (have: %s)" (string-join types ", ")))
    (let* ((ext  (pcase mime
                   ("image/png"  "png")
                   ("image/jpeg" "jpg")
                   (_ (string-remove-prefix "image/" mime))))
           (base (file-name-directory (buffer-file-name)))
           (dir  (expand-file-name "images" base))
           (file (expand-file-name (concat (format-time-string "%Y%m%d-%H%M%S") "." ext) dir))
           (rel  (file-relative-name file base)))
      (make-directory dir t)
      (if (zerop (call-process-shell-command
                  (format "wl-paste --no-newline --type %s > %s"
                          (shell-quote-argument mime)
                          (shell-quote-argument file))))
          (progn
            (insert (format "![](%s)" rel))
            (when (bound-and-true-p markdown-inline-image-overlays)
              (markdown-display-inline-images))
            (message "Saved %s" rel))
        (delete-file file)
        (user-error "wl-paste failed to write the image")))))

(map! :after markdown-mode
      :map markdown-mode-map
      :localleader
      "p" #'+markdown/paste-image)

(after! tex
  ;; Render to PDF and view it with pdf-tools (Emacs-native; auto-reverts after
  ;; each recompile). latexmk handles reruns/bibtex automatically.
  (setq TeX-view-program-selection '((output-pdf "PDF Tools"))
        TeX-source-correlate-start-server t)        ; SyncTeX: C-click PDF -> source
  ;; Recompile on every save so the side-window PDF stays live as you type.
  ;; `TeX-command-run-all' takes a mandatory prefix ARG; after-save-hook calls
  ;; functions with no args, so wrap it to pass nil (avoids "wrong number of
  ;; arguments").
  (add-hook! 'LaTeX-mode-hook
    (add-hook 'after-save-hook
              (lambda () (TeX-command-run-all nil))
              nil 'local)))

;; Dock the rendered PDF in a persistent right-hand side window instead of
;; stealing the editing window.
(set-popup-rule! "\\.pdf\\'" :side 'right :size 0.5 :select nil :quit nil :ttl nil :modeline t)

;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys

;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
(setq doom-theme 'catppuccin)
