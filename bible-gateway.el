;;; bible-gateway.el --- A Simple BibleGateway Client -*- lexical-binding: t -*-

;; Copyright (C) 2026 Kristjon Ciko

;; Author: Kristjon Ciko
;; Keywords: convenience comm hypermedia
;; Homepage: https://github.com/kristjoc/bible-gateway
;; Package-Requires: ((emacs "29.1"))
;; Package-Version: 1.6.7

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

;; bible-gateway is a simple package that fetches content from
;; [BibleGateway.com](http://BibleGateway.com). It can:
;;
;; - Fetch and display the Bible verse of the day
;; - Insert Bible passages/chapters at point or in a dedicated buffer
;; - Open audio chapters in your browser
;; - Search the Bible by keyword and display results in a dedicated buffer with
;;   clickable references and pagination
;; - Follow a daily reading plan from a CSV file
;;
;; Usage:
;;
;; A transient menu (M-x `bible-gateway') gives access to all the
;; commands above.
;;
;; `bible-gateway-get-verse' fetches the verse of the day for use as
;; an emacs-dashboard footer or a scratch buffer message.
;;
;; M-x `bible-gateway-get-passage' fetches a Bible passage and inserts
;; it at point. It can be called both interactively from
;; \\[execute-extended-command] or programmatically with the book name
;; and verse(s) as arguments.
;;
;; M-x `bible-gateway-read-passage' works like `bible-gateway-get-passage'
;; but displays the passage in a dedicated buffer in `text-mode'.
;;
;; M-x `bible-gateway-listen-passage' plays a Bible chapter from KJV
;; Zondervan Audio in the browser.
;;
;; M-x `bible-gateway-search' prompts for a search query, fetches results
;; from BibleGateway, and displays them in a dedicated buffer.
;;
;; M-x `bible-gateway-read-today' fetches all of today's passages from
;; the active reading plan (set via `bible-gateway-reading-plan') and
;; displays them in a single buffer.

;;; Code:

(require 'url)
(require 'json)
(require 'cl-lib)

(defgroup bible-gateway nil
  "A BibleGateway client package."
  :group 'external)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                           Customizable variables                           ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom bible-gateway-bible-version "KJV"
  "The Bible version, default KJV.
Other supported versions, which are available in the Public Domain, are
LSG in French, RVA in Spanish, ALB in Albanian, UKR in Ukrainian, RUSV
in Russian, LUTH1545 in German, DNB1930 in Norwegian, BULG in Bulgarian,
SV1917 in Swedish, and DN1933 in Danish."
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

(defcustom bible-gateway-search-results-per-page 100
  "Maximum number of search results to fetch per query."
  :type 'natnum)

(defcustom bible-gateway-use-english-book-names nil
  "If non-nil, use English book names for completion regardless of version.
The query to BibleGateway is still sent using the localized book name."
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
    ("Ecclesiastes" . 12) ("Song of Solomon" . 8) ("Isaiah" . 66)
    ("Jeremiah" . 52) ("Lamentations" . 5) ("Ezekiel" . 48) ("Daniel" . 12)
    ("Hosea" . 14) ("Joel" . 3) ("Amos" . 9) ("Obadiah" . 1) ("Jonah" . 4)
    ("Micah" . 7) ("Nahum" . 3) ("Habakkuk" . 3) ("Zephaniah" . 3)
    ("Haggai" . 2) ("Zechariah" . 14) ("Malachi" . 4) ("Matthew" . 28)
    ("Mark" . 16) ("Luke" . 24) ("John" . 21) ("Acts" . 28) ("Romans" . 16)
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
    ("Ecclésiaste" . 12) ("Cantique des Cantiques" . 8) ("Ésaïe" . 66)
    ("Jérémie" . 52) ("Lamentations" . 5) ("Ézéchiel" . 48) ("Daniel" . 12)
    ("Osée" . 14) ("Joël" . 3) ("Amos" . 9) ("Abdias" . 1) ("Jonas" . 4)
    ("Michée" . 7) ("Nahum" . 3) ("Habacuc" . 3) ("Sophonie" . 3) ("Aggée" . 2)
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
    ("1 i Samuelit" . 31) ("2 i Samuelit" . 24) ("1 i Mbretërve" . 22)
    ("2 i Mbretërve" . 25) ("1 i Kronikave" . 29) ("2 i Kronikave" . 36)
    ("Esdra" . 10) ("Nehemia" . 13) ("Ester" . 10) ("Jobi" . 42)
    ("Psalmet" . 150) ("Fjalët e urta" . 31) ("Predikuesi" . 12)
    ("Kantiku i Kantikëve" . 8) ("Isaia" . 66) ("Jeremia" . 52) ("Vajtimet" . 5)
    ("Ezekieli" . 48) ("Danieli" . 12) ("Osea" . 14) ("Joeli" . 3) ("Amosi" . 9)
    ("Abdia" . 1) ("Jona" . 4) ("Mikea" . 7) ("Nahumi" . 3) ("Habakuku" . 3)
    ("Sofonia" . 3) ("Hagai" . 2) ("Zakaria" . 14) ("Malakia" . 4)
    ("Mateu" . 28) ("Marku" . 16) ("Luka" . 24) ("Gjoni" . 21)
    ("Veprat e Apostujve" . 28) ("Romakëve" . 16) ("1 e Korintasve" . 16)
    ("2 e Korintasve" . 13) ("Galatasve" . 6) ("Efesianëve" . 6)
    ("Filipianëve" . 4) ("Kolosianëve" . 4) ("1 Thesalonikasve" . 5)
    ("2 Thesalonikasve" . 3) ("1 Timoteut" . 6) ("2 Timoteut" . 4)
    ("Titi" . 3) ("Filemonit" . 1) ("Hebrenjve" . 13) ("Jakobit" . 5)
    ("1 Pjetrit" . 5) ("2 Pjetrit" . 3) ("1 Gjonit" . 5) ("2 Gjonit" . 1)
    ("3 Gjonit" . 1) ("Juda" . 1) ("Zbulesa" . 22))
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
    ("1-я Царств" . 31) ("2-я Царств" . 24) ("3-я Царств" . 22)
    ("4-я Царств" . 25) ("1-я Паралипоменон" . 29) ("2-я Паралипоменон" . 36)
    ("Ездра" . 10) ("Неемия" . 13) ("Есфирь" . 10) ("Иов" . 42)
    ("Псалтирь" . 150) ("Притчи" . 31) ("Екклесиаст" . 12) ("Песни Песней" . 8)
    ("Исаия" . 66) ("Иеремия" . 52) ("Плач Иеремии" . 5) ("Иезекииль" . 48)
    ("Даниил" . 12) ("Осия" . 14) ("Иоиль" . 3) ("Амос" . 9) ("Авдия" . 1)
    ("Иона" . 4) ("Михей" . 7) ("Наум" . 3) ("Аввакум" . 3) ("Софония" . 3)
    ("Аггей" . 2) ("Захария" . 14) ("Малахия" . 4) ("От Матфея" . 28)
    ("От Марка" . 16) ("От Луки" . 24) ("От Иоанна" . 21) ("Деяния" . 28)
    ("К Римлянам" . 16) ("1-е Коринфянам" . 16) ("2-е Коринфянам" . 13)
    ("К Галатам" . 6) ("К Ефесянам" . 6) ("К Филиппийцам" . 4)
    ("К Колоссянам" . 4) ("1-е Фессалоникийцам" . 5) ("2-е Фессалоникийцам" . 3)
    ("1-е Тимофею" . 6) ("2-е Тимофею" . 4) ("К Титу" . 3) ("К Филимону" . 1)
    ("К Евреям" . 13) ("Иакова" . 5) ("1-е Петра" . 5) ("2-е Петра" . 3)
    ("1-е Иоанна" . 5) ("2-е Иоанна" . 1) ("3-е Иоанна" . 1) ("Иуда" . 1)
    ("Откровение" . 22))
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
  "List of Bible books (LUTH1545 version) with their number of chapters.")

(defconst bible-gateway-bible-books-dnb1930
  '(("1 Mosebok" . 50) ("2 Mosebok" . 40) ("3 Mosebok" . 27) ("4 Mosebok" . 36)
    ("5 Mosebok" . 34) ("Josvas" . 24) ("Dommernes" . 21) ("Ruts" . 4)
    ("1 Samuels" . 31) ("2 Samuel" . 24) ("1 Kongebok" . 22) ("2 Kongebok" . 25)
    ("1 Krønikebok" . 29) ("2 Krønikebok" . 36) ("Esras" . 10) ("Nehemias" . 13)
    ("Esters" . 10) ("Jobs" . 42) ("Salmenes" . 150) ("Salomos Ordsprog" . 31)
    ("Predikerens" . 12) ("Salomos Høisang" . 8) ("Esaias" . 66) ("Jeremias" . 52)
    ("Klagesangene" . 5) ("Esekiel" . 48) ("Daniel" . 12) ("Hoseas" . 14)
    ("Joel" . 3) ("Amos" . 9) ("Obadias" . 1) ("Jonas" . 4) ("Mika" . 7)
    ("Nahum" . 3) ("Habakuk" . 3) ("Sefanias" . 3) ("Haggai" . 2)
    ("Sakarias" . 14) ("Malakias" . 4) ("Matteus" . 28) ("Markus" . 16)
    ("Lukas" . 24) ("Johannes" . 21) ("Apostlenesgjerninge" . 28) ("Romerne" . 16)
    ("1 Korintierne" . 16) ("2 Korintierne" . 13) ("Galaterne" . 6)
    ("Efeserne" . 6) ("Filippenserne" . 4) ("Kolossenserne" . 4)
    ("1 Tessalonikerne" . 5) ("2 Tessalonikerne" . 3) ("1 Timoteus" . 6)
    ("2 Timoteus" . 4) ("Titus" . 3) ("Filemon" . 1) ("Hebreerne" . 13)
    ("Jakobs" . 5) ("1 Peters" . 5) ("2 Peters" . 3) ("1 Johannes" . 5)
    ("2 Johannes" . 1) ("3 Johannes" . 1) ("Judas" . 1) ("Apenbaring" . 22))
  "List of Bible books (DNB1930 version) with their number of chapters.")

(defconst bible-gateway-bible-books-bulg
  '(("Битие" . 50) ("Изход" . 40) ("Левит" . 27) ("Числа" . 36)
    ("Второзаконие" . 34) ("Исус Навиев" . 24) ("Съдии" . 21) ("Рут" . 4)
    ("1 Царе" . 31) ("2 Царе" . 24) ("3 Царе" . 22) ("4 Царе" . 25)
    ("1 Летописи" . 29) ("2 Летописи" . 36) ("Ездра" . 10) ("Неемия" . 13)
    ("Естир" . 10) ("Йов" . 42) ("Псалми" . 150) ("Притчи" . 31)
    ("Еклесиаст" . 12) ("Песен на песните" . 8) ("Исая" . 66) ("Еремия" . 52)
    ("Плач Еремиев" . 5) ("Езекил" . 48) ("Данаил" . 12) ("Осия" . 14)
    ("Иоил" . 3) ("Амос" . 9) ("Авдий" . 1) ("Йон" . 4) ("Михей" . 7)
    ("Наум" . 3) ("Авакум" . 3) ("Софоний" . 3) ("Агей" . 2)
    ("Захария" . 14) ("Малахия" . 4) ("Матей" . 28) ("Марко" . 16)
    ("Лука" . 24) ("Йоан" . 21) ("Деяния" . 28) ("Римляни" . 16)
    ("1 Коринтяни" . 16) ("2 Коринтяни" . 13) ("Галатяни" . 6)
    ("Ефесяни" . 6) ("Филипяни" . 4) ("Колосяни" . 4)
    ("1 Солунци" . 5) ("2 Солунци" . 3) ("1 Тимотей" . 6)
    ("2 Тимотей" . 4) ("Тит" . 3) ("Филимон" . 1) ("Евреи" . 13)
    ("Яков" . 5) ("1 Петрово" . 5) ("2 Петрово" . 3) ("1 Йоаново" . 5)
    ("2 Йоаново" . 1) ("3 Йоаново" . 1) ("Юда" . 1) ("Откровение" . 22))
  "List of Bible books (BULG version) with their number of chapters.")

(defconst bible-gateway-bible-books-sv1917
  '(("1 Mosebok" . 50) ("2 Mosebok" . 40) ("3 Mosebok" . 27) ("4 Mosebok" . 36)
    ("5 Mosebok" . 34) ("Josua" . 24) ("Domarboken" . 21) ("Rut" . 4)
    ("1 Samuelsboken" . 31) ("2 Samuelsboken" . 24) ("1 Kungaboken" . 22)
    ("2 Kungaboken" . 25) ("1 Krönikeboken" . 29) ("2 Krönikeboken" . 36)
    ("Esra" . 10) ("Nehemja" . 13)
    ("Ester" . 10) ("Job" . 42) ("Psaltaren" . 150) ("Ordspråksboken" . 31)
    ("Predikaren" . 12) ("Höga Visan" . 8) ("Jesaja" . 66) ("Jeremia" . 52)
    ("Klagovisorna" . 5) ("Hesekiel" . 48) ("Daniel" . 12) ("Hosea" . 14)
    ("Joel" . 3) ("Amos" . 9) ("Obadja" . 1) ("Jona" . 4) ("Mika" . 7)
    ("Nahum" . 3) ("Habackuk" . 3) ("Sefanja" . 3) ("Haggai" . 2)
    ("Sakaria" . 14) ("Malaki" . 4) ("Matteus" . 28) ("Markus" . 16)
    ("Lukas" . 24) ("Johannes" . 21) ("Apostlagärningarna" . 28)
    ("Romarbrevet" . 16) ("1 Korinthierbrevet" . 16) ("2 Korinthierbrevet" . 13)
    ("Galaterbrevet" . 6) ("Efesierbrevet" . 6) ("Filipperbrevet" . 4)
    ("Kolosserbrevet" . 4) ("1 Thessalonikerbrevet" . 5)
    ("2 Thessalonikerbrevet" . 3) ("1 Timotheosbrevet" . 6)
    ("2 Timotheosbrevet" . 4) ("Titusbrevet" . 3) ("Filemonbrevet" . 1)
    ("Hebreerbrevet" . 13) ("Jakobsbrevet" . 5) ("1 Petrusbrevet" . 5)
    ("2 Petrusbrevet" . 3) ("1 Johannesbrevet" . 5) ("2 Johannesbrevet" . 1)
    ("3 Johannesbrevet" . 1) ("Judasbrevet" . 1) ("Uppenbarelseboken" . 22))
  "List of Bible books (SV1917 version) with their number of chapters.")

(defconst bible-gateway-bible-books-dn1933
  '(("1 Mosebog" . 50) ("2 Mosebog" . 40) ("3 Mosebog" . 27) ("4 Mosebog" . 36)
    ("5 Mosebog" . 34) ("Josua" . 24) ("Dommer" . 21) ("Rut" . 4)
    ("1 Samuel" . 31) ("2 Samuel" . 24) ("Første Kongebog" . 22) ("Anden Kongebog" . 25)
    ("Første Krønikebog" . 29) ("Anden Krønikebog" . 36) ("Ezra" . 10) ("Nehemias" . 13)
    ("Ester" . 10) ("Job" . 42) ("Salme" . 150) ("Ordsprogene" . 31)
    ("Prædikeren" . 12) ("Højsangen" . 8) ("Esajas" . 66) ("Jeremias" . 52)
    ("Klagesangene" . 5) ("Ezekiel" . 48) ("Daniel" . 12) ("Hoseas" . 14)
    ("Joel" . 3) ("Amos" . 9) ("Obadias" . 1) ("Jonas" . 4) ("Mikas" . 7)
    ("Nahum" . 3) ("Habakkuk" . 3) ("Zefanias" . 3) ("Haggaj" . 2)
    ("Zakarias" . 14) ("Malakias" . 4) ("Matthæus" . 28) ("Markus" . 16)
    ("Lukas" . 24) ("Johannes" . 21) ("Apostelenes gerninger" . 28) ("Romerne" . 16)
    ("1 Korinterne" . 16) ("2 Korinterne" . 13) ("Galaterne" . 6)
    ("Efeserne" . 6) ("Filipperne" . 4) ("Kolossensern" . 4)
    ("1 Tessalonikerne" . 5) ("2 Tessalonikerne" . 3) ("1 Timoteus" . 6)
    ("2 Timoteus" . 4) ("Titus" . 3) ("Filemon" . 1) ("Hebræerne" . 13)
    ("Jakob" . 5) ("1 Peter" . 5) ("2 Peter" . 3) ("1 Johannes" . 5)
    ("2 Johannes" . 1) ("3 Johannes" . 1) ("Judas" . 1) ("Aabenbaringen" . 22))
  "List of Bible books (DN1933 version) with their number of chapters.")

(defconst bible-gateway-version-names
  '(("KJV" . "King James Version")
    ("LSG" . "Louis Segond")
    ("RVA" . "Reina-Valera Antigua")
    ("ALB" . "Albanian Bible")
    ("UKR" . "Ukrainian Bible")
    ("RUSV" . "Russian Synodal Version")
    ("LUTH1545" . "Luther Bible 1545")
    ("DNB1930" . "Det Norsk Bibelselskap 1930")
    ("BULG" . "Bulgarian Bible")
    ("SV1917" . "Svenska 1917")
    ("DN1933" . "Dette er Biblen på dansk"))
  "Mapping of Bible version codes to their full names.")

(defun bible-gateway--version-books ()
  "Return the book list for the current `bible-gateway-bible-version'."
  (pcase bible-gateway-bible-version
    ("KJV"     bible-gateway-bible-books-kjv)
    ("LSG"     bible-gateway-bible-books-lsg)
    ("RVA"     bible-gateway-bible-books-rva)
    ("ALB"     bible-gateway-bible-books-alb)
    ("UKR"     bible-gateway-bible-books-ukr)
    ("RUSV"    bible-gateway-bible-books-rusv)
    ("LUTH1545" bible-gateway-bible-books-luth1545)
    ("DNB1930" bible-gateway-bible-books-dnb1930)
    ("BULG"    bible-gateway-bible-books-bulg)
    ("SV1917"  bible-gateway-bible-books-sv1917)
    ("DN1933"  bible-gateway-bible-books-dn1933)
    (_         bible-gateway-bible-books-kjv)))

(defun bible-gateway--localize-book (display-name)
  "Return the localized book name for DISPLAY-NAME.
If `bible-gateway-use-english-book-names' is nil, DISPLAY-NAME is already
localized and is returned as-is.  Otherwise, DISPLAY-NAME is a KJV name and
is mapped positionally to the localized equivalent in the current version."
  (if (not bible-gateway-use-english-book-names)
      display-name
    (let* ((kjv-names (mapcar #'car bible-gateway-bible-books-kjv))
           (index (cl-position display-name kjv-names :test #'string=))
           (version-books (bible-gateway--version-books)))
      (if index
          (car (nth index version-books))
        display-name)))) ; fallback: return as-is

;;;###autoload
(defun bible-gateway-set-version ()
  "Interactively select and set the active Bible version.
Updates `bible-gateway-bible-version' for the current session.
Use `customize-variable' to persist the change across sessions."
  (interactive)
  (let* ((choices (mapcar (lambda (pair)
                            (format "%-10s %s" (car pair) (cdr pair)))
                          bible-gateway-version-names))
         (selection (completing-read
                     (format "Bible version (current: %s): "
                             bible-gateway-bible-version)
                     choices nil t))
         (code (car (split-string (string-trim selection)))))
    (setq bible-gateway-bible-version code)
    (message "BibleGateway: version set to %s (%s)"
             code
             (or (cdr (assoc code bible-gateway-version-names)) code))))


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

(defun bible-gateway--save-cache (data date version)
  "Save DATA, DATE, and VERSION to the cache file."
  (bible-gateway--ensure-cache-dir)
  (with-temp-file bible-gateway-cache-file
    (let ((print-length nil)
          (print-level nil))
      (insert ";; BibleGateway Verse of the Day\n")
      (prin1 `(:date ,date :version ,version :data ,data) (current-buffer)))))

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
        (url (concat
	      "https://www.biblegateway.com/votd/get/?format=json&version="
	      bible-gateway-bible-version))
        (fallback-result
	 (format "%s\n%s"
		 (bible-gateway--format-verse bible-gateway-fallback-verse)
		 (let ((ref-text bible-gateway-fallback-reference))
		   (concat (make-string
			    (- bible-gateway-text-width (length ref-text)) ?\s)
			   ref-text)))))
    (condition-case nil
	(with-current-buffer (let ((url-mime-charset-string "utf-8"))
			       (url-retrieve-synchronously
				url t t bible-gateway-request-timeout))
	  (goto-char (point-min))
	  (when (search-forward "\n\n" nil t)
	    (let ((response-body
		   (buffer-substring-no-properties (point) (point-max))))
              ;; Check if API returned "Content Unavailable" instead of JSON
	      (if (or (string-match-p "<title>Content Unavailable</title>"
				      response-body)
		      (not (string-match-p "^\\s-*{" response-body)))
                  ;; API unavailable, try scraping
                  (condition-case nil
                      (bible-gateway--scrape-votd)
                    (error
                     (message "BibleGateway API and scraping unavailable, using fallback verse.")
                     fallback-result))
                ;; API returned JSON, process it
                (let* ((json-data
			(json-parse-string response-body :object-type 'hash-table))
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
                            (concat
			     (make-string (- fill-width (length ref-text)) ?\s)
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
      (let ((url "https://www.biblegateway.com") citation)
        ;; 1. Retrieve homepage and extract reference.
        (with-current-buffer
	    (url-retrieve-synchronously url t t bible-gateway-request-timeout)
	  (set-buffer-multibyte t)
	  (decode-coding-region (point-min) (point-max) 'utf-8)
          (goto-char (point-min))
          (when(re-search-forward
		"<span class=\"citation\">\\([^<]+\\)</span>" nil t)
            (setq citation (match-string 1))))
        (unless citation
          (error "Bible reference not found"))

        ;; 2. Split citation into book + passage.
        ;; (let* ((parts (split-string citation " +" t))
        ;;        (passage (car (last parts)))
        ;;        (book (string-join (butlast parts) " ")))

	(let* ((split-pos (string-match "\\b[0-9]+:\\s-*[0-9]" citation))
	       (book    (string-trim (substring citation 0 split-pos)))
	       (passage (replace-regexp-in-string ":\\s-+" ":"
						  (string-trim (substring
								citation
								split-pos)))))
          ;; 3. Capture passage output.
          (with-temp-buffer
	    (let ((bible-gateway-include-ref t))
	      (bible-gateway-get-passage (bible-gateway--localize-book book) passage))
	    (let* ((raw (buffer-string))
                   ;; Remove any success/status lines.
                   (raw (replace-regexp-in-string
			 "Bible passage inserted successfully!.*$" "" raw))
                   ;; Split into lines for filtering.
                   (lines (split-string raw "\n"))
                   kept)

              ;; 4. Remove header / reference / empty lines, and verse numbers.
	      (let ((local-ref nil))
		(dolist (ln lines)
                  (let ((trim (string-trim ln))
			(skip nil))
                    (when (or (string-match-p "\\`\\s-*\\'" trim)
                              ;; Header line often contains passage and version.
                              ;; (and (string-match-p (regexp-quote passage) trim)
                              ;; (and (string-match-p (regexp-quote book) trim)
			      (and (string-match-p (regexp-quote (bible-gateway--localize-book book)) trim)
				   (string-match-p
				    (regexp-quote (format "(%s)" bible-gateway-bible-version)) trim)
				   (setq local-ref trim))
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
			 (ref-text (format "%s (%s)"
					   (concat (bible-gateway--localize-book book)
						   " "
						   passage)
					   bible-gateway-bible-version))
			 ;; (ref-text (format "%s (%s)" citation bible-gateway-bible-version))
			 (fill-width bible-gateway-text-width)
			 (aligned-ref (concat (make-string (max 0 (- fill-width (length ref-text))) ?\s)
                                              ref-text)))
                    (format "%s\n%s" formatted aligned-ref))))))))
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
Checks the cache first. If the cache is from today AND the stored
Bible version matches `bible-gateway-bible-version', returns the cached
string. Otherwise, fetches the verse from BibleGateway, updates the
cache ONLY if successful, and returns the verse."
  (let* ((today (format-time-string "%Y-%m-%d"))
         (version bible-gateway-bible-version)
         (cached-item (bible-gateway--read-cache))
         (cached-date (plist-get cached-item :date))
         (cached-version (plist-get cached-item :version)))

    (if (and (string= today cached-date)
             (string= version cached-version))
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
            (bible-gateway--save-cache result today version))

          ;; Return the result (whether real or fallback)
          result)))))


;;;###autoload
(defun bible-gateway-clear-cache ()
  "Delete the cached verse of the day, forcing a fresh fetch next time."
  (interactive)
  (when (file-exists-p bible-gateway-cache-file)
    (delete-file bible-gateway-cache-file)
    (message "BibleGateway cache cleared.")))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Package section II - Fetch a Bible Passage             ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun bible-gateway--prompt-book ()
  "Prompt for a Bible book name with completion.
If `bible-gateway-use-english-book-names' is non-nil, show KJV names
for completion regardless of the active version; the selected name is
later localized by `bible-gateway--localize-book' before querying."
  (let ((display-list (mapcar #'car
                              (if bible-gateway-use-english-book-names
                                  bible-gateway-bible-books-kjv
                                (bible-gateway--version-books)))))
    (completing-read
     "Select a Book: "
     (lambda (str pred action)
       (if (eq action 'metadata)
           '(metadata (display-sort-function . identity)
                      (cycle-sort-function   . identity))
         (complete-with-action action display-list str pred)))
     nil t)))


(defun bible-gateway--prompt-chapter-verse (display-book)
  "Prompt for a chapter/verse for DISPLAY-BOOK.
DISPLAY-BOOK may be a KJV name (when `bible-gateway-use-english-book-names'
is non-nil) or an already-localized name.  Returns a string of the form
\"LOCALIZED-BOOK CHAPTER[:VERSE]\" ready to be sent to BibleGateway."
  (let* ((localized-book (bible-gateway--localize-book display-book))
         (books-list (bible-gateway--version-books))
         (max-chapters (cdr (assoc localized-book books-list))))
    (unless max-chapters
      (error "Could not find chapter count for book: %s in version %s"
             localized-book bible-gateway-bible-version))
    (let ((input (read-string
                  (format "Select passage from %s (1-%d): "
                          display-book max-chapters))))
      (format "%s %s" localized-book input))))


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
      ;; Remove inline footnote markers (e.g., <sup class='footnote' ...>[a]</sup>)
      (replace-all "<sup[^>]*class='footnote'[^>]*>\\(.\\|\n\\)*?</sup>" "")
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
    (let ((fill-prefix "    ")
          (fill-column (- (window-body-width) 5)))
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
         ;; `chosen-passage' is "BOOK PASSAGE" when built by
         ;; `bible-gateway--prompt-chapter-verse', and just "PASSAGE" when
         ;; supplied programmatically.  Normalize both into a single
         ;; "BOOK PASSAGE" form; URL encoding handles the space.
         (search-string (if passage-supplied
                            (format "%s %s"
                                    (string-trim chosen-book)
                                    (string-trim chosen-passage))
                          (string-trim chosen-passage)))
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
                    (setq title
                          (decode-coding-string
                           (encode-coding-string
                            (buffer-substring-no-properties start (1- end)) 'utf-8)
                           'utf-8)))))

              ;; Then get the verses
              (goto-char (point-min))
              (let ((raw-content "")
                    (verses '()))
                (while (search-forward "<div class='passage-content passage-class-0'>" nil t)
                  (let* ((start (point))
                         (end (search-forward "</div>" nil t))
                         (block (and end
                                     (buffer-substring-no-properties start (1- end)))))
                    (when block
                      (setq raw-content (concat raw-content block)))))

                (if (not (string-empty-p raw-content))
                    (progn
                      ;; First, remove chapter numbers
                      (setq raw-content
                            (replace-regexp-in-string
                             "<span class=\"chapternum\">[^<]*</span>" "" raw-content))

                      ;; Remove verse numbers but keep content
                      (setq raw-content
                            (replace-regexp-in-string
                             "<sup class=\"versenum\">[^<]*</sup>" "" raw-content))

                      ;; Remove footnotes section (entire block at the end)
                      (setq raw-content
                            (replace-regexp-in-string
                             "<div class=\"footnotes\">\\(.\\|\n\\)*" "" raw-content))

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
                                 (verse-text (bible-gateway--process-verse-text verse-content))
                                 (final-text (bible-gateway--wrap-verse-text verse-text)))
                            (when (not (string-empty-p final-text))
                              (push (format "%s.%s%s"
                                            verse-num
                                            (if (< (string-to-number verse-num) 10) "  " " ")
                                            final-text)
                                    verses)))))

                      ;; Insert title and verses
                      (with-current-buffer original-buffer
                        (when (and bible-gateway-include-ref title)
                          (insert title "\n\n"))
                        (insert (string-join (reverse verses) "\n"))))
                  (message
                   (concat "Sorry, we didn’t find any results for your search.\n"
                           "Please double-check that the chapter and verse numbers are valid.")))))))
      (error
       (message "Error while fetching the passage: %s" (error-message-string err))))))

(defvar bible-gateway-passage-buffer-name)
(defvar bible-gateway-passage--highlight-overlay)

;;;###autoload
(defun bible-gateway-read-passage (&optional book passage)
  "Fetch a Bible passage and append it to the *Bible Passage* buffer.
Like `bible-gateway-get-passage', but instead of inserting at point,
the passage is appended to a dedicated read-only buffer in
`bible-gateway-passage-mode'.  Each verse is tagged so that \\`n' and
\\`p' highlight one verse at a time.  Subsequent calls accumulate
passages.  BOOK and PASSAGE are handled identically to
`bible-gateway-get-passage'."
  (interactive)
  ;; Hide the passage window if it's already visible, so it doesn't
  ;; show during prompting.
  (when-let ((existing-buf (get-buffer bible-gateway-passage-buffer-name))
             (existing-win (get-buffer-window existing-buf)))
    (when (window-deletable-p existing-win)
      (delete-window existing-win)))
  ;; Collect all user input FIRST, before touching any buffers/windows.
  (let* ((book-supplied (and book (not (string-empty-p book))))
         (passage-supplied (and passage (not (string-empty-p passage))))
         (chosen-book (if book-supplied book (bible-gateway--prompt-book)))
         (chosen-passage (if passage-supplied
                             passage
                           (let* ((raw (bible-gateway--prompt-chapter-verse chosen-book))
                                  (trimmed (string-trim (substring raw (length chosen-book)))))
                             (if (string-empty-p trimmed) "1" trimmed)))))
    ;; All prompting is done. Now create/display the buffer.
    (message "Fetching %s %s..." chosen-book chosen-passage)
    (let ((buf (get-buffer-create bible-gateway-passage-buffer-name))
          (passage-start nil))
      (display-buffer buf '(display-buffer-full-frame))
      (when-let ((win (get-buffer-window buf)))
        (select-window win)
        (with-current-buffer buf
          (let ((inhibit-read-only t))
            (goto-char (point-max))
            (unless (bobp)
              (insert "\n\n"))
            (setq passage-start (point))
            (let ((bible-gateway-include-ref t))
              (bible-gateway-get-passage chosen-book chosen-passage)
              ;; Tag each verse with a text property.
              ;; A verse starts at "N. " and ends right before the next "N. "
              ;; or at the end of the inserted text.
              (save-excursion
                (goto-char passage-start)
                (while (re-search-forward
                        "^[0-9]+\\.\\s-+" nil t)
                  (let ((verse-start (match-beginning 0))
                        (verse-end
                         (save-excursion
                           (if (re-search-forward "^[0-9]+\\.\\s-+" nil t)
                               (1- (match-beginning 0))
                             (point-max)))))
                    (put-text-property verse-start verse-end
                                       'bible-gateway-verse t))))
              ;; Place cursor just after the reference line.
              (goto-char passage-start)
              (forward-line 2)))
          ;; Remove any existing verse highlight.
          (when (and bible-gateway-passage--highlight-overlay
                     (overlay-buffer bible-gateway-passage--highlight-overlay))
            (delete-overlay bible-gateway-passage--highlight-overlay)
            (setq bible-gateway-passage--highlight-overlay nil))
          (bible-gateway-passage-mode)
          ;; Highlight the first verse of the just-added passage.
          (let ((new-first nil)
                (verses (bible-gateway-passage--verse-positions))
                (idx 0))
            (dolist (v verses)
              (when (and (not new-first) (>= (car v) passage-start))
                (setq new-first idx))
              (setq idx (1+ idx)))
            (bible-gateway-passage--highlight-index (or new-first 0))))))))


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
  "Generate a BibleGateway KJV Dramatized audio URL for CHAPTER of BOOK.
Audio is only available for the KJV version, so the URL always uses
KJV regardless of `bible-gateway-bible-version'."
  (let ((osis-code (cdr (assoc book bible-gateway-bible-books-osis)))
        (base-url "https://www.biblegateway.com/audio/dramatized/kjv"))
    (if osis-code
        (format "%s/%s.%d" base-url osis-code chapter)
      (error "Unknown book: %s" book))))

;;;###autoload
(defun bible-gateway-listen-passage ()
  "Prompt for a Bible chapter and play KJV Dramatized Audio in the browser.
Audio is only available for the KJV version; the book prompt and the
resulting URL always use KJV regardless of the current
`bible-gateway-bible-version'."
  (interactive)
  (let* ((books-list bible-gateway-bible-books-kjv)
         (book (completing-read "Select Book (KJV): "
                                (mapcar #'car books-list) nil t))
         (max-chapters (cdr (assoc book books-list)))
         (input (read-string
                 (format "Select Chapter from %s (1-%d): " book max-chapters)))
         (chapter (string-to-number input)))
    (unless (and (> chapter 0) (<= chapter max-chapters))
      (user-error "Invalid chapter: %S (must be 1-%d)" input max-chapters))
    (browse-url (bible-gateway--get-audio-link book chapter))
    (message "Switch to your browser and click Play to listen to %s %s (KJV)."
             book chapter)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;       Package Section IV - Search the Bible by Keyword                     ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar bible-gateway-search-buffer-name "*Bible Search*"
  "Name of the buffer used to display Bible search results.")

(defvar bible-gateway-passage-buffer-name "*Bible Passage*"
  "Name of the buffer used to display a passage from search results.")

(defun bible-gateway--build-search-url (keyword &optional start)
  "Build the BibleGateway quicksearch URL for KEYWORD.
Optional START is the result offset for pagination (default 0)."
  (concat "https://www.biblegateway.com/quicksearch/?qs_version="
	  (url-encode-url bible-gateway-bible-version)
	  "&quicksearch="
	  (url-encode-url keyword)
	  "&resultspp="
	  (number-to-string bible-gateway-search-results-per-page)
	  "&startnumber="
	  (number-to-string (1+ (or start 0)))))

(defun bible-gateway--strip-search-html (text)
  "Strip HTML from search result TEXT, keeping only the plain content."
  (with-temp-buffer
    (insert text)
    ;; Remove the bible-item-extras div and its contents
    (goto-char (point-min))
    (while (re-search-forward
	    "<div class=\"bible-item-extras\">\\(.\\|\n\\)*?</div>" nil t)
      (replace-match ""))
    ;; Replace small-caps Lord with "LORD" (may contain <b> inside)
    (goto-char (point-min))
    (while (re-search-forward
	    "<span class=\"small-caps\"[^>]*>\\(?:<b>\\)?\\(Lord\\)\\(?:</b>\\)?</span>" nil t)
      (replace-match "LORD"))
    ;; Replace small-caps Jesus with "JESUS" (may contain <b> inside)
    (goto-char (point-min))
    (while (re-search-forward
	    "<span class=\"small-caps\"[^>]*>\\(?:<b>\\)?\\(Jesus\\)\\(?:</b>\\)?</span>" nil t)
      (replace-match "JESUS"))
    ;; Remove <b> and </b> tags but keep their content
    (goto-char (point-min))
    (while (re-search-forward "</?b>" nil t)
      (replace-match ""))
    ;; Remove all remaining HTML tags
    (goto-char (point-min))
    (while (re-search-forward "<[^>]+>" nil t)
      (replace-match ""))
    ;; Decode HTML entities
    (let ((result (bible-gateway--decode-html (buffer-string))))
      (string-trim (replace-regexp-in-string "\\s-+" " " result)))))

(defun bible-gateway--parse-search-results (keyword &optional start)
  "Fetch and parse BibleGateway search results for KEYWORD.
Optional START is the result offset for pagination.
Returns a plist with keys :count, :keyword, :start, and :results,
where :results is a list of (ref . text) cons cells."
  (let ((url (bible-gateway--build-search-url keyword start))
	(count 0)
	(results '()))
    (condition-case err
	(with-current-buffer
	    (url-retrieve-synchronously url t t bible-gateway-request-timeout)
	  (set-buffer-multibyte t)
	  (decode-coding-region (point-min) (point-max) 'utf-8)

	  ;; Extract total count from the "All (N)" filter option
	  ;; Handles comma-separated numbers like "All (6,753)"
	  (goto-char (point-min))
	  (when (re-search-forward
		 "data-display=\"All\"[^>]*>All[[:space:]]*(\\([0-9,]+\\))" nil t)
	    (setq count (string-to-number
			 (replace-regexp-in-string "," "" (match-string 1)))))

	  ;; Fallback: try "N Results" pattern (e.g., "6,968 Results")
	  (when (zerop count)
	    (goto-char (point-min))
	    (when (re-search-forward
		   "\\([0-9,]+\\)[[:space:]]+Results" nil t)
	      (setq count (string-to-number
			   (replace-regexp-in-string "," "" (match-string 1))))))

	  ;; Extract each search result from <li class="row bible-item">
	  (goto-char (point-min))
	  (while (re-search-forward
		  "<li class=\"row bible-item\"" nil t)
	    (let ((li-start (match-beginning 0))
		  (li-end (save-excursion
			    (if (re-search-forward "</li>" nil t)
				(match-end 0)
			      (point-max))))
		  (ref nil)
		  (text nil))
	      ;; Extract reference
	      (goto-char li-start)
	      (when (re-search-forward
		     "<a class=\"bible-item-title\"[^>]*>\\([^<]+\\)</a>"
		     li-end t)
		(setq ref (string-trim (match-string 1))))
	      ;; Extract preview text
	      (goto-char li-start)
	      (when (re-search-forward
		     "<div class=\"bible-item-text[^\"]*\">"
		     li-end t)
		(let ((text-start (match-end 0))
		      (text-end (save-excursion
				  (if (re-search-forward
				       "</div><!-- bible-item-text -->"
				       li-end t)
				      (match-beginning 0)
				    (if (re-search-forward "</div>" li-end t)
					(match-beginning 0)
				      li-end)))))
		  (setq text (bible-gateway--strip-search-html
			      (buffer-substring-no-properties
			       text-start text-end)))))
	      ;; Collect result
	      (when (and ref text)
		(push (cons ref text) results))
	      (goto-char li-end)))
	  (list :count count
		:keyword keyword
		:start (or start 0)
		:results (nreverse results)))
      (error
       (message "Error fetching search results: %s" (error-message-string err))
       (list :count 0 :keyword keyword :start (or start 0) :results nil)))))

(defface bible-gateway-search-ref-face
  '((t :inherit link :weight bold))
  "Face for Bible references in search results."
  :group 'bible-gateway)

(defface bible-gateway-search-keyword-face
  '((t :inherit highlight))
  "Face for the highlighted keyword in search results."
  :group 'bible-gateway)

(defface bible-gateway-search-header-face
  '((t :inherit font-lock-comment-face :weight bold))
  "Face for the search results header line."
  :group 'bible-gateway)

(defface bible-gateway-verse-highlight-face
  '((t :inherit highlight :extend t))
  "Face used to highlight the current verse in `bible-gateway-passage-mode'."
  :group 'bible-gateway)

(defun bible-gateway--highlight-keyword (text keyword)
  "Return TEXT with all occurrences of KEYWORD highlighted."
  (let ((result (copy-sequence text))
	(case-fold-search t)
	(start 0)
	(kw-re (regexp-quote keyword)))
    (while (string-match kw-re result start)
      (let ((beg (match-beginning 0))
	    (end (match-end 0)))
	(put-text-property beg end 'face 'bible-gateway-search-keyword-face result)
	(setq start end)))
    result))

(defun bible-gateway--wrap-search-text (text indent)
  "Wrap TEXT with INDENT spaces for continuation lines."
  (with-temp-buffer
    (insert text)
    (let ((fill-prefix (make-string indent ?\s))
	  (fill-column (- (window-body-width) 5)))
      (fill-region (point-min) (point-max))
      (buffer-string))))

(defvar-local bible-gateway-search--keyword nil
  "The current search keyword for this search buffer.")

(defvar-local bible-gateway-search--start 0
  "The current result offset for pagination.")

(defvar-local bible-gateway-search--total 0
  "The total number of search results.")

(defun bible-gateway--display-search-results (data)
  "Display search results DATA in a dedicated buffer.
DATA is a plist as returned by `bible-gateway--parse-search-results'."
  (let ((buf (get-buffer-create bible-gateway-search-buffer-name))
	(count (plist-get data :count))
	(keyword (plist-get data :keyword))
	(start (plist-get data :start))
	(results (plist-get data :results))
	(rpp bible-gateway-search-results-per-page)
	(version-name (or (cdr (assoc bible-gateway-bible-version
				      bible-gateway-version-names))
			  bible-gateway-bible-version)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
	(erase-buffer)

	;; Header
	(let* ((page-start (1+ start))
	       (page-end (min count (+ start (length results))))
	       (header (if (> count rpp)
			   (format "%d Bible results for \"%s\" from %s. (showing %d-%d)"
				   count keyword version-name page-start page-end)
			 (format "%d Bible results for \"%s\" from %s."
				 count keyword version-name))))
	  (insert (propertize header 'face 'bible-gateway-search-header-face))
	  (insert "\n\n"))

	(if (null results)
	    (insert "No results found.\n")

	  (insert (propertize "Bible search results"
			      'face 'bible-gateway-search-header-face))
	  (insert "\n\n")

	  ;; Each result
	  (dolist (entry results)
	    (let* ((ref (car entry))
		   (text (cdr entry))
		   (highlighted-text (bible-gateway--highlight-keyword
				      text keyword))
		   (wrapped-text (bible-gateway--wrap-search-text
				  highlighted-text 3)))
	      ;; Reference as a clickable button with * prefix
	      (insert "* ")
	      (let ((ref-start (point)))
		(insert ref)
		(put-text-property ref-start (point)
				   'face 'bible-gateway-search-ref-face)
		(put-text-property ref-start (point)
				   'bible-gateway-ref ref)
		(put-text-property ref-start (point)
				   'mouse-face 'highlight))
	      (insert "\n")
	      ;; Preview text
	      (insert "   " wrapped-text)
	      (insert "\n\n")))

	  ;; Pagination footer
	  (when (> count rpp)
	    (let* ((current-page (1+ (/ start rpp)))
		   (total-pages (ceiling (/ (float count) rpp)))
		   (has-prev (> start 0))
		   (has-next (< (+ start rpp) count))
		   (nav-parts '()))
	      (when has-prev (push "P: previous page" nav-parts))
	      (when has-next (push "N: next page" nav-parts))
	      (insert (propertize
		       (format "— Page %d/%d — %s —"
			       current-page total-pages
			       (string-join (nreverse nav-parts) ", "))
		       'face 'bible-gateway-search-header-face))
	      (insert "\n")))))

      ;; Set mode FIRST, then store state (mode kills local vars)
      (bible-gateway-search-mode)
      (setq bible-gateway-search--keyword keyword)
      (setq bible-gateway-search--start start)
      (setq bible-gateway-search--total count)
      (goto-char (point-min)))
    (pop-to-buffer buf)))

(defun bible-gateway-search--next-page ()
  "Fetch and display the next page of search results."
  (interactive)
  (let* ((rpp bible-gateway-search-results-per-page)
	 (next-start (+ bible-gateway-search--start rpp))
	 (total bible-gateway-search--total))
    (if (>= next-start total)
	(message "Already on the last page.")
      (message "Fetching next page...")
      (let ((data (bible-gateway--parse-search-results
		   bible-gateway-search--keyword next-start)))
	;; Preserve total count if the new page didn't find it
	(when (zerop (plist-get data :count))
	  (plist-put data :count total))
	(bible-gateway--display-search-results data)))))

(defun bible-gateway-search--prev-page ()
  "Fetch and display the previous page of search results."
  (interactive)
  (if (<= bible-gateway-search--start 0)
      (message "Already on the first page.")
    (let* ((rpp bible-gateway-search-results-per-page)
	   (prev-start (max 0 (- bible-gateway-search--start rpp)))
	   (total bible-gateway-search--total))
      (message "Fetching previous page...")
      (let ((data (bible-gateway--parse-search-results
		   bible-gateway-search--keyword prev-start)))
	;; Preserve total count if the new page didn't find it
	(when (zerop (plist-get data :count))
	  (plist-put data :count total))
	(bible-gateway--display-search-results data)))))

(defun bible-gateway-search--open-passage ()
  "Open the Bible passage for the reference at point with context."
  (interactive)
  (let ((ref (get-text-property (point) 'bible-gateway-ref)))
    ;; If not directly on a reference, search backward for one
    (unless ref
      (save-excursion
	(when (re-search-backward "^\\* " nil t)
	  (goto-char (match-end 0))
	  (setq ref (get-text-property (point) 'bible-gateway-ref)))))
    (if ref
	(let* ((parts (bible-gateway--split-reference ref))
	       (book (car parts))
	       (passage (cdr parts))
	       (expanded (bible-gateway--expand-verse-context passage))
	       (buf (get-buffer-create bible-gateway-passage-buffer-name)))
	  (message "Fetching %s %s..." book expanded)
	  (with-current-buffer buf
	    (let ((inhibit-read-only t))
	      (erase-buffer)
	      (let ((bible-gateway-include-ref t))
		(bible-gateway-get-passage book expanded))
	      (goto-char (point-min))
	      (bible-gateway-passage-mode)))
	  (display-buffer buf '(display-buffer-in-side-window
				(side . bottom)
				(window-height . 0.35))))
      (message "No reference found at point."))))

(defun bible-gateway-search--mouse-open-passage (event)
  "Open the Bible passage for the reference using mouse EVENT."
  (interactive "e")
  (let ((pos (posn-point (event-end event))))
    (when pos
      (goto-char pos)
      (bible-gateway-search--open-passage))))

(defun bible-gateway--split-reference (ref)
  "Split a Bible reference REF into (BOOK . PASSAGE).
For example, \"1 Chronicles 5:7\" returns (\"1 Chronicles\" . \"5:7\")."
  (if (string-match "\\(.*\\)\\s-+\\([0-9].*\\)" ref)
      (cons (match-string 1 ref) (match-string 2 ref))
    (cons ref "")))

(defun bible-gateway--expand-verse-context (passage)
  "Expand PASSAGE to include ±1 verse of context.
\"5:7\" becomes \"5:6-8\", \"1:1\" becomes \"1:1-3\",
\"5\" (whole chapter, no verse) is returned as-is."
  (if (string-match "^\\([0-9]+\\):\\([0-9]+\\)$" passage)
      (let* ((chapter (match-string 1 passage))
	     (verse (string-to-number (match-string 2 passage)))
	     (start (max 1 (1- verse)))
	     (end (1+ verse)))
	(format "%s:%d-%d" chapter start end))
    ;; No verse number (whole chapter) or already a range — return as-is
    passage))

(defun bible-gateway-search--next-result ()
  "Move to the next search result."
  (interactive)
  (let ((pos (point)))
    (forward-line 1)
    (if (re-search-forward "^\\* " nil t)
	(goto-char (match-end 0))
      (goto-char pos)
      (message "No more results."))))

(defun bible-gateway-search--prev-result ()
  "Move to the previous search result."
  (interactive)
  (let ((pos (point)))
    (beginning-of-line)
    (if (re-search-backward "^\\* " nil t)
	(goto-char (match-end 0))
      (goto-char pos)
      (message "No previous result."))))

(defvar bible-gateway-search-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "RET") #'bible-gateway-search--open-passage)
    (define-key map [mouse-1] #'bible-gateway-search--mouse-open-passage)
    (define-key map (kbd "n") #'bible-gateway-search--next-result)
    (define-key map (kbd "p") #'bible-gateway-search--prev-result)
    ;; For evil users
    (define-key map (kbd "j") #'bible-gateway-search--next-result)
    (define-key map (kbd "k") #'bible-gateway-search--prev-result)
    (define-key map (kbd "N") #'bible-gateway-search--next-page)
    (define-key map (kbd "P") #'bible-gateway-search--prev-page)
    map)
  "Keymap for `bible-gateway-search-mode'.")

(define-derived-mode bible-gateway-search-mode special-mode "Bible-Search"
  "Major mode for displaying BibleGateway search results.

\\{bible-gateway-search-mode-map}"
  :group 'bible-gateway
  (setq-local truncate-lines nil)
  (setq-local word-wrap t))

(defvar-local bible-gateway-passage--highlight-overlay nil
  "Overlay used to highlight the current verse.")

(defun bible-gateway-passage--verse-positions ()
  "Return a sorted list of (START . END) for every verse in the buffer.
A verse is any region of text with the `bible-gateway-verse' property."
  (let ((positions '())
        (pos (point-min)))
    (while (setq pos (next-single-property-change pos 'bible-gateway-verse))
      (when (get-text-property pos 'bible-gateway-verse)
        (let ((end (or (next-single-property-change pos 'bible-gateway-verse)
                       (point-max))))
          (push (cons pos end) positions)
          (setq pos end))))
    (nreverse positions)))

(defun bible-gateway-passage--current-index ()
  "Return the index of the currently highlighted verse, or -1."
  (if (and bible-gateway-passage--highlight-overlay
           (overlay-buffer bible-gateway-passage--highlight-overlay))
      (let ((ov-start (overlay-start bible-gateway-passage--highlight-overlay))
            (verses (bible-gateway-passage--verse-positions))
            (idx 0))
        (catch 'found
          (dolist (v verses)
            (when (= (car v) ov-start)
              (throw 'found idx))
            (setq idx (1+ idx)))
          -1))
    -1))

(defun bible-gateway-passage--highlight-index (index)
  "Highlight the verse at INDEX (0-based)."
  (let ((verses (bible-gateway-passage--verse-positions)))
    (when (and (>= index 0) (< index (length verses)))
      (let ((v (nth index verses)))
        (if (and bible-gateway-passage--highlight-overlay
                 (overlay-buffer bible-gateway-passage--highlight-overlay))
            (move-overlay bible-gateway-passage--highlight-overlay (car v) (cdr v))
          (setq bible-gateway-passage--highlight-overlay
                (make-overlay (car v) (cdr v)))
          (overlay-put bible-gateway-passage--highlight-overlay
                       'face 'bible-gateway-verse-highlight-face))
        (goto-char (car v))))))

(defun bible-gateway-passage--next ()
  "Highlight the next verse."
  (interactive)
  (let* ((cur (bible-gateway-passage--current-index))
         (next (1+ cur))
         (total (length (bible-gateway-passage--verse-positions))))
    (if (< next total)
        (bible-gateway-passage--highlight-index next)
      (message "Last verse."))))

(defun bible-gateway-passage--prev ()
  "Highlight the previous verse."
  (interactive)
  (let* ((cur (bible-gateway-passage--current-index))
         (prev (1- cur)))
    (if (>= prev 0)
        (bible-gateway-passage--highlight-index prev)
      (message "First verse."))))

(defvar bible-gateway-passage-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map special-mode-map)
    (define-key map (kbd "n") #'bible-gateway-passage--next)
    (define-key map (kbd "p") #'bible-gateway-passage--prev)
    (define-key map (kbd "j") #'bible-gateway-passage--next)
    (define-key map (kbd "k") #'bible-gateway-passage--prev)
    map)
  "Keymap for `bible-gateway-passage-mode'.")

(define-derived-mode bible-gateway-passage-mode special-mode "Bible-Passage"
  "Major mode for reading Bible passages.
The buffer is read-only.  Use \\`n' and \\`p' to move the highlight
between verses, and \\`q' to close.

\\{bible-gateway-passage-mode-map}"
  :group 'bible-gateway
  (setq-local truncate-lines nil)
  (setq-local word-wrap t))


;;;###autoload
(defun bible-gateway-search (keyword)
  "Search BibleGateway for KEYWORD and display results in a buffer.
Results are shown in a dedicated buffer with clickable references.
Press RET on a reference to view the full passage.
Press n/p to navigate between results.
Press N/P to navigate between pages.
Press q to close the buffer."
  (interactive "sSearch the Bible for: ")
  (when (string-empty-p (string-trim keyword))
    (user-error "Please enter a search keyword"))
  (message "Searching BibleGateway for \"%s\"..." keyword)
  (let ((data (bible-gateway--parse-search-results keyword)))
    (bible-gateway--display-search-results data)
    (message "%d results for \"%s\"."
	     (plist-get data :count) keyword)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                   Package Section V - Bible Reading Plan                   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defcustom bible-gateway-plans-dir
  (locate-user-emacs-file "bible-gateway/plans/")
  "Directory containing reading-plan CSV files.

Each CSV must have a header row with columns Date,Passage and use
ISO dates (YYYY-MM-DD) in column 1.  The Passage column may contain
one or more references separated by semicolons, e.g.
\"Gen 1; Mat 1; Ezr 1; Acts 1\".

Row 1 of the CSV defines the start date of the plan; subsequent
rows are read in order and matched against the current date."
  :type 'directory
  :group 'bible-gateway)

(defcustom bible-gateway-reading-plan nil
  "Filename of the active reading plan inside `bible-gateway-plans-dir'.
Set to nil to disable reading-plan commands.  Example:
  (setq bible-gateway-reading-plan \"bibleplan.csv\")"
  :type '(choice (const :tag "None" nil) string)
  :group 'bible-gateway)

(defun bible-gateway--plan-file ()
  "Return the absolute path to the active plan CSV, or signal an error."
  (unless bible-gateway-reading-plan
    (user-error
     "No reading plan set.  Customize `bible-gateway-reading-plan'"))
  (let ((path (expand-file-name bible-gateway-reading-plan
                                bible-gateway-plans-dir)))
    (unless (file-readable-p path)
      (user-error "Reading plan not found: %s" path))
    path))

(defconst bible-gateway--csv-book-translations
  '(("Sos" . "Song")     ; Song of Solomon
    ("Jdg" . "Judges")
    ("Joe" . "Joel")
    ("Oba" . "Obadiah")
    ("Amo" . "Amos")
    ("Eze" . "Ezekiel")
    ("Rut" . "Ruth"))
  "Translation map from CSV abbreviations to BibleGateway-friendly names.

Some CSV exporters (such as bibleplangenerator) use short forms
that BibleGateway does not recognize.  This map is consulted only
for plan rendering; abbreviations not in the map pass through
unchanged.")

(defun bible-gateway--translate-csv-book (book)
  "Translate BOOK from CSV abbreviation to BibleGateway-friendly name.
Returns BOOK unchanged if no translation is defined."
  (or (cdr (assoc book bible-gateway--csv-book-translations))
      book))

(defun bible-gateway--parse-csv-row (line)
  "Parse a single CSV LINE into (DATE . PASSAGE) or nil if malformed.
Handles double-quoted fields; expects exactly two columns."
  (when (string-match
         "\\`\"\\([^\"]*\\)\",\"\\([^\"]*\\)\"\\s-*\\'"
         line)
    (cons (match-string 1 line) (match-string 2 line))))

(defun bible-gateway--plan-lookup (date)
  "Return the passage string scheduled for DATE in the active plan.
DATE is a string in YYYY-MM-DD form.  Returns nil if not found."
  (with-temp-buffer
    (insert-file-contents (bible-gateway--plan-file))
    (goto-char (point-min))
    (forward-line 1)            ; skip header
    (let (result)
      (while (and (not result) (not (eobp)))
        (let* ((line (buffer-substring-no-properties
                      (line-beginning-position) (line-end-position)))
               (row (bible-gateway--parse-csv-row line)))
          (when (and row (string= (car row) date))
            (setq result (cdr row))))
        (forward-line 1))
      result)))

(defun bible-gateway--split-references (passage)
  "Split PASSAGE \"Gen 1; Mat 1; Ezr 1\" into a list of trimmed references."
  (mapcar #'string-trim (split-string passage ";" t)))

(defun bible-gateway--parse-reference (ref)
  "Parse REF into a (BOOK . PASSAGE) cons.

REF is a single Bible reference such as \"Gen 1\", \"Mat 9-10\",
\"1 Sa 3:16\", or \"Song of Solomon 2:1-7\".  Returns a cons of
(BOOK . PASSAGE) where PASSAGE is the chapter/verse portion (may
contain colons and hyphens) and BOOK is everything before it.

The parser walks back from the end: the trailing run of digits,
colons, hyphens, and commas is the passage; everything before is
the book.  Returns nil if REF cannot be parsed."
  (let ((trimmed (string-trim ref)))
    (when (string-match "\\`\\(.+?\\)[ \t]+\\([0-9][0-9:,-]*\\)\\'" trimmed)
      (cons (string-trim (match-string 1 trimmed))
            (match-string 2 trimmed)))))

(defun bible-gateway--render-plan-day (date passage)
  "Render PASSAGE (semicolon-separated refs) for DATE in the passage buffer."
  (let ((references (bible-gateway--split-references passage))
        (buf (get-buffer-create bible-gateway-passage-buffer-name)))
    ;; Drop any existing highlight before erasing.
    (when (and bible-gateway-passage--highlight-overlay
               (overlay-buffer bible-gateway-passage--highlight-overlay))
      (delete-overlay bible-gateway-passage--highlight-overlay)
      (setq bible-gateway-passage--highlight-overlay nil))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "Reading Plan — %s\n" date))
        (insert (make-string bible-gateway-text-width ?=) "\n\n")
        (dolist (ref references)
          (let ((parsed (bible-gateway--parse-reference ref)))
            (cond
             (parsed
              (let ((book (bible-gateway--translate-csv-book (car parsed)))
                    (chap (cdr parsed))
                    (passage-start (point)))
                (insert (format "── %s ──\n\n" ref))
                (let ((bible-gateway-include-ref t))
                  (bible-gateway-get-passage book chap))
                ;; Tag each verse so n/p navigation works.
                (save-excursion
                  (goto-char passage-start)
                  (while (re-search-forward "^[0-9]+\\.\\s-+" nil t)
                    (let ((vstart (match-beginning 0))
                          (vend
                           (save-excursion
                             (if (re-search-forward "^[0-9]+\\.\\s-+" nil t)
                                 (1- (match-beginning 0))
                               (point-max)))))
                      (put-text-property vstart vend
                                         'bible-gateway-verse t))))
                (goto-char (point-max))
                (insert "\n\n")))
             (t
              (insert (format "── %s ──\n\n" ref))
              (insert (format "(could not parse reference: %s)\n\n" ref))))))
        (goto-char (point-min)))
      (bible-gateway-passage-mode)
      ;; Highlight the first tagged verse.
      (let ((verses (bible-gateway-passage--verse-positions)))
        (when verses
          (bible-gateway-passage--highlight-index 0))))
    (pop-to-buffer buf)))

;;;###autoload
(defun bible-gateway-read-today ()
  "Open today's readings from the active reading plan in one buffer.
References are concatenated with headers separating each passage."
  (interactive)
  (let* ((today (format-time-string "%Y-%m-%d"))
         (passage (bible-gateway--plan-lookup today)))
    (unless passage
      (user-error "No reading scheduled for %s in %s"
                  today bible-gateway-reading-plan))
    (bible-gateway--render-plan-day today passage)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     Package Section VI - Transient Menu                    ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'transient)

(defun bible-gateway--version-description ()
  "Return a string showing the active Bible version for the transient header."
  (let ((code bible-gateway-bible-version)
        (name (cdr (assoc bible-gateway-bible-version bible-gateway-version-names))))
    (if name
        (format "%s - %s" code name)
      (format "%s" code))))

;;;###autoload
(defun bible-gateway-show-verse ()
  "Fetch and display the verse of the day in the echo area."
  (interactive)
  (message "%s" (bible-gateway-get-verse)))

;;;###autoload
(transient-define-prefix bible-gateway ()
  "Transient menu for 'bible-gateway' commands."
  ["Passages"
   :description (lambda ()
                  (concat "BibleGateway ("
                          (bible-gateway--version-description) ")\n\nPassages"))
   ("v" "Verse of the day" bible-gateway-show-verse)
   ("i" "Insert Bible passage" bible-gateway-get-passage)
   ("r" "Read Bible passage" bible-gateway-read-passage)
   ("p" "Today's reading" bible-gateway-read-today)]
  ["Audio"
   ("l" "Listen to chapter (KJV Dramatized)" bible-gateway-listen-passage)]
  ["Search"
   ("s" "Search by keyword" bible-gateway-search)]
  ["Settings & Utilities"
   ("V" "Set Bible version" bible-gateway-set-version)
   ("c" "Clear verse-of-the-day cache" bible-gateway-clear-cache)])

(provide 'bible-gateway)
;;; bible-gateway.el ends here
