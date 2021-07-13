;;; elpher.el --- A friendly gopher and gemini client  -*- lexical-binding:t -*-

;; Copyright (C) 2019 Tim Vaughan

;; Author: Tim Vaughan <plugd@thelambdalab.xyz>
;; Created: 11 April 2019
;; Version: 2.7.11
;; Keywords: comm gopher
;; Homepage: http://thelambdalab.xyz/elpher
;; Package-Requires: ((emacs "26"))

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Elpher aims to provide a practical and friendly gopher and gemini
;; client for GNU Emacs.  It supports:

;; - intuitive keyboard and mouse-driven browsing,
;; - out-of-the-box compatibility with evil-mode,
;; - clickable web and gopher links *in plain text*,
;; - caching of visited sites,
;; - pleasant and configurable colouring of Gopher directories,
;; - direct visualisation of image files,
;; - a simple bookmark management system,
;; - gopher connections using TLS encryption,
;; - the fledgling Gemini protocol,
;; - the greybeard Finger protocol.

;; To launch Elpher, simply use 'M-x elpher'.  This will open a start
;; page containing information on key bindings and suggested starting
;; points for your gopher exploration.

;; Full instructions can be found in the Elpher info manual.

;; Elpher is under active development.  Any suggestions for
;; improvements are welcome, and can be made on the official
;; project page, gopher://thelambdalab.xyz/1/projects/elpher/.

;;; Code:

(provide 'elpher)

;;; Dependencies
;;

(require 'seq)
(require 'pp)
(require 'shr)
(require 'url-util)
(require 'subr-x)
(require 'dns)
(require 'ansi-color)
(require 'nsm)


;;; Global constants
;;

(defconst elpher-version "2.7.11"
  "Current version of elpher.")

(defconst elpher-margin-width 6
  "Width of left-hand margin used when rendering indicies.")

(defconst elpher-type-map
  '(((gopher ?0) elpher-get-gopher-page elpher-render-text "txt" elpher-text)
    ((gopher ?1) elpher-get-gopher-page elpher-render-index "/" elpher-index)
    ((gopher ?4) elpher-get-gopher-page elpher-render-download "bin" elpher-binary)
    ((gopher ?5) elpher-get-gopher-page elpher-render-download "bin" elpher-binary)
    ((gopher ?7) elpher-get-gopher-query-page elpher-render-index "?" elpher-search)
    ((gopher ?9) elpher-get-gopher-page elpher-render-download "bin" elpher-binary)
    ((gopher ?g) elpher-get-gopher-page elpher-render-image "img" elpher-image)
    ((gopher ?p) elpher-get-gopher-page elpher-render-image "img" elpher-image)
    ((gopher ?I) elpher-get-gopher-page elpher-render-image "img" elpher-image)
    ((gopher ?d) elpher-get-gopher-page elpher-render-download "doc" elpher-binary)
    ((gopher ?P) elpher-get-gopher-page elpher-render-download "doc" elpher-binary)
    ((gopher ?s) elpher-get-gopher-page elpher-render-download "snd" elpher-binary)
    ((gopher ?h) elpher-get-gopher-page elpher-render-html "htm" elpher-html)
    (gemini elpher-get-gemini-page elpher-render-gemini "gem" elpher-gemini)
    (finger elpher-get-finger-page elpher-render-text "txt" elpher-text)
    (telnet elpher-get-telnet-page nil "tel" elpher-telnet)
    (other-url elpher-get-other-url-page nil "url" elpher-other-url)
    ((special bookmarks) elpher-get-bookmarks-page nil "/" elpher-index)
    ((special start) elpher-get-start-page nil))
  "Association list from types to getters, renderers, margin codes and index faces.")


;;; Customization group
;;

(defgroup elpher nil
  "A gopher client."
  :group 'applications)

;; General appearance and customizations

(defcustom elpher-open-urls-with-eww nil
  "If non-nil, open URL selectors using eww.
Otherwise, use the system browser via the BROWSE-URL function."
  :type '(boolean))

(defcustom elpher-use-header t
  "If non-nil, display current page information in buffer header."
  :type '(boolean))

(defcustom elpher-auto-disengage-TLS nil
  "If non-nil, automatically disengage TLS following an unsuccessful connection.
While enabling this may seem convenient, it is also potentially dangerous as it
allows switching from an encrypted channel back to plain text without user input."
  :type '(boolean))

(defcustom elpher-connection-timeout 5
  "Specifies the number of seconds to wait for a network connection to time out."
  :type '(integer))

(defcustom elpher-filter-ansi-from-text nil
  "If non-nil, filter ANSI escape sequences from text.
The default behaviour is to use the ansi-color package to interpret these
sequences."
  :type '(boolean))

(defcustom elpher-gemini-TLS-cert-checks nil
  "If non-nil, verify gemini server TLS certs using the default security level.
Otherwise, certificate verification is disabled.

This defaults to off because it is standard practice for Gemini servers
to use self-signed certificates, meaning that most servers provide what
EMACS considers to be an invalid certificate."
  :type '(boolean))

(defcustom elpher-gemini-max-fill-width 80
  "Specify the maximum default width (in columns) of text/gemini documents.
The actual width used is the minimum of this value and the window width at
the time when the text is rendered."
  :type '(integer))

(defcustom elpher-gemini-link-string "→ "
  "Specify the string used to indicate links when rendering gemini maps.
May be empty."
  :type '(string))

(defcustom elpher-gemini-bullet-string "•"
  "Specify the string used for bullets when rendering gemini maps."
  :type '(string))

(defcustom elpher-bookmarks-file (locate-user-emacs-file "elpher-bookmarks")
  "Specify the name of the file where elpher bookmarks will be saved."
  :type '(file))

(defcustom elpher-ipv4-always nil
  "If non-nil, elpher will always use IPv4 to establish network connections.
This can be useful when browsing from a computer that supports IPv6, because
some servers which do not support IPv6 can take a long time to time-out."
  :type '(boolean))

;; Face customizations

(defgroup elpher-faces nil
  "Elpher face customizations."
  :group 'elpher)

(defface elpher-index
  '((t :inherit font-lock-keyword-face))
  "Face used for directory type directory records.")

(defface elpher-text
  '((t :inherit bold))
  "Face used for text type directory records.")

(defface elpher-info
  '((t :inherit default))
  "Face used for info type directory records.")

(defface elpher-image
  '((t :inherit font-lock-string-face))
  "Face used for image type directory records.")

(defface elpher-search
  '((t :inherit warning))
  "Face used for search type directory records.")

(defface elpher-html
  '((t :inherit font-lock-comment-face))
  "Face used for html type directory records.")

(defface elpher-gemini
  '((t :inherit font-lock-regexp-grouping-backslash))
  "Face used for Gemini type directory records.")

(defface elpher-other-url
  '((t :inherit font-lock-comment-face))
  "Face used for other URL type links records.")

(defface elpher-telnet
  '((t :inherit font-lock-function-name-face))
  "Face used for telnet type directory records.")

(defface elpher-binary
  '((t :inherit font-lock-doc-face))
  "Face used for binary type directory records.")

(defface elpher-unknown
  '((t :inherit error))
  "Face used for directory records with unknown/unsupported types.")

(defface elpher-margin-key
  '((t :inherit bold))
  "Face used for directory margin key.")

(defface elpher-margin-brackets
  '((t :inherit shadow))
  "Face used for brackets around directory margin key.")

(defface elpher-gemini-heading1
  '((t :inherit bold :height 1.8))
  "Face used for gemini heading level 1.")

(defface elpher-gemini-heading2
  '((t :inherit bold :height 1.5))
  "Face used for gemini heading level 2.")

(defface elpher-gemini-heading3
  '((t :inherit bold :height 1.2))
  "Face used for gemini heading level 3.")

(defface elpher-gemini-preformatted
  '((t :inherit fixed-pitch))
  "Face used for pre-formatted gemini text blocks.")

;;; Model
;;

;; Address

;; An elpher "address" object is either a url object or a symbol.
;; Symbol addresses are "special", corresponding to pages generated
;; dynamically for and by elpher.  All others represent pages which
;; rely on content retrieved over the network.

(defun elpher-address-from-url (url-string)
  "Create a ADDRESS object corresponding to the given URL-STRING."
  (let ((data (match-data))) ; Prevent parsing clobbering match data
    (unwind-protect
        (let ((url (url-generic-parse-url url-string)))
          (unless (and (not (url-fullness url)) (url-type url))
            (setf (url-fullness url) t)
            (setf (url-filename url)
                  (url-unhex-string (url-filename url)))
            (unless (url-type url)
              (setf (url-type url) "gopher"))
            (when (or (equal "gopher" (url-type url))
                      (equal "gophers" (url-type url)))
              ;; Gopher defaults
              (unless (url-host url)
                (setf (url-host url) (url-filename url))
                (setf (url-filename url) ""))
              (when (or (equal (url-filename url) "")
                        (equal (url-filename url) "/"))
                (setf (url-filename url) "/1")))
            (when (equal "gemini" (url-type url))
              ;; Gemini defaults
              (if (equal (url-filename url) "")
                  (setf (url-filename url) "/"))))
          url)
      (set-match-data data))))

(defun elpher-make-gopher-address (type selector host port &optional tls)
  "Create an ADDRESS object using gopher directory record attributes.
The basic attributes include: TYPE, SELECTOR, HOST and PORT.
If the optional attribute TLS is non-nil, the address will be marked as
requiring gopher-over-TLS."
  (cond
   ((equal type ?i) nil)
   ((and (equal type ?h)
         (string-prefix-p "URL:" selector))
    (elpher-address-from-url (elt (split-string selector "URL:") 1)))
   ((equal type ?8)
    (elpher-address-from-url
     (concat "telnet"
             "://" host
             ":" (number-to-string port))))
   (t
    (elpher-address-from-url
     (concat "gopher" (if tls "s" "")
             "://" host
             ":" (number-to-string port)
             "/" (string type)
             selector)))))

(defun elpher-make-special-address (type)
  "Create an ADDRESS object corresponding to the given special address symbol TYPE."
  type)

(defun elpher-address-to-url (address)
  "Get string representation of ADDRESS, or nil if ADDRESS is special."
  (if (elpher-address-special-p address)
      nil
    (url-encode-url (url-recreate-url address))))

(defun elpher-address-type (address)
  "Retrieve type of ADDRESS object.
This is used to determine how to retrieve and render the document the
address refers to, via the table `elpher-type-map'."
  (if (symbolp address)
      (list 'special address)
    (let ((protocol (url-type address)))
      (cond ((or (equal protocol "gopher")
                 (equal protocol "gophers"))
             (list 'gopher
                   (if (member (url-filename address) '("" "/"))
                       ?1
                     (string-to-char (substring (url-filename address) 1)))))
            ((equal protocol "gemini")
             'gemini)
            ((equal protocol "telnet")
             'telnet)
            ((equal protocol "finger")
             'finger)
            (t 'other-url)))))

(defun elpher-address-protocol (address)
  "Retrieve the transport protocol for ADDRESS.  This is nil for special addresses."
  (if (symbolp address)
      nil
    (url-type address)))

(defun elpher-address-filename (address)
  "Retrieve the filename component of ADDRESS.
For gopher addresses this is a combination of the selector type and selector."
  (if (symbolp address)
      nil
    (url-filename address)))

(defun elpher-address-host (address)
  "Retrieve host from ADDRESS object."
  (url-host address))

(defun elpher-address-user (address)
  "Retrieve user from ADDRESS object."
  (url-user address))

(defun elpher-address-port (address)
  "Retrieve port from ADDRESS object.
If no address is defined, returns 0.  (This is for compatibility with the URL library.)"
  (if (symbolp address)
      0
    (url-port address)))

(defun elpher-address-special-p (address)
  "Return non-nil if ADDRESS object is special (e.g. start page, bookmarks page)."
  (symbolp address))

(defun elpher-address-gopher-p (address)
  "Return non-nill if ADDRESS object is a gopher address."
  (and (not (elpher-address-special-p address))
       (member (elpher-address-protocol address) '("gopher gophers"))))

(defun elpher-gopher-address-selector (address)
  "Retrieve gopher selector from ADDRESS object."
  (if (member (url-filename address) '("" "/"))
      ""
    (url-unhex-string (substring (url-filename address) 2))))


;; Cache

(defvar elpher-content-cache (make-hash-table :test 'equal))
(defvar elpher-pos-cache (make-hash-table :test 'equal))

(defun elpher-get-cached-content (address)
  "Retrieve the cached content for ADDRESS, or nil if none exists."
  (gethash address elpher-content-cache))

(defun elpher-cache-content (address content)
  "Set the content cache for ADDRESS to CONTENT."
  (puthash address content elpher-content-cache))

(defun elpher-get-cached-pos (address)
  "Retrieve the cached cursor position for ADDRESS, or nil if none exists."
  (gethash address elpher-pos-cache))

(defun elpher-cache-pos (address pos)
  "Set the cursor position cache for ADDRESS to POS."
  (puthash address pos elpher-pos-cache))


;; Page

(defun elpher-make-page (display-string address)
  "Create a page with DISPLAY-STRING and ADDRESS."
  (list display-string address))

(defun elpher-page-display-string (page)
  "Retrieve the display string corresponding to PAGE."
  (elt page 0))

(defun elpher-page-address (page)
  "Retrieve the address corresponding to PAGE."
  (elt page 1))

(defun elpher-page-set-address (page new-address)
  "Set the address corresponding to PAGE to NEW-ADDRESS."
  (setcar (cdr page) new-address))

(defvar elpher-current-page nil)
(defvar elpher-history nil)

(defun elpher-visit-page (page &optional renderer no-history)
  "Visit PAGE using its own renderer or RENDERER, if non-nil.
Additionally, push PAGE onto the stack of previously-visited pages,
unless NO-HISTORY is non-nil."
  (elpher-save-pos)
  (elpher-process-cleanup)
  (unless (or no-history
              (equal (elpher-page-address elpher-current-page)
                     (elpher-page-address page)))
    (push elpher-current-page elpher-history))
  (setq elpher-current-page page)
  (let* ((address (elpher-page-address page))
         (type (elpher-address-type address))
         (type-record (cdr (assoc type elpher-type-map))))
    (if type-record
        (funcall (car type-record)
                 (if renderer
                     renderer
                   (cadr type-record)))
      (elpher-visit-previous-page)
      (pcase type
        (`(gopher ,type-char)
         (error "Unsupported gopher selector type '%c' for '%s'"
                type-char (elpher-address-to-url address)))
        (other
         (error "Unsupported address type '%S' for '%s'"
                other (elpher-address-to-url address)))))))

(defun elpher-visit-previous-page ()
  "Visit the previous page in the history."
  (let ((previous-page (pop elpher-history)))
    (if previous-page
        (elpher-visit-page previous-page nil t)
      (error "No previous page"))))
      
(defun elpher-reload-current-page ()
  "Reload the current page, discarding any existing cached content."
  (elpher-cache-content (elpher-page-address elpher-current-page) nil)
  (elpher-visit-page elpher-current-page))

(defun elpher-save-pos ()
  "Save the current position of point to the current page."
  (when elpher-current-page
    (elpher-cache-pos (elpher-page-address elpher-current-page) (point))))

(defun elpher-restore-pos ()
  "Restore the position of point to that cached in the current page."
  (let ((pos (elpher-get-cached-pos (elpher-page-address elpher-current-page))))
    (if pos
        (goto-char pos)
      (goto-char (point-min)))))


;;; Buffer preparation
;;

(defun elpher-update-header ()
  "If `elpher-use-header' is true, display current page info in window header."
  (if elpher-use-header
      (let* ((display-string (elpher-page-display-string elpher-current-page))
             (address (elpher-page-address elpher-current-page))
             (tls-string (if (and (not (elpher-address-special-p address))
                                  (member (elpher-address-protocol address)
                                          '("gophers" "gemini")))
                             " [TLS encryption]"
                           ""))
             (header (concat display-string
                             (propertize tls-string 'face 'bold))))
        (setq header-line-format header))))

(defmacro elpher-with-clean-buffer (&rest args)
  "Evaluate ARGS with a clean *elpher* buffer as current."
  (list 'with-current-buffer "*elpher*"
        '(elpher-mode)
        (append (list 'let '((inhibit-read-only t))
                      '(setq-local network-security-level
                                   (default-value 'network-security-level))
                      '(erase-buffer)
                      '(elpher-update-header))
                args)))


;;; Text Processing
;;

(defvar elpher-user-coding-system nil
  "User-specified coding system to use for decoding text responses.")

(defun elpher-decode (string)
  "Decode STRING using autodetected or user-specified coding system."
  (decode-coding-string string
                        (if elpher-user-coding-system
                            elpher-user-coding-system
                          (detect-coding-string string t))))

(defun elpher-preprocess-text-response (string)
  "Preprocess text selector response contained in STRING.
This involes decoding the character representation, and clearing
away CRs and any terminating period."
  (elpher-decode (replace-regexp-in-string "\n\.\n$" "\n"
                                           (replace-regexp-in-string "\r" "" string))))


;;; Network error reporting
;;

(defun elpher-network-error (address error)
  "Display ERROR message following unsuccessful negotiation with ADDRESS.
ERROR can be either an error object or a string."
  (elpher-with-clean-buffer
   (insert (propertize "\n---- ERROR -----\n\n" 'face 'error)
           "When attempting to retrieve " (elpher-address-to-url address) ":\n"
           (if (stringp error) error (error-message-string error)) "\n"
           (propertize "\n----------------\n\n" 'face 'error)
           "Press 'u' to return to the previous page.")))


;;; Gopher selector retrieval
;;

(defvar elpher-network-timer nil
  "Timer used for network connections.")

(defun elpher-process-cleanup ()
  "Immediately shut down any extant elpher process and timers."
  (let ((p (get-process "elpher-process")))
    (if p (delete-process p)))
  (if (timerp elpher-network-timer)
      (cancel-timer elpher-network-timer)))

(defvar elpher-use-tls nil
  "If non-nil, use TLS to communicate with gopher servers.")

(defun elpher-get-selector (address renderer &optional force-ipv4)
  "Retrieve selector specified by ADDRESS, then render it using RENDERER.
If FORCE-IPV4 is non-nil, explicitly look up and use IPv4 address corresponding
to ADDRESS."
  (when (equal (elpher-address-protocol address) "gophers")
    (if (gnutls-available-p)
        (when (not elpher-use-tls)
          (setq elpher-use-tls t)
          (message "Engaging TLS gopher mode."))
      (error "Cannot retrieve TLS gopher selector: GnuTLS not available")))
  (unless (< (elpher-address-port address) 65536)
    (error "Cannot retrieve gopher selector: port number > 65536"))
  (defvar gnutls-verify-error)
  (condition-case nil
      (let* ((kill-buffer-query-functions nil)
             (gnutls-verify-error nil) ; We use the NSM for verification
             (port (elpher-address-port address))
             (host (elpher-address-host address))
             (selector-string-parts nil)
             (bytes-received 0)
             (hkbytes-received 0)
             (proc (open-network-stream "elpher-process"
                                        nil
                                        (if (or elpher-ipv4-always force-ipv4)
                                            (dns-query host)
                                          host)
                                        (if (> port 0) port 70)
                                        :type (if elpher-use-tls 'tls 'plain)
                                        :nowait t))
             (timer (run-at-time elpher-connection-timeout
                                 nil
                                 (lambda ()
                                   (pcase (process-status proc)
                                     ('failed
                                      (if (and (not (equal (elpher-address-protocol address)
                                                           "gophers"))
                                               elpher-use-tls
                                               (or elpher-auto-disengage-TLS
                                                   (yes-or-no-p "Could not establish encrypted connection.  Disable TLS mode?")))
                                          (progn
                                            (message "Disabling TLS mode.")
                                            (setq elpher-use-tls nil)
                                            (elpher-get-selector address renderer))
                                        (elpher-network-error address "Could not establish encrypted connection")))
                                     ('connect
                                      (elpher-process-cleanup)
                                      (unless (or elpher-ipv4-always force-ipv4)
                                        (message "Connection timed out. Retrying with IPv4 address.")
                                        (elpher-get-selector address renderer t))))))))
        (setq elpher-network-timer timer)
        (set-process-coding-system proc 'binary)
        (set-process-filter proc
                            (lambda (_proc string)
                              (when timer
                                (cancel-timer timer)
                                (setq timer nil))
                              (setq bytes-received (+ bytes-received (length string)))
                              (let ((new-hkbytes-received (/ bytes-received 102400)))
                                (when (> new-hkbytes-received hkbytes-received)
                                  (setq hkbytes-received new-hkbytes-received)
                                  (with-current-buffer "*elpher*"
                                    (let ((inhibit-read-only t))
                                      (goto-char (point-min))
                                      (beginning-of-line 2)
                                      (delete-region (point) (point-max))
                                      (insert "("
                                              (number-to-string (/ hkbytes-received 10.0))
                                              " MB read)")))))
                              (setq selector-string-parts
                                    (cons string selector-string-parts))))
        (set-process-sentinel proc
                              (lambda (_proc event)
                                (condition-case the-error
                                    (cond
                                     ((string-prefix-p "deleted" event))
                                     ((string-prefix-p "open" event)
                                      (let ((inhibit-eol-conversion t))
                                        (process-send-string
                                         proc
                                         (concat (elpher-gopher-address-selector address)
                                                 "\r\n"))))
                                     (t
                                      (when timer
                                        (cancel-timer timer)
                                        (setq timer nil))
                                      (funcall renderer (apply #'concat
                                                               (reverse selector-string-parts)))
                                      (elpher-restore-pos)))
                                  (error
                                   (elpher-network-error address the-error))))))
    (error
     (error "Error initiating connection to server"))))

(defun elpher-get-gopher-page (renderer)
  "Getter function for gopher pages.
The RENDERER procedure is used to display the contents of the page
once they are retrieved from the gopher server."
  (let* ((address (elpher-page-address elpher-current-page))
         (content (elpher-get-cached-content address)))
    (if (and content (funcall renderer nil))
        (elpher-with-clean-buffer
         (insert content)
         (elpher-restore-pos))
      (elpher-with-clean-buffer
       (insert "LOADING... (use 'u' to cancel)\n"))
      (condition-case the-error
          (elpher-get-selector address renderer)
        (error
         (elpher-network-error address the-error))))))

;; Index rendering

(defun elpher-insert-index (string)
  "Insert the index corresponding to STRING into the current buffer."
  ;; Should be able to split directly on CRLF, but some non-conformant
  ;; LF-only servers sadly exist, hence the following.
  (let ((str-processed (elpher-preprocess-text-response string)))
    (dolist (line (split-string str-processed "\n"))
      (ignore-errors
        (unless (= (length line) 0)
          (let* ((type (elt line 0))
                 (fields (split-string (substring line 1) "\t"))
                 (display-string (elt fields 0))
                 (selector (elt fields 1))
                 (host (elt fields 2))
                 (port (if (elt fields 3)
                           (string-to-number (elt fields 3))
                         nil))
                 (address (elpher-make-gopher-address type selector host port)))
            (elpher-insert-index-record display-string address)))))))

(defun elpher-insert-margin (&optional type-name)
  "Insert index margin, optionally containing the TYPE-NAME, into the current buffer."
  (if type-name
      (progn
        (insert (format (concat "%" (number-to-string (- elpher-margin-width 1)) "s")
                        (concat
                         (propertize "[" 'face 'elpher-margin-brackets)
                         (propertize type-name 'face 'elpher-margin-key)
                         (propertize "]" 'face 'elpher-margin-brackets))))
        (insert " "))
    (insert (make-string elpher-margin-width ?\s))))

(defun elpher--page-button-help (_window buffer pos)
  "Function called by Emacs to generate mouse-over text.
The arguments specify the BUFFER and the POS within the buffer of the item
for which help is required.  The function returns the help to be
displayed.  The _WINDOW argument is currently unused."
  (with-current-buffer buffer
    (let ((button (button-at pos)))
      (when button
        (let* ((page (button-get button 'elpher-page))
               (address (elpher-page-address page)))
          (format "mouse-1, RET: open '%s'" (if (elpher-address-special-p address)
                                                address
                                              (elpher-address-to-url address))))))))

(defun elpher-insert-index-record (display-string &optional address)
  "Function to insert an index record into the current buffer.
The contents of the record are dictated by DISPLAY-STRING and ADDRESS.
If ADDRESS is not supplied or nil the record is rendered as an
'information' line."
  (let* ((type (if address (elpher-address-type address) nil))
         (type-map-entry (cdr (assoc type elpher-type-map))))
    (if type-map-entry
        (let* ((margin-code (elt type-map-entry 2))
               (face (elt type-map-entry 3))
               (filtered-display-string (ansi-color-filter-apply display-string))
               (page (elpher-make-page filtered-display-string address)))
          (elpher-insert-margin margin-code)
          (insert-text-button filtered-display-string
                              'face face
                              'elpher-page page
                              'action #'elpher-click-link
                              'follow-link t
                              'help-echo #'elpher--page-button-help))
      (pcase type
        ('nil ;; Information
         (elpher-insert-margin)
         (let ((propertized-display-string
                (propertize display-string 'face 'elpher-info)))
           (insert (elpher-process-text-for-display propertized-display-string))))
        (`(gopher ,selector-type) ;; Unknown
         (elpher-insert-margin (concat (char-to-string selector-type) "?"))
         (insert (propertize display-string
                             'face 'elpher-unknown)))))
    (insert "\n")))

(defun elpher-click-link (button)
  "Function called when the gopher link BUTTON is activated (via mouse or keypress)."
  (let ((page (button-get button 'elpher-page)))
    (elpher-visit-page page)))

(defun elpher-render-index (data &optional _mime-type-string)
  "Render DATA as an index.  MIME-TYPE-STRING is unused."
  (elpher-with-clean-buffer
   (if (not data)
       t
     (elpher-insert-index data)
     (elpher-cache-content (elpher-page-address elpher-current-page)
                           (buffer-string)))))

;; Text rendering

(defconst elpher-url-regex
  "\\([a-zA-Z]+\\)://\\([a-zA-Z0-9.\-]*[a-zA-Z0-9\-]\\|\[[a-zA-Z0-9:]+\]\\)\\(:[0-9]+\\)?\\(/\\([0-9a-zA-Z\-_~?/@|:.%#=&]*[0-9a-zA-Z\-_~?/@|#]\\)?\\)?"
  "Regexp used to locate and buttinofy URLs in text files loaded by elpher.")

(defun elpher-buttonify-urls (string)
  "Turn substrings which look like urls in STRING into clickable buttons."
  (with-temp-buffer
    (insert string)
    (goto-char (point-min))
    (while (re-search-forward elpher-url-regex nil t)
      (let ((page (elpher-make-page (substring-no-properties (match-string 0))
                                    (elpher-address-from-url (match-string 0)))))
          (make-text-button (match-beginning 0)
                            (match-end 0)
                            'elpher-page  page
                            'action #'elpher-click-link
                            'follow-link t
                            'help-echo #'elpher--page-button-help
                            'face 'button)))
    (buffer-string)))

(defconst elpher-ansi-regex "\x1b\\[[^m]*m"
  "Wildly incomplete regexp used to strip out some troublesome ANSI escape sequences.")

(defun elpher-process-text-for-display (string)
  "Perform any desired processing of STRING prior to display as text.
Currently includes buttonifying URLs and processing ANSI escape codes."
  (elpher-buttonify-urls (if elpher-filter-ansi-from-text
                             (ansi-color-filter-apply string)
                           (ansi-color-apply string))))

(defun elpher-render-text (data &optional _mime-type-string)
  "Render DATA as text.  MIME-TYPE-STRING is unused."
  (elpher-with-clean-buffer
   (if (not data)
       t
     (insert (elpher-process-text-for-display (elpher-preprocess-text-response data)))
     (elpher-cache-content
      (elpher-page-address elpher-current-page)
      (buffer-string)))))

;; Image retrieval

(defun elpher-render-image (data &optional _mime-type-string)
  "Display DATA as image.  MIME-TYPE-STRING is unused."
  (if (not data)
      nil
    (if (display-images-p)
        (progn
          (let ((image (create-image
                        data
                        nil t)))
            (elpher-with-clean-buffer
             (insert-image image)
             (elpher-restore-pos))))
      (elpher-render-download data))))

;; Search retrieval and rendering

(defun elpher-get-gopher-query-page (renderer)
  "Getter for gopher addresses requiring input.
The response is rendered using the rendering function RENDERER."
   (let* ((address (elpher-page-address elpher-current-page))
          (content (elpher-get-cached-content address))
          (aborted t))
    (if (and content (funcall renderer nil))
        (elpher-with-clean-buffer
         (insert content)
         (elpher-restore-pos)
         (message "Displaying cached search results.  Reload to perform a new search."))
      (unwind-protect
          (let* ((query-string (read-string "Query: "))
                 (query-selector (concat (elpher-gopher-address-selector address) "\t" query-string))
                 (search-address (elpher-make-gopher-address ?1
                                                             query-selector
                                                             (elpher-address-host address)
                                                             (elpher-address-port address)
                                                             (equal (elpher-address-type address) "gophers"))))
            (setq aborted nil)

            (elpher-with-clean-buffer
             (insert "LOADING RESULTS... (use 'u' to cancel)"))
            (elpher-get-selector search-address renderer))
        (if aborted
            (elpher-visit-previous-page))))))
 
;; Raw server response rendering

(defun elpher-render-raw (data &optional mime-type-string)
  "Display raw DATA in buffer.  MIME-TYPE-STRING is also displayed if provided."
  (if (not data)
      nil
    (elpher-with-clean-buffer
     (when mime-type-string
       (insert "MIME type specified by server: '" mime-type-string "'\n"))
     (insert data)
     (goto-char (point-min)))
    (message "Displaying raw server response.  Reload or redraw to return to standard view.")))

;; File save "rendering"

(defun elpher-render-download (data &optional _mime-type-string)
  "Save DATA to file.  MIME-TYPE-STRING is unused."
  (if (not data)
      nil
    (let* ((address (elpher-page-address elpher-current-page))
           (selector (if (elpher-address-gopher-p address)
                         (elpher-gopher-address-selector address)
                       (elpher-address-filename address))))
      (elpher-visit-previous-page) ; Do first in case of non-local exits.
      (let* ((filename-proposal (file-name-nondirectory selector))
             (filename (read-file-name "Download complete. Save file as: "
                                       nil nil nil
                                       (if (> (length filename-proposal) 0)
                                           filename-proposal
                                         "download.file"))))
        (let ((coding-system-for-write 'binary))
          (with-temp-file filename
            (insert data)))
        (message (format "Saved to file %s." filename))))))

;; HTML rendering

(defun elpher-render-html (data &optional _mime-type-string)
  "Render DATA as HTML using shr.  MIME-TYPE-STRING is unused."
  (elpher-with-clean-buffer
   (if (not data)
       t
     (let ((dom (with-temp-buffer
                  (insert data)
                  (libxml-parse-html-region (point-min) (point-max)))))
       (shr-insert-document dom)))))

;; Gemini page retrieval

(defvar elpher-gemini-redirect-chain)

(defun elpher-get-gemini-response (address renderer &optional force-ipv4)
  "Retrieve gemini ADDRESS, then render using RENDERER.
If FORCE-IPV4 is non-nil, explicitly look up and use IPv4 address corresponding
to ADDRESS."
  (unless elpher-gemini-TLS-cert-checks
    (setq-local network-security-level 'low))
  (if (not (gnutls-available-p))
      (error "Cannot establish gemini connection: GnuTLS not available")
    (unless (< (elpher-address-port address) 65536)
      (error "Cannot establish gemini connection: port number > 65536"))
    (defvar gnutls-verify-error)
    (condition-case nil
        (let* ((kill-buffer-query-functions nil)
               (gnutls-verify-error nil) ; We use the NSM for verification
               (port (elpher-address-port address))
               (host (elpher-address-host address))
               (response-string-parts nil)
               (bytes-received 0)
               (hkbytes-received 0)
               (proc (open-network-stream "elpher-process"
                                          nil
                                          (if (or elpher-ipv4-always force-ipv4)
                                              (dns-query host)
                                            host)
                                          (if (> port 0) port 1965)
                                          :type 'tls
                                          :nowait t))
               (timer (run-at-time elpher-connection-timeout nil
                                   (lambda ()
                                     (elpher-process-cleanup)
                                     (unless (or elpher-ipv4-always force-ipv4)
                                        ; Try again with IPv4
                                       (message "Connection timed out.  Retrying with IPv4.")
                                       (elpher-get-gemini-response address renderer t))))))
          (setq elpher-network-timer timer)
          (set-process-coding-system proc 'binary)
          (set-process-filter proc
                              (lambda (_proc string)
                                (when timer
                                  (cancel-timer timer)
                                  (setq timer nil))
                                (setq bytes-received (+ bytes-received (length string)))
                                (let ((new-hkbytes-received (/ bytes-received 102400)))
                                  (when (> new-hkbytes-received hkbytes-received)
                                    (setq hkbytes-received new-hkbytes-received)
                                    (with-current-buffer "*elpher*"
                                      (let ((inhibit-read-only t))
                                        (goto-char (point-min))
                                        (beginning-of-line 2)
                                        (delete-region (point) (point-max))
                                        (insert "("
                                                (number-to-string (/ hkbytes-received 10.0))
                                                " MB read)")))))
                                (setq response-string-parts
                                      (cons string response-string-parts))))
          (set-process-sentinel proc
                                (lambda (proc event)
                                  (condition-case the-error
                                      (cond
                                       ((string-prefix-p "open" event)    ; request URL
                                        (let ((inhibit-eol-conversion t))
                                          (process-send-string
                                           proc
                                           (concat (elpher-address-to-url address)
                                                   "\r\n"))))
                                       ((string-prefix-p "deleted" event)) ; do nothing
                                       ((and (not response-string-parts)
                                             (not (or elpher-ipv4-always force-ipv4)))
                                        ; Try again with IPv4
                                        (message "Connection failed. Retrying with IPv4.")
                                        (cancel-timer timer)
                                        (elpher-get-gemini-response address renderer t))
                                       (t
                                        (funcall #'elpher-process-gemini-response
                                                 (apply #'concat (reverse response-string-parts))
                                                 renderer)
                                        (elpher-restore-pos)))
                                    (error
                                     (elpher-network-error address the-error))))))
      (error
       (error "Error initiating connection to server")))))

(defun elpher-parse-gemini-response (response)
  "Parse the RESPONSE string and return a list of components.
The list is of the form (code meta body).  A response of nil implies
that the response was malformed."
  (let ((header-end-idx (string-match "\r\n" response)))
    (if header-end-idx
        (let ((header (string-trim (substring response 0 header-end-idx)))
              (body (substring response (+ header-end-idx 2))))
          (if (>= (length header) 2)
              (let ((code (substring header 0 2))
                    (meta (string-trim (substring header 2))))
                (list code meta body))
            (error "Malformed response: No response status found in header %s" header)))
      (error "Malformed response: No CRLF-delimited header found in response %s" response))))

(defun elpher-process-gemini-response (response-string renderer)
  "Process the gemini response RESPONSE-STRING and pass the result to RENDERER."
  (let ((response-components (elpher-parse-gemini-response response-string)))
    (let ((response-code (elt response-components 0))
          (response-meta (elt response-components 1))
          (response-body (elt response-components 2)))
      (pcase (elt response-code 0)
        (?1 ; Input required
         (elpher-with-clean-buffer
          (insert "Gemini server is requesting input."))
         (let* ((query-string (read-string (concat response-meta ": ")))
                (url (elpher-address-to-url (elpher-page-address elpher-current-page)))
                (query-address (elpher-address-from-url (concat url "?" query-string))))
           (elpher-get-gemini-response query-address renderer)))
        (?2 ; Normal response
         (funcall renderer response-body response-meta))
        (?3 ; Redirect
         (message "Following redirect to %s" response-meta)
         (if (>= (length elpher-gemini-redirect-chain) 5)
             (error "More than 5 consecutive redirects followed"))
         (let ((redirect-address (elpher-address-from-gemini-url response-meta)))
           (if (member redirect-address elpher-gemini-redirect-chain)
               (error "Redirect loop detected"))
           (if (not (string= (elpher-address-protocol redirect-address)
                             "gemini"))
               (error "Server tried to automatically redirect to non-gemini URL: %s"
                      response-meta))
           (elpher-page-set-address elpher-current-page redirect-address)
           (add-to-list 'elpher-gemini-redirect-chain redirect-address)
           (elpher-get-gemini-response redirect-address renderer)))
        (?4 ; Temporary failure
         (error "Gemini server reports TEMPORARY FAILURE for this request: %s %s"
                response-code response-meta))
        (?5 ; Permanent failure
         (error "Gemini server reports PERMANENT FAILURE for this request: %s %s"
                response-code response-meta))
        (?6 ; Client certificate required
         (error "Gemini server requires client certificate (unsupported at this time)"))
        (_other
         (error "Gemini server response unknown: %s %s"
                response-code response-meta))))))

(defun elpher-get-gemini-page (renderer)
  "Getter which retrieves and renders a Gemini page and renders it using RENDERER."
  (let* ((address (elpher-page-address elpher-current-page))
         (content (elpher-get-cached-content address)))
    (condition-case the-error
        (if (and content (funcall renderer nil))
            (elpher-with-clean-buffer
              (insert content)
              (elpher-restore-pos))
          (elpher-with-clean-buffer
           (insert "LOADING GEMINI... (use 'u' to cancel)\n"))
          (setq elpher-gemini-redirect-chain nil)
          (elpher-get-gemini-response address renderer))
      (error
       (elpher-network-error address the-error)))))


(defun elpher-render-gemini (body &optional mime-type-string)
  "Render gemini response BODY with rendering MIME-TYPE-STRING."
  (if (not body)
      t
    (let* ((mime-type-string* (if (or (not mime-type-string)
                                      (string-empty-p mime-type-string))
                                  "text/gemini; charset=utf-8"
                                mime-type-string))
           (mime-type-split (split-string mime-type-string* ";" t))
           (mime-type (string-trim (car mime-type-split)))
           (parameters (mapcar (lambda (s)
                                 (let ((key-val (split-string s "=")))
                                   (list (downcase (string-trim (car key-val)))
                                         (downcase (string-trim (cadr key-val))))))
                               (cdr mime-type-split))))
      (when (string-prefix-p "text/" mime-type)
        (setq body (decode-coding-string
                    body
                    (if (assoc "charset" parameters)
                        (intern (cadr (assoc "charset" parameters)))
                      'utf-8)))
        (setq body (replace-regexp-in-string "\r" "" body)))
      (pcase mime-type
        ((or "text/gemini" "")
         (elpher-render-gemini-map body parameters))
        ("text/html"
         (elpher-render-html body))
        ((pred (string-prefix-p "text/"))
         (elpher-render-gemini-plain-text body parameters))
        ((pred (string-prefix-p "image/"))
         (elpher-render-image body))
        (_other
         (elpher-render-download body))))))

(defun elpher-gemini-get-link-url (link-line)
  "Extract the url portion of LINK-LINE, a gemini map file link line.
Returns nil in the event that the contents of the line following the
=> prefix are empty."
  (let ((l (split-string (substring link-line 2))))
    (if l
        (string-trim (elt l 0))
      nil)))

(defun elpher-gemini-get-link-display-string (link-line)
  "Extract the display string portion of LINK-LINE, a gemini map file link line.
Returns the url portion in the event that the display-string portion is empty."
  (let* ((rest (string-trim (elt (split-string link-line "=>") 1)))
         (idx (string-match "[ \t]" rest)))
    (string-trim (if idx
                     (substring rest (+ idx 1))
                   rest))))

(defun elpher-collapse-dot-sequences (filename)
  "Collapse dot sequences in FILENAME.
For instance, the filename /a/b/../c/./d will reduce to /a/c/d"
  (let* ((path (split-string filename "/"))
         (path-reversed-normalized
          (seq-reduce (lambda (a b)
                        (cond ((and a (equal b "..") (cdr a)))
                              ((and (not a) (equal b "..")) a) ;leading .. are dropped
                              ((equal b ".") a)
                              (t (cons b a))))
                      path nil)))
    (string-join (reverse path-reversed-normalized) "/")))

(defun elpher-address-from-gemini-url (url)
  "Extract address from URL with defaults as per gemini map files."
  (let ((address (url-generic-parse-url url))
        (current-address (elpher-page-address elpher-current-page)))
    (unless (and (url-type address) (not (url-fullness address))) ;avoid mangling mailto: urls
      (setf (url-fullness address) t)
      (if (url-host address) ;if there is an explicit host, filenames are absolute
          (if (string-empty-p (url-filename address))
              (setf (url-filename address) "/")) ;ensure empty filename is marked as absolute
        (setf (url-host address) (url-host current-address))
        (setf (url-port address) (url-port current-address))
        (unless (string-prefix-p "/" (url-filename address)) ;deal with relative links
          (setf (url-filename address)
                (concat (file-name-directory (url-filename current-address))
                        (url-filename address)))))
      (unless (url-type address)
        (setf (url-type address) "gemini"))
      (if (equal (url-type address) "gemini")
          (setf (url-filename address)
                (elpher-collapse-dot-sequences (url-filename address)))))
    address))

(defun elpher-gemini-insert-link (link-line)
  "Insert link described by LINK-LINE into a text/gemini document."
  (let* ((url (elpher-gemini-get-link-url link-line))
         (display-string (elpher-gemini-get-link-display-string link-line))
         (address (elpher-address-from-gemini-url url))
         (type (if address (elpher-address-type address) nil))
         (type-map-entry (cdr (assoc type elpher-type-map))))
    (when display-string
      (insert elpher-gemini-link-string)
      (if type-map-entry
          (let* ((face (elt type-map-entry 3))
                 (filtered-display-string (ansi-color-filter-apply display-string))
                 (page (elpher-make-page filtered-display-string address)))
            (insert-text-button filtered-display-string
                                'face face
                                'elpher-page page
                                'action #'elpher-click-link
                                'follow-link t
                                'help-echo #'elpher--page-button-help))
        (insert (propertize display-string 'face 'elpher-unknown)))
      (insert "\n"))))
  
(defun elpher-gemini-insert-header (header-line)
  "Insert header described by HEADER-LINE into a text/gemini document.
The gemini map file line describing the header is given
by HEADER-LINE."
  (when (string-match "^\\(#+\\)[ \t]*" header-line)
    (let ((level (length (match-string 1 header-line)))
          (header (substring header-line (match-end 0))))
      (unless (display-graphic-p)
        (insert (make-string level ?#) " "))
      (insert (propertize header 'face
                          (pcase level
                            (1 'elpher-gemini-heading1)
                            (2 'elpher-gemini-heading2)
                            (3 'elpher-gemini-heading3)
                            (_ 'default)))
              "\n"))))

(defun elpher-gemini-insert-text (text-line)
  "Insert a plain non-preformatted TEXT-LINE into a text/gemini document.
This function uses Emacs' auto-fill to wrap text sensibly to a maximum
width defined by elpher-gemini-max-fill-width."
  (string-match "\\(^[ \t]*\\)\\(\*[ \t]\\)?" text-line)
  (let* ((processed-text-line (if (match-string 2 text-line)
                                  (concat
                                   (replace-regexp-in-string "\*"
                                                             elpher-gemini-bullet-string
                                                             (match-string 0 text-line))
                                   (substring text-line (match-end 0)))
                                text-line))
         (fill-prefix (if (match-string 1 text-line)
                          (replace-regexp-in-string "\*" " " (match-string 0 text-line))
                        nil)))
    (insert (elpher-process-text-for-display processed-text-line))
    (newline)))

(defun elpher-render-gemini-map (data _parameters)
  "Render DATA as a gemini map file, PARAMETERS is currently unused."
  (elpher-with-clean-buffer
   (let ((preformatted nil))
     (auto-fill-mode 1)
     (setq-local fill-column (min (window-width) elpher-gemini-max-fill-width))
     (dolist (line (split-string data "\n"))
       (cond
        ((string-prefix-p "```" line) (setq preformatted (not preformatted)))
        (preformatted (insert (elpher-process-text-for-display
                               (propertize line 'face 'elpher-gemini-preformatted))
                              "\n"))
        ((string-prefix-p "=>" line) (elpher-gemini-insert-link line))
        ((string-prefix-p "#" line) (elpher-gemini-insert-header line))
        (t (elpher-gemini-insert-text line)))))
   (elpher-cache-content
    (elpher-page-address elpher-current-page)
    (buffer-string))))

(defun elpher-render-gemini-plain-text (data _parameters)
  "Render DATA as plain text file.  PARAMETERS is currently unused."
  (elpher-with-clean-buffer
   (insert (elpher-process-text-for-display data))
   (elpher-cache-content
    (elpher-page-address elpher-current-page)
    (buffer-string))))

;; Finger page connection

(defun elpher-get-finger-page (renderer &optional force-ipv4)
  "Opens a finger connection to the current page address.
The result is rendered using RENDERER.  When the optional argument
FORCE-IPV4 or the variable `elpher-ipv4-always' are non-nil, the
IPv4 address returned by a DNS lookup will be used explicitly in
making the connection."
  (let* ((address (elpher-page-address elpher-current-page))
         (content (elpher-get-cached-content address)))
    (if (and content (funcall renderer nil))
        (elpher-with-clean-buffer
         (insert content)
         (elpher-restore-pos))
      (elpher-with-clean-buffer
       (insert "LOADING... (use 'u' to cancel)\n"))
      (condition-case the-error
          (let* ((kill-buffer-query-functions nil)
                 (user (let ((filename (elpher-address-filename address)))
                         (if (> (length filename) 1)
                             (substring filename 1)
                           (elpher-address-user address))))
                 (port (let ((given-port (elpher-address-port address)))
                         (if (> given-port 0) given-port 79)))
                 (host (elpher-address-host address))
                 (selector-string-parts nil)
                 (proc (open-network-stream "elpher-process"
                                            nil
                                            (if (or elpher-ipv4-always force-ipv4)
                                                (dns-query host)
                                              host)
                                            port
                                            :type 'plain
                                            :nowait t))
                 (timer (run-at-time elpher-connection-timeout
                                     nil
                                     (lambda ()
                                       (pcase (process-status proc)
                                         ('connect
                                          (elpher-process-cleanup)
                                          (unless (or elpher-ipv4-always force-ipv4)
                                            (message "Connection timed out. Retrying with IPv4 address.")
                                            (elpher-get-finger-page renderer t))))))))
            (setq elpher-network-timer timer)
            (set-process-coding-system proc 'binary)
            (set-process-filter proc
                                (lambda (_proc string)
                                  (when timer
                                    (cancel-timer timer)
                                    (setq timer nil))
                                  (setq selector-string-parts
                                        (cons string selector-string-parts))))
            (set-process-sentinel proc
                                  (lambda (_proc event)
                                    (condition-case _the-error
                                        (cond
                                         ((string-prefix-p "deleted" event))
                                         ((string-prefix-p "open" event)
                                          (let ((inhibit-eol-conversion t))
                                            (process-send-string
                                             proc
                                             (concat user "\r\n"))))
                                         (t
                                          (when timer
                                            (cancel-timer timer)
                                            (setq timer nil))
                                          (funcall renderer (apply #'concat
                                                                   (reverse selector-string-parts)))
                                          (elpher-restore-pos)))))))
        (error
         (elpher-network-error address the-error))))))


;; Other URL page opening

(defun elpher-get-other-url-page (renderer)
  "Getter which attempts to open the URL specified by the current page (RENDERER must be nil)."
  (when renderer
    (elpher-visit-previous-page)
    (error "Command not supported for general URLs"))
  (let* ((address (elpher-page-address elpher-current-page))
         (url (elpher-address-to-url address)))
    (progn
      (elpher-visit-previous-page) ; Do first in case of non-local exits.
      (message "Opening URL...")
      (if elpher-open-urls-with-eww
          (browse-web url)
        (browse-url url)))))

;; Telnet page connection

(defun elpher-get-telnet-page (renderer)
  "Opens a telnet connection to the current page address (RENDERER must be nil)."
  (when renderer
    (elpher-visit-previous-page)
    (error "Command not supported for telnet URLs"))
  (let* ((address (elpher-page-address elpher-current-page))
         (host (elpher-address-host address))
         (port (elpher-address-port address)))
    (elpher-visit-previous-page)
    (if (> port 0)
        (telnet host port)
      (telnet host))))

;; Start page page retrieval

(defun elpher-get-start-page (renderer)
  "Getter which displays the start page (RENDERER must be nil)."
  (when renderer
    (elpher-visit-previous-page)
    (error "Command not supported for start page"))
  (elpher-with-clean-buffer
   (insert "     --------------------------------------------\n"
           "           Elpher Gopher and Gemini Client       \n"
           "                   version " elpher-version "\n"
           "     --------------------------------------------\n"
           "\n"
           "Default bindings:\n"
           "\n"
           " - TAB/Shift-TAB: next/prev item on current page\n"
           " - RET/mouse-1: open item under cursor\n"
           " - m: select an item on current page by name (autocompletes)\n"
           " - u/mouse-3/U: return to previous page or to the start page\n"
           " - o/O: visit different selector or the root menu of the current server\n"
           " - g: go to a particular address (gopher, gemini, finger)\n"
           " - d/D: download item under cursor or current page\n"
           " - i/I: info on item under cursor or current page\n"
           " - c/C: copy URL representation of item under cursor or current page\n"
           " - a/A: bookmark the item under cursor or current page\n"
           " - x/X: remove bookmark for item under cursor or current page\n"
           " - B: visit the bookmarks page\n"
           " - r: redraw current page (using cached contents if available)\n"
           " - R: reload current page (regenerates cache)\n"
           " - S: set character coding system for gopher (default is to autodetect)\n"
           " - T: toggle TLS gopher mode\n"
           " - .: display the raw server response for the current page\n"
           "\n"
           "Start your exploration of gopher space and gemini:\n")
   (elpher-insert-index-record "Floodgap Systems Gopher Server"
                               (elpher-make-gopher-address ?1 "" "gopher.floodgap.com" 70))
   (elpher-insert-index-record "Project Gemini home page"
                               (elpher-address-from-url "gemini://gemini.circumlunar.space/"))
   (insert "\n"
           "Alternatively, select a search engine and enter some search terms:\n")
   (elpher-insert-index-record "Gopher Search Engine (Veronica-2)"
                               (elpher-make-gopher-address ?7 "/v2/vs" "gopher.floodgap.com" 70))
   (elpher-insert-index-record "Gemini Search Engine (GUS)"
                               (elpher-address-from-url "gemini://gus.guru/search"))
   (insert "\n"
           "This page contains your bookmarked sites (also visit with B):\n")
   (elpher-insert-index-record "Your Bookmarks" 'bookmarks)
   (insert "\n"
           "For Elpher release news or to leave feedback, visit:\n")
   (elpher-insert-index-record "The Elpher Project Page"
                               (elpher-make-gopher-address ?1
                                                           "/projects/elpher/"
                                                           "thelambdalab.xyz"
                                                           70))
   (insert "\n"
           "** Refer to the ")
   (let ((help-string "RET,mouse-1: Open Elpher info manual (if available)"))
     (insert-text-button "Elpher info manual"
                         'face 'link
                         'action (lambda (_)
                                   (interactive)
                                   (info "(elpher)"))
                         'follow-link t
                         'help-echo help-string))
   (insert " for the full documentation. **\n")
   (insert (propertize
            (concat "  (This should be available if you have installed Elpher using\n"
                    "   MELPA. Otherwise you will have to install the manual yourself.)\n")
            'face 'shadow))
   (elpher-restore-pos)))

;; Bookmarks page page retrieval

(defun elpher-get-bookmarks-page (renderer)
  "Getter to load and display the current bookmark list (RENDERER must be nil)."
  (when renderer
    (elpher-visit-previous-page)
    (error "Command not supported for bookmarks page"))
  (elpher-with-clean-buffer
   (insert "---- Bookmark list ----\n\n")
   (let ((bookmarks (elpher-load-bookmarks)))
     (if bookmarks
         (dolist (bookmark bookmarks)
           (let ((display-string (elpher-bookmark-display-string bookmark))
                 (address (elpher-address-from-url (elpher-bookmark-url bookmark))))
             (elpher-insert-index-record display-string address)))
       (insert "No bookmarks found.\n")))
   (insert "\n-----------------------\n"
           "\n"
           "- u: return to previous page\n"
           "- x: delete selected bookmark\n"
           "- a: rename selected bookmark\n"
           "\n"
           "Bookmarks are stored in the file ")
   (let ((filename elpher-bookmarks-file)
         (help-string "RET,mouse-1: Open bookmarks file in new buffer for editing."))
     (insert-text-button filename
                         'face 'link
                         'action (lambda (_)
                                   (interactive)
                                   (find-file filename))
                         'follow-link t
                         'help-echo help-string))
   (insert "\n")
   (elpher-restore-pos)))
  

;;; Bookmarks
;;

(defun elpher-make-bookmark (display-string url)
  "Make an elpher bookmark.
DISPLAY-STRING determines how the bookmark will appear in the
bookmark list, while URL is the url of the entry."
  (list display-string url))
  
(defun elpher-bookmark-display-string (bookmark)
  "Get the display string of BOOKMARK."
  (elt bookmark 0))

(defun elpher-set-bookmark-display-string (bookmark display-string)
  "Set the display string of BOOKMARK to DISPLAY-STRING."
  (setcar bookmark display-string))

(defun elpher-bookmark-url (bookmark)
  "Get the address for BOOKMARK."
  (elt bookmark 1))

(defun elpher-save-bookmarks (bookmarks)
  "Record the bookmark list BOOKMARKS to the user's bookmark file.
Beware that this completely replaces the existing contents of the file."
  (with-temp-file elpher-bookmarks-file
    (erase-buffer)
    (insert "; Elpher bookmarks file\n\n"
            "; Bookmarks are stored as a list of (label URL) items.\n"
            "; Feel free to edit by hand, but take care to ensure\n"
            "; the list structure remains intact.\n\n")
    (pp bookmarks (current-buffer))))

(defun elpher-load-bookmarks ()
  "Get the list of bookmarks from the users's bookmark file."
  (let ((bookmarks
         (with-temp-buffer
           (ignore-errors
             (insert-file-contents elpher-bookmarks-file)
             (goto-char (point-min))
             (read (current-buffer))))))
    (if (and bookmarks (listp (cadar bookmarks)))
        (progn
          (message "Reading old bookmark file. (Will be updated on write.)")
          (mapcar (lambda (old-bm)
                    (list (car old-bm)
                          (elpher-address-to-url (apply #'elpher-make-gopher-address
                                                        (cadr old-bm)))))
                  bookmarks))
      bookmarks)))

(defun elpher-add-address-bookmark (address display-string)
  "Save a bookmark for ADDRESS with label DISPLAY-STRING.)))
If ADDRESS is already bookmarked, update the label only."
  (let ((bookmarks (elpher-load-bookmarks))
        (url (elpher-address-to-url address)))
    (let ((existing-bookmark (rassoc (list url) bookmarks)))
      (if existing-bookmark
          (elpher-set-bookmark-display-string existing-bookmark display-string)
        (push (elpher-make-bookmark display-string url) bookmarks)))
    (elpher-save-bookmarks bookmarks)))

(defun elpher-remove-address-bookmark (address)
  "Remove any bookmark to ADDRESS."
  (let ((url (elpher-address-to-url address)))
    (elpher-save-bookmarks
     (seq-filter (lambda (bookmark)
                   (not (equal (elpher-bookmark-url bookmark) url)))
                 (elpher-load-bookmarks)))))

;;; Interactive procedures
;;

(defun elpher-next-link ()
  "Move point to the next link on the current page."
  (interactive)
  (forward-button 1))

(defun elpher-prev-link ()
  "Move point to the previous link on the current page."
  (interactive)
  (backward-button 1))

(defun elpher-follow-current-link ()
  "Open the link or url at point."
  (interactive)
  (push-button))

(defun elpher-go (host-or-url)
  "Go to a particular gopher site HOST-OR-URL.
When run interactively HOST-OR-URL is read from the minibuffer."
  (interactive "sGopher or Gemini URL: ")
  (let* ((cleaned-host-or-url (string-trim host-or-url))
         (address (elpher-address-from-url cleaned-host-or-url))
         (page (elpher-make-page cleaned-host-or-url address))) 
    (switch-to-buffer "*elpher*")
    (elpher-visit-page page)
    nil))

(defun elpher-go-current ()
  "Go to a particular site read from the minibuffer, initialized with the current URL."
  (interactive)
  (let ((address (elpher-page-address elpher-current-page)))
    (if (elpher-address-special-p address)
        (error "Command invalid for this page")
      (let ((url (read-string "Gopher or Gemini URL: " (elpher-address-to-url address))))
        (elpher-visit-page (elpher-make-page url (elpher-address-from-url url)))))))

(defun elpher-redraw ()
  "Redraw current page."
  (interactive)
  (elpher-visit-page elpher-current-page))

(defun elpher-reload ()
  "Reload current page."
  (interactive)
  (elpher-reload-current-page))

(defun elpher-toggle-tls ()
  "Toggle TLS encryption mode for gopher."
  (interactive)
  (setq elpher-use-tls (not elpher-use-tls))
  (if elpher-use-tls
      (if (gnutls-available-p)
          (message "TLS gopher mode enabled.  (Will not affect current page until reload.)")
        (setq elpher-use-tls nil)
        (error "Cannot enable TLS gopher mode: GnuTLS not available"))
    (message "TLS gopher mode disabled.  (Will not affect current page until reload.)")))

(defun elpher-view-raw ()
  "View raw server response for current page."
  (interactive)
  (if (elpher-address-special-p (elpher-page-address elpher-current-page))
      (error "This page was not generated by a server")
    (elpher-visit-page elpher-current-page
                       #'elpher-render-raw)))

(defun elpher-back ()
  "Go to previous site."
  (interactive)
  (elpher-visit-previous-page))

(defun elpher-back-to-start ()
  "Go all the way back to the start page."
  (interactive)
  (setq elpher-current-page nil)
  (setq elpher-history nil)
  (let ((start-page (elpher-make-page "Elpher Start Page"
                                      (elpher-make-special-address 'start))))
    (elpher-visit-page start-page)))

(defun elpher-download ()
  "Download the link at point."
  (interactive)
  (let ((button (button-at (point))))
    (if button
        (let ((page (button-get button 'elpher-page)))
          (if (elpher-address-special-p (elpher-page-address page))
              (error "Cannot download %s"
                     (elpher-page-display-string page))
            (elpher-visit-page (button-get button 'elpher-page)
                               #'elpher-render-download)))
      (error "No link selected"))))

(defun elpher-download-current ()
  "Download the current page."
  (interactive)
  (if (elpher-address-special-p (elpher-page-address elpher-current-page))
      (error "Cannot download %s"
             (elpher-page-display-string elpher-current-page))
    (elpher-visit-page (elpher-make-page
                        (elpher-page-display-string elpher-current-page)
                        (elpher-page-address elpher-current-page))
                       #'elpher-render-download
                       t)))

(defun elpher-build-link-map ()
  "Build alist mapping link names to destination pages in current buffer."
  (let ((link-map nil)
        (b (next-button (point-min) t)))
    (while b
      (push (cons (button-label b) b) link-map)
      (setq b (next-button (button-start b))))
    link-map))

(defun elpher-jump ()
  "Select a directory entry by name.  Similar to the info browser (m)enu command."
  (interactive)
  (let* ((link-map (elpher-build-link-map)))
    (if link-map
        (let ((key (let ((completion-ignore-case t))
                     (completing-read "Directory item/link: "
                                      link-map nil t))))
          (if (and key (> (length key) 0))
              (let ((b (cdr (assoc key link-map))))
                (goto-char (button-start b))
                (button-activate b)))))))

(defun elpher-root-dir ()
  "Visit root of current server."
  (interactive)
  (let ((address (elpher-page-address elpher-current-page)))
    (if (not (elpher-address-special-p address))
        (if (or (member (url-filename address) '("/" ""))
                (and (elpher-address-gopher-p address)
                     (= (length (elpher-gopher-address-selector address)) 0)))
            (error "Already at root directory of current server")
          (let ((address-copy (elpher-address-from-url
                               (elpher-address-to-url address))))
            (setf (url-filename address-copy) "")
            (elpher-go (elpher-address-to-url address-copy))))
      (error "Command invalid for %s" (elpher-page-display-string elpher-current-page)))))

(defun elpher-bookmarks-current-p ()
  "Return non-nil if current page is a bookmarks page."
  (equal (elpher-address-type (elpher-page-address elpher-current-page))
         '(special bookmarks)))

(defun elpher-reload-bookmarks ()
  "Reload bookmarks if current page is a bookmarks page."
  (if (elpher-bookmarks-current-p)
      (elpher-reload-current-page)))

(defun elpher-bookmark-current ()
  "Bookmark the current page."
  (interactive)
  (let ((address (elpher-page-address elpher-current-page))
        (display-string (elpher-page-display-string elpher-current-page)))
    (if (not (elpher-address-special-p address))
        (let ((bookmark-display-string (read-string "Bookmark display string: "
                                                    display-string)))
          (elpher-add-address-bookmark address bookmark-display-string)
          (message "Bookmark added."))
      (error "Cannot bookmark %s" display-string))))

(defun elpher-bookmark-link ()
  "Bookmark the link at point."
  (interactive)
  (let ((button (button-at (point))))
    (if button
        (let* ((page (button-get button 'elpher-page))
               (address (elpher-page-address page))
               (display-string (elpher-page-display-string page)))
          (if (not (elpher-address-special-p address))
              (let ((bookmark-display-string (read-string "Bookmark display string: "
                                                          display-string)))
                (elpher-add-address-bookmark address bookmark-display-string)
                (elpher-reload-bookmarks)
                (message "Bookmark added."))
            (error "Cannot bookmark %s" display-string)))
      (error "No link selected"))))

(defun elpher-unbookmark-current ()
  "Remove bookmark for the current page."
  (interactive)
  (let ((address (elpher-page-address elpher-current-page)))
    (when (and (not (elpher-address-special-p address))
               (y-or-n-p "Really remove bookmark for the current page? "))
      (elpher-remove-address-bookmark address)
      (message "Bookmark removed."))))

(defun elpher-unbookmark-link ()
  "Remove bookmark for the link at point."
  (interactive)
  (let ((button (button-at (point))))
    (if button
        (when (y-or-n-p "Really remove bookmark for this link? ")
          (let ((page (button-get button 'elpher-page)))
            (elpher-remove-address-bookmark (elpher-page-address page))
            (elpher-reload-bookmarks)
            (message "Bookmark removed.")))
      (error "No link selected"))))

(defun elpher-bookmarks ()
  "Visit bookmarks page."
  (interactive)
  (switch-to-buffer "*elpher*")
  (elpher-visit-page
   (elpher-make-page "Bookmarks Page" (elpher-make-special-address 'bookmarks))))

(defun elpher-info-page (page)
  "Display information on PAGE."
  (let ((display-string (elpher-page-display-string page))
        (address (elpher-page-address page)))
    (if (elpher-address-special-p address)
        (message "Special page: %s" display-string)
      (message "%s" (elpher-address-to-url address)))))

(defun elpher-info-link ()
  "Display information on page corresponding to link at point."
  (interactive)
  (let ((button (button-at (point))))
    (if button
        (elpher-info-page (button-get button 'elpher-page))
      (error "No item selected"))))
  
(defun elpher-info-current ()
  "Display information on current page."
  (interactive)
  (elpher-info-page elpher-current-page))

(defun elpher-copy-page-url (page)
  "Copy URL representation of address of PAGE to `kill-ring'."
  (let ((address (elpher-page-address page)))
    (if (elpher-address-special-p address)
        (error (format "Cannot represent %s as URL" (elpher-page-display-string page)))
      (let ((url (elpher-address-to-url address)))
        (message "Copied \"%s\" to kill-ring/clipboard." url)
        (kill-new url)))))

(defun elpher-copy-link-url ()
  "Copy URL of item at point to `kill-ring'."
  (interactive)
  (let ((button (button-at (point))))
    (if button
        (elpher-copy-page-url (button-get button 'elpher-page))
      (error "No item selected"))))

(defun elpher-copy-current-url ()
  "Copy URL of current page to `kill-ring'."
  (interactive)
  (elpher-copy-page-url elpher-current-page))

(defun elpher-set-gopher-coding-system ()
  "Specify an explicit character coding system for gopher selectors."
  (interactive)
  (let ((system (read-coding-system "Set coding system to use for gopher (default is to autodetect): " nil)))
    (setq elpher-user-coding-system system)
    (if system
        (message "Gopher coding system fixed to %s. (Reload to see effect)." system)
      (message "Gopher coding system set to autodetect. (Reload to see effect)."))))


;;; Mode and keymap
;;

(defvar elpher-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") 'elpher-next-link)
    (define-key map (kbd "<backtab>") 'elpher-prev-link)
    (define-key map (kbd "C-M-i") 'elpher-prev-link)
    (define-key map (kbd "u") 'elpher-back)
    (define-key map (kbd "U") 'elpher-back-to-start)
    (define-key map [mouse-3] 'elpher-back)
    (define-key map (kbd "O") 'elpher-root-dir)
    (define-key map (kbd "g") 'elpher-go)
    (define-key map (kbd "o") 'elpher-go-current)
    (define-key map (kbd "r") 'elpher-redraw)
    (define-key map (kbd "R") 'elpher-reload)
    (define-key map (kbd "T") 'elpher-toggle-tls)
    (define-key map (kbd ".") 'elpher-view-raw)
    (define-key map (kbd "d") 'elpher-download)
    (define-key map (kbd "D") 'elpher-download-current)
    (define-key map (kbd "m") 'elpher-jump)
    (define-key map (kbd "i") 'elpher-info-link)
    (define-key map (kbd "I") 'elpher-info-current)
    (define-key map (kbd "c") 'elpher-copy-link-url)
    (define-key map (kbd "C") 'elpher-copy-current-url)
    (define-key map (kbd "a") 'elpher-bookmark-link)
    (define-key map (kbd "A") 'elpher-bookmark-current)
    (define-key map (kbd "x") 'elpher-unbookmark-link)
    (define-key map (kbd "X") 'elpher-unbookmark-current)
    (define-key map (kbd "B") 'elpher-bookmarks)
    (define-key map (kbd "S") 'elpher-set-gopher-coding-system)
    (when (fboundp 'evil-define-key*)
      (evil-define-key* 'motion map
        (kbd "TAB") 'elpher-next-link
        (kbd "C-") 'elpher-follow-current-link
        (kbd "C-t") 'elpher-back
        (kbd "u") 'elpher-back
        (kbd "U") 'elpher-back-to-start
        [mouse-3] 'elpher-back
        (kbd "g") 'elpher-go
        (kbd "o") 'elpher-go-current
        (kbd "r") 'elpher-redraw
        (kbd "R") 'elpher-reload
        (kbd "T") 'elpher-toggle-tls
        (kbd ".") 'elpher-view-raw
        (kbd "d") 'elpher-download
        (kbd "D") 'elpher-download-current
        (kbd "m") 'elpher-jump
        (kbd "i") 'elpher-info-link
        (kbd "I") 'elpher-info-current
        (kbd "c") 'elpher-copy-link-url
        (kbd "C") 'elpher-copy-current-url
        (kbd "a") 'elpher-bookmark-link
        (kbd "A") 'elpher-bookmark-current
        (kbd "x") 'elpher-unbookmark-link
        (kbd "X") 'elpher-unbookmark-current
        (kbd "B") 'elpher-bookmarks
        (kbd "S") 'elpher-set-gopher-coding-system))
    map)
  "Keymap for gopher client.")

(define-derived-mode elpher-mode special-mode "elpher"
  "Major mode for elpher, an elisp gopher client.

This mode is automatically enabled by the interactive
functions which initialize the gopher client, namely
`elpher', `elpher-go' and `elpher-bookmarks'.")

(when (fboundp 'evil-set-initial-state)
  (evil-set-initial-state 'elpher-mode 'motion))


;;; Main start procedure
;;

;;;###autoload
(defun elpher ()
  "Start elpher with default landing page."
  (interactive)
  (if (get-buffer "*elpher*")
      (switch-to-buffer "*elpher*")
    (switch-to-buffer "*elpher*")
    (setq elpher-current-page nil)
    (setq elpher-history nil)
    (let ((start-page (elpher-make-page "Elpher Start Page"
                                        (elpher-make-special-address 'start))))
      (elpher-visit-page start-page)))
  "Started Elpher.") ; Otherwise (elpher) evaluates to start page string.

;;; elpher.el ends here
