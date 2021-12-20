#!/bin/bash
source ./Color.bash
#Dies ist die Funktionsbibliothek - Hier werden alle Funktionen gespeichert, um mehr Ordnung zu schaffen

#WICHTIG: Bitte von unten nach oben anfangen
#Reihenfolge um Prozess zu starten (Hauptfunktion)->  processSizeCheck () - assignProcess() - setTargetBuddy - splitBuddy () | Einfach vun
#Reihenfolge um Prozess zu beenden (Hauptfunktionen) -> getProcessList () - terminateProcess () - mergeBuddy () <-> getTwinIndex ()

#WICHTIG: Die Buddy-"ID" im Format "0-0000-0000" ist in 3 Abschnitten unterteilt, getrennt durch Bindestriche. Die erste Ziffer zeigt ob der Buddy aktiv ist. (BusyBit)
#Der mittlere Bereich ist der Index - zb: ${buddyList[11]} = "0-'011'-004"
#Der hintere Bereich zeigt die Größe des Speicherbuddies.
#Bei der Prozess-"ID" fällt der erste Bereich weg.

declare -A activeList
declare -a buddyList
declare -a processList
declare -a orderList
declare -i idCount=0

#WICHTIG:
#Es gibt 4 Arrays:
#buddyList - enthält alle Buddies mit dem jeweiligen Index.  Z.B. ${buddyList[11]} = "0-'011'-002"

#processList - enthält alle Prozesse mit dem jeweiligen Index  Z.B. ${processList[1]} = "'001'-001"

#activeList - dies ist ein assoziates Array und enthält alle AKTIVEN Speicherbuddies und jeweils die Prozesse, die zugewiesen sind.
#(Es herrscht eine Assoziation in activeList, da die Buddy-"ID" als Indizen(/Index) fungieren und jeweils die Prozess-"IDs" als Elemente gespeichert sind. zb. ${activeList["0-011-002"]} = "001-001"

#orderList - Hilfe um Reihenfolge bei einer for-Schleife (oder andere Iterationen) zu erhalten. (Input-order)
# z.b. aus: "003, 005. 002, 004, 001" wird: "001, 002, 003, 004, 005" (Bei der activeList)

function getmenu () {         #Gibt den "Menutext aus"
  echo -e "\nHauptmenü\n1) Prozess starten\t3) Informationen anzeigen\n2) Prozess beenden\t4) Simulator beenden${normal}" >&2
}

getError () {                 #Wenn der Teststring "error" einen Wert hat, wird dieser hier geprüft und eine Errormeldung wird ausgedruckt
  if [[ $error = "outofmemory" ]]; then
    echo -e "\n${red}${bold}Kein passender Speicher verfügbar!${normal}"
    error=""
  fi

  if [[ $error = "waiting" ]]; then
    error=""
    echo -e "\n${red}${bold}Fehler - Keine gültige Auswahl!${normal}"
  fi

  if [[ $error = "bigger" ]]; then
    error=""
    echo -e "\n${red}${bold}Fehler - Keine gültige Auswahl!${normal}"
  fi
  if [[ $error = "pass" ]]; then
    error=""
    echo -e "\n${green}${bold}Die Zuweisung war erfolgreich!${normal}"
  fi
  if [[ $error = "removed" ]]; then
    error=""
    echo -e "\n${green}${bold}Die Terminierung war erfolgreich!${normal}"
  fi
}

function getBuddySize () {   #Aus der vollen ID wird der hintere Bereich als Substring extrahiert. (SizeID)
  local fullID="$1" #Übergibt die volle ID an fullID
  subSizeID=${fullID##*-} #alles hinter dem 2. Bindestrich wird weitergegeben. Hinweis: (##*-) -> der längste Weg zum Bindestrich: zb. 0-213-034 => 034
  subSizeID=$(( 10#$subSizeID )) #Werte mit führende Nullen also zb "003" werden bei Test-Abfragen (zb if) als octal interpretiert. Hier wird der Wert gezwungen als Dezimal interpretiert zu werden.
  echo "$subSizeID"  #gibt die "subSizeID" zurück. also die Größe.
}

function getBuddyIndex () { #Aus der vollen ID wird der mittlere Bereich als Substring extrahiert. (IndexID) (Volle ID muss weitergegeben werden)
  local fullID="$1"
  subIndexID=${fullID#*-}  #alles hinter dem 1. Bindestrich wird weitergegeben. Hinweis: (#*-) -> der kürzeste Weg zum Bindestrich: zb. 0-213-034 => 213-034
  subIndexID=${subIndexID%-*} #alles vor dem 1. Bindestrich wird weitergegeben. Hinweis: (%-*) -> der kürzeste Weg zum Bindestrich: zb. 213-034 => 213
  subIndexID=$(( 10#$subIndexID  )) #Z.59
  echo "$subIndexID"  #gibt die "subIndexID" zurück. also den Index.
}

function getProcessIndex () { #fast Wie getBuddyIndex () (Volle ID muss weitergegeben werden)
  local fullID="$1"
  subIndexID=${fullID%-*} #Z.65
  subIndexID=$(( 10#$subIndexID ))
  echo "$subIndexID"
}

function getFirstBit() { #(Volle ID muss weitergegeben werden)
  local busyBit="${1:0:1}" #Extrahiert das 1. Zeichen aus dem String den Busybit
  echo "$busyBit"
}

function toggleBusyBit () { #(Volle ID muss weitergegeben werden ($1) und entweder 0 oder 1 (für $2))
  buddyList+=([$1]="$2${buddyList[$1]:1}")
}

function getInfo () { #Gibt weitere Informationen aus
  usedSpace=0 #Reset / Ausgangswert
  freeSpace=0 #Reset / Ausgangswert
  local buddyCounter=0 #Zählt wie viele Buddies existieren
  for i in ${buddyList[@]} #Für jeden Eintrag in buddyList. "i" hat das Element in sich (Also die BuddyID).
  do
    if [[ $(getFirstBit $i) -ne 1 ]]; then #Wenn Busybit/FirstBit nicht 1 ist bzw. der Buddy nicht besetzt ist, dann...
      subSizeID=$(getBuddySize $i) #Holt sich den 3. Abschnitt, also die Größe. (Aus der vollen BuddyID)
      freeSpace=$(( $subSizeID + $freeSpace )) #fügt bei jedem freien Buddy dessen Speicherplatz dazu
    else                                   #Ansonsten (also Busybit = 1)
      subSizeID=$(getBuddySize $i)
      usedSpace=$(( $subSizeID + $usedSpace )) #fügt bei jedem besetzten Buddy dessen Speicherplatz dazu
    fi
  done

  echo -e "\n${bold}${lightred}Verwendeter Speicher: ${usedSpace}MB${normal}"
  echo -e "${bold}${green}Verfügbarer Speicher: ${freeSpace}MB\n${normal}"
  echo "${bold}Anzahl Speicherbuddies: ${#buddyList[*]}${normal}" #Anzahl der Buddies
  echo "${bold}Anzahl aktiver Prozesse: ${#activeList[*]}${normal}" #Anzahl der aktiven Buddies
}

function getBuddyList () { #Gibt die buddyList aus - also alle Speicherbuddies
  echo -e "\n${bold}Alle Speicherbuddies${normal}"
  for i in ${buddyList[@]}
  do
    echo "$i"
  done
}

function getActiveList () { #Gibt die activeList aus - also alle aktiven Speicherbuddies und alle Prozesse (In der Input-Reihenfolge)
  echo -e "\n${bold}aktive Buddies\taktive Prozesse${normal}"
  if [[ ${#activeList[@]} -eq 0 ]]; then
    echo -e "-\t\t-"
  fi
  for i in "${!orderList[@]}" #order hat die Reihenfolge: 1, 2, 3, 4, 5...Somit wird eine richtige Reihenfolge gesichert (Hat als Elemente die aktiven BuddyIDs)
  do
    echo -e "${orderList[$i]}\t${activeList[${orderList[$i]}]}" #Die Elemente (BuddyIDs) werden eingefügt in die activeList und man erhält die ProcessIDs
  done
}

function addActives() { #Hier wird ein neuer Eintrag eingefügt in die activeList. $1 ist BuddyID (Auch neuer OrderList Eintrag)
  ((idCount++)) #Mit jedem Einfügen geht dieser Counter hoch (Gleichzeitig der Index der Prozesse)
  orderList+=( ["$idCount"]="$1" )  #order hat die Reihenfolge: 1, 2, 3, 4, 5...Somit wird eine richtige Reihenfolge gesichert (Hat als Elemente die aktiven BuddyIDs ($1))
  activeList+=( [$1]="$(printf "%04d" "$idCount")-$(printf "%04d" "$processSize")" ) #BuddyID als Index eingefügt - Der Rest steht schon als Name da
  processList+=( ["$idCount"]="$(printf "%04d" "$idCount")-$(printf "%04d" "$processSize")" ) #Neuer Eintrag in processList
}

#HINWEIS: printf "%04d" bedeutet, dass die Zahl immer 4 Stellen als String hat, also auch mit führenden Nullen - zb: 25 -> 0025 / 3 -> 0003

function addBuddyList() { #Hier wird ein neuer Eintrag eingefügt in die buddyList. $1 ist Index, $2 ist die Größe
  local index="$1"
  local size="$2"
  buddyList+=( ["$index"]="0-$(printf "%04d" "$index")-$(printf "%04d" "$size")" )
}

function getTwinIndex() { #Ein Zwillingspaar besteht immer aus zuerst einem geraden Index und dann einem ungeraden Index. $1 ->Index
  twinIndexID="$1" #Index wird an "twinIndexID übergeben
  if !(($twinIndexID%2)); then #Wenn der ursprüngliche Index gerade ist (modulo 2)...         WICHTIG: Bei der Bash Arithmetik - also (($twinIndexID%2)) ist die 0 false und 1 true - deshalb "!"
    ((twinIndexID++))          #...dann ist der Zwillingsindex +1 (vom Ausgangsindex)
  else                  #ansonsten (also ungerade), dann...
    ((twinIndexID--))   #...dann ist der Zwillingsindex -1 (vom Ausgangsindex)
  fi
  echo $twinIndexID   #gibt den Zwillingsindex zurück
}

#Ziel=Target
function setTargetBuddy () { #Zielbuddy wird ausgewertet
  fullID="$1" #Volle BuddyID
  subSizeID=$(getBuddySize "$fullID") #Größe des Buddys
  subIndexID=$(getBuddyIndex "$fullID") #Index des Buddys
  if [[ "$targetSize" -gt "$subSizeID" && "$subSizeID" -ge "$processSize"  && -n ${buddyList[$subIndexID]} ]]
  then  #Wenn bestehende Zielgröße größer als die übergebene Buddygröße ist und übergebene Buddygröße  größer gleich die Prozessgröße ist und der Eintrag buddyList[$subIndexID] nicht null ist
    targetSize=$subSizeID #Dann werden die neuen Werte übergeben
    targetIndex=$subIndexID #sonst nicht
  fi
}

function mergeBuddy() { #vereint Zwillingsbuddies (passende Buddies), wenn es geht
  subIndexID="$1"
  twinIndexID=$(getTwinIndex $subIndexID) #Holt sich den Zwillingsindex
  if [[ $(getFirstBit ${buddyList[$twinIndexID]}) -ne 1 && -n ${buddyList[$twinIndexID]} ]]; then #Wenn der Busybit vom Zwillingsbuddy nich aktiv bzw. nicht "1" ist und
    if (( $subIndexID % 2 )); then #Wenn der eigentliche BuddyIndex ungerade ist                  #der Eintrag aus buddyList[$twinIndexID] nicht null ist.
      targetIndex=$twinIndexID #Dann wird der ZwillingsIndex an targetIndex übergeben (muss der gerade Index sein)
    else #ansonsten, also wenn der eigentliche BuddyIndex gerade ist
      targetIndex=$subIndexID #dann wird  der eigentliche BuddyIndex an targetIndex übergeben (muss der gerade Index sein)
    fi        #WICHTIG: Bei der Bash Arithmetik - also (($twinIndexID%2)) ist die 0 false und 1 true - deshalb "!" bei Z. 166

    #Gegenteil zur Funktion splitBuddy ()
    targetSize=$(( $(getBuddySize ${buddyList[$subIndexID]}) * 2 )) #Der Wert der targetSize(Zielgröße) wird verdoppelt
    targetIndex=$(( $targetIndex / 2 )) #Der Wert der targetIndex(ZielIndex) wird halbiert
    addBuddyList $targetIndex $targetSize #Ein großer Buddy wird nun hinzugefügt .
    unset buddyList[$subIndexID] #Die Eintrag des Zwillingspaares wird gelöscht
    unset buddyList[$twinIndexID]
    mergeBuddy $targetIndex #Wiederholt den Befehl, bis keine Buddies mehr vereint werden können.
  fi
}

function terminateProcess () { #einzelner Prozess wird terminiert - $1 ist die processID
  processID=$1 #Übergabe ProzessID
  error="waiting" #Teststring wird im Vorraus geändert. Wenn er nicht zurückgesetzt wird in dieser Funktion (Siehe Z.187), dann bleibt der Fehler bis getError ihn validiert
  for i in ${orderList[@]} #Für jeden Eintrag in orderList.. (i enthält die Elemente / BuddyID)
  do
    if [[ ${activeList[$i]} == $processID ]]; then #Wenn dieser Eintrag von activeList der übergebenen processID entspricht, dann
      error="removed"; #error gibt später eine Bestätigung aus
      local subIndexID=$(getBuddyIndex "$i") #Holt den Index vom aktiven Buddy (dieser Buddy besitzt auch den zu terminierenden Prozess)
      processIndex=$(getProcessIndex $processID) #Holt den Index vom zu terminierenden Prozess
      toggleBusyBit "$subIndexID" "0" #Deaktiviert den Buddy wieder (Macht BusyBit zu "0")
      unset activeList[$i] #Löscht den activeList Eintrag und somit die Assoziation zwischen dem aktiven Buddy und dem Prozess
      unset processList[$processIndex] #Löscht den Eintrag aus processList und somit auch den Prozess an sich
      unset orderList[$processIndex] #löscht den zusammenhängenden orderList Eintrag, damit keine falschen Infos ausgegeben werden.
      mergeBuddy $subIndexID #Wenn möglich, dann werden die BuddyZwillinge zusammengeführt
      break #Beendet die for Schleife
    fi
  done
}

function getProcessList () { #Gibt weiteren Selectmenu aus
  if [[ ${#activeList[@]} -ne 0 ]]; then #Wenn die aktivListe nicht leer ist (Also wenn mind. 1 Prozess aktiv ist)
    echo -e "\n" #Absatz
    select choice in "Einzelnen Prozess beenden" "Alle Prozesse beenden" "Abbrechen" #3 Auswahlmöglichkeiten
    do
      case "$choice" in
        "Einzelnen Prozess beenden" ) #Im Prinzip fast wie ein Reset
          echo "Welcher Prozess soll beendet werden?"
          select process in ${processList[*]} #Selectmenu aus allen Prozessen
          do
            processID=$process #übergibt die ProzessID
            break #Beendet die momentante Select-Schleife
          done
          break ;; #Beendet die Select-Schleife
        "Alle Prozesse beenden" )
          error="noinput" #Verhindert den Vorgang der Terminierung "eines Prozesses"
          unset buddyList #Löscht den kompletten buddyList-Array
          unset processList #Löscht den kompletten processList-Array
          for i in ${orderList[@]} #für jeden Eintrag in der OrderList (i beinhaltet die Elemente / aktiven BuddyIDs)
          do
            unset activeList["$i"] #Löscht die Einträge einzeln in der Schleife
          done #Methode alle Einträge zu löschen in einem assoziaten Array. (Wenn komplett löschen, dann Deklarierung nicht möglich)
          unset orderList
          addBuddyList 1 "$memory" #"Erstellt" den Array buddyList und fügt den 1. großen Buddy hinzu. (Also 0-001-"Memory")
          getBuddyList #Gibt die frische BuddyList aus
          echo -e "\n${green}${bold}Die Terminierung war erfolgreich!${normal}"
          echo
          break ;; #Beendet die Select-Schleife
        "Abbrechen" ) #Zurück zum Hauptmenü
          error="noinput" #Verhindert den Vorgang der Terminierung "eines Prozesses"
          break ;; #Beendet die Select-Schleife
      esac
      break
    done
  else
    echo -e "\n${lightred}Momentan sind keine Prozesse aktiv!${normal}" #Wenn keine Prozesse aktiv bzw. activeList hat keine Einträge
    error="noinput"
  fi
}

function splitBuddy() { #Ein Buddy wird hier geteilt, falls ein Buddy zu groß war (doppelt so groß oder größer als ProcessSize)
  fullID="$1"
  unset buddyList[$targetIndex] #Zuerst wird der Buddy aus der BuddyList gelöscht

  targetSize=$(( $targetSize / 2 )) #Der Wert der targetSize wird halbiert
  targetIndex=$(( $targetIndex * 2 )) #Der Wert der targetIndex wird verdoppelt um zu versichern, dass es keine doppelten Werte gibt.
  addBuddyList "$targetIndex" "$targetSize" #Der erste kleine Buddy wird in die BuddyList eingefügt
  buddyIndex=$(( $targetIndex + 1 )) #Der Index wird um "1" erhöht um den 2. Buddy zu identifizieren
  addBuddyList "$buddyIndex" "$targetSize" #Der zweite kleine Buddy wird in die BuddyList eingefügt.
  # (Beide neuen Buddies sind identisch, bloß der 2. Buddy hat "index+1")
}

function assignProcess () { #Der Prozess wird hier zugewiesen, anhand der Größe des Prozesses. $1 ist die Prozessgröße
  processSize="$1"
  targetSize="$memory" #Anfangswert für den "TargetSize" ist immer "memory", also dem Gesamtspeicherplatz
  targetIndex="1" #Anfangswert für den "TargetIndex" ist immer "1".
  #Diese TargetVariablen zeigen am Ende, welcher Buddy den Prozess bekommt.

  for i in ${buddyList[@]} #Für jeden Eintrag in buddyList (i enthält die Elemente, also die vollen BuddyIDs)
  do #Bedingung leer
    if [[ $(getFirstBit $i) -ne 1 ]]; then #Wenn das 1. Zeichen, also der BusyBit nicht belegt ist bzw. nicht "1" ist, dann
      setTargetBuddy "$i" #Gibt die unbelegte BuddyID weiter #Hier bitte die setTargetBuddy () Funktion anschauen
    fi
  done

    local busyBit=$(getFirstBit ${buddyList[$targetIndex]})
if [[ $targetSize -ge $(( processSize * 2 )) && "$busyBit" -ne "1" && -n ${buddyList[$targetIndex]} ]] ; then #Wenn der Zielbuddy größer gleich(TargetSize) als das Doppelte der Prozessgröße ist(processSize)
    splitBuddy ${buddyList[$targetIndex]}  #Der Buddy wird geteilt                                            und der busyBit nicht aktiv/1 ist und der Eintrag buddyList[$targetIndex] nicht null ist.
    assignProcess "$processSize" #Wiederholt den Befehl, bis ein passender Buddy für den Prozess gefunden wurde, der nicht größer gleich das doppelte der Prozessgröße ist
  elif [[ $busyBit -eq 0 && -n ${buddyList[$targetIndex]} ]]; then #Wenn der busyBit nicht aktiv/1 ist und der Eintrag buddyList[$targetIndex] nicht null ist.
    toggleBusyBit "$targetIndex" "1" #Der 1. Bit der BuddyID wird zu einer "1" und ist somit als aktiv markiert
    addActives ${buddyList["$targetIndex"]} #Macht einen neuen Eintrag in die activeList, die dann die BuddyID als Index hat und die ProzessID als Element
    error="pass" #Wird eine Bestätigung am Ende ausdrucken
  else
    error="outofmemory" #Teststring "error" bekommt "outofmemory" zugewiesen - wird in "getError" validiert
  fi

}


function parseInteger () { #Löscht alle führende Nullen und löscht alles ab dem "." oder "," falls vorhanden. ($1 ist der Wert)
  n=$1 #n bekommt den "Wert"
  n=${n//,/.} #Alle Kommas werden zu Punkte umgewandelt
  n=${n%%.*} #Alles vor dem Punkt wird weitergegeben, alles dahinter wird gelöscht
  i=$(( 10#$n )) #Werte mit führende Nullen also zb "003" werden bei Test-Abfragen (zb if) als octal interpretiert. Hier wird der Wert gezwungen als Dezimal interpretiert zu werden. (nur i)
  if [[ "$i" != "0" && -n $i ]]; then #Wenn "i" (deximal interpretiert) nicht "0" ist und "i" nicht null ist.
    while [[ $(getFirstBit $n) -eq 0 ]]; do #Solange das 1. Zeichen "0" entspricht, mache...
      n=${n#*0} #Die 1. "0" wird gelöscht
    done
  fi #Solange, bis das 1. Zeichen keine "0" mehr ist
  echo $n
}

function processSizeCheck () { #prüft ob eingegebener Wert ein Integer ist
  processSize=$1 #"processSize" ist ein wichtiger Wert, dessen Wert immer die eingegebene "Prozessgröße" ist nach dieser Funktion.
  if [[ "$processSize" == "a" ]]; then #Wenn EingabeString "a" ist, dann (Möglichkeit Abbruch)
    error="noinput" #Teststring error wird zu "noinput" - Kein Prozess wird zugewisen- zurück zum Hauptmenü
  elif [[ -z $processSize ]] || [[ -n ${processSize//[0-9,.]/} ]]; then #Wenn "processSize" null ist oder etwas anderes hat als eine Zahl (oder ".,")
    echo -en "\n${red}Fehler - Eingabe wurde nicht erkannt!\n \"a\" zum Abbrechen drücken\nBitte erneut versuchen: ${normal}"
    read "processSize" #Neuer Wert wird gelesen
    processSizeCheck $processSize #neue Prüfung
  elif [[ -n ${processSize//[!0-9.,]/} ]]; then #Wenn "processSize" nur Zahlen oder ",." hat
    processSize=$(parseInteger $processSize) #Wird zu einem  puren Integer umgewandelt
    if [[ $processSize -gt $memory ]]; then #Wenn "processSize" größer als "memory" /also Gesamtspeicherplatz
      error="noinput" #Teststring error wird zu "noinput" - Kein Prozess wird zugewisen- zurück zum Hauptmenü
      echo -en "\n${red}${bold}Fehler - Prozessgröße darf nicht größer als der Hauptspeicher sein!\n(${memory}MB)\n${normal}" #Wird ausgegeben
    elif [[ $processSize -lt 1 ]]; then #Wenn "processSize" kleiner als 0 ist
      error="noinput" #Teststring error wird zu "noinput" - Kein Prozess wird zugewisen- zurück zum Hauptmenü
      echo -en "\n${red}${bold}Fehler - Prozessgröße muss mindestens 1MB groß sein\n${normal}" #Wird ausgegeben
    fi
  fi
}


function memoryCheck () { #Prüft ob die eingegebener Wert eine Zweierpotenz ist (!Weiter!, wenn Funktion durch ist)
  memory=$1 #memory ist der wichtige Wert
  if [[ $attempt -gt 0 ]] && [[ -z $memory || -n ${memory//[0-9.,]/} ]]; then # (Wenn mehr als 0 Versuche übrig sind) und wenn ("memory" null ist oder mehr als nur Zahlen(oder ,.) enthält )
    echo -en "\n${red}${bold}Fehler - Eingabe wurde nicht erkannt\n${underline}$attempt Versuche übrig${normal}\nBitte erneut versuchen: "
    ((attempt--)) #Mit jeder falschen Eingabe, hat man einen Versuch weniger
    read "memory" #Neuer Wert wird gelesen
    memoryCheck $memory #neue Prüfung
  elif [[ -n ${memory//[!0-9.,]/} ]]; then #Wenn keine anderen Zeichen als Zahlen und ",." existieren in "memory", dann
    memory=$(parseInteger $memory) #wird zu einem puren Integer umgewandelt
    n=$memory #n hat den Wert von memory, also die Gesamtspeicherplatz
    if !(( n > 0 && (n & (n - 1)) == 0 )) #Bitwise zb. 8(binär: 1000) & 7(binär: 0111) = 0000 -> Zweierpotenz (außerdem muss n größer als 0 sein)
    then
      if [[ $attempt -gt 0 && -n "$memory" ]]; then #Wenn mehr als 0 Versuche übrig sind und "$memory" nicht null ist
        echo -en "\n${red}${bold}Fehler: \"${underline}${memory}${normal}${red}${bold}\" ist keine Zweierpotenz\n${underline}$attempt Versuche übrig${normal}\nBitte erneut versuchen: "
        ((attempt--)) #Mit jeder falschen Eingabe, hat man einen Versuch weniger
        read "memory" #Neuer Wert wird gelesen
        memoryCheck $memory #neue Prüfung
      else #wenn Versuche/attempt=0
        echo -e "\n${red}${bold}$attempt Versuche übrig - Die Simulation wird beendet...${normal}\n" #Beendet das komplette Programm bei 0 Versuchen
        exit 1
      fi
      #Hier ist der Ausgang
    fi
  else
    echo -e "\n${red}${bold}$attempt Versuche übrig - Die Simulation wird beendet...${normal}\n" #Beendet das komplette Programm bei 0 Versuchen
    exit 1
  fi
}
