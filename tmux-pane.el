;;; tmux-pane.el --- Provide integration between emacs window and tmux pane  -*- lexical-binding: t; -*-

;; Copyright (C) 2018

;; URL: https://github.com/laishulu/emacs-tmux-pane
;; Created: November 1, 2018
;; Keywords: convenience, terminals, tmux, window, pane, navigation, integration
;; Package-Requires: ((names "0.5") (emacs "24") (s "0") (dash "0"))
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;; This package provide integration between emacs window and tmux pane.
;;; For more information see the README in the github repo.

;;; Code:
(require 's)
(require 'dash)

;; `define-namespace' is autoloaded, so there's no need to require
;; `names'. However, requiring it here means it will also work for
;; people who don't install through package.el.
(eval-when-compile (require 'names))

(define-namespace tmux-pane-

(defcustom vertical-percent 25
  "horizontal percent of the vertical pane"
  :type 'integer
  :group 'tmux-pane)

(defcustom horizontal-percent 25
  "horizontal percent of the horizontal pane"
  :type 'integer
  :group 'tmux-pane)

(defcustom ensure-run-on-current-pane t
  "When `t` ensure that the command is running on current pane.
This means that when running emacsclient on multiple tmux sessions tmux commands
will not always run in the original session (i.e: tmux session that started emacsclient)."
  :type 'boolean
  :group 'tmux-pane)

(defun format-with-right-pane (cmd &rest args)
  (if-let ((current-pane (and ensure-run-on-current-pane
                              (->> (selected-frame)
                                   frame-parameters
                                   (assq 'environment)
                                   cdr
                                   (--filter (s-starts-with? "TMUX_PANE=" it))
                                   car
                                   (s-chop-prefix "TMUX_PANE=")))))
      (apply #'format (s-concat cmd " -t %s") (append args (list current-pane)))
    cmd))

(defun get-inactive-pane ()
  (when-let* ((inactive-panes (->> (format-with-right-pane "tmux list-panes -F \"#{pane_id}:#{pane_active}\"")
                                   shell-command-to-string
                                   s-trim
                                   s-lines
                                   (--filter (s-ends-with? ":0" it))
                                   (--map (s-chop-suffix ":0" it)))))
    (and (= 1 (length inactive-panes))
         (car inactive-panes))))

(defun number-of-panes-in-window ()
  (->> (format-with-right-pane "tmux list-panes")
       shell-command-to-string
       s-trim
       s-lines
       length))

:autoload
(defun -windmove(dir tmux-cmd)
  (interactive)
  (if (ignore-errors (funcall (intern (concat "windmove-" dir))))
      nil                       ; Moving within emacs
    (shell-command tmux-cmd)))  ; At edges, send command to tmux

:autoload
(defun open-vertical ()
  (interactive)
  (shell-command (format-with-right-pane "tmux split-window -h -p %s" vertical-percent)))

:autoload
(defun open-horizontal ()
  (interactive)
  (shell-command (format-with-right-pane "tmux split-window -v -p %s" horizontal-percent)))

:autoload
(defun close ()
  (interactive)
  (if-let ((terminal-pane (get-inactive-pane)))
      (shell-command (format "tmux kill-pane -t %s" terminal-pane))
    (message "Can `close` only when there are exactly two panes in the current window")))

:autoload
(defun rerun ()
  (interactive)
  (if-let ((terminal-pane (get-inactive-pane)))
      (progn
        (shell-command (format "tmux send-keys -t %s C-c" terminal-pane))
        (shell-command (format "tmux send-keys -t %s !! Enter" terminal-pane)))
    (message "Can `rerun` only when there's exactly two panes in the current window")))

:autoload
(defun toggle-vertical()
  (interactive)
  (let ((number-of-panes (number-of-panes-in-window)))
    (cond
     ((< 2 number-of-panes) (message "Can `toggle` only when there's at most 2 panes in the current window"))
     ((= 1 number-of-panes) (open-vertical))
     (t
      (close)
      (open-vertical)))))

:autoload
(defun toggle-horizontal()
  (interactive)
  (let ((number-of-panes (number-of-panes-in-window)))
    (cond
     ((< 2 number-of-panes) (message "Can `toggle-` only when there's at most two panes in the current window"))
     ((= 1 number-of-panes) (open-horizontal))
     (t
      (close)
      (open-horizontal)))))

;; end of namespace
)

(defvar tmux-pane-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-k")
      (lambda () (interactive) (tmux-pane--windmove "up"  (tmux-pane-format-with-right-pane "tmux select-pane -U"))))
    (define-key map (kbd "C-j")
      (lambda () (interactive) (tmux-pane--windmove "down"  (tmux-pane-format-with-right-pane "tmux select-pane -D"))))
    (define-key map (kbd "C-h")
      (lambda () (interactive) (tmux-pane--windmove "left" (tmux-pane-format-with-right-pane "tmux select-pane -L"))))
    (define-key map (kbd "C-l")
      (lambda () (interactive) (tmux-pane--windmove "right" (tmux-pane-format-with-right-pane "tmux select-pane -R"))))
    map))

(define-minor-mode tmux-pane-mode
  "Seamlessly navigate between tmux pane and emacs window"
  :init-value nil
  :global t
  :keymap 'tmux-pane-mode-map)

(provide 'tmux-pane)
;;; tmux-pane.el ends here
