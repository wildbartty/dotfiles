(scroll-bar-mode -1)

;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.



(require 'package)

(add-to-list 'package-archives '("melpa" . "http://melpa.org/packages/"))

(package-initialize)

(require 'evil)

(evil-mode 1)

;; (require 'evil-mode)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(ansi-color-faces-vector
   [default default default italic underline success warning error])
 '(ansi-color-names-vector
   ["#212526" "#ff4b4b" "#b4fa70" "#fce94f" "#729fcf" "#e090d7" "#8cc4ff" "#eeeeec"])
 '(company-auto-complete ''company-explicit-action-p)
 '(company-auto-complete-chars "
")
 '(company-clang-arguments '("-I /home/wildbartty/code/include/"))
 '(company-idle-delay 0.3)
 '(company-minimum-prefix-length 1)
 '(company-occurrence-weight-function 'company-occurrence-prefer-closest-above)
 '(company-search-regexp-function 'regexp-quote)
 '(company-tooltip-idle-delay 0)
 '(custom-safe-themes
   '("34ed3e2fa4a1cb2ce7400c7f1a6c8f12931d8021435bad841fdc1192bd1cc7da" "36282815a2eaab9ba67d7653cf23b1a4e230e4907c7f110eebf3cdf1445d8370" "73ad471d5ae9355a7fa28675014ae45a0589c14492f52c32a4e9b393fcc333fd" "1263771faf6967879c3ab8b577c6c31020222ac6d3bac31f331a74275385a452" "93268bf5365f22c685550a3cbb8c687a1211e827edc76ce7be3c4bd764054bad" "25c06a000382b6239999582dfa2b81cc0649f3897b394a75ad5a670329600b45" "d9dab332207600e49400d798ed05f38372ec32132b3f7d2ba697e59088021555" "85d609b07346d3220e7da1e0b87f66d11b2eeddad945cac775e80d2c1adb0066" "e1498b2416922aa561076edc5c9b0ad7b34d8ff849f335c13364c8f4276904f0" "b3bcf1b12ef2a7606c7697d71b934ca0bdd495d52f901e73ce008c4c9825a3aa" default))
 '(display-battery-mode t)
 '(evil-emacs-state-modes
   '(doc-view-mode archive-mode bbdb-mode biblio-selection-mode bookmark-bmenu-mode bookmark-edit-annotation-mode browse-kill-ring-mode bzr-annotate-mode calc-mode cfw:calendar-mode completion-list-mode custom-theme-choose-mode delicious-search-mode desktop-menu-blist-mode desktop-menu-mode dvc-bookmarks-mode dvc-diff-mode dvc-info-buffer-mode dvc-log-buffer-mode dvc-revlist-mode dvc-revlog-mode dvc-status-mode dvc-tips-mode ediff-mode ediff-meta-mode efs-mode Electric-buffer-menu-mode emms-browser-mode emms-mark-mode emms-metaplaylist-mode emms-playlist-mode ess-help-mode etags-select-mode fj-mode gc-issues-mode gdb-breakpoints-mode gdb-disassembly-mode gdb-frames-mode gdb-locals-mode gdb-memory-mode gdb-registers-mode gdb-threads-mode gist-list-mode git-commit-mode git-rebase-mode gnus-article-mode gnus-browse-mode gnus-group-mode gnus-server-mode gnus-summary-mode google-maps-static-mode ibuffer-mode jde-javadoc-checker-report-mode magit-cherry-mode magit-diff-mode magit-log-mode magit-log-select-mode magit-popup-mode magit-popup-sequence-mode magit-process-mode magit-reflog-mode magit-refs-mode magit-revision-mode magit-stash-mode magit-stashes-mode magit-status-mode magit-mode magit-branch-manager-mode magit-commit-mode magit-key-mode magit-rebase-mode magit-wazzup-mode mh-folder-mode monky-mode mu4e-main-mode mu4e-headers-mode mu4e-view-mode notmuch-hello-mode notmuch-search-mode notmuch-show-mode notmuch-tree-mode occur-mode org-agenda-mode pdf-outline-buffer-mode pdf-view-mode proced-mode rcirc-mode rebase-mode recentf-dialog-mode reftex-select-bib-mode reftex-select-label-mode reftex-toc-mode sldb-mode slime-inspector-mode slime-thread-control-mode slime-xref-mode sr-buttons-mode sr-mode sr-tree-mode sr-virtual-mode tar-mode tetris-mode tla-annotate-mode tla-archive-list-mode tla-bconfig-mode tla-bookmarks-mode tla-branch-list-mode tla-browse-mode tla-category-list-mode tla-changelog-mode tla-follow-symlinks-mode tla-inventory-file-mode tla-inventory-mode tla-lint-mode tla-logs-mode tla-revision-list-mode tla-revlog-mode tla-tree-lint-mode tla-version-list-mode twittering-mode urlview-mode vc-annotate-mode vc-dir-mode vc-git-log-view-mode vc-hg-log-view-mode vc-svn-log-view-mode vm-mode vm-summary-mode w3m-mode wab-compilation-mode xgit-annotate-mode xgit-changelog-mode xgit-diff-mode xgit-revlog-mode xhg-annotate-mode xhg-log-mode xhg-mode xhg-mq-mode xhg-mq-sub-mode xhg-status-extra-mode))
 '(evil-motion-state-modes
   '(apropos-mode calendar-mode color-theme-mode command-history-mode compilation-mode dictionary-mode ert-results-mode help-mode Info-mode Man-mode speedbar-mode undo-tree-visualizer-mode woman-mode))
 '(evil-normal-state-modes
   '(treemacs-mode Buffer-menu-mode debugger-mode Custom-mode package-menu-mode) t)
 '(indent-guide-global-mode t)
 '(indent-guide-recursive t)
 '(package-selected-packages
   '(ansible ansible-doc poly-ansible highlight-indent-guides highlight-indentation xkcd anaconda-mode db-pg docker-cli dune elpher lolcat mermaid-mode ovpn-mode company-distel flycheck-clang-analyzer flycheck-clojure flycheck-dialyxir flycheck-dialyzer flymake-elixir flymake-lua flymake-perlcritic flymake-rust flymake-go flycheck flycheck-clang-tidy flycheck-clangcheck flycheck-irony slime-company company-irony company-irony-c-headers irony emacsql-psql emacsql-sqlite pg projectile treemacs-projectile evil-magit yaml-mode cmake-mode w3 company-c-headers company-erlang company-glsl company-go company-inf-ruby ecb lsp-java lsp-ocaml treemacs lxc lsp-clangd lsp-go lsp-mode lsp-python lsp-rust lsp-ui lua-mode forth-mode erlang slime gle-mode glsl-mode evil))
 '(show-paren-mode t)
 '(socks-server '("Default server" "localhost" 8080 5))
 '(tramp-default-method "ssh")
 '(tramp-terminal-type "tramp" nil (tramp)))



(global-linum-mode 1)

(setq-default indent-tabs-mode nil)

(setq inferior-lisp-program "sbcl")
(setq slime-contribs '(slime-fancy))

(add-hook 'after-change-major-mode-hook 
          '(lambda () 
             (setq-default indent-tabs-mode nil)
             (setq c-basic-indent 4)
             (setq tab-width 4)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(add-hook 'c-mode-hook 'company-mode)
(add-hook 'c-mode-hook 'flycheck-mode)

(add-hook 'c++-mode-hook 'company-mode)
(add-hook 'c++-mode-hook 'flycheck-mode)

(add-hook 'c++-mode-hook (lambda () (setq flycheck-clang-include-path
                                          (list (expand-file-name "~/code/include/")))))

(add-hook 'lisp-mode-hook 'paredit-mode)


(require 'tramp)
(setq tramp-default-method "ssh")

(require 'erlang)
(add-to-list 'erlang-compile-extra-opts 'debug_info)

(defun my-find-makefile-root ()
  (let ((dir (locate-dominating-file default-directory "Makefile")))
    (or dir default-directory)))

(defun my-find-rebar-root ()
  (let ((dir (locate-dominating-file default-directory "rebar.config")))
    (or dir default-directory)))

(defun my-inferior-erlang-compile ()
  (interactive)
  (let ((default-directory (my-find-rebar-root)))
    (compile "rebar compile")))

(defvar erlang-compile-function 'my-inferior-erlang-compile)

(add-hook 'window-setup-hook (lambda () (run-at-time "1 sec" nil 'tool-bar-mode -1)))

(add-hook 'yaml-mode-hook
          (lambda ()
            (highlight-indent-guides-mode)))
