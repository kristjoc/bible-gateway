;;; bible-gateway.el --- A Simple BibleGateway Client -*- lexical-binding: t -*-

;; Copyright (C) 2026 Kristjon Ciko

;; Author: Kristjon Ciko
;; Keywords: convenience comm hypermedia
;; Homepage: https://github.com/kristjoc/bible-gateway
;; Package-Requires: ((emacs "29.1"))
;; Package-Version: 1.5

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; bible-gateway is a simple package that fetches the verse of the
;; day, as well as any requested verse, passage, and chapter in both
;; text and audio format from https://BibleGateway.com
;;
;; Usage:
;;
;; `bible-gateway-get-verse' fetches the verse of the day for use as
;; an emacs-dashboard footer or a scratch buffer message.
;;
;; M-x `bible-gateway-get-passage' fetches a Bible passage and inserts
;; it at point. It can be called both interactively from
;; \\[execute-extended-command] or programmatically with the book name
;; and verse(s) as arguments.
;;
;; M-x `bible-gateway-listen-passage' plays a Bible chapter from KJV
;; Zondervan Audio in the browser.

;;; Code:

(require 'url)
(require 'json)
(require 'cl-lib)

(defgroup bible-gateway nil
  "Package that fetches the Bible verse of the day from BibleGateway."
  :group 'external)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                           Customizable variables                           ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom bible-gateway-bible-version "KJV"
  "The Bible version, default KJV.
Other supported versions, which are available in the Public Domain, are
LSG in French, RVA in Spanish, ALB in Albanian, UKR in Ukrainian, RUSV
in Russian, LUTH1545 in German and UBG in Polish (New Testament + Proverbs + Psalms)."
  :type 'string)

(defcustom bible-gateway-text-width 80
  "The width of the verse of the day body in number of characters, default 80."
  :type 'natnum)

(defcustom bible-gateway-fallback-verse "For God so loved the world,
that he gave his only begotten Son,
that whosoever believeth in him should not perish,
but have everlasting life."
  "The fallback verse to use when the online request fails."
  :type 'string)

(defcustom bible-gateway-fallback-reference "John 3:16"
  "The reference for the fallback verse."
  :type 'string)

(defcustom bible-gateway-request-timeout 3
  "The timeout for the URL request in seconds."
  :type 'integer)

(defcustom bible-gateway-include-ref t
  "If non-nil, print the reference (e.g., \"John 3 (KJV)\") with the passage."
  :type 'boolean)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Bible books in supported languages                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst bible-gateway-bible-books-kjv
  '(("Genesis" . 50) ("Exodus" . 40) ("Leviticus" . 27) ("Numbers" . 36)
    ("Deuteronomy" . 34) ("Joshua" . 24) ("Judges" . 21) ("Ruth" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("1 Kings" . 22) ("2 Kings" . 25)
    ("1 Chronicles" . 29) ("2 Chronicles" . 36) ("Ezra" . 10) ("Nehemiah" . 13)
    ("Esther" . 10) ("Job" . 42) ("Psalms" . 150) ("Proverbs" . 31)
    ("Ecclesiastes" . 12) ("Song of Solomon" . 8) ("Isaiah" . 66) ("Jeremiah" . 52)
    ("Lamentations" . 5) ("Ezekiel" . 48) ("Daniel" . 12) ("Hosea" . 14)
    ("Joel" . 3) ("Amos" . 9) ("Obadiah" . 1) ("Jonah" . 4) ("Micah" . 7)
    ("Nahum" . 3) ("Habakkuk" . 3) ("Zephaniah" . 3) ("Haggai" . 2)
    ("Zechariah" . 14) ("Malachi" . 4) ("Matthew" . 28) ("Mark" . 16)
    ("Luke" . 24) ("John" . 21) ("Acts" . 28) ("Romans" . 16)
    ("1 Corinthians" . 16) ("2 Corinthians" . 13) ("Galatians" . 6)
    ("Ephesians" . 6) ("Philippians" . 4) ("Colossians" . 4)
    ("1 Thessalonians" . 5) ("2 Thessalonians" . 3) ("1 Timothy" . 6)
    ("2 Timothy" . 4) ("Titus" . 3) ("Philemon" . 1) ("Hebrews" . 13)
    ("James" . 5) ("1 Peter" . 5) ("2 Peter" . 3) ("1 John" . 5)
    ("2 John" . 1) ("3 John" . 1) ("Jude" . 1) ("Revelation" . 22))
  "List of Bible books (KJV version) with their number of chapters.")

(defconst bible-gateway-bible-books-lsg
  '(("Genèse" . 50) ("Exode" . 40) ("Lévitique" . 27) ("Nombres" . 36)
    ("Deutéronome" . 34) ("Josué" . 24) ("Juges" . 21) ("Ruth" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("1 Rois" . 22) ("2 Rois" . 25)
    ("1 Chroniques" . 29) ("2 Chroniques" . 36) ("Esdras" . 10) ("Néhémie" . 13)
    ("Esther" . 10) ("Job" . 42) ("Psaumes" . 150) ("Proverbes" . 31)
    ("Ecclésiaste" . 12) ("Cantique des Cantiques" . 8) ("Ésaïe" . 66) ("Jérémie" . 52)
    ("Lamentations" . 5) ("Ézéchiel" . 48) ("Daniel" . 12) ("Osée" . 14)
    ("Joël" . 3) ("Amos" . 9) ("Abdias" . 1) ("Jonas" . 4) ("Michée" . 7)
    ("Nahum" . 3) ("Habacuc" . 3) ("Sophonie" . 3) ("Aggée" . 2)
    ("Zacharie" . 14) ("Malachie" . 4) ("Matthieu" . 28) ("Marc" . 16)
    ("Luc" . 24) ("Jean" . 21) ("Actes" . 28) ("Romains" . 16)
    ("1 Corinthiens" . 16) ("2 Corinthiens" . 13) ("Galates" . 6)
    ("Éphésiens" . 6) ("Philippiens" . 4) ("Colossiens" . 4)
    ("1 Thessaloniciens" . 5) ("2 Thessaloniciens" . 3) ("1 Timothée" . 6)
    ("2 Timothée" . 4) ("Tite" . 3) ("Philémon" . 1) ("Hébreux" . 13)
    ("Jacques" . 5) ("1 Pierre" . 5) ("2 Pierre" . 3) ("1 Jean" . 5)
    ("2 Jean" . 1) ("3 Jean" . 1) ("Jude" . 1) ("Apocalypse" . 22))
  "List of Bible books (LSG version) with their number of chapters.")

(defconst bible-gateway-bible-books-rva
  '(("Génesis" . 50) ("Éxodo" . 40) ("Levítico" . 27) ("Números" . 36)
    ("Deuteronomio" . 34) ("Josué" . 24) ("Jueces" . 21) ("Rut" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("1 Reyes" . 22) ("2 Reyes" . 25)
    ("1 Crónicas" . 29) ("2 Crónicas" . 36) ("Esdras" . 10) ("Nehemías" . 13)
    ("Ester" . 10) ("Job" . 42) ("Salmos" . 150) ("Proverbios" . 31)
    ("Eclesiastés" . 12) ("Cantares" . 8) ("Isaías" . 66) ("Jeremías" . 52)
    ("Lamentaciones" . 5) ("Ezequiel" . 48) ("Daniel" . 12) ("Oseas" . 14)
    ("Joel" . 3) ("Amós" . 9) ("Abdías" . 1) ("Jonás" . 4) ("Miqueas" . 7)
    ("Nahúm" . 3) ("Habacuc" . 3) ("Sofonías" . 3) ("Hageo" . 2)
    ("Zacarías" . 14) ("Malaquías" . 4) ("Mateo" . 28) ("Marcos" . 16)
    ("Lucas" . 24) ("Juan" . 21) ("Hechos" . 28) ("Romanos" . 16)
    ("1 Corintios" . 16) ("2 Corintios" . 13) ("Gálatas" . 6)
    ("Efesios" . 6) ("Filipenses" . 4) ("Colosenses" . 4)
    ("1 Tesalonicenses" . 5) ("2 Tesalonicenses" . 3) ("1 Timoteo" . 6)
    ("2 Timoteo" . 4) ("Tito" . 3) ("Filemón" . 1) ("Hebreos" . 13)
    ("Santiago" . 5) ("1 Pedro" . 5) ("2 Pedro" . 3) ("1 Juan" . 5)
    ("2 Juan" . 1) ("3 Juan" . 1) ("Judas" . 1) ("Apocalipsis" . 22))
  "List of Bible books (RVA version) with their number of chapters.")

(defconst bible-gateway-bible-books-alb
  '(("Zanafilla" . 50) ("Eksodi" . 40) ("Levitiku" . 27) ("Numrat" . 36)
    ("Ligji i Përtërirë" . 34) ("Jozueu" . 24) ("Gjyqtarët" . 21) ("Ruthi" . 4)
    ("1 i Samuelit" . 31) ("2 i Samuelit" . 24) ("1 i Mbretërve" . 22) ("2 i Mbretërve" . 25)
    ("1 i Kronikave" . 29) ("2 i Kronikave" . 36) ("Esdra" . 10) ("Nehemia" . 13)
    ("Ester" . 10) ("Jobi" . 42) ("Psalmet" . 150) ("Fjalët e urta" . 31)
    ("Predikuesi" . 12) ("Kantiku i Kantikëve" . 8) ("Isaia" . 66) ("Jeremia" . 52)
    ("Vajtimet" . 5) ("Ezekieli" . 48) ("Danieli" . 12) ("Osea" . 14)
    ("Joeli" . 3) ("Amosi" . 9) ("Abdia" . 1) ("Jona" . 4) ("Mikea" . 7)
    ("Nahumi" . 3) ("Habakuku" . 3) ("Sofonia" . 3) ("Hagai" . 2)
    ("Zakaria" . 14) ("Malakia" . 4) ("Mateu" . 28) ("Marku" . 16)
    ("Luka" . 24) ("Gjoni" . 21) ("Veprat e Apostujve" . 28) ("Romakëve" . 16)
    ("1 e Korintasve" . 16) ("2 e Korintasve" . 13) ("Galatasve" . 6)
    ("Efesianëve" . 6) ("Filipianëve" . 4) ("Kolosianëve" . 4)
    ("1 Thesalonikasve" . 5) ("2 Thesalonikasve" . 3) ("1 Timoteut" . 6)
    ("2 Timoteut" . 4) ("Titi" . 3) ("Filemonit" . 1) ("Hebrenjve" . 13)
    ("Jakobit" . 5) ("1 Pjetrit" . 5) ("2 Pjetrit" . 3) ("1 Gjonit" . 5)
    ("2 Gjonit" . 1) ("3 Gjonit" . 1) ("Juda" . 1) ("Zbulesa" . 22))
  "List of Bible books (ALB version) with their number of chapters.")

(defconst bible-gateway-bible-books-ukr
  '(("Буття" . 50) ("Вихід" . 40) ("Левит" . 27) ("Числа" . 36)
    ("Повторення Закону" . 34) ("Ісус Навин" . 24) ("Книга Суддів" . 21) ("Рут" . 4)
    ("1 Самуїлова" . 31) ("2 Самуїлова" . 24) ("1 царів" . 22) ("2 царів" . 25)
    ("1 хроніки" . 29) ("2 хроніки" . 36) ("Ездра" . 10) ("Неемія" . 13)
    ("Естер" . 10) ("Йов" . 42) ("Псалми" . 150) ("Приповісті" . 31)
    ("Екклезіяст" . 12) ("Пісня над піснями" . 8) ("Ісая" . 66) ("Єремія" . 52)
    ("Плач Єремії" . 5) ("Єзекіїль" . 48) ("Даниїл" . 12) ("Осія" . 14)
    ("Йоїл" . 3) ("Амос" . 9) ("Овдій" . 1) ("Йона" . 4) ("Михей" . 7)
    ("Наум" . 3) ("Авакум" . 3) ("Софонія" . 3) ("Огій" . 2)
    ("Захарія" . 14) ("Малахії" . 4) ("Від Матвія" . 28) ("Від Марка" . 16)
    ("Від Луки" . 24) ("Від Івана" . 21) ("Дії" . 28) ("До римлян" . 16)
    ("1 до коринтян" . 16) ("2 до коринтян" . 13) ("До галатів" . 6)
    ("До ефесян" . 6) ("До филип'ян" . 4) ("До колоссян" . 4)
    ("1 до солунян" . 5) ("2 до солунян" . 3) ("1 Тимофію" . 6)
    ("2 Тимофію" . 4) ("До Тита" . 3) ("До Филимона" . 1) ("До євреїв" . 13)
    ("Якова" . 5) ("1 Петра" . 5) ("2 Петра" . 3) ("1 Івана" . 5)
    ("2 Івана" . 1) ("3 Івана" . 1) ("Юда" . 1) ("Об'явлення" . 22))
  "List of Bible books (UKR version) with their number of chapters.")

(defconst bible-gateway-bible-books-rusv
  '(("Бытие" . 50) ("Исход" . 40) ("Левит" . 27) ("Числа" . 36)
    ("Второзаконие" . 34) ("Иисус Навин" . 24) ("Книга Судей" . 21) ("Руфь" . 4)
    ("1-я Царств" . 31) ("2-я Царств" . 24) ("3-я Царств" . 22) ("4-я Царств" . 25)
    ("1-я Паралипоменон" . 29) ("2-я Паралипоменон" . 36) ("Ездра" . 10) ("Неемия" . 13)
    ("Есфирь" . 10) ("Иов" . 42) ("Псалтирь" . 150) ("Притчи" . 31)
    ("Екклесиаст" . 12) ("Песни Песней" . 8) ("Исаия" . 66) ("Иеремия" . 52)
    ("Плач Иеремии" . 5) ("Иезекииль" . 48) ("Даниил" . 12) ("Осия" . 14)
    ("Иоиль" . 3) ("Амос" . 9) ("Авдия" . 1) ("Иона" . 4) ("Михей" . 7)
    ("Наум" . 3) ("Аввакум" . 3) ("Софония" . 3) ("Аггей" . 2)
    ("Захария" . 14) ("Малахия" . 4) ("От Матфея" . 28) ("От Марка" . 16)
    ("От Луки" . 24) ("От Иоанна" . 21) ("Деяния" . 28) ("К Римлянам" . 16)
    ("1-е Коринфянам" . 16) ("2-е Коринфянам" . 13) ("К Галатам" . 6)
    ("К Ефесянам" . 6) ("К Филиппийцам" . 4) ("К Колоссянам" . 4)
    ("1-е Фессалоникийцам" . 5) ("2-е Фессалоникийцам" . 3) ("1-е Тимофею" . 6)
    ("2-е Тимофею" . 4) ("К Титу" . 3) ("К Филимону" . 1) ("К Евреям" . 13)
    ("Иакова" . 5) ("1-e Петра" . 5) ("2-e Петра" . 3) ("1-e Иоанна" . 5)
    ("2-e Иоанна" . 1) ("3-e Иоанна" . 1) ("Иуда" . 1) ("Откровение" . 22))
  "List of Bible books (RUSV version) with their number of chapters.")

(defconst bible-gateway-bible-books-luth1545
  '(("1 Mose" . 50) ("2 Mose" . 40) ("3 Mose" . 27) ("4 Mose" . 36)
    ("5 Mose" . 34) ("Josua" . 24) ("Richter" . 21) ("Rut" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("1 Koenige" . 22) ("2 Koenige" . 25)
    ("1 Chronik" . 29) ("2 Chronik" . 36) ("Esra" . 10) ("Nehemia" . 13)
    ("Ester" . 10) ("Hiob" . 42) ("Psalm" . 150) ("Sprueche" . 31)
    ("Prediger" . 12) ("Hohelied" . 8) ("Jesaja" . 66) ("Jeremia" . 52)
    ("Klagelieder" . 5) ("Hesekiel" . 48) ("Daniel" . 12) ("Hosea" . 14)
    ("Joel" . 3) ("Amos" . 9) ("Obadja" . 1) ("Jona" . 4) ("Mica" . 7)
    ("Nahum" . 3) ("Habakuk" . 3) ("Zephanja" . 3) ("Hagai" . 2)
    ("Sacharja" . 14) ("Maleachi" . 4) ("Matthaeus" . 28) ("Markus" . 16)
    ("Lukas" . 24) ("Johannes" . 21) ("Apostelgeschichte" . 28) ("Roemer" . 16)
    ("1 Korinther" . 16) ("2 Korinther" . 13) ("Galater" . 6)
    ("Epheser" . 6) ("Philipper" . 4) ("Kolosser" . 4)
    ("1 Thessalonicher" . 5) ("2 Thessalonicher" . 3) ("1 Timotheus" . 6)
    ("2 Timotheus" . 4) ("Titus" . 3) ("Philemon" . 1) ("Hebraeer" . 13)
    ("Jakobus" . 5) ("1 Petrus" . 5) ("2 Petrus" . 3) ("1 Johannes" . 5)
    ("2 Johannes" . 1) ("3 Johannes" . 1) ("Judas" . 1) ("Offenbarung" . 22))
  "List of Bible books (Luther Bibel 1545 version) with their number of chapters.")

(defconst bible-gateway-bible-books-ubg
  '(("Psalmy" . 150) ("Księga Przysłów" . 31)
    ("Ewangelia według św. Mateusza" . 28) ("Ewangelia według św. Marka" . 16)
    ("Ewangelia według św. Łukasza" . 24) ("Ewangelia według św. Jana" . 21) ("Dzieje Apostolskie" . 28) ("List św. Pawła do Rzymian" . 16)
    ("Pierwszy List św. Pawła do Koryntian" . 16) ("Drugi List św. Pawła do Koryntian" . 13) ("List św. Pawła do Galacjan" . 6)
    ("List św. Pawła do Efezjan" . 6) ("List św. Pawła do Filipian" . 4) ("List św. Pawła do Kolosan" . 4)
    ("Pierwszy List św. Pawła do Tesaloniczan" . 5) ("Drugi List św. Pawła do Tesaloniczan" . 3) ("Pierwszy List św. Pawła do Tymoteusza" . 6)
    ("Drugi List św. Pawła do Tymoteusza" . 4) ("List św. Pawła do Tytusa" . 3) ("List św. Pawła do Filemona" . 1) ("List do Hebrajczyków" . 13)
    ("List św. Jakuba" . 5) ("Pierwszy List św. Piotra" . 5) ("Drugi List św. Piotra" . 3) ("Pierwszy List św. Jana" . 5)
    ("Drugi List św. Jana" . 1) ("Trzeci List św. Jana" . 1) ("List św. Judy" . 1) ("Objawienie św. Jana" . 22))
  "List of Bible books (UBG) with their number of chapters.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                           Caching Mechanism                                ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar bible-gateway-cache-dir
  (locate-user-emacs-file ".cache/bible-gateway/")
  "Directory where bible-gateway cache file is stored.")

(defvar bible-gateway-cache-file
  (expand-file-name "bible-gateway-votd" bible-gateway-cache-dir)
  "File path for the verse of the day cache.")

(defun bible-gateway--ensure-cache-dir ()
  "Ensure that the cache directory exists."
  (unless (file-exists-p bible-gateway-cache-dir)
    (make-directory bible-gateway-cache-dir t)))

(defun bible-gateway--save-cache (data date)
  "Save the DATA (formatted string) and DATE to the cache file."
  (bible-gateway--ensure-cache-dir)
  (with-temp-file bible-gateway-cache-file
    (let ((print-length nil)
          (print-level nil))
      (insert ";; Bible Gateway Verse of the Day Cache\n")
      (prin1 `(:date ,date :data ,data) (current-buffer)))))

(defun bible-gateway--read-cache ()
  "Read and return the cached plist (:date :data).
Returns nil if the cache file does not exist or is invalid."
  (when (file-exists-p bible-gateway-cache-file)
    (condition-case nil
        (with-temp-buffer
          (insert-file-contents bible-gateway-cache-file)
          (goto-char (point-min))
          (read (current-buffer)))
      (error nil))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Package Section I: Fetch the Verse of The Day          ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun bible-gateway--justify-line (line width)
  "Justify LINE to WIDTH characters."
  (let* ((words (split-string line))
         (word-count (length words)))
    (if (<= word-count 1)
        line  ; Return single words unchanged
      (let* ((total-word-length (apply #'+ (mapcar #'length words)))
             (spaces-needed (- width total-word-length))
             (gaps (1- word-count))
             (base-spaces-per-gap (/ spaces-needed gaps))
             (extra-spaces (% spaces-needed gaps))
             (result ""))
        ;; Distribute spaces as evenly as possible
        (dotimes (i (1- word-count))
          (setq result
                (concat result
                        (nth i words)
                        (make-string
                         (if (< i extra-spaces)
                             (1+ base-spaces-per-gap)
                           base-spaces-per-gap)
                         ?\s))))
        (concat result (car (last words)))))))

(defun bible-gateway--format-verse (text &optional width)
  "Format verse TEXT as a justified paragraph with optional WIDTH."
  (when text  ; Only process if text is not nil
    (with-temp-buffer
      (let* ((fill-column (or width bible-gateway-text-width))
             (lines '()))
        ;; First fill the paragraph normally
        (insert text)
        (fill-region (point-min) (point-max))
        ;; Collect lines
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (string-trim (buffer-substring (line-beginning-position)
                                                     (line-end-position)))))
            (unless (string-empty-p line)
              (push line lines)))
          (forward-line 1))
        ;; Justify each line except the last one
        (setq lines (nreverse lines))
        (let* ((justified-lines
                (append
                 (mapcar (lambda (line)
                           (bible-gateway--justify-line line fill-column))
                         (butlast lines))
                 (last lines)))
               (result (string-join justified-lines "\n")))
          result)))))

(defun bible-gateway--decode-html (text)
  "Decode HTML entities in TEXT, including numeric character references."
  (when text
    (let ((entity-map '(("&ldquo;" . "\"")
                        ("&rdquo;" .  "\"")
                        ("&#8212;" . "—")
                        ("&#8217;" . "'")
                        ("&#8220;" . "\"")
                        ("&#8221;" . "\"")
                        ("&quot;" . "\"")
                        ("&apos;" .  "'")
                        ("&lt;" . "<")
                        ("&gt;" . ">")
                        ("&nbsp;" . " ")
                        ("&amp;" . "&"))))
      (replace-regexp-in-string
       "&#\\([0-9]+\\);"
       (lambda (match)
	 (char-to-string (string-to-number (match-string 1 match))))
       (replace-regexp-in-string
	"&[a-z]+;"
	(lambda (match)
	  (or (alist-get match entity-map nil nil #'string=)
	      match))
	text)))))

(defun bible-gateway--fetch-votd ()
  "Fetch the daily Bible verse using the BibleGateway API.
If the API is unavailable (e.g., geo-blocked), falls back to scraping.
If scraping also fails, returns the fallback verse."
  (let ((url-request-method "GET")
        (url (concat "https://www.biblegateway.com/votd/get/?format=json&version=" bible-gateway-bible-version))
        (fallback-result (format "%s\n%s"
                                 (bible-gateway--format-verse bible-gateway-fallback-verse)
                                 (let ((ref-text bible-gateway-fallback-reference))
                                   (concat (make-string (- bible-gateway-text-width (length ref-text)) ?\s)
                                           ref-text)))))
    (condition-case nil
	(with-current-buffer (let ((url-mime-charset-string "utf-8"))
			       (url-retrieve-synchronously url t t bible-gateway-request-timeout))
	  (goto-char (point-min))
	  (when (search-forward "\n\n" nil t)
	    (let ((response-body (buffer-substring-no-properties (point) (point-max))))
              ;; Check if API returned "Content Unavailable" HTML instead of JSON
	      (if (or (string-match-p "<title>Content Unavailable</title>" response-body)
		      (not (string-match-p "^\\s-*{" response-body)))
                  ;; API unavailable, try scraping
                  (condition-case nil
                      (bible-gateway--scrape-votd)
                    (error
                     (message "BibleGateway API and scraping unavailable, using fallback verse.")
                     fallback-result))
                ;; API returned JSON, process it
                (let* ((json-data (json-parse-string response-body :object-type 'hash-table))
                       (votd (gethash "votd" json-data))
                       (raw-text (gethash "text" votd))
                       (verse-text (bible-gateway--decode-html raw-text))
                       (clean-verse (replace-regexp-in-string "[\"]" "" verse-text))
                       (formatted-verse (bible-gateway--format-verse clean-verse))
                       (verse-reference (gethash "display_ref" votd))
                       (fill-width bible-gateway-text-width))
                  (format "%s\n%s"
                          formatted-verse
                          (let ((ref-text verse-reference))
                            (concat (make-string (- fill-width (length ref-text)) ?\s)
                                    ref-text))))))))
      (error
       ;; Network error or timeout, try scraping first
       (condition-case nil
           (bible-gateway--scrape-votd)
         (error
          (message "BibleGateway unreachable, using fallback verse.")
          fallback-result))))))

(defun bible-gateway--scrape-votd ()
  "Fetch the Verse of the Day by scraping BibleGateway.
Returns a single formatted string without verse numbers nor reference."
  (condition-case _err
      (let ((url "https://www.biblegateway.com")
            citation book passage)
        ;; 1. Retrieve homepage and extract citation.
        (with-current-buffer (url-retrieve-synchronously url t t bible-gateway-request-timeout)
	  (set-buffer-multibyte t)
	  (decode-coding-region (point-min) (point-max) 'utf-8)
          (goto-char (point-min))
          (when (re-search-forward "<span class=\"citation\">\\([^<]+\\)</span>" nil t)
            (setq citation (match-string 1))))
        (unless citation
          (error "Citation not found"))

        ;; 2. Split citation into book + passage.
        (let* ((parts (split-string citation " +" t))
               (passage (car (last parts)))
               (book (string-join (butlast parts) " ")))
          ;; 3. Capture passage output.
          (with-temp-buffer
	    (let ((bible-gateway-include-ref nil))
              (bible-gateway-get-passage book passage))
            (let* ((raw (buffer-string))
                   ;; Remove any success/status lines.
                   (raw (replace-regexp-in-string "Bible passage inserted successfully!.*$" "" raw))
                   ;; Split into lines for filtering.
                   (lines (split-string raw "\n"))
                   kept)

              ;; 4. Remove header / reference / empty lines, and verse numbers.
              (dolist (ln lines)
                (let ((trim (string-trim ln))
                      (skip nil))
                  (when (or (string-match-p "\\`\\s-*\\'" trim)
                            ;; Header line often contains passage and version.
                            (and (string-match-p (regexp-quote passage) trim)
                                 (string-match-p (format "(\\%s)" (regexp-quote bible-gateway-bible-version)) trim))
                            ;; Any trailing reference line duplicated below.
                            (and (string-match-p (regexp-quote citation) trim)
                                 (string-match-p (regexp-quote bible-gateway-bible-version) trim)))
                    (setq skip t))
                  (unless skip
                    ;; Remove verse numbers.
                    (setq trim (replace-regexp-in-string "\\s-*\\([0-9]+\\)\\.\\s-*" " " trim))
		    (when (length> trim 0)
                      (push trim kept)))))

              (setq kept (nreverse kept))

              ;; 5. Join all remaining lines into one paragraph (space separated).
              (let* ((joined (string-join kept " "))
                     ;; Normalize whitespace.
                     (joined (replace-regexp-in-string "\\s-+" " " joined))
                     ;; Trim.
                     (joined (string-trim joined)))

                ;; 6. Final format with your existing formatter.
                (let* ((formatted (bible-gateway--format-verse joined))
                       (ref-text (format "%s (%s)" citation bible-gateway-bible-version))
                       (fill-width bible-gateway-text-width)
                       (aligned-ref (concat (make-string (max 0 (- fill-width (length ref-text))) ?\s)
                                            ref-text)))
                  (format "%s\n%s" formatted aligned-ref)))))))
    (error
     ;; Fallback verse.
     (let* ((formatted (bible-gateway--format-verse bible-gateway-fallback-verse))
            (ref-text bible-gateway-fallback-reference)
            (aligned-ref (concat (make-string (max 0 (- bible-gateway-text-width (length ref-text))) ?\s)
                                 ref-text)))
       (format "%s\n%s" formatted aligned-ref)))))


;;;###autoload
(defun bible-gateway-get-verse ()
  "Get the verse of the day.
Checks the cache first. If the cache is from today, returns the cached
string. Otherwise, fetches the verse from BibleGateway, updates the
cache ONLY if successful, and returns the verse."
  (let* ((today (format-time-string "%Y-%m-%d"))
         (cached-item (bible-gateway--read-cache))
         (cached-date (plist-get cached-item :date)))

    (if (string= today cached-date)
        ;; Cache Hit: Return the stored formatted string
        (plist-get cached-item :data)

      ;; Cache Miss: Fetch
      (let ((result (bible-gateway--fetch-votd)))
        ;; Check if result is the fallback verse (formatted). We
        ;; construct the fallback string exactly as the original
        ;; function does to compare.
        (let ((fallback-string (format
				"%s\n%s" (bible-gateway--format-verse
					  bible-gateway-fallback-verse)
				(let ((ref-text bible-gateway-fallback-reference))
				  (concat (make-string (- bible-gateway-text-width
							  (length ref-text))
						       ?\s)
					  ref-text)))))

          ;; Only save to cache if it is NOT the fallback verse
          (unless (string= result fallback-string)
            (bible-gateway--save-cache result today))

          ;; Return the result (whether real or fallback)
          result)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Package section II - Fetch a Bible Passage             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun bible-gateway--prompt-book ()
  "Prompt for a Bible book name with completion based on selected Bible version."
  (completing-read
   "Select a Book: "
   (mapcar #'car  ; Get just the book names for completion
	   (pcase bible-gateway-bible-version
	     ("KJV" bible-gateway-bible-books-kjv)
	     ("LSG" bible-gateway-bible-books-lsg)
	     ("RVA" bible-gateway-bible-books-rva)
	     ("ALB" bible-gateway-bible-books-alb)
	     ("UKR" bible-gateway-bible-books-ukr)
	     ("RUSV" bible-gateway-bible-books-rusv)
	     ("LUTH1545" bible-gateway-bible-books-luth1545)
             ("UBG" bible-gateway-bible-books-ubg)
	     (_ bible-gateway-bible-books-kjv)))
   nil t))

(defun bible-gateway--prompt-chapter-verse (book)
  "Prompt for a chapter and verse for the BOOK."
  (let* ((books-list (pcase bible-gateway-bible-version
		       ("KJV" bible-gateway-bible-books-kjv)
		       ("LSG" bible-gateway-bible-books-lsg)
		       ("RVA" bible-gateway-bible-books-rva)
		       ("ALB" bible-gateway-bible-books-alb)
		       ("UKR" bible-gateway-bible-books-ukr)
		       ("RUSV" bible-gateway-bible-books-rusv)
		       ("LUTH1545" bible-gateway-bible-books-luth1545)
                       ("UBG" bible-gateway-bible-books-ubg)
		       (_ bible-gateway-bible-books-kjv)))
         (max-chapters (cdr (assoc book books-list))))
    (unless max-chapters
      (error "Could not find chapter count for book: %s in version %s" book bible-gateway-bible-version))
    (let ((input (read-string
                  (format "Select passage from %s (1-%d): " book max-chapters))))
      (format "%s %s" book input))))

(defun bible-gateway--process-verse-text (text)
  "Process verse TEXT.
Handling special cases like small-caps LORD or JESUS and UTF-8 encoding."
  (with-temp-buffer
    (insert text)
    (cl-flet ((replace-all (pattern replacement)
                (goto-char (point-min))
                (while (re-search-forward pattern nil t)
                  (replace-match replacement t t))))
      ;; Replace small-caps Lord with "LORD"
      (replace-all "<span style=\"font-variant: small-caps\" class=\"small-caps\">\\(Lord\\)</span>" "LORD")
      ;; Replace small-caps span with "JESUS"
      (replace-all "<span style=\"font-variant: small-caps\" class=\"small-caps\">\\(Jesus\\)</span>" "JESUS")
      ;; Remove "Read full chapter" text
      (replace-all "Read full chapter.*$" "")
      ;; Remove empty span tags (like <span class="text Rev-22-21"></span>)
      (replace-all "<span[^>]*>\\s-*</span>" "")
      ;; Remove trailing span IDs and div tags
      (replace-all "\\(<span id=\"[^\"]*\".*\\|</div.*\\)$" "")
      ;; Remove incomplete HTML tags at the end (like <span without >)
      (replace-all "<[^>]*$" "")
      ;; Remove any remaining HTML tags
      (replace-all "<[^>]+>" "")
      ;; Fix non-breaking space
      (replace-all "\\\\302\\\\240" " "))
    ;; Decode HTML entities (if any remain) and trim
    (string-trim (bible-gateway--decode-html (buffer-string)))))

(defun bible-gateway--wrap-verse-text (verse-text)
  "Wrap VERSE-TEXT according to window width with 4 spaces for wrapped lines."
  (with-temp-buffer
    (insert verse-text)
    (let ((fill-prefix "    ")  ; 4 spaces for wrapped lines
          (fill-column (- (window-width) 5))) ; window width minus some margin
      (fill-region (point-min) (point-max))
      (buffer-string))))

;;;###autoload
(defun bible-gateway-get-passage (&optional book passage)
  "Fetch a Bible passage from https://biblegateway.com/.
If BOOK and PASSAGE are provided, use them directly.
If only BOOK is provided, prompt for passage only. TODO: Validate BOOK string.
If neither, prompt for both."
  (interactive)
  (let* ((book-supplied (and book (not (string-empty-p book))))
         (passage-supplied (and passage (not (string-empty-p passage))))
         (chosen-book (if book-supplied book (bible-gateway--prompt-book)))
         (chosen-passage (if passage-supplied
                             passage
                           (bible-gateway--prompt-chapter-verse chosen-book)))
         (search-string (if passage-supplied
                            (concat chosen-book
                                    (if (string= bible-gateway-bible-version "UBG")  ;; UBG books have a lot of spaces - essential for API
                                        chosen-passage
				      (replace-regexp-in-string " " "" chosen-passage)))
                        (if (string= bible-gateway-bible-version "UBG")
                              chosen-passage
                          (replace-regexp-in-string " " "" chosen-passage))))

         (url (concat "https://www.biblegateway.com/passage/?search="
		      (url-encode-url search-string)
		      "&version=" (url-encode-url bible-gateway-bible-version))))
    (condition-case err
	(let ((original-buffer (current-buffer)))
	  (with-current-buffer
	      (url-retrieve-synchronously url t t bible-gateway-request-timeout)
	    (set-buffer-multibyte t)
	    (decode-coding-region (point-min) (point-max) 'utf-8)
            (goto-char (point-min))

	    ;; First get the title if required
	    (let ((title nil))
	      (when bible-gateway-include-ref
		(goto-char (point-min))
		(when (search-forward "<meta name=\"twitter:title\" content=\"" nil t)
		  (let ((start (point))
			(end (search-forward "\"")))
		    ;; Decode the title here
		    (setq title (decode-coding-string
				 (encode-coding-string
				  (buffer-substring-no-properties start (1- end)) 'utf-8)
				 'utf-8)))))

              ;; Then get the verses
              (goto-char (point-min))
              (if (search-forward "<div class='passage-content passage-class-0'>" nil t)
		  (let* ((start (point))
			 (end (search-forward "</div>"))
			 (raw-content (buffer-substring-no-properties start (1- end)))
			 (verses '()))
                    ;; (pos 0))

                    ;; First, remove chapter numbers
                    (setq raw-content
			  (replace-regexp-in-string
			   "<span class=\"chapternum\">[^<]*</span>" "" raw-content))

                    ;; Remove verse numbers but keep content
                    (setq raw-content
			  (replace-regexp-in-string
			   "<sup class=\"versenum\">[^<]*</sup>" "" raw-content))

                    ;; Break the content into individual verse spans for processing
                    (with-temp-buffer
                      (insert raw-content)
                      (goto-char (point-min))
                      (while (re-search-forward "class=\"text [^\"]*-\\([0-9]+\\)\">" nil t)
			(let* ((verse-num (match-string 1))
                               (verse-start (match-end 0))
                               (verse-end (save-excursion
                                            (if (re-search-forward "class=\"text" nil t)
						(match-beginning 0)
                                              (point-max))))
                               (verse-content
				(buffer-substring-no-properties verse-start verse-end))
			       ;; First process the verse text normally
                               (verse-text (bible-gateway--process-verse-text verse-content))
			       ;; Then wrap it with proper formatting
			       (final-text (bible-gateway--wrap-verse-text verse-text)))
			  (when (not (string-empty-p final-text))
			    (push (format "%s.%s%s" verse-num
					  (if (< (string-to-number verse-num) 10) "  " " ")
					  final-text)
				  verses)))))

                    ;; Insert title and verses
                    (with-current-buffer original-buffer
                      (when (and bible-gateway-include-ref title)
			(insert title "\n\n"))
                      (insert (string-join (reverse verses) "\n"))))
		(message
		 (concat "Sorry, we didn’t find any results for your search.
Please double-check that the chapter and verse numbers are valid."))))))
      ('error
       (message "Error while fetching the passage: %s" (error-message-string err))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;   Package Section III - Play Bible chapter from KJV Dramatized Audio       ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defconst bible-gateway-bible-books-osis
  '(("Genesis" . "Gen") ("Exodus" . "Exod") ("Leviticus" . "Lev")
    ("Numbers" . "Num") ("Deuteronomy" . "Deut") ("Joshua" . "Josh")
    ("Judges" . "Judg") ("Ruth" . "Ruth") ("1 Samuel" . "1Sam")
    ("2 Samuel" . "2Sam") ("1 Kings" . "1Kgs") ("2 Kings" . "2Kgs")
    ("1 Chronicles" . "1Chr") ("2 Chronicles" . "2Chr") ("Ezra" . "Ezra")
    ("Nehemiah" . "Neh") ("Esther" . "Esth") ("Job" . "Job")
    ("Psalms" . "Ps") ("Proverbs" . "Prov") ("Ecclesiastes" . "Eccl")
    ("Song of Solomon" . "Song") ("Isaiah" . "Isa") ("Jeremiah" . "Jer")
    ("Lamentations" . "Lam") ("Ezekiel" . "Ezek") ("Daniel" . "Dan")
    ("Hosea" . "Hos") ("Joel" . "Joel") ("Amos" . "Amos")
    ("Obadiah" . "Obad") ("Jonah" . "Jonah") ("Micah" . "Mic")
    ("Nahum" . "Nah") ("Habakkuk" . "Hab") ("Zephaniah" . "Zeph")
    ("Haggai" . "Hag") ("Zechariah" . "Zech") ("Malachi" . "Mal")
    ("Matthew" . "Matt") ("Mark" . "Mark") ("Luke" . "Luke")
    ("John" . "John") ("Acts" . "Acts") ("Romans" . "Rom")
    ("1 Corinthians" . "1Cor") ("2 Corinthians" . "2Cor")
    ("Galatians" . "Gal") ("Ephesians" . "Eph") ("Philippians" . "Phil")
    ("Colossians" . "Col") ("1 Thessalonians" . "1Thess")
    ("2 Thessalonians" . "2Thess") ("1 Timothy" . "1Tim")
    ("2 Timothy" . "2Tim") ("Titus" . "Titus") ("Philemon" . "Phlm")
    ("Hebrews" . "Heb") ("James" . "Jas") ("1 Peter" . "1Pet")
    ("2 Peter" . "2Pet") ("1 John" . "1John") ("2 John" . "2John")
    ("3 John" . "3John") ("Jude" . "Jude") ("Revelation" . "Rev"))
  "Mapping of Bible book names to their OSIS abbreviations for audio links.")

(defun bible-gateway--get-audio-link (book chapter)
  "Generate and open BibleGateway audio link for CHAPTER from BOOK."
  (let* ((osis-code (cdr (assoc book bible-gateway-bible-books-osis)))
         (version (downcase bible-gateway-bible-version))
         (base-url "https://www.biblegateway.com/audio/dramatized")
         (url (if osis-code
                  (format "%s/%s/%s.%d" base-url version osis-code chapter)
		(error "Unknown book: %s" book))))
    url))

;;;###autoload
(defun bible-gateway-listen-passage ()
  "Prompt for a Bible chapter and play KJV Dramatized Audio in the browser."
  (interactive)
  (let* ((books-list (cond ((string= bible-gateway-bible-version "KJV")
                            bible-gateway-bible-books-kjv)
                           (t bible-gateway-bible-books-kjv)))
         (book (completing-read "Select Book: " (mapcar #'car books-list)))
         (max-chapters (cdr (assoc book books-list)))
         (input (read-string
                 (format "Select Chapter from %s (1-%d): " book max-chapters)))
         (audio-link (bible-gateway--get-audio-link book
						    (string-to-number input))))
    (browse-url audio-link)
    ;; More detailed message with the specific chapter being opened
    (message "Switch to your browser and click Play to listen %s %s (KJV)."
             book input)))


(provide 'bible-gateway)
;;; bible-gateway.el ends here
