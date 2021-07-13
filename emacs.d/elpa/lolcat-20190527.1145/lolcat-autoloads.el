;;; lolcat-autoloads.el --- automatically extracted autoloads
;;
;;; Code:

(add-to-list 'load-path (directory-file-name
                         (or (file-name-directory #$) (car load-path))))


;;;### (autoloads nil "lolcat" "lolcat.el" (0 0 0 0))
;;; Generated autoloads from lolcat.el

(autoload 'lolcat-this-buffer "lolcat" "\
Colorize BUFFER (defaults to the current buffer).

\(fn &optional BUFFER)" t nil)

(autoload 'lolcat-view-file "lolcat" "\
View FILENAME with color.

\(fn FILENAME)" t nil)

(autoload 'lolcat-view-buffer "lolcat" "\
View BUFFER with color.

\(fn BUFFER)" t nil)

(autoload 'lolcat-message "lolcat" "\
Like `message' but with color.

FORMAT-STRING and ARGS are used in the same way as `message'.

\(fn FORMAT-STRING &rest ARGS)" t nil)

(autoload 'eshell/lolcat "lolcat" "\
Display contents of FILENAME with color.

\(fn FILENAME)" nil nil)

(if (fboundp 'register-definition-prefixes) (register-definition-prefixes "lolcat" '("lolcat")))

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; lolcat-autoloads.el ends here
