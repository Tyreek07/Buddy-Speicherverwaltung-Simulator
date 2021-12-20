#!/bin/bash

#Dies ist die Hauptquelle
#BuddySimulator v0.7B by Tarek Sabbagh and Thatree Ludwig
#IMPORTANT: Bash v4.0+ is required as associative arrays are part of the source

source ./Library.bash #Externe Funktionsbibliothek

echo -e "\n${bold}Willkommen zum BuddySimulator v0.7B"
echo -en "\n${bold}Wie groß soll der Hauptspeicher sein?\n${blue}Bitte nur in Zweierpotenzen: ${normal}" # "-n" verhindert eine Newline, also ein Zeichenumbruch, "-e" erkennt die Backshlashkommandos "\n" - newline, "\t"- tabulator.
read "memory" #Eingabe der Hauptspeicherkapazität

attempt=3 #Insgesamt 4 Versuche um eine Zweierpotenz einzugeben

memoryCheck "$memory" #Prüft, ob die Eingabe eine Zweierpotenz ist
addBuddyList 1 "$memory"  #Fügt den 1. Buddy in einen Array - "0-001-'memory'"
echo -e "\n${bold}Der Hauptspeicher besitzt nun ${underline}${memory}MB${normal}"
#HINWEIS: Die Variable "memory" bleibt IMMER den Gesamtspeicher

#Hauptmenü-Schleife
echo -e "\n${bold}Hauptmenü${normal}"
PS3=$'\n'"Bitte Auswählen: "  #Dieser String erscheint immer, wenn ein Selectmenu aufgerufen wird
select auswahl in "Prozess starten" "Prozess beenden" "Informationen anzeigen" "Simulator beenden" #Hier wird die Hauptmenü-Schleife aktiviert. Wird diese Schleife beendet, endet das Programm
do
  case "$auswahl" in  #Case-Funktion um zwischen den Möglichkeiten zu differenzieren
    "Prozess starten" ) #Wenn ein Prozess gestartet werden soll
      echo -n "${bold}Prozessgröße angeben:${normal} "
      read "processSize"  #Größe des zu aktivierenden Prozesses wird angefragt. HINWEIS: Die Variable "processSize" ist wichtig
      processSizeCheck $processSize #Prüft ob die Eingabe ein Integer ist
      if [[ $error != "noinput" ]]; then #Wenn der Teststring "error"(in Library) nicht den String "noinput" als Element besitzt, wird der Prozess gestartet bzw. einem passenden Buddy zugeteilt.
        assignProcess "$processSize"  #Hier wird der Prozess gestartet bzw. einem passenden Buddy zugeteilt
        getBuddyList #Die Werte von der buddyList wird ausgegeben - Alle Speicherbuddies werden angezeigt
        getActiveList #Werte von activeList wird ausgegeben - Alle Prozesse und aktive Buddies werden angezeit
        getError #Es sind eventuell Errors ausgegeben, die dann ausgegeben werden, zb. Wenn der Speicher zu voll ist
      fi
      error="" #Der Teststring "error" wird zurückgesetzt
      getmenu ;; #Gibt das Menu aus für die nächste Select-Schleife
    "Prozess beenden" ) #Wenn Prozesse beendet werden soll
      getProcessList #Startet neue Select (1 Prozess beenden) (alle Prozesse beenden) (Zurück)
      if [[ $error != "noinput" ]]; then #Wenn kein Error ist, dann wird ein Prozess beendet
        terminateProcess $processID #Terminiert den Prozess und schaut ob Buddies vereint werden können
        getBuddyList  #Siehe Z. 31 - 36
        getActiveList
        getError
      fi
      error=""
      getmenu ;; #Gibt das Menu aus für die nächste Select-Schleife
    "Informationen anzeigen" ) #Diverse Informationen werden ausgegeben (Gesamtspeicher) (Freier Speicher) (belegter Speicher) (Wie viele Buddies)
      getBuddyList #Z.31
      getActiveList #Z.32
      echo -e "${bold}\nGesamtspeicher: ${blue}${memory}MB${normal}"
      getInfo #Holt diverse Infos
      getmenu ;; #Z.36
    "Simulator beenden" ) #Das Programm wird beendet
      echo -e "\n${bold}${blue}Auf Wiedersehen!${normal}\n"
      exit 1 ;; #terminiert das Programm
    * ) #Bei nicht-vorgegebenen Antworten
      echo -e "${bold}${red}Fehler - Ungültige Eingabe erkannt\nBitte Wiederholen:${normal}"
      getmenu ;; #Gibt das Menu aus für die nächste Select-Schleife
  esac
done
