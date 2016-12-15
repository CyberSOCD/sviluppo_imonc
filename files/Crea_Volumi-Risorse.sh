#!/bin/bash
#
#Vers x Ansible
#
#
#set +o posix
creaDir(){
 mkdir -p "$1"
}

creaClusDir(){
echo -e "${r}creo MountPoint${z} ${y}$1${z} ${r}sugli altri nodi del cluster${z}" >> $LOGFILE
for i in $("${hapath}"/hasys -list | grep -v $(hostname|awk -F"." '{print $1}'))
do ssh -q $i "mkdir -p $1" >> $LOGFILE
done
}

chownClusDir(){
 echo -e "${r} chown ${z} ${g}${orauser}:dba ${z} ${y}$1${z} ${r}sugli altri nodi del cluster${z}" >> $LOGFILE
 for i in $("${hapath}"/hasys -list | grep -v $(hostname|awk -F"." '{print $1}'))
    do ssh -q $i "chown ${orauser}:dba ${1}" >> $LOGFILE
 done
}

creaLink(){
 "${hapath}"/hares -link "$1" "$2"
}

creaRisorsa(){
  dir="$1"
  creaDir "${dir}"
    "${hapath}"/hares -add    "$3" Mount ${PKG}
    "${hapath}"/hares -modify "$3" MountPoint "$1"
    "${hapath}"/hares -modify "$3" BlockDevice "$2"
    "${hapath}"/hares -modify "$3" FSType ext4
    "${hapath}"/hares -modify "$3" FsckOpt "%-y"
    "${hapath}"/hares -modify "$3" CreateMntPt 1
    "${hapath}"/hares -modify "$3" SnapUmount 0
    "${hapath}"/hares -modify "$3" CkptUmount 1
    "${hapath}"/hares -modify "$3" RecursiveMnt 1
    "${hapath}"/hares -modify "$3" VxFSMountLock 1
    "${hapath}"/hares -modify "$3" CacheRestoreAccess 0
    "${hapath}"/hares -modify "$3" Enabled 1
    [[ -n $4 ]] && "${hapath}"/hares -modify "$3" Critical $4
#   exit 0
}

onlineRIS() {
 SYSTX=$(hostname | awk -F"." '{print $1}')
 for i in $("${hapath}"/hasys -list)
 do
   echo " PROBE SU $i"
   echo -e "${g}"${hapath}"/hares -probe $Risorsa -sys $i ${z}\n" >> "${LOGFILE}"
   "${hapath}"/hares -probe $Risorsa -sys $i >> "${LOGFILE}"
   sleep 10
 done
 echo -e " ${r}METTO ONLINE:${z} ${g}"${hapath}"/hares -online ${y}$Risorsa${z} -sys ${y}$SYSTX${z} \n" >> "${LOGFILE}"
 "${hapath}"/hares -online $Risorsa -sys $SYSTX >> "${LOGFILE}"
 for i in {1..2}
 do
  stato $PKG >> $LOGFILE
  sleep 5
 done
}


#==================  MAIN =================
#Setta colori
r=$'\e[31m'
g=$'\e[32m'
y=$'\e[33m'
ERR='\e[5;34;103m'
z=$'\e[0m'
Z='\e[0m'

#--- Variabili Globali
amb=""
ERRCOD="0"

SYSQ=$(hostname | awk -F '.' {'print $1'})
NOW=$(date +"%F")
LOGPARTIAL="/var/log/crea_pkg-vol-*"
LOGFILE="/var/log/crea_pkg-vol-$NOW.log"

if [[ -f "${LOGPARTIAL}" ]]; then
    rm  "${LOGPARTIAL}"
fi

#--- PARAMETRI DA ANSIBLE
PKG=`echo "${1}" | tr "[a-z]" "[A-Z]"`
pkg=`echo "${1}" | tr "[A-Z]" "[a-z]"`

#--- setto ambiente PROD/TEST
if [[ "${PKG:5:1}" = "P" ]]; then
   amb="prod"
elif [[ "${PKG:5:1}" = "T" ]]; then
   amb="sys"
fi

vg="$8"
VG=`echo "${vg}" | tr "[a-z]" "[A-Z]"`
vgRis="${vg}-VG"
dbuser="${11}"
ORAUSER=`echo "${12}" | tr "[a-z]" "[A-Z]"`
orauser=`echo "${12}" | tr "[A-Z]" "[a-z]"`
SID=`echo "${6}" | tr "[a-z]" "[A-Z]"`
sid=`echo "${6}" | tr "[A-Z]" "[a-z]"`

mod_stor="${9}"
sito="{10}"

ASLIST="${PKG:3:1}"

MountPoint="$2"
fold="${MountPoint##*/}"
fold_data=$(echo $MountPoint | awk -F"/" '{print $(NF-1)}')
lvname="$6"
BlockDevice="/dev/mapper/${vg}-${lvname}"
Risorsa="oradata_${SID}_${fold}-${pkg}-MNT"

#----- setto path veritas e apro configurazione
hapath="/opt/VRTS/bin"
"${hapath}"/haconf -makerw


#----- Creo Risorsa Volume
echo -e "Creo risorsa MNT ${fold} \n" >> $LOGFILE
creaRisorsa $MountPoint $BlockDevice $Risorsa
onlineRIS $Risorsa

#----- Creo directory sui nodi del cluster
if [[ "${fold_data}" != "datafile" ]]; then
    creaClusDir "$MountPoint"
else
    echo -e " change owner to datafile" >> ${LOGFILE}
    chown ${orauser}:dba /oradata/${SID}/database/datafile
    dataf="/oradata/${SID}/database/datafile"
    echo -e "${r}DEBUG: creo directory e cambio propietario e gruppo sui tutti i nodi del cluster${z}" >> ${LOGFILE}
    creaClusDir "$dataf"
    chownClusDir "$dataf"
fi


#----- Creo Link tra Risorse
if [[ "${fold_data}" != "datafile" ]]; then
  case "${fold}" in
    database) arg1="${Risorsa}"
             arg2="${vgRis}"
             echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" >> $LOGFILE
             creaLink $arg1 $arg2
          #   chown ${orauser}:dba ${MountPoint}
             ;;
    archive) arg1="${Risorsa}"
             arg2="oradata_${SID}_database-${pkg}-MNT"
             echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" >> $LOGFILE
             creaLink $arg1 $arg2
          #   chown ${orauser}:dba ${MountPoint}
             ;;
        tmp) arg1="${Risorsa}"
             arg2="oradata_${SID}_database-${pkg}-MNT"
             echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" >> $LOGFILE
             creaLink $arg1 $arg2
          #   chown ${orauser}:dba ${MountPoint}
             chown ${orauser}:dba "/oradata/${SID}/database/system"
             ;;
       undo) arg1="${Risorsa}"
             arg2="oradata_${SID}_database-${pkg}-MNT"
             echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" >> $LOGFILE
             creaLink $arg1 $arg2
          #   chown ${orauser}:dba ${MountPoint}
             ;;
       home) arg1="${Risorsa}"
             arg2="${vgRis}"
             echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" >> $LOGFILE
             creaLink $arg1 $arg2
          #   chown ${dbuser}:dba ${MountPoint}
             ;;
  esac
else
arg1="${Risorsa}"
arg2="oradata_${SID}_database-${pkg}-MNT"
creaLink $arg1 $arg2
fi
