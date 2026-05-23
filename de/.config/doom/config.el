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
      select-enable-clipboard t)

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

(after! markdown-mode
  ;; Variable-height headers: each level (h1..h6) gets a distinct :height
  ;; multiplier relative to body text, so all six are visually distinguishable.
  ;; NOTE: use `setq!' (not `setq') — these are defcustoms whose :set handler
  ;; re-renders the header faces. Plain `setq' changes the value but never
  ;; updates the faces, so the sizes appear unchanged.
  (setq! markdown-header-scaling t
         markdown-header-scaling-values '(2.0 1.7 1.5 1.3 1.15 1.0))
  (setq markdown-hide-markup t
        markdown-max-image-size '(1600 . 1200)))   ; max (width . height) in px

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
