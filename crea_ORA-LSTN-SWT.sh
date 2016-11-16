#!/bin/bash
#
#Vers 01.02 --> aggiunto EMCTL ORA LISTNER
#
#Author L.C.
#
#
#
set +o posix


function DEBUG() {
 [ "$_DEBUG" == "on" ] && $@ || :
}

ferma() {
 read -p "${r}${mesg}${z}${r}Dai ENTER per continuare o CTRL-C per abortire "${z} ; echo
}

mostra_help() {
    echo -e "Lo script deve essere lanciato come root senza argomenti che verranno richiesti in seguito.\n Gli Argomenti richiesti possono essere maiuscoli come minuscoli.\nATTENZIONE: la scheda di rete didefault è la eth1 in caso non sia così bisogna correggere lo script"
    echo -e "\nUso:\n$0\n"
}

menu() {
 echo "${r}Filesystem disponibili:${z}"
 for i in ${!options[@]}; do
   printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
 done
 [[ "$msg" ]] && echo "$msg"; :
}

creaDIR(){
 mkdir -p "$1"
}

TrMaiuscolo(){
 local out=`echo $1 | tr "[a-z]" "[A-Z]"`
 echo "$out"
}

creaLink(){
 "${hapath}"/hares -link "$1" "$2"
}

ErrDesc() {

 case $1 in
   0) echo -e "${r}RISORSE CREATE${z}\n" | tee -a $LOGFILE && exit 0
   ;;
   00) echo -e "${r}SWITCH ESEGUITO${z}\n" | tee -a $LOGFILE && exit 0
   ;;
   240) echo -e "${r}240 - L'UTENTE${z}${y}${twsnum}${z} ${r}NON ESISTE. SIPREGA DI CREARLO PRIMA DI PROCEDERE${z}\n" | tee -a $LOGFILE
   ;;
   251) echo -e "${r}251 - NESSUNA DELLE LUN FORNITE E' VISIBILE DAL SISTEMA${z} \n" | tee -a $LOGFILE
   ;;
   252) echo -e "${r}252 - NON ESISTE LO SPECIAL FILE PER IL MULTIPATH ${z}\n" | tee -a $LOGFILE
   ;;
   253) echo -e "${r}253 - MULTIPATH DEVICE GIA' IN USO${z}\n" | tee -a $LOGFILE
   ;;
   260) echo -e "${r}260 - IL BOX DEI DISCHI ${y}$abox${z} è SCONOSCIUTO${z} \n" | tee -a $LOGFILE
   ;;
   261) echo -e "${r}261 - L'AUTOSTART LIST E' VUOTA!${z}\n" | tee -a $LOGFILE
   ;;
   262) echo -e "${r}262 - SITO SCONOSCIUTO\n${z}" | tee -a $LOGFILE
   ;;
   263) echo -e "${r}263 - SYSLIST VUOTA. DEVI AGGIORNARE LA LISTA DEI NODI NELLO SCRIPT${z}\n" | tee -a $LOGFILE
   ;;
   300) echo -e "${r}300 - NON HO CREATO RISORSE${z}\n" | tee -a $LOGFILE
   ;;
   301) echo -e "${r}301 - NON HO CREATO NESSUN LINK${z}\n" | tee -a $LOGFILE
   ;;
   400) echo -e "${r}400 - NESSUNA RISORSA VIENE MESSA ONLINE${z}\n" | tee -a $LOGFILE
   ;;
   500) echo -e "${r}PACCHETTO IN STATO ${z}${g}PARTIAL${z}${r}. NON VERRA' ESEGUITO NESSUN SWITCH${z}" | tee -a $LOGFILE
   ;;
   501) echo -e "${r}SWITCH DEL PACHETTO${z} ${y}${PKG}${z} ${r}FALLITO${z}"
   ;;
     *) echo "${r}NON DEVE SUCCEDERE${z}\n" | tee -a $LOGFILE
   ;;
 esac
}

Erro() {
 echo -e "${r}Esco con Codice Errore${z} ${y}$1${z}${r}:${z}  " | tee -a $LOGFILE
 ErrDesc $1
 exit 1
}

onlineRIS() {
 SYSTX=$(hostname)
 DEBUG echo "RISORSA ONLINE risvg=$1 sys=$SYSTX[0]"
 echo -e "\n"
 for i in $("${hapath}"/hasys -list)
 do
   echo " PROBE SU $i"
   echo -e "${g}"${hapath}"/hares -probe $1 -sys $i ${z}\n" | tee -a "${LOGFILE}"
   "${hapath}"/hares -probe $1 -sys $i | tee -a "${LOGFILE}"
   sleep 10
 done
 echo -e " ${r}METTO ONLINE:${z} ${g}"${hapath}"/hares -online ${y}$1${z} -sys ${y}$SYSTX${z} \n" | tee -a "${LOGFILE}"
 "${hapath}"/hares -online $1 -sys $SYSTX | tee -a "${LOGFILE}"
 for i in {1..2}
 do
  stato $PKG | tee -a $LOGFILE
  sleep 5
 done
}

creaAppEMCTL(){
 "${hapath}"/hares -add    "${Risorsa}" Application "${PKG}"
 "${hapath}"/hares -modify "${Risorsa}" Enabled 1
 "${hapath}"/hares -modify "${Risorsa}" Critical 0
 "${hapath}"/hares -modify "${Risorsa}" StartProgram "/opt/VRTSvcs/bin/CUSTOM/EMCTL/online ${PKG}"
 "${hapath}"/hares -modify "${Risorsa}" StopProgram "/opt/VRTSvcs/bin/CUSTOM/EMCTL/offline ${PKG}"
 "${hapath}"/hares -modify "${Risorsa}" PidFiles  "/var/run/${pkg}_emctl.pid" "/var/run/${pkg}_emctl.ppid"
 "${hapath}"/hares -modify "${Risorsa}" User root
 "${hapath}"/hares -modify "${Risorsa}" MonitorProcesses -delete -keys
 "${hapath}"/hares -modify "${Risorsa}" UseSUDash 0
}

creaORA(){
 "${hapath}"/hares -add ${Risorsa} Oracle ${PKG}
 "${hapath}"/hares -modify ${Risorsa} Enabled 1
 "${hapath}"/hares -modify ${Risorsa} Critical 1
 "${hapath}"/hares -modify ${Risorsa} Sid ${SID}
 "${hapath}"/hares -modify ${Risorsa} Owner $orauser
 "${hapath}"/hares -modify ${Risorsa} Home "${oraver}"
 "${hapath}"/hares -modify ${Risorsa} Pfile "/oradata/${SID}/database/admin/init${SID}.ora"
 "${hapath}"/hares -modify ${Risorsa} StartUpOpt STARTUP
 "${hapath}"/hares -modify ${Risorsa} ShutDownOpt IMMEDIATE
 "${hapath}"/hares -modify ${Risorsa} ManagedBy ADMIN
 "${hapath}"/hares -modify ${Risorsa} AutoEndBkup 1
 "${hapath}"/hares -modify ${Risorsa} MonScript "./bin/Oracle/SqlTest.pl"
}

copiaClusITT(){
 echo -e "${r}copio $1 sugli altri nodi del cluster${z}" | tee -a $LOGFILE
 for i in $("${hapath}"/hasys -list | grep -v $(hostname))
 do ssh -q $i "mkdir -p $1" | tee -a $LOGFILE
 scp -rp ${1}* root@${i}:${1}
 done
}

creafileITT(){
# render a template configuration file
# expand variables + preserve formatting
 eval "echo \"$(cat $1)\""
}

filePARS(){
# echo "DEBUG_FILEPARS: ${1} > ${2}"
 creafileITT ${1} > ${2}
 stringa=""
 echo "ho copiato i file ITT0 online offline e monitor"
# ferma
}

checkSID(){
#echo "DEBUG:IL PACCHETTO è ${PKG:5:1}"
 if [[ "${PKG:5:1}" = "T" || "${PKG:5:1}" = "U" || "${PKG:5:1}" = "S" ]]; then
    varacr="${SIDsolo}"
    varser="ITT0_${SIDsolo}_${PKG}"
    ITF_path="/opt/VRTSvcs/bin/CUSTOM/${PKG}/ITT0_${SIDsolo}/"
    risIT=${SIDsolo}
 fi
 if [[ "${PKG:5:1}" = "P" ]]; then
    varacr="${SID}"
    varser="ITT0_${SID}_${PKG}"
    ITF_path="/opt/VRTSvcs/bin/CUSTOM/${PKG}/ITT0_${SID}/"
    risIT=${SID}
 fi
#echo "DEBUG:esco con PACCHETTO è ${PKG:5:1} ITF_path=$ITF_path risIT=$risIT"

}

fileTEMPL(){
#checkSID
# if [[ "${PKG:5:1}" = "T" || "${PKG:5:1}" = "U" || "${PKG:5:1}" = "S" ]]; then
#    varacr="${SIDsolo}"
#    varser="ITT0_${SIDsolo}_${PKG}"
#    ITF_path="/opt/VRTSvcs/bin/CUSTOM/${PKG}/ITT0_${SIDsolo}/"
# fi
# if [[ "${PKG:5:1}" = "P" ]]; then
#    varacr="${SID}"
#    varser="ITT0_${SID}_${PKG}"
#    ITF_path="/opt/VRTSvcs/bin/CUSTOM/${PKG}/ITT0_${SID}/"
# fi
# echo "DEBUG: creo DIR ${ITF_path} varacr=$varacr"
 #mkdir -p "${ITF_path}"

 creaDIR "${ITF_path}"
# ferma
 for AA in "online" "offline" "monitor"; do
#     echo "DEBUG: Stringa= ${T_path}${AA}" "${ITF_path}${AA}"
     filePARS "${T_path}${AA}" "${ITF_path}${AA}"
 done
 rm -rf /tmp/ITT0
 chmod -R 775 /opt/VRTSvcs/bin/CUSTOM/${PKG}
 copiaClusITT "${ITF_path}"
}

chiediSPAUS(){
 echo -e "\n${g}inserisci utente SPAZIO:${z}(default:spa251) "
 read xspauser
 xspauser="${xspauser:=spa251}"
 echo -e "$xspauser \n"
 SPAUSER=`echo "${xspauser}" | tr "[a-z]" "[A-Z]"`
 spauser=`echo "${xspauser}" | tr "[A-Z]" "[a-z]"`
 fileTEMPL
}

creaITT(){
 "${hapath}"/hares -add ${Risorsa} Application $PKG
 "${hapath}"/hares -modify ${Risorsa} Critical 0
 "${hapath}"/hares -modify ${Risorsa} CleanProgram "/opt/VRTSvcs/bin/CUSTOM/$PKG/ITT0_${risIT}/offline"
 "${hapath}"/hares -modify ${Risorsa} MonitorProgram "/opt/VRTSvcs/bin/CUSTOM/$PKG/ITT0_${risIT}/monitor"
 "${hapath}"/hares -modify ${Risorsa} StartProgram "/opt/VRTSvcs/bin/CUSTOM/$PKG/ITT0_${risIT}/online"
 "${hapath}"/hares -modify ${Risorsa} StopProgram "/opt/VRTSvcs/bin/CUSTOM/$PKG/ITT0_${risIT}/offline"
 "${hapath}"/hares -modify ${Risorsa} User root
 "${hapath}"/hares -modify ${Risorsa} UseSUDash 0
 "${hapath}"/hares -modify ${Risorsa} Enabled 0
}

creaPOLLER(){
 "${hapath}"/hares -add ${Risorsa} Application ${PKG}
 "${hapath}"/hares -modify ${Risorsa} Critical 0
 "${hapath}"/hares -modify ${Risorsa} CleanProgram "/etc/init.d/IXTPoller.sh ${dbuser} stop"
 "${hapath}"/hares -modify ${Risorsa} MonitorProgram "/etc/init.d/IXTPoller.sh ${dbuser} check"
 "${hapath}"/hares -modify ${Risorsa} StartProgram "/etc/init.d/IXTPoller.sh ${dbuser} start"
 "${hapath}"/hares -modify ${Risorsa} StopProgram "/etc/init.d/IXTPoller.sh ${dbuser} stop"
 "${hapath}"/hares -modify ${Risorsa} User root
 "${hapath}"/hares -modify ${Risorsa} UseSUDash 0
 "${hapath}"/hares -modify ${Risorsa} Enabled 0
}

creaLSNR(){
 "${hapath}"/hares -add    ${Risorsa} Netlsnr ${PKG}
 "${hapath}"/hares -modify ${Risorsa} Enabled 1
 "${hapath}"/hares -modify ${Risorsa} Critical 0
 "${hapath}"/hares -modify ${Risorsa} Owner "${orauser}"
 "${hapath}"/hares -modify ${Risorsa} Home "${oraver}"
 "${hapath}"/hares -modify ${Risorsa} TnsAdmin "/oradata/${SID}/database/admin"
 "${hapath}"/hares -modify ${Risorsa} Listener lsn_${SID}
 "${hapath}"/hares -modify ${Risorsa} MonScript "./bin/Netlsnr/LsnrTest.pl"
}

creaSHARE(){
 "${hapath}"/hares -add    ${Risorsa} Share ${PKG}
 "${hapath}"/hares -modify ${Risorsa} Critical 0
 "${hapath}"/hares -modify ${Risorsa} PathName "/oradata/${SID}/app"
 "${hapath}"/hares -modify ${Risorsa} Client "${hostlog1}"
 "${hapath}"/hares -modify ${Risorsa} OtherClients "${hostlog2}"
 "${hapath}"/hares -modify ${Risorsa} Options "ro,insecure"
 "${hapath}"/hares -modify ${Risorsa} Enabled 1
}

preparaEXPORT(){
 rigaexp=""
 cartella=""
 cartella=$("${hapath}"/hares -disp $Risorsa | grep -i pathname | awk '{print $6}' | head -1)
 echo "${r}CARTELLA ESPORTATA ===>>${z} ${y}${cartella}${z}"
 if [[ "${PKG:5:1}" = "P" ]]; then
 rigaexp="/readlogs/produzione/db/${PKG}/${SID}/app ${pkg}:${cartella}"
 echo ${rigaexp} > $varfile
 elif [[ "${PKG:5:1}" = "T" ]]; then
 rigaexp="/readlogs/system/db/${PKG}/${SID}/app ${pkg}:${cartella}"
 echo ${rigaexp} > $varfile
 fi
}

switchPKG(){
# echo "ClientAliveInterval 30" >> /etc/ssh/sshd_config
# ferma
 swflag=""
 nod_onl=""
 nodo1=""
 for AA in $("${hapath}"/hagrp -disp ${PKG} | grep "State "| awk '{print $3 $4}'); do
     nod_onl=$(echo $AA | awk -F'|' '{print $1}')
     stato=$(echo $AA | awk -F'|' '{print $2}')
     if [[ "$stato" == "ONLINE" ]]; then
        nodo1=${nod_onl}
        echo -e "${r}Sono ONLINE sul nodo: ${z}${y}${nodo1}${z}"
        swflag="ON"
     fi
 done
 if [[ "$swflag" == "ON" ]]; then
#    echo -e "NODO ESCLUSO==$nodo1"
    for LL in $("${hapath}"/hasys -list | grep -v ${nodo1}); do
        echo -e "${r}Switch verso il nodo: ${z}${y}${LL}${z}"
        "${hapath}"/hagrp -switch "${PKG}" -to ${LL}
        "${hapath}"/hagrp -wait "${PKG}" State ONLINE -sys ${LL} -time 300
        rc="$?"
#        echo -e "RC DENTRO FOR-->$rc"
        if [[ $rc != "0" ]]; then
           ERRCOD=501 && Erro $ERRCOD
        else
           stato ${PKG}
 #          ferma
        fi
    done
    echo -e "${r}Torno al nodo iniziale: ${z}${y}${nodo1}${z}"
    "${hapath}"/hagrp -switch "${PKG}" -to "${nodo1}"
    "${hapath}"/hagrp -wait "${PKG}" State ONLINE -sys "${nodo1}" -time 300
     rc="$?"
      echo -e "RC_TORNO NODO INIZIALE-->$rc"
     if [[ $rc != "0" ]]; then
        ERRCOD=501 && Erro $ERRCOD
     else
        stato ${PKG}
     fi
    ERRCOD=00 && Erro $ERRCOD
 else
    ERRCOD=500 && Erro $ERRCOD
 fi
}

################################ *** MAIN *** ################################
#Setta colori
r=$'\e[31m'
g=$'\e[32m'
y=$'\e[33m'
ERR='\e[5;34;103m'
z=$'\e[0m'
Z='\e[0m'

#Setta Variabili Globali
SYSQ=$(hostname)
ERRCOD="0"
NOW=$(date +"%F")
LOGPARTIAL="/tmp/crea_pkg-vol-*"
LOGFILE="/tmp/crea_pkg-vol-$NOW.log"
tempfile="/tmp/SG_tempfile"
varfile="/tmp/SG_varfile"
SYSAS=""
orauser=""
ORAUSER=""
oraver=""
VRora=""
VRlsnr=""
VRemctl=""
VRshare=""
risIT=""
#
hostlog1="sglmop19.sede.corp.sanpaoloimi.com"
hostlog2="sglstp15.sede.corp.sanpaoloimi.com"

hostl="sglvmp32.sede.corp.sanpaoloimi.com"

orapath="/opt/oracle/app/oracle/product"

if [[ -f "${LOGPARTIAL}" ]]; then
    rm  "${LOGPARTIAL}"
fi


if [[ "$1" = "-h" || "$1" = "--help" ]]; then
   mostra_help
   exit 0
fi
if [[ $USER != "root" ]]; then
   echo "This script must be run as root!"
   exit 1
fi


#

if [[ -f "${tempfile}" ]]; then
   pkg=$(cat $tempfile)
fi

DEBUG echo "TROVO PACCHETTO=$pkg"
#
if [[ -z "$pkg" ]]; then
   echo -n "${g}inserisci nome pacchetto e premi ENTER:${z} "
   read xpkg
   PKG=`echo "${xpkg}" | tr "[a-z]" "[A-Z]"`
   pkg=`echo "${xpkg}" | tr "[A-Z]" "[a-z]"`

else
   #trasformo la variabile arrivata dal crea_all
   PKG=`echo $pkg | tr "[a-z]" "[A-Z]"`
   DEBUG echo "ARRIVO DAL CREA_ALL pkg=$pkg PKG=$PKG"
fi

if [[ -f "${tempfile}" ]]; then
    rm  "${tempfile}"
fi


echo -n "${g}inserisci acronimo (comprensivo di lettera ambiente es: ${y}JISA0 SJISA0 TJISA0)${z}${g}:${z} "
read xsid
SID=`echo "${xsid}" | tr "[a-z]" "[A-Z]"`
sid=`echo "${xsid}" | tr "[A-Z]" "[a-z]"`
sidsolo=${sid:1}
SIDsolo=${SID:1}

echo -n "${g}inserisci utente oracle:${z}(default:ora1124) "
read xoru
xoru="${xoru:=ora1124}"
echo -e "$xoru \n"
ORAUSER=`echo "${xoru}" | tr "[a-z]" "[A-Z]"`
orauser=`echo "${xoru}" | tr "[A-Z]" "[a-z]"`


dbuser="db$sid"
DBUSER=`echo "${dbuser}" | tr "[a-z]" "[A-Z]"`
twssuf=""

hapath="/opt/VRTS/bin"



########**ricavo versione oracle -metodo ps **####
string=$(ps -ef |grep -i "lsn" |grep "${SID}" | awk '{print $8}')
xstring=$(echo $string| tr "/" " ")
version="$(echo ${xstring##*product } | awk '{print $1}')"
######## ** ricavo versione oracle ** ####
oMjv=${orauser:3:2}
oMnv=${orauser:5:1}
oLsr=${orauser:6:1}
oraver="${orapath}/${oMjv}.${oMnv}.0.${oLsr}"
[[ -d "${oraver}" ]] || echo "${r}WARNING:la Versione di Oracle ${y}${oraver}${z} ${r}non è installata. Se vuoi procedere con la creazione delle risorse : ${z}"
#ferma

# variabil per script avvio ITT0
ITF_path=""
T_path="/tmp/ITT0/"
spauser=""
SPAUSER=""
varacr=""
varser=""
risIT=""

## Chiamo funzione distinzione pkg test prod svil
checkSID

"${hapath}"/haconf -makerw

options=("risorsa-ORACLE" "risorsa-LISTNER" "risorsa-EMCTL" "risorsa-ITT" "risorsa-POLLER"  "risorsa-SHARE")


prompt="${g}inserisci il numero della risorsa e dai ENTER (lo stesso per annullare ), ancora ENTER quando hai finito:${z} "
while menu && read -rp "$prompt" num && [[ "$num" ]]; do
    [[ "$num" != *[![:digit:]]* ]] &&
    (( num > 0 && num <= ${#options[@]} )) ||
    { msg="opzione non valida: $num"; continue; }
    ((num--)); msg="${y}${options[num]}${z} ${r}è  ${choices[num]:+"UN"}CHECKED${z}"
    [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
done

printf "${y}Risorse selezionate${z}"; msg=" NESSUNA"
for i in ${!options[@]}; do
    [[ "${choices[i]}" ]] && { printf " %s" "${options[i]}"; msg=""; }
done
echo "${y}$msg${z}"



for K in "${!choices[@]}"; do
   if [[ "${choices[$K]}" = "+" ]]; then
   ERRCOD="0"
     case "$K" in
        0) echo -e "\n${r}Creo${z} ${y}${options[K]}${z}"
           Risorsa="${sid}-${pkg}-ORA"
           creaORA $Risorsa
           VRora="$Risorsa"
           chown ${orauser}:dba "/opt/oracle/app/oracle/product/${orave}"
           chown ${orauser}:dba "/oradata/${SID}/database/admin/init${SID}.ora"
           ;;
        1) echo -e "\n${r}Creo${z} ${y}${options[K]}${z}"
           Risorsa="lsn_${SID}-${pkg}-LSNR"
           creaLSNR $Risorsa
           VRlsnr="$Risorsa"
           ;;
        2) echo -e "\n${r}Creo risorsa${z} APP ${y}${options[K]}${z}"
           Risorsa="emctl-${pkg}-APP"
           creaAppEMCTL $Risorsa
           VRemctl="$Risorsa"
           ;;
        3) chiediSPAUS
           echo -e "\n${r}Creo risorsa${z} ITT ${y}${options[K]}${z}"
           Risorsa="ITT0_${risIT}-${pkg}-APP"
           creaITT $Risorsa
           VRitt="$Risorsa"
           ;;
        4) echo -e "\n${r}Creo risorsa${z} POLLER ${y}${options[K]}${z}"
           Risorsa="poller_${DBUSER}-${pkg}-APP"
           creaPOLLER $Risorsa
           VRpoller="$Risorsa"
           ;;
        5) echo -e "\n${r}Creo risorsa${z} SHARE ${y}${options[K]}${z}"
           Risorsa="${SID}_APP-${pkg}-SHARE"
           creaSHARE $Risorsa
           VRshare="$Risorsa"
           ;;
        *) ERRCOD=300 && Erro $ERRCOD
           echo "NON CREO RISORSE"
           ;;
     esac
   fi
done

for K in "${!choices[@]}"; do
  if [[ "${choices[$K]}" = "+" ]]; then
     DEBUG echo $K
     ERRCOD="0"
     case "$K" in
       0) arg1="${sid}-${pkg}-ORA"
          for LK in $(stato ${pkg} | grep MNT| grep -v grep | \
          grep -vi database|  grep -vi  app|  grep -vi agentOEM| \
          grep -vi twz | awk '{print $2}'); do
          echo "link a ${LK}"
          arg2="${LK}"
          creaLink $arg1 $arg2
          done
          ;;
       1) arg1="lsn_${SID}-${pkg}-LSNR"
          arg2="${pkg}-IP"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          arg1="lsn_${SID}-${pkg}-LSNR"
          arg2="${sid}-${pkg}-ORA"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          arg1="emctl-${pkg}-APP"
          arg2="lsn_${SID}-${pkg}-LSNR"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       2) arg1="emctl-${pkg}-APP"
          arg2="agentOEM-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       3) arg1="ITT0_${risIT}-${pkg}-APP"
          arg2="oradata_${SID}_app-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       4) arg1="poller_${DBUSER}-${pkg}-APP"
          arg2="oradata_${SID}_app-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       5) arg1="${SID}_APP-${pkg}-SHARE"
          arg2="oradata_${SID}_app-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          arg1="${SID}_APP-${pkg}-SHARE"
          arg2="${pkg}-IP"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       *) ERRCOD=301 && Erro $ERRCOD
          echo "NON CREO NESSUN LINK"
          ;;
     esac
  fi
done


##### METTO ONLINE LE RISORSE IN ORDINE DIVERSO
if [[ -n "$VRora" ]]; then
   onlineRIS $VRora
fi
if [[ -n "$VRlsnr" ]]; then
   onlineRIS $VRlsnr
fi
if [[ -n "$VRemctl" ]]; then
   onlineRIS $VRemctl
fi
#if [[ -n "$VRitt" ]]; then
#   onlineRIS $VRitt
#fi

## online del poller
#if [[ -n "$VRpoller" ]]; then
#   onlineRIS $VRpoller
#fi

if [[ -n "$VRshare" ]]; then
   echo "VRSHARE=$VRshare"
   onlineRIS $VRshare
   preparaEXPORT $VRshare
fi

if [[ -z "$VRora" && -z "$VRlsnr" && -z "$VRemctl" && -z "$VRshare" && -z "$VRitt" ]]; then
   "${hapath}"/haconf -dump -makero
   ERRCOD=400
fi

#
 while true; do
     vswitch=""
     read -p "${g}Vuoi eseguire lo switch ${g}(y/n)?${z}" vswitch
     case $vswitch in
         [Yy]* ) switchPKG; break;;
         [Nn]* ) echo "${r}non eseguo lo switch per il pacchetto ${z}${y}${PKG}$z " ; break;;
             * ) echo "Rspondi 'y' o 'n'";;
     esac
 done


#VEDI COME MODIFICARE USCITA
   "${hapath}"/haconf -dump -makero
   Erro $ERRCOD
