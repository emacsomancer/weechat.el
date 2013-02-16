(require 'ert)

;;; weechat-relay.el

(ert-deftest weechat-relay-id-callback ()
  (let ((weechat--relay-id-callback-hash
         (copy-hash-table weechat--relay-id-callback-hash)))
    (let ((fun (lambda (_) nil)) )
      (weechat-relay-add-id-callback "23" fun)
      (should (equal fun (weechat-relay-get-id-callback "23")))
      (should (equal fun (weechat-relay-remove-id-callback "23"))))
    (clrhash weechat--relay-id-callback-hash)
    (should-error (progn (weechat-relay-add-id-callback "42" (lambda ()))
                         (weechat-relay-add-id-callback "42" (lambda ()))))))

(ert-deftest weechat-relay-id-callback-one-shot ()
  (let ((weechat--relay-id-callback-hash
         (copy-hash-table weechat--relay-id-callback-hash)))
    (let ((fun (lambda (_) nil)))
      (weechat-relay-add-id-callback "23" fun 'one-shot)
      (funcall (weechat-relay-get-id-callback "23") nil)
      (should (equal nil (weechat-relay-get-id-callback "23"))))))

(ert-deftest weechat-test-message-fns ()
  (let ((message '("42" ("version" . "0.3.8"))))
    (should (equal "42" (weechat--message-id message)))
    (should (equal '("version" . "0.3.8") (car (weechat--message-data message))))))

(ert-deftest weechat-test-hdata-fns ()
  (let ((hdata '("foo/bar"
                 ((("0x155f870" "0xffffff")
                   ("title" . "IRC: irc.euirc.net/6667 (83.137.41.33)")
                   ("short_name" . "euirc")
                   ("name" . "server.euirc"))
                  (("0x1502940")
                   ("title" . "IRC: irc.freenode.net/6697 (174.143.119.91)")
                   ("short_name" . "freenode")
                   ("name" . "server.freenode"))))))
    (should (equal "foo/bar" (weechat--hdata-path hdata)))
    (should (listp (weechat--hdata-values hdata)))
    (should (equal '(("0x155f870" "0xffffff") ("0x1502940"))
                   (mapcar #'weechat--hdata-value-pointer-path (weechat--hdata-values hdata))))
    (should (equal '((("title" . "IRC: irc.euirc.net/6667 (83.137.41.33)")
                      ("short_name" . "euirc")
                      ("name" . "server.euirc"))
                     (("title" . "IRC: irc.freenode.net/6697 (174.143.119.91)")
                      ("short_name" . "freenode")
                      ("name" . "server.freenode")))
                   (mapcar #'weechat--hdata-value-alist (weechat--hdata-values hdata))))))

(ert-deftest weechat-test-infolist ()
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert (concat [0 0 0 32 0 255 255 255 255 105 110 102 0 0
                       0 7 118 101 114 115 105 111 110 0 0 0 5
                       48 46 51 46 56]))
    (let ((data (weechat--relay-parse-new-message (current-buffer))))
      (should (equal ""  (weechat--message-id data)))
      (should (equal '("version" . "0.3.8")
                     (car (weechat--message-data data)))))))


(ert-deftest weechat-test-id ()
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert (concat [0 0 0 35 0 0 0 0 3 54 54 54 105 110 102 0
                       0 0 7 118 101 114 115 105 111 110 0 0 0
                       5 48 46 51 46 56]))
    (let ((data (weechat--relay-parse-new-message (current-buffer))))
      (should (equal "666" (weechat--message-id data)))
      (should (equal '("version" . "0.3.8")
                     (car (weechat--message-data data)))))))

(ert-deftest weechat-relay-test-connection ()
  (when (weechat-relay-connected-p)
    (let ((info-data nil)
          (info-id (symbol-name (cl-gensym))))
      (weechat-relay-add-id-callback info-id (lambda (data) (setq info-data data)) t)
      (weechat--relay-send-message "info version" info-id)
      (while (not info-data)
        (sleep-for 0 50))
      (should (equal "version" (caar info-data))))))

(ert-deftest weechat-relay-test-test-command ()
  (when (weechat-relay-connected-p)
    (let ((data nil)
          (id (symbol-name (cl-gensym))))
      (weechat-relay-add-id-callback id (lambda (d) (setq data d)) t)
      (weechat--relay-send-message "test" id)
      (while (not data)
        (sleep-for 0 50))
      (message "%S" data)
      (should (equal ?A (nth 0 data)))
      (should (equal 123456 (nth 1 data)))
      (should (equal 1234567890 (nth 2 data)))
      (should (equal "a string" (nth 3 data)))
      (should (equal "" (nth 4 data)))
      (should (equal "" (nth 5 data)))
      (should (equal [98 117 102 102 101 114] (nth 6 data)))
      (should (equal [] (nth 7 data)))
      ;; (should (equal "0x1234abcd" (nth 8 data)))
      (should (equal (seconds-to-time 1321993456) (nth 9 data)))
      (should (equal '("abc" "de") (nth 10 data)))
      (should (equal '(123 456 789) (nth 11 data))))))

;;; weechat.el

(ert-deftest weechat-test-buffer-store ()
  (let ((weechat--buffer-hashes (copy-hash-table weechat--buffer-hashes)))
    (weechat--clear-buffer-store)
    (should (eql 0 (hash-table-count weechat--buffer-hashes)))
    (let ((data '(("name" . "Foobar"))))
      (weechat--store-buffer-hash "0xffffff" data)
      (should (eq (cdar data)
                  (gethash "name" (weechat-buffer-hash "0xffffff")))))
    (weechat--remove-buffer-hash "0xffffff")
    (should (not (weechat-buffer-hash "0xffffff")))))

(ert-deftest weechat-color-stripping ()
  (should (equal (weechat-strip-formatting
                  "F14someone282728F05 has joined 13#asdfasdfasdfF05")
                 "someone has joined #asdfasdfasdf"))
  (should (equal (weechat-strip-formatting "ddd") "ddd")))

(ert-deftest weechat-color-handling ()
  "Test `weechat-handle-color-codes'."
  (should (string= (weechat-handle-color-codes "foo bar baz")
                   "foo bar baz"))
  (should (string= (weechat-handle-color-codes "\x19\F*02hi\x1C \x19\F/04world")
                   "hi world")))
