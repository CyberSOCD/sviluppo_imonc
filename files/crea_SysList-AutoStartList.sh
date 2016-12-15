#!/bin/bash
#Crea System List e Autostart List
#Vers x Ansible




ErrDesc() {
  case $1 in
    0) echo -e "${r}LV E RISORSE CREATE${z}\n" >> $LOGFILE && exit 0 ;;
    251) echo -e "${r}251 - NESSUNA DELLE LUN FORNITE E' VISIBILE DAL SISTEMA${z} \n" >> $LOGFILE ;;
    252) echo -e "${r}252 - NON ESISTE LO SPECIAL FILE PER IL MULTIPATH ${z}\n" >> $LOGFILE ;;
    253) echo -e "${r}253 - MULTIPATH DEVICE GIA' IN USO${z}\n" >> $LOGFILE ;;
    260) echo -e "${r}260 - IL BOX DEI DISCHI ${y}$abox${z} è SCONOSCIUTO${z} \n" >> $LOGFILE ;;
    261) echo -e "${r}261 - L'AUTOSTART LIST E' VUOTA!${z}\n" >> $LOGFILE ;;
    262) echo -e "${r}262 - SITO SCONOSCIUTO\n${z}" >> $LOGFILE ;;
    263) echo -e "${r}263 - SYSLIST VUOTA. DEVI AGGIORNARE LA LISTA DEI NODI NELLO SCRIPT${z}\n" >> $LOGFILE ;;
    300) echo -e "${r}300 - NON HO CREATO RISORSE${z}\n" >> $LOGFILE ;;
    301) echo -e "${r}301 - NON HO CREATO NESSUN LINK${z}\n" >> $LOGFILE ;;
    *) echo "${r}NON DEVE SUCCEDERE${z}\n" >> $LOGFILE ;;
  esac
}

Erro() {
  echo -e "${r}Esco con Codice Errore${z} ${y}$1${z}${r}:${z}  " >> $LOGFILE
  ErrDesc $1
  exit 1
}

systLIST() {
  # ferma
  #Apro configurazione Cluster
  # "${hapath}"/haconf -makerw
  syshost="$(hostname | awk -F '.' '{print $1}')"
  echo -e "\n${r}il pacchetto è sul nodo${z} ${y}${syshost}${z}" >>
  SITX="${syshost:3:1}"
  if [[ "${SITX}" = "s" ]]; then
    SITO="sdlstp"
  elif [[ "${SITX}" = "m" ]]; then
    SITO="sdlmop"
  else
    ERRCOD=262 && Erro $ERRCOD
  fi
  if [[ "${flagsito}" = "1" ]]; then
    echo -e "\n${r}i dischi sono in ${z} ${y}TRIPLETTA. BOX=${abox}${z}"
    if [[ "${syshost}" = "${mon1}" ]]; then
      SYSKY="${mon2} 1 ${set1} 2 ${set2} 3"
      SYSAS="${mon1} ${mon2} ${set1} ${set2}"
    elif [[ "${syshost}" = "${mon2}" ]]; then
      SYSKY="${mon1} 1 ${set1} 2 ${set2} 3"
      SYSAS="${mon2} ${mon1} ${set1} ${set2}"
    elif [[ "${syshost}" = "${set1}" ]]; then
      SYSKY="${set2} 1 ${mon1} 2 ${mon2} 3"
      SYSAS="${set1} ${set2} ${mon1} ${mon2}"
    elif [[ "${syshost}" = "${set2}" ]]; then
      SYSKY="${set1} 1 ${mon1} 2 ${mon2} 3"
      SYSAS="${set2} ${set1} ${mon1} ${mon2}"
    else
      ERRCOD=263 && Erro $ERRCOD
    fi

  elif [[ "${flagsito}" = "2" ]]; then
    echo -e "\n${r}i dischi sono in ${z} ${y}DOPPIETTA SU MONCALIERI. BOX=${abox}${z}"
    if [[ "${syshost}" = "${mon1}" ]]; then
      SYSKY="${mon2} 1"
      SYSAS="${mon1} ${mon2}"
    elif [[ "${syshost}" = "${mon2}" ]]; then
      SYSKY="${mon1} 1"
      SYSAS="${mon2} ${mon1}"
    fi
  elif [[ "${flagsito}" = "3" ]]; then
    echo -e "\n${r}i dischi sono in ${z} ${y}DOPPIETTA SU SETTIMO. BOX=${abox}${z}"
    if [[ "${syshost}" = "${set1}" ]]; then
      SYSKY="${set2} 1"
      SYSAS="${set1} ${set2}"
    elif [[ "${syshost}" = "${set2}" ]]; then
      SYSKY="${set1} 1"
      SYSAS="${set2} ${set1}"
    fi
  else
    echo -e "ERRRRRRRORRRRE!!!!!! flagsito ERRATO!!!!! == $flagsito" >> $LOGFILE
  fi

  #Apro configurazione Cluster
  "${hapath}"/haconf -makerw
  if [[ -n "${SYSKY}" ]]; then
    echo -e "\n${r}Aggiungo questa SYSTEM LIST${z} ${y}${SYSKY}${z}" >> $LOGFILE
    "${hapath}"/hagrp -modify ${PKG} SystemList -add ${SYSKY}
  else
    ERRCOD=261 && Erro $ERRCOD
  fi

  if [[ "${ASLIST}" = "A" || "${ASLIST}" = "V" ]]; then
    echo -e "\n${r}Aggiungo questa AUTOSTART LIST${z} ${y}${SYSAS}${z}" >> $LOGFILE
    echo -e "\n${r} $PKG è vitale o altamente critico.${z} ${y}AUTOSTART LIST${z}: ${SYSAS}${z}" >> $LOGFILE
    "${hapath}"/hagrp -modify ${PKG} AutoStartList ${SYSAS}
  fi

  "${hapath}"/haconf -makerw
}

onlineRIS() {
  SYSTX=$(hostname|awk -F"." '{print $1}')
  DEBUG echo "RISORSA ONLINE risvg=$1 sys=$SYSTX[0]"
  echo -e "\n"
  for i in $("${hapath}"/hasys -list); do
    echo " PROBE SU $i"
    echo -e "${g}"${hapath}"/hares -probe $Risorsa -sys $i ${z}\n" >> "${LOGFILE}"
    "${hapath}"/hares -probe $Risorsa -sys $i >> "${LOGFILE}"
    sleep 10
  done
  echo -e " ${r}METTO ONLINE:${z} ${g}"${hapath}"/hares -online ${y}$Risorsa${z} -sys ${y}$SYSTX${z} \n" >> "${LOGFILE}"
  "${hapath}"/hares -online $Risorsa -sys $SYSTX >> "${LOGFILE}"
  for i in {1..2}; do
    stato $PKG >> $LOGFILE
    sleep 5
  done
}

decidi() {
if [[ "$mod_storage" = "$tri" ]]; then
  echo -e "${r}Il box usato è${z} ${y}${abox} = TRIPLETTA${z}\n " >> $LOGFILE
  flagsito="1"
elif [[ "$mod_storage" = "$dcm" ]]; then
  echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA SOLO MONCALIERI${z}\n " >> $LOGFILE
  flagsito="2"
elif [[ "$$mod_storage" = "$scm" ]]; then
  echo -e "${r}Il box usato è${z} ${y}${abox}= STANDALONE SOLO MONCALIERI${z}\n " >> $LOGFILE
  flagsito="2"
elif [[ "$mod_storage" = "$dst" ]]; then
  echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA SOLO SETTIMO${z}\n " >> $LOGFILE
  flagsito="3"
elif [[ "$mod_storage" = "$sst" ]]; then
  echo -e "${r}Il box usato è${z} ${y}${abox}= STANDALONE SOLO SETTIMO${z}\n " >> $LOGFILE
  flagsito="3"
else
  ERRCOD=260 && Erro $ERRCOD
fi

if [[ "${PKG:5:1}" = "P" ]]; then
  systLIST
elif [[ "${PKG:5:1}" = "T" ]]; then
  if [[ "${ASLIST}" = "A" || "${ASLIST}" = "V" ]]; then
    SYSTL=$("${hapath}"/hasys -list | grep -v $(hostname|awk -F"." '{print $1}') | paste -s -d" ")
    "${hapath}"/hagrp -modify $PKG AutoStartList $SYSTQ $SYSTL
  fi
fi

Risorsa=$vg-VG
"${hapath}"/hares -modify $Risorsa Enabled 1
onlineRIS $Risorsa
}


#============= MAIN =====================
#Setta colori
r=$'\e[31m'
g=$'\e[32m'
y=$'\e[33m'
ERR='\e[5;34;103m'
z=$'\e[0m'
Z='\e[0m'

#Variabili Globali
flagsito=""
tri=""
dcm=""
dst=""
scm=""
sst=""

#PARAMETRI da Ansible
xpkg="$1"           #{{ nome_pacchetto }}
vg="$2"            #{{ vg }}
mod_storage="$3"   #{{ modalita_storage }}
sito="$4"          #{{ sito }}
box="$5"           #{{ seriale_storage}}

PKG=`echo "${xpkg}" | tr "[a-z]" "[A-Z]"`
pkg=`echo "${xpkg}" | tr "[A-Z]" "[a-z]"`

#Variabili box disco
if [[ "${mod_storage}" == "gold" ]]; then
tri="gold"
fi
if [[ "${mod_storage}" == "silver" && "${sito}" == "moncalieri" ]]; then
dcm="silver"
fi
if [[ "${mod_storage}" == "silver" && "${sito}" == "settimo" ]]; then
dst="silver"
fi
if [[ "${mod_storage}" == "bronze" && "${sito}" == "moncalieri" ]]; then
scm="bronze"
fi
if [[ "${mod_storage}" == "bronze" && "${sito}" == "settimo" ]]; then
sst="bronze"
fi



dcm="85779"      ###doppietta moncalieri
dcm_b="53988"    ###doppietta moncalieri
scm="78692"      ###standalone moncalieri senza DR
dst="85770"      ###doppietta settimo
dst_b="85756"    ###doppietta settimo
sst="53250"      ###standolne o doppietta settimo
tpa="CZ3550S4TA" ###standalone 3PAR

#nodi cluster produzuione
# qui è necessario sostituire con 2 array (monc/sett) creati da hasys -list
mon1="sdlmop20"
mon2="sdlmop22"
#mon3="sdlmop18"
set1="sdlstp21"
set2="sdlstp23"
#set3="sdlstp19"
amb=""

decidi
