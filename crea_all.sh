#!/bin/bash
# Version:3.01                                    #
# Author : LMC                                    #
#                                                 #
###################################################


##colore

#30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white

R='\e[31m'
UR='\e[4;31m'
IY='\e[0;93m'
IG='\e[0;92m'
IB='\e[0;94m'
IP='\e[0;95m'
IC='\e[0;96m'
IW='\e[0;97m'
IR='\e[0;91m'
#CM='\E[4;94;42m'
CM='\E[4;34;103m'
BG='\e[0;92;44m'
BR='\e[0;91;44m'

#Il settaggio di questi colori è diverso per il "read -p"
r=$'\e[31m'
g=$'\e[32m'
y=$'\e[33m'
ERR='\e[5;34;103m'
z=$'\e[0m'
Z='\e[0m'




mostra_help() {
        echo -e "Lo script deve essere lanciato come root senza argomenti \n  \
                Gli Argomenti richiesti in seguito possono essere sia maiuscoli che minuscoli. \n \
                ATTENZIONE: la scheda di rete di default è la eth1 in caso non sia così bisogna correggere lo script"
        echo -e "\nUso:\n$0\n"
 }

ferma() {
 read -p "${r}${msg}${z}.${r}Dai ENTER per continuare o CTRL-C per abortire "${z} ; echo
}

countdown(){
   date1=$((`date +%s` + $1));
   while [ "$date1" -ge `date +%s` ]; do
     echo -ne "Lo script partirà fra: $(date -u --date @$(($date1 - `date +%s`)) +%S) secondi\r";
     sleep 0.1
   done
}


cerca_nodo() {
VARS=""
VARS=$(ssh $1 "$( cat <<'EOT'
declare -A ar2
hapath="/opt/VRTS/bin"
#for i in $("${hapath}"/hasys -list); do ar2[$i]=$("${hapath}"/hagrp -state -sys $i | grep ^P | grep -vi "offline" | wc -l); done
for i in $("${hapath}"/hasys -state| tail -n+2 | grep RUNNING | awk '{print $1}'); do ar2[$i]=$("${hapath}"/hagrp -state -sys $i | grep ^P | grep -vi "offline" | wc -l); done
allnods=(${!ar2[@]})
nodo1=${allnods[0]}
max1="${ar2[@]:0:1}"
xnodo=$nodo1
#echo $max1
for n in "${!ar2[@]}"; do
    if [[ ${ar2[$n]} < $max1 ]]; then
       xnodo="${n}"
       max1="${ar2[$n]}"
    fi
done
nodoScarico="${xnodo}"
value=$max1
echo "${nodoScarico} ${max1}"
EOT
)")
echo "$VARS"
}

chiedi_cls() {
echo -e "\n${IY}Inserisci il nome del Cluster se vuoi cercare il nodo piu' scarico.\n\
Oppure dai${Z} ${BG}ENTER${Z} ${IY}e ti verra' richiesto il nome di un nodo: \n${Z}" >/dev/tty
read xcls
if [[ -n $xcls ]]; then
   cls=`echo $xcls | tr [A-Z] [a-z]`
   host $cls
   if [[ $? == 1 ]]; then
      echo -e "${ERR} IL CLUSTER $cls  NON E'RISOLVIBILE SUL DNS ${Z}"
      exit $?
   fi
   nodo=$(ssh $cls 'hostname')
   VARS=$(cerca_nodo $nodo)
#   echo "VAR=$VARS" >/dev/tty
   nod_sca=$(echo "$VARS" | cut -f1 -d" ")
   npkg=$(echo "$VARS" | cut -f2 -d" ")

   echo -e "\n${IY}il nodo meno carico e'${Z} ${CM} $nod_sca ${Z} ${IY}con${Z} ${CM} $npkg ${Z} ${IY}pacchetti ONLINE.\n\
Il pacchetto verrà creato sul nodo:${Z} ${CM}* $nod_sca *${Z} ${IY}sul cluster${Z} ${CM}* $cls *${Z}" >/dev/tty

else
    echo -e "\n${IY}inserisci il nome del nodo:\n${Z}" >/dev/tty
    read xnod
    nod_sca=$(echo $xnod | tr [A-Z] [a-z] )
    host $nod_sca
    if [[ $? == 1 ]]; then
      echo -e "${ERR} IL NODO $nod_sca  NON E'RISOLVIBILE SUL DNS ${Z}"
      exit $?
    fi

fi
}

chiedi_pkg() {
    echo -e "\n${IY}inserisci il nome del pacchetto:\n${Z}" >/dev/tty
    read apkg
    bpkg=$(echo $apkg | tr "[A-Z]" "[a-z]")
    host $bpkg
    if [[ $? == 1 ]]; then
      echo -e "${ERR} IL PACCHETTO $pkg  NON E'RISOLVIBILE SUL DNS ${Z}"
      exit $?
    fi
    if [[ "${flagp}" != "X" ]]; then
       echo "DENTRO_IF_CHIDI_PKG"
       ping -c1 ${bpkg} 2>/dev/null
       if [[ "$?" = 0 ]]; then
          echo -e "${ERR} IL PACCHETTO $pkg E' GIA ESISTENTE E RISPONDE AL PING${Z}"
          ping -c1 ${bpkg} 2>/dev/null | head -1
          exit 1
       fi
    fi
}

scriviEXPORT(){
 varf=""
 varf=$(ssh "${bpkg}" "cat $varfile")
 if [[ -n ${varf} ]]; then
    echo "${r}EXPORT DELLA SHARE SU READLOGS ===>>${z}${y}${varf}${z}"
    ferma
    ssh -q ${hostlog1} "echo ${varf} >> ${f_nores}"
    ssh -q ${hostlog1} "service autofs reload"
    ssh "${bpkg}" "rm $varfile"
fi
}

###################################### *** M A I N *** #############################

hapath="/opt/VRTS/bin"

hostlog1="sglmop19.sede.corp.sanpaoloimi.com"
hostlog2="sglstp15.sede.corp.sanpaoloimi.com"

if [[ "$1" = "-h" || "$1" = "--help" ]]; then
    mostra_help
    exit 0
fi

if [[ $USER != "root" ]]; then
    mostra_help
    exit 1
fi


nod_sca=""
mesg=""
choice=6
flagp=""
tempfile="/tmp/SG_tempfile"
flagfile="/tmp/SG_flagfile"
varfile="/tmp/SG_varfile"
f_nores="/etc/autofs_noresvport_migradb"


echo -e "\n"
echo -e "${IY}1. Crea Pacchetto${Z}\n"
echo -e "${IY}2. Crea Volumi e Risorse Cluster - PV VG LV ${Z}\n"
echo -e "${IY}3. Crea Risorse EMCTL ORACLE LISTNER ITT POLLER SHARE e TEST-SWITCH${Z}\n"
echo -e "${IY}4. Crea solo VG ${Z}\n"
echo -e "${IY}5. Aggiungi risorsa IP di bkp ${Z}\n"


echo -e -n "${UR}Scegli tra [1 2 3 4 5]:${Z} "

while [ $choice -eq 6 ]; do
 read choice

      if [ $choice -eq 1 ] ; then
         flagp=""
         chiedi_cls
         msg="ATTENZIONE: prima del lancio. nod_sca=$nod_sca"
#         countdown 3
         ssh -t $nod_sca "$(</opt/gest/SCRIPT_CREA_SG/FINALE/crea_PKG)"
      elif [ $choice -eq 2 ] ; then
            bpkg=""
            apkg=""
            pkg=""
            flagp="X"
            chiedi_pkg
            msg="ATTENZIONE: prima del lancio. PKG=$bpkg"
           #  invio il nome pacchetto
            ssh "${bpkg}" "echo "${bpkg}" > $tempfile"
            ferma $msg
            ssh -t $bpkg "$(</opt/gest/SCRIPT_CREA_SG/FINALE/crea_VOL-RIS)"

      elif [ $choice -eq 3 ] ; then
            bpkg=""
            apkg=""
            pkg=""
            flagp="X"
            chiedi_pkg
            msg="ATTENZIONE: prima del lancio. PKG=$bpkg"
         #  invio il nome pacchetto
            ssh "${bpkg}" "echo "${bpkg}" > $tempfile"
         #  copio file template per ITT0
#            scp -rp ./ITT0 root@${bpkg}:/tmp/ 1>/dev/null
            scp -rp /opt/gest/SCRIPT_CREA_SG/FINALE/ITT0 root@${bpkg}:/tmp/ 1>/dev/null
            nodopk=$(ssh "${bpkg}" "hostname")
            ferma $msg
            ssh -t $nodopk "$(</opt/gest/SCRIPT_CREA_SG/FINALE/crea_ORA-LSTN)"
            scriviEXPORT
      elif [ $choice -eq 4 ] ; then
            bpkg=""
            apkg=""
            pkg=""
            flagp="X"
            chiedi_pkg
            msg="ATTENZIONE: prima del lancio. PKG=$bpkg"
           #  invio il flag per creare solo il VG
            ssh "${bpkg}" "echo "${bpkg}" > $tempfile"
            ssh "${bpkg}" "echo "solovg" > $flagfile"
            ferma $msg
            ssh -t $bpkg "$(</opt/gest/SCRIPT_CREA_SG/FINALE/crea_VOL-RIS)"
      elif [ $choice -eq 5 ] ; then
            bpkg=""
            apkg=""
            pkg=""
            flagp="X"
            chiedi_pkg
            ssh "${bpkg}" "echo "${bpkg}" > $tempfile"
#            msg="ATTENZIONE: 3 secondi al lancio"
#            countdown 3
            ssh ${bpkg} "stato ${bpkg}"
            msg="ATTENZIONE: controlla lo stato del pacchetto. Se non vuoi procedere esci con CTRL-C"
            ferma $msg
            ssh -t $bpkg "$(</opt/gest/SCRIPT_CREA_SG/FINALE/crea_PKG)"
      else
            echo -e "${IY}1. Crea Pacchetto${Z}\n"
            echo -e "${IY}2. Crea Volumi e Risorse Cluster - PV VG LV ${Z}\n"
            echo -e "${IY}3. Crea Risorse EMCTL ORACLE LISTNER ITT POLLER SHARE e TEST-SWITCH${Z}\n"
            echo -e "${IY}4. Crea solo VG ${Z}\n"
            echo -e "${IY}5. Aggiungi risorsa IP${Z}\n"
            echo -e -n "${UR}Scegli tra [1 2 3 4 5]: ${Z}\n "
            choice=6

      fi

done
