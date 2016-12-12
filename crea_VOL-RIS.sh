#!/bin/bash
#
#Vers 7.0--> aggiunto EMCTL APP
#risorsa EMCT E TWS non ABILITATE
#risorsa EMCTL
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
#
menu() {
 echo "${r}Filesystem disponibili:${z}"
 for i in ${!options[@]}; do
   printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
 done
 [[ "$msg" ]] && echo "$msg"; :
}

check(){
#echo "DENTRO CASE---->$1"
 case $1 in
      (*[[:alnum:]]*) echo ' ' ;;
#      (*[[:alnum:]]*) echo ' ';;
      (*) echo "la stringa $1 è blanks o contiene spazi o caratteri non validi ";;
 esac
}

creaDir(){
 mkdir -p "$1"
}

TrMaiuscolo(){
local out=`echo $1 | tr "[a-z]" "[A-Z]"`
echo "$out"
}

creaClusDir(){
echo -e "${r}creo MountPoint${z} ${y}$1${z} ${r}sugli altri nodi del cluster${z}" | tee -a $LOGFILE
for i in $("${hapath}"/hasys -list | grep -v $(hostname))
do ssh -q $i "mkdir -p $1" | tee -a $LOGFILE
done
}

chownClusDir(){
 echo -e "${r} chown ${z} ${g}${orauser}:dba ${z} ${y}$1${z} ${r}sugli altri nodi del cluster${z}" | tee -a $LOGFILE
 for i in $("${hapath}"/hasys -list | grep -v $(hostname))
#    do ssh -q $i "chown ${orauser}:dba /oradata/${SID}/database/datafile" | tee -a $LOGFILE
    do ssh -q $i "chown ${orauser}:dba ${1}" | tee -a $LOGFILE
 done
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

creaLink(){
 "${hapath}"/hares -link "$1" "$2"
}

ErrDesc() {
 case $1 in
   0) echo -e "${r}LV E RISORSE CREATE${z}\n" | tee -a $LOGFILE && exit 0
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
     *) echo "${r}NON DEVE SUCCEDERE${z}\n" | tee -a $LOGFILE
   ;;
 esac
}

Erro() {
 echo -e "${r}Esco con Codice Errore${z} ${y}$1${z}${r}:${z}  " | tee -a $LOGFILE
 ErrDesc $1
 exit 1
}

cercaBOX() {
 adev=$(multipath -ll $1 | awk 'NR==4{print $3}')
 abox=$(smartctl -a /dev/$adev | awk 'NR==10{print $3}')
}

systLIST() {
# ferma
#Apro configurazione Cluster
# "${hapath}"/haconf -makerw
 syshost="$(hostname)"
 echo -e "\n${r}il pacchetto è sul nodo${z} ${y}${syshost}${z}"
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
       SYSKY="${mon2} 1 ${mon3} 2 ${set1} 3 ${set2} 4 ${set3} 5"
       SYSAS="${mon1} ${mon2} ${mon3} ${set1} ${set2} ${set3}"
    elif [[ "${syshost}" = "${mon2}" ]]; then
       SYSKY="${mon1} 1  ${mon3} 2 ${set1} 3 ${set2} 4 ${set3} 5"
       SYSAS="${mon2} ${mon1} ${mon3} ${set1} ${set2} ${set3}"
    elif [[ "${syshost}" = "${mon3}" ]]; then
       SYSKY="${mon1} 1  ${mon2} 2 ${set1} 3 ${set2} 4 ${set3} 5"
       SYSAS="${mon2} ${mon1} ${mon3} ${set1} ${set2} ${set3}"
    elif [[ "${syshost}" = "${set1}" ]]; then
       SYSKY="${set2} 1 ${set3} 2  ${mon1} 3 ${mon2} 4 ${mon3} 5"
       SYSAS="${set1} ${set2} ${set3} ${mon1} ${mon2} ${mon3}"
    elif [[ "${syshost}" = "${set2}" ]]; then
       SYSKY="${set1} 1 ${set3} 2 ${mon1} 3 ${mon2} 4 ${mon3} 5"
       SYSAS="${set2} ${set1} ${set3} ${mon1} ${mon2} ${mon3}"
    elif [[ "${syshost}" = "${set3}" ]]; then
       SYSKY="${set1} 1 ${set2} 2 ${mon1} 3 ${mon2} 4 ${mon3} 5"
       SYSAS="${set3} ${set2} ${set1} ${mon1} ${mon2} ${mon3}"
    else
       ERRCOD=263 && Erro $ERRCOD
    fi

 elif [[ "${flagsito}" = "2" ]]; then
      echo -e "\n${r}i dischi sono in ${z} ${y}DOPPIETTA SU MONCALIERI. BOX=${abox}${z}"
      if [[ "${syshost}" = "${mon1}" ]]; then
        SYSKY="${mon2} 1  ${mon3} 2"
        SYSAS="${mon1} ${mon2} ${mon3}"
      elif [[ "${syshost}" = "${mon2}" ]]; then
        SYSKY="${mon1} 1  ${mon3} 2"
        SYSAS="${mon2} ${mon1} ${mon3}"
      elif [[ "${syshost}" = "${mon3}" ]]; then
        SYSKY="${mon1} 1  ${mon2} 2"
        SYSAS="${mon3} ${mon1} ${mon2}"
      fi
 elif [[ "${flagsito}" = "3" ]]; then
      echo -e "\n${r}i dischi sono in ${z} ${y}DOPPIETTA SU SETTIMO. BOX=${abox}${z}"
      if [[ "${syshost}" = "${set1}" ]]; then
        SYSKY="${set2} 1 ${set3} 2"
        SYSAS="${set1} ${set2} ${set3}"
      elif [[ "${syshost}" = "${set2}" ]]; then
        SYSKY="${set1} 1 ${set3} 2"
        SYSAS="${set2} ${set1} ${set3}"
       elif [[ "${syshost}" = "${set3}" ]]; then
        SYSKY="${set1} 1 ${set2} 2"
        SYSAS="${set2} ${set1} ${set3}"
      fi
 else
      echo -e "ERRRRRRRORRRRE!!!!!! flagsito ERRATO!!!!! == $flagsito"
 fi

ferma
#Apro configurazione Cluster
     "${hapath}"/haconf -makerw
 if  [[ -n "${SYSKY}" ]]; then
     echo -e "\n${r}Aggiungo questa SYSTEM LIST${z} ${y}${SYSKY}${z}" | tee -a $LOGFILE
     "${hapath}"/hagrp -modify ${PKG} SystemList -add ${SYSKY}
 else
     ERRCOD=261 && Erro $ERRCOD
 fi

 if [[ "${ASLIST}" = "A" ||  "${ASLIST}" = "V" ]]; then
    echo -e "\n${r}Aggiungo questa AUTOSTART LIST${z} ${y}${SYSAS}${z}" | tee -a $LOGFILE
    echo -e "\n${r} $PKG è vitale o altamente critico.${z} ${y}AUTOSTART LIST${z}: ${SYSAS}${z}" | tee -a $LOGFILE
    "${hapath}"/hagrp -modify ${PKG} AutoStartList ${SYSAS}
 fi

 "${hapath}"/haconf -makerw
}

onlineRIS() {
 SYSTX=$(hostname)
 DEBUG echo "RISORSA ONLINE risvg=$1 sys=$SYSTX[0]"
 echo -e "\n"
 for i in $("${hapath}"/hasys -list)
 do
   echo " PROBE SU $i"
   echo -e "${g}"${hapath}"/hares -probe $Risorsa -sys $i ${z}\n" | tee -a "${LOGFILE}"
   "${hapath}"/hares -probe $Risorsa -sys $i | tee -a "${LOGFILE}"
   sleep 10
 done
 echo -e " ${r}METTO ONLINE:${z} ${g}"${hapath}"/hares -online ${y}$Risorsa${z} -sys ${y}$SYSTX${z} \n" | tee -a "${LOGFILE}"
 "${hapath}"/hares -online $Risorsa -sys $SYSTX | tee -a "${LOGFILE}"
 for i in {1..2}
 do
  stato $PKG | tee -a $LOGFILE
  sleep 5
 done
}

creaFS(){
 echo -e "${r}Controllo se ho creato il LV${z}" | tee -a $LOGFILE
 lvs |grep $lvnome | tee -a $LOGFILE
 DEBUG echo "FFFFFSSSSSSS= $vg $lvnome"
 echo -e "${r}creo il FILESYSTEM${z}: ${g}mkfs.ext4${z} ${y}/dev/$vg/$lvnome ${z}\n" | tee -a $LOGFILE
# ferma
 mkfs.ext4 -m 1 "/dev/$vg/$lvnome" | tee -a $LOGFILE
}

creaPV() {
   echo -e "${r}Eseguo ${z}${g}pvcreate su${z} ${y}$1${z}${g}. Dai ENTER per continuare o Ctrl-C per abortire ${z} \n" | tee -a $LOGFILE
   ferma
   pvcreate $1
   echo -e "${r}Controllo se ho creato il PV${g}: ${y}$1${z} \n" | tee -a $LOGFILE
   for i in "$1"; do
       pvs $1 | tee -a $LOGFILE
   done
   retcod=""
}

extendVG() {
 rc=""
 echo -e "${r}Eseguo un${z} ${y}PVSCAN${z} \n" |tee -a $LOGFILE
 pvscan >> $LOGFILE
 echo -e "${r}Estendo il VG${z} ${y}$vg${z} ${r}con${z} ${y}$VVMpath${z}\n" | tee -a $LOGFILE
 vgextend ${vg} ${VVMpath} | tee -a $LOGFILE
 echo -e "${r}Controllo l'extend del VG con${z} ${y}PVS${z} \n" | tee -a $LOGFILE
 pvs | grep $1 | tee -a $LOGFILE
 ferma
 echo -e "${r}Controllo l'extende del VG con${z} ${y}VGS${z}\n" | tee -a $LOGFILE
 vgs "$vg" | tee -a $LOGFILE
 ferma
}

creaVG() {
 rc=""
 echo -e "${r}Eseguo un${z} ${y}PVSCAN${z} \n" |tee -a $LOGFILE
 pvscan >> $LOGFILE
 echo -e "${r}Creo il VG${z} ${y}$vg${z} ${r}con${z} ${y}$VVMpath${z}\n" | tee -a $LOGFILE
 vgcreate ${vg} ${VVMpath} | tee -a $LOGFILE
 echo -e "${r}Controllo se ho creato il VG con${z} ${y}PVS${z} \n" | tee -a $LOGFILE
 pvs | grep $1 | tee -a $LOGFILE
 echo -e "${r}Controllo se ho creato il VG con${z} ${y}VGS${z}\n" | tee -a $LOGFILE
 vgs "$vg" | tee -a $LOGFILE
 devmp=$1
 cercaBOX "$devmp"
 flagsito=""
 if [[ "$abox" = "$tri" ]]; then
    echo -e "${r}Il box usato è${z} ${y}${abox} = TRIPLETTA${z}\n " | tee -a $LOGFILE
    flagsito="1"
 elif [[ "$abox" = "$tri_b" ]]; then
    echo -e "${r}Il box usato è${z} ${y}${abox}= TRIPLETTA${z}\n " | tee -a $LOGFILE
    flagsito="1"
 elif [[ "$abox" = "$dcm" ]]; then
      echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA SOLO MONCALIERI${z}\n " | tee -a $LOGFILE
      flagsito="2"
 elif [[ "$abox" = "$dcm_b" ]]; then
      echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA SOLO MONCALIERI${z}\n " | tee -a $LOGFILE
      flagsito="2"
 elif [[ "$abox" = "$scm" ]]; then
      echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA SENZA DR SOLO MONCALIERI${z}\n " | tee -a $LOGFILE
      flagsito="2"
 elif [[ "$abox" = "$tpa" ]]; then
      echo -e "${r}Il box usato è${z} ${y}${abox}= 3PAR STANDALONE SOLO MONCALIERI${z}\n " | tee -a $LOGFILE
      flagsito="2"
 elif [[ "$abox" = "$dst" ]]; then
      echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA SOLO SETTIMO${z}\n " | tee -a $LOGFILE
      flagsito="3"
 elif [[ "$abox" = "$dst_b" ]]; then
      echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA SOLO SETTIMO${z}\n " | tee -a $LOGFILE
      flagsito="3"
 elif [[ "$abox" = "$sst" ]]; then
      echo -e "${r}Il box usato è${z} ${y}${abox}= DOPPIETTA o STANDALONE SOLO SETTIMO${z}\n " | tee -a $LOGFILE
      flagsito="3"
 else
      ERRCOD=260 && Erro $ERRCOD
 fi

 if [[ "${PKG:5:1}" = "P" ]]; then
    systLIST
 elif [[ "${PKG:5:1}" = "T" ]]; then
      if [[ "${ASLIST}" = "A" ||  "${ASLIST}" = "V" ]]; then
         SYSTL=$("${hapath}"/hasys -list | grep -v $(hostname) | paste -s -d" ")
         "${hapath}"/hagrp -modify $PKG AutoStartList $SYSTQ $SYSTL
      fi
 fi
 ferma
 Risorsa=$vg-VG
 "${hapath}"/hares -modify $Risorsa Enabled 1
 onlineRIS $Risorsa

 if [[ $VGflag == "solovg" ]]; then
    echo -e "${r}Il VolumeGroup${z} ${y}$vg${z} ${r}E' STATO CREATO${z}"
#    "${hapath}"/haconf -dump -makero
    exit 0
 fi
}

creaDATA(){
 echo -e "\n${r}Creo risorsa${z} MNT ${y}${1}${z}"
 Risorsa="oradata_${SID}_${datnome}-${pkg}-MNT"
 MountPoint="/oradata/${SID}/database/datafile/${datnome}"
 BlockDevice="/dev/mapper/${vg}-${sid}${datnome}"
 creaRisorsa $MountPoint $BlockDevice $Risorsa
}

linkDATA(){
arg1="oradata_${SID}_${1}-${pkg}-MNT"
arg2="oradata_${SID}_database-${pkg}-MNT"
creaLink $arg1 $arg2
}

creaLVDATA(){
 lvnome="$sid$datnome"
 echo -e "${g}lvcreate -L${2}m -n ${lvnome} $vg \n${z}" | tee -a $LOGFILE
 ferma
 lvcreate -L${2} -n $lvnome $vg | tee -a "${LOGFILE}"
}


creaLV() {
 lvname=`echo $1 | tr "[A-Z]" "[a-z]"`
 lvNAME=$(TrMaiuscolo "$lvname")
 echo "${r}STO CREANDO IL VOLUME:${z} ${y}${lvNAME}${z}. ${r}CONTROLLA lo spazio libero sul VG${z}" | tee -a "${LOGFILE}"
 vgs "$vg" | tee -a $LOGFILE
# echo "${g}inserisci grandezza filesystem${z} ${y}$lvNAME${z} ${g}in numeri seguito da${z} M per Mega e G per Giga o 'FREE' ${g}per il riempimento del VG:${z}"
# read xsize
 while true; do
       read -p "${g}inserisci grandezza filesystem${z} ${y}$lvNAME${z} ${g}in numeri seguito da${z} M per Mega e G per Giga o 'FREE' ${g}per il riempimento del VG:${z}
> " risp
       check $risp
       dim="${risp: -1}"
#       echo -e "DEBUG DIM $dim"
       case $dim in
          [MmGgEe]* ) echo -e " "; break;;
                  * ) echo "${r}Metti${z} ${y}'m'${z} ${r}per Megabyte o ${z}${y}'g'${z} ${r}per Gigabyte"${z};;
       esac

 done
 xsize="$risp"
 csize=${xsize//[^a-zA-Z0-9]/}
 size=$(TrMaiuscolo "$csize")
 echo "********SIZE--->$size"
 lvnome="$sid$lvname"
 lvNOME=$(TrMaiuscolo "$lvnome")
# echo -e "DEBUG:prima di IF_FREE lvnome=$lvnome lvname=$lvname size=$size"
 ferma
 echo -e "${r}Creo il logical volume${z} ${y}$lvNOME${z} \n" | tee -a $LOGFILE
####### **** 17/03/2016 commentate tre righe sopra e sostituite per FS DATA > 2000 GB ***#######
 if [[ "$size" == "FREE" ]]; then
    if [[ "$lvname" == "data" ]]; then
        vgfrees=$(vgs --units m "${vg}" | tail -1 | awk '{print $7}')
        vgfrees=$(echo ${vgfrees%.*})
        if [[ $vgfrees -gt $datlimit ]]; then
           datlast=$(echo $(( $vgfrees % $datlimit )))
           alpha=abcdefghijklmnopqrstuvqxyz
           counter=0
           datprefix="dat"
           for datsize in $(seq "$datlimit" "$datlimit" "$vgfrees"); do
                datsuffix=$(echo ${alpha:$counter:1})
                datnome="${datprefix}${datsuffix}"
#               echo "*******DENTROFOR--->lvnome=$lvnome datnome=$datnome datlimit=$datlimit"
                Risorsa="oradata_${SID}_${datnome}-${pkg}-MNT"
                creaLVDATA $datnome $datlimit
                creaFS $lvnome
                creaDATA $datnome $Risorsa
                linkDATA ${datnome}
                onlineRIS $Risorsa
                echo "DEBUG: eseguo chown ${orauser}:dba ${MountPoint}"
                chown ${orauser}:dba ${MountPoint}
                ((counter++))
           done
           datsuffix=$(echo ${alpha:$counter:1})
           datnome="${datprefix}${datsuffix}"
#                  echo "*******DOPOFOR--->$datnome $datlast"
           Risorsa="oradata_${SID}_${datnome}-${pkg}-MNT"
           creaLVDATA $datnome $datlast
           creaFS $lvnome
           creaDATA $datnome $Risorsa
           linkDATA $datnome
           onlineRIS $Risorsa
           echo "DEBUG: eseguo chown ${orauser}:dba ${MountPoint}"
           chown ${orauser}:dba ${MountPoint}
####### **** 17/03/2016 *****************FINE MODIFICA****FS DATA > 2000 GB ***#######
        else
           echo -e "${g}lvcreate -l100%$size -n $lvnome $vg \n${z}" | tee -a $LOGFILE
           lvcreate -l100%"$size" -n $lvnome $vg  | tee -a $LOGFILE
           datnome=${lvname}
           echo "*******DOPO-ELSE--->$datnome"
           Risorsa="oradata_${SID}_${datnome}-${pkg}-MNT"
           creaFS $lvnome
           creaDATA $datnome
           linkDATA $datnome
           onlineRIS $Risorsa
           echo "DEBUG: eseguo chown ${orauser}:dba ${MountPoint}"
           chown ${orauser}:dba ${MountPoint}
        fi
    else
       echo -e "${g}lvcreate -l100%$size -n $lvnome $vg \n${z}" | tee -a $LOGFILE
       lvcreate -l100%"$size" -n $lvnome $vg  | tee -a $LOGFILE
       creaFS $lvnome
       echo -e "DEBUG: primo else $lvname"
       if [[ "$lvname" == "data" ]]; then
           creaDATA $datnome $Risorsa
           linkDATA $datnome
           onlineRIS $Risorsa
           echo "DEBUG: eseguo chown ${orauser}:dba ${MountPoint}"
           chown ${orauser}:dba ${MountPoint}
       fi
    fi
 else
   echo -e "${g}lvcreate -L$size -n $lvnome $vg \n${z}" | tee -a $LOGFILE
   lvcreate -L$size -n $lvnome $vg | tee -a "${LOGFILE}"
   creaFS $lvnome
   echo -e "DEBUG: secondo else $lvname"
    if [[ "$lvname" == "data" ]]; then
           datnome="${lvname}"
           creaDATA $datnome $Risorsa
           linkDATA $datnome
           onlineRIS $Risorsa
           echo "DEBUG: eseguo chown ${orauser}:dba ${MountPoint}"
           chown ${orauser}:dba ${MountPoint}
    fi
 fi
# echo -e "${r}Controllo se ho creato il LV${z}" | tee -a $LOGFILE
# lvs |grep $lvnome | tee -a $LOGFILE
# DEBUG echo "FFFFFSSSSSSS= $vg $lvnome"
# echo -e "${r}creo il FILESYSTEM${z}: ${g}mkfs.ext4${z} ${y}/dev/$vg/$lvnome ${z}\n" | tee -a $LOGFILE
 #ferma
# mkfs.ext4 -m 1 "/dev/$vg/$lvnome" | tee -a $LOGFILE
}

checkPV() {
 pvs $1
 rcp="$?"
 if [[ $rcp = "0" ]]; then
   echo "${r}CHECK PV FALLITO${z} ${y}$1${z} ${r}già in uso${z}"
 else
   VVMpath="$VVMpath$1 "
   creaPV $1
   rcp=""
   rc="0"
 fi
}

rescanLUN() {
  if [[ "${flaglun}" = "" ]]; then
     echo -e "${r}ESEGUO RESCAN SCSI BUS${z}" | tee -a $LOGFILE
     ferma
     for i in $(ls /sys/class/fc_host); do echo $i && echo "- - -" > /sys/class/scsi_host/$i/scan; done
#     rescan-scsi-bus.sh -s | tee -a $LOGFILE
     flaglun="1"
  fi
}

testMPATH() {
 if [[ -n $1 ]]; then
        echo -e "${r}Eseguo multipath -ll sulla lun:${z} ${y}/dev/mapper/$1${z} \n" |tee -a $LOGFILE
        VarMpath="/dev/mapper/$1"
        multipath -ll $VarMpath >>$LOGFILE
        echo -e "${r}Controllo esistenza special file:${z}\n"
        if [[ -n $VarMpath ]]; then
           ls -la $VarMpath | tee -a $LOGFILE
        else
           ERRCOD=252 && Erro $ERRCOD
        fi
        checkPV $VarMpath
 fi
}

creaVOL(){
 if [[ -n "${1}" ]]; then
   DEBUG echo "DEBUG\$$i=$(eval echo \$$i)"
   if [[ "${LunList}" = "" ]]; then
     echo -e "${g}inserisci CU:LDEV CON O SENZA i due punti (:), in caso di più CU:LDEV separali tra loro con uno spazio.\n \
     Es: 001a 001b... Le lettere devono essere minuscole. \n \
     In caso di box 3PAR inserire l'INTERA STRINGA e non solo le ultime 4 posizioni \n${z}"
#     read LunList
     read XLunList
     LunList="$(echo "$XLunList" | tr -d : )"
     echo -e "${r}CONTROLLA CON ATTENZIONE LA LISTA DELLE LUN${z}: ${y}$LunList${z}" | tee -a $LOGFILE
   fi
   ferma
   for a in ${LunList}; do
       multipath -ll | grep "$a)"
       rc=$?
       if [[ $rc = "1" ]]; then
          retcod=100
          rescanLUN
       fi
       var=""
##################### modifica per 3PAR #########################################
        tipo=$(multipath -ll | grep -i "${a})" | awk '{print $4}')
        if [[ "${tipo::4}" == "3PAR" ]]; then
           while IFS= read -r line; do
             var="$var$line\n"
             Vmpath=""
             Vmpath=$(echo $line | awk {'print $1'})
             if [[ -n $Vmpath ]]; then
                testMPATH $Vmpath
             fi
           done < <(multipath -ll |sed '/([0-9a-f]\{33\})/ i \\' \
  | awk 'BEGIN {RS=""; FS="\n"} {for(i=2; i<=NF; i++) {print $1,$2}}' \
  | cut -d ' ' -f1-5 | uniq | grep -i "$a") && echo -e $var
################################### Entrambi questi due blocchi permettono di avere su un unica riga l'output di multipath con la dimensione
        else
           while IFS= read -r line; do
             var="$var$line\n"
             Vmpath=""
             Vmpath=$(echo $line | awk {'print $1'})
             if [[ -n $Vmpath ]]; then
                testMPATH $Vmpath
             fi
           done < <(multipath -ll |sed '/([0-9a-f]\{33\})/ i \\' \
  | sed -r 's/\(.*(....)\)/\1/' | awk 'BEGIN {RS=""; FS="\n"} {for(i=2; i<=NF; i++) {print $1,$2}}' \
  | cut -d ' ' -f1-5 | uniq | grep -i "$a") && echo -e $var
        fi
   done

   if [[ "$flag_vg" = "C" ]]; then
      if [[ $rc = "0" ]]; then
         creaVG "$VVMpath"
         retcod=""
         msg="ESCO DAL LOOP creaVOL"
         ferma $msg
      else
         ERRCOD=251 && Erro $ERRCOD
      fi
   elif [[ "$flag_vg" = "R" ]]; then
        if [[ $rc = "0" ]]; then
           extendVG "$VVMpath"
           retcod=""
           msg="ESCO DAL LOOP creaVOL"
           ferma $msg
        else
         ERRCOD=251 && Erro $ERRCOD
        fi
   fi
 fi
}


chiediVOL() {
 volume=$1
 flag_vg=""
####### ****** 23/02/2016 ** aggiunto il seguente e commntato sotto############
 if [[ "$rispVG" = "" ]]; then
    while true; do
       read -p "${g}Vuoi Creare il VG?${z}${r} ${VG} ${z} ${y}(y/n)${z}" rispVG
       case $rispVG in
           [Yy]* ) flag_vg="C"
                   creaVOL $volume
                   while [[ "${retcod}" = "100" ]]; do
                         if [ $retcod -eq 100 ]; then
                            retcod=""
                            creaVOL "${volume} ${retcod}"
                         fi
                   done
                   break;;
           [Nn]* ) echo "${r}non creo il VG${z} ${y}${VG}$z "
                   if [[ $VG_flagfile == "solovg" ]]; then
                      exit 0
                   else
##############################*** 27-04-16 ***##############################
                      read -p "${g}Vuoi fare un extend del VG?${z}${r} ${VG} ${z} ${y}(y/n)${z}" rispVG
                      case $rispVG in
                          [Yy]* ) flag_vg="R"
                                  creaVOL $volume
                                  while [[ "${retcod}" = "100" ]]; do
                                        if [ $retcod -eq 100 ]; then
                                           retcod=""
                                           creaVOL "${volume} ${retcod}"
                                        fi
                                  done
                                  break;;
                          [Nn]* ) echo "${r}non estendo il VG${z} ${y}${VG}$z "
                                  if [[ $VG_flagfile == "solovg" ]]; then
                                     exit 0
                                  fi
                                  ;;
#                                  break;;
                              * ) echo "Rspondi 'y' o 'n'";;
                      esac
############################################################################
                   fi
                   echo -e " ${r}METTO OFFLINE:${z} ${g}"${hapath}"/hares -offline ${y}$vgris${z} \
                   -sys ${y}$(hostname)${z} \n" | tee -a "${LOGFILE}"
                   "${hapath}"/hares -offline $vgris -sys $(hostname) | tee -a "${LOGFILE}"
                   sleep 10
                   echo -e " ${r}METTO ONLINE:${z} ${g}"${hapath}"/hares -online ${y}$vgris${z} \
                   -sys ${y}$(hostname)${z} \n" | tee -a "${LOGFILE}"
                   "${hapath}"/hares -online $vgris -sys $(hostname) | tee -a "${LOGFILE}"
                   sleep 20
                   break;;
               * ) echo "Rspondi 'y' o 'n'";;
    esac
done
fi
#
 while true; do
     rispLV=""
     read -p "${g}Creo LV${z} ${y}${volume}$z ${g}(y/n)?${z}" rispLV
     case $rispLV in
         [Yy]* ) creaLV ${volume}; break;;
         [Nn]* ) echo "${r}non creo logical volume per ${z}${y}${volume}$z " ; break;;
             * ) echo "Rspondi 'y' o 'n'";;
     esac
 done
}

utTWS(){
 echo -e "${r}CONTROLLO ESISTENZA UTENTE TWS: ${z}${y}${twsut}${z}" | tee -a $LOGFILE
 rc=""
 id "${twsut}"
 rc=$?
 if [[ $rc = "1" ]]; then
    echo -e "\n${r}L'UTENTE${z} ${y}${twsut}${z} ${r}NON ESISTE CREO L'UTENTE${z}"
#    for LST in $("${hapath}"/hasys -state| tail -n+2 | grep RUNNING | awk '{print $1}'); do
    for LST in $("${hapath}"/hasys -list); do
    test="/SUPPORTO_OPEN_OS_UNIX/SCRIPT_MAKEUSERS/asd.sh -u ${twsut} -g 'twsgroup' -h '/var/tws/$twsut' -c 'da Migrazione Automatica' -a $amb -L $LST"
    ferma
         echo "DEBUG_ASD: $test"
         ssh -n -q sglvmp32 $test
    done
 fi
}

chiediTWS(){
 echo -e "${g}Inserisci SUFFISSO ${z} ${y}TWZXXXX (es:UP76 per twzUP76)$z ${g}e dai ENTER${z} \n"
 read xtwssuf
 twssuf=`echo "${xtwssuf}" | tr "[A-Z]" "[a-z]"`
 twsut="twz${twssuf}"
}

creoAppTWS(){
"${hapath}"/hares -add "${Risorsa}" Application "${PKG}"
"${hapath}"/hares -modify "${Risorsa}" Enabled 0
"${hapath}"/hares -modify "${Risorsa}" Critical 0
"${hapath}"/hares -modify "${Risorsa}" StartProgram "/opt/VRTSvcs/bin/CUSTOM/ZCENTRIC/online ${twsfs}"
"${hapath}"/hares -modify "${Risorsa}" StopProgram "/opt/VRTSvcs/bin/CUSTOM/ZCENTRIC/offline ${twsfs}"
"${hapath}"/hares -modify "${Risorsa}" MonitorProgram "/opt/VRTSvcs/bin/CUSTOM/ZCENTRIC/monitor ${twsfs}"
"${hapath}"/hares -modify "${Risorsa}" User root
"${hapath}"/hares -modify "${Risorsa}" PidFiles -delete -keys
"${hapath}"/hares -modify "${Risorsa}" MonitorProcesses -delete -keys
"${hapath}"/hares -modify "${Risorsa}" UseSUDash 0
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
declare risp=""
SYSQ=$(hostname)
ERRCOD="0"
NOW=$(date +"%F")
LOGPARTIAL="/tmp/crea_pkg-vol-*"
LOGFILE="/tmp/crea_pkg-vol-$NOW.log"
tempfile="/tmp/SG_tempfile"
VG_flagfile="/tmp/SG_flagfile"
VVMpath=""
SYSAS=""
orauser=""
retcod=""
flaglun=""
rispVG=""
mes=""
abox=""
twsut=""
VGflag=""
flagsito=""
flagdata=""
###variabili box disco
tri="076713"       ###tripletta
tri_b="020203"      ###tripletta
dcm="85779"        ###doppietta moncalieri
dcm_b="53988"      ###doppietta moncalieri
scm="78692"        ###standalone moncalieri senza DR
dst="85770"        ###doppietta settimo
dst_b="85756"      ###doppietta settimo
sst="53250"        ###standolne o doppietta settimo
tpa="CZ3550S4TA"   ###standalone 3PAR

######### limite massimo grandezza filesystem "data"
datlimit=2000000

###variabili nodi per SystemList
mon1="sdlmop12"
mon2="sdlmop13"
mon3="sdlmop18"
set1="sdlstp14"
set2="sdlstp15"
set3="sdlstp19"
amb=""

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
if [[ -f "${VG_flagfile}" ]]; then
   VGflag=$(cat $VG_flagfile)
   echo "VGFLAG=$VGflag"
fi
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
 if [[ "${PKG:5:1}" = "P" ]]; then
    amb="prod"
 elif [[ "${PKG:5:1}" = "T" ]]; then
    amb="sys"
 fi
#
if [[ -f "${tempfile}" ]]; then
    rm  "${tempfile}"
fi
if [[ -f "${VG_flagfile}" ]]; then
    rm  "${VG_flagfile}"
fi
#
if [[ "${VGflag}" == "" ]]; then
   echo -n "${g}inserisci acronimo:${z} "
   read xsid
   SID=`echo "${xsid}" | tr "[a-z]" "[A-Z]"`
   sid=`echo "${xsid}" | tr "[A-Z]" "[a-z]"`

   echo -n "${g}inserisci utente oracle:${z}(default:ora1124) "
   read xoru
   xoru="${xoru:=ora1124}"
   echo -e "$xoru"
   ORAUSER=`echo "${xoru}" | tr "[a-z]" "[A-Z]"`
   orauser=`echo "${xoru}" | tr "[A-Z]" "[a-z]"`
fi

VG="VG00_$PKG"
vg="vg00_$pkg"
vgris="vg00_$pkg-VG"
ASLIST="${PKG:3:1}"
dbuser="db$sid"
twssuf=""

hapath="/opt/VRTS/bin"
"${hapath}"/haconf -makerw

#######################**** Modifica SOLOVG 2016-07-03 ***####################

if [[ "${VGflag}" == "solovg" ]]; then
   Volume="da_buttare"
   chiediVOL $Volume
fi

#######################

options=("tws" "agentOEM" "database" "archive" "home" "tmp" "undo" "app" "data")

prompt="${g}inserisci il numero del filesystem  e dai ENTER (lo stesso per annullare ), ancora ENTER quando hai finito:${z} "
while menu && read -rp "$prompt" num && [[ "$num" ]]; do
    [[ "$num" != *[![:digit:]]* ]] &&
    (( num > 0 && num <= ${#options[@]} )) ||
    { msg="opzione non valida: $num"; continue; }
    ((num--)); msg="${y}${options[num]}${z} ${r}è  ${choices[num]:+"UN"}CHECKED${z}"
    [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
done

printf "${g}FileSystem selezionati${z}"; msg=" NESSUNO"
for i in ${!options[@]}; do
    [[ "${choices[i]}" ]] && { printf " %s" "${options[i]}"; msg=""; }
done
echo "${g}$msg${z}"



for K in "${!choices[@]}"; do
   if [[ "${choices[$K]}" = "+" ]]; then
   ERRCOD="0"
     case "$K" in
       0)  chiediTWS
           twsfs="${twsut}"
#          twsfs="twz${twssuf}"
           RisTws=""
           flagRis=""
           RisTws="${twsfs}-${pkg}-MNT"
           flagRis=$("${hapath}"/hares -list | grep -i "${RisTws}" | awk {'print $1'} | uniq)
           echo "FLAGRIS=$flagRis  RisTws=${RisTws} "
           if [[ -z "${flagRis}" ]]; then
                chiediVOL "${twsfs}"
                echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
                Risorsa="${twsfs}-${pkg}-MNT"
                MountPoint="/var/tws/${twsfs}"
                BlockDevice="/dev/mapper/${vg}-${sid}${twsfs}"
                creaRisorsa $MountPoint $BlockDevice $Risorsa
                onlineRIS $Risorsa
                utTWS ${twsut}
                echo -e "\n${r}Creo risorsa${z} APP ${y}${options[K]}${z}"
                Risorsa="${twsfs}-${pkg}-APP"
                creoAppTWS $Risorsa
#               onlineRIS $Risorsa
                chown ${twsut}:twsgroup ${MountPoint}
           else
                echo -e "\n ${r}La risorsa${z} ${y}${RisTws}${z} ${r}è GIA' ESISTENTE.${z}\n"
           fi
           ;;
       1)  chiediVOL "${options[K]}"
           echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
           Risorsa="agentOEM-${pkg}-MNT"
           MountPoint="/agentOEM/${PKG}"
           BlockDevice="/dev/mapper/${vg}-${sid}agentoem"
           Critical="0"
           creaRisorsa "$MountPoint" "$BlockDevice" "$Risorsa" "$Critical"
           onlineRIS $Risorsa
           creaClusDir "$MountPoint"
           chown oem11g:dba ${MountPoint}
           ;;
       2)  chiediVOL "${options[K]}"
           echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
           Risorsa="oradata_${SID}_database-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database"
           BlockDevice="/dev/mapper/${vg}-${sid}database"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           creaClusDir "$MountPoint"
           chown ${orauser}:dba ${MountPoint}
           ;;
       3)  chiediVOL "${options[K]}"
           echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
           Risorsa="oradata_${SID}_archive-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database/archive"
           BlockDevice="/dev/mapper/${vg}-${sid}archive"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${orauser}:dba ${MountPoint}
           ;;
       4)  chiediVOL "${options[K]}"
           echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
           Risorsa="oradata_${SID}_home-${pkg}-MNT"
           MountPoint="/oradata/${SID}/home/${dbuser}"
           BlockDevice="/dev/mapper/${vg}-${sid}home"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           creaClusDir "$MountPoint"
           chown ${dbuser}:dba ${MountPoint}
           ;;
       5)  chiediVOL "${options[K]}"
           echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
           Risorsa="oradata_${SID}_tmp-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database/system/tmp"
           BlockDevice="/dev/mapper/${vg}-${sid}tmp"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${orauser}:dba ${MountPoint}
           chown ${orauser}:dba "/oradata/${SID}/database/system"
           ;;
       6)  chiediVOL "${options[K]}"
           echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
           Risorsa="oradata_${SID}_undo-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database/system/undo"
           BlockDevice="/dev/mapper/${vg}-${sid}undo"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${orauser}:dba ${MountPoint}
           chown ${orauser}:dba "/oradata/${SID}/database/system"
           ;;
       7)  chiediVOL "${options[K]}"
           echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
           Risorsa="oradata_${SID}_app-${pkg}-MNT"
           MountPoint="/oradata/${SID}/app"
           BlockDevice="/dev/mapper/${vg}-${sid}app"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${dbuser}:users ${MountPoint}
           ;;
       8)  chiediVOL "${options[K]}"
#          echo -e "\n${r}Creo risorsa${z} MNT ${y}${options[K]}${z}"
#          Risorsa="oradata_${SID}_data-${pkg}-MNT"
#          MountPoint="/oradata/${SID}/database/datafile/data"
#          BlockDevice="/dev/mapper/${vg}-${sid}data"
#          creaRisorsa $MountPoint $BlockDevice $Risorsa
#          onlineRIS $Risorsa
#          chown ${orauser}:dba ${MountPoint}
           echo -e " chown datafile"
           chown ${orauser}:dba /oradata/${SID}/database/datafile
           dataf="/oradata/${SID}/database/datafile"
           echo -e "${r}DEBUG: creo directory e cambio propietario e gruppo sui tutti i nodi del cluster${z}"
           creaClusDir "$dataf"
           chownClusDir "$dataf"
           ;;
       *)  ERRCOD=300 && Erro $ERRCOD
           echo "NON CREO RISORSE"
           ;;
     esac
   fi
done


for K in "${!choices[@]}"; do
  if [[ "${choices[$K]}" = "+" ]]; then
#     echo "DEBUG LINK========>>>>>>>>>>>$K"
     ERRCOD="0"
     case "$K" in
       0) arg1="${twsfs}-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          arg1="${twsfs}-${pkg}-APP"
          arg2="${twsfs}-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       1) arg1="agentOEM-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       2) arg1="oradata_${SID}_database-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       3) arg1="oradata_${SID}_archive-${pkg}-MNT"
          arg2="oradata_${SID}_database-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       4) arg1="oradata_${SID}_home-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       5) arg1="oradata_${SID}_tmp-${pkg}-MNT"
          arg2="oradata_${SID}_database-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       6) arg1="oradata_${SID}_undo-${pkg}-MNT"
          arg2="oradata_${SID}_database-${pkg}-MNT"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       7) arg1="oradata_${SID}_app-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "\n${r}Creo LINK${z} TRA ${y}${arg1}--->${arg2}${z}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       8) echo -e "controlla link"
#         arg1="oradata_${SID}_data-${pkg}-MNT"
#         arg2="oradata_${SID}_database-${pkg}-MNT"
#         creaLink $arg1 $arg2
          ;;
       *) ERRCOD=301 && Erro $ERRCOD
          echo "NON CREO NESSUN LINK"
          ;;
     esac
  fi
done

#"${hapath}"/haconf -dump -makero
"${hapath}"/haconf -dump


#id "${twsut}"
#rc=$?
#if [[ $rc = "1" ]]; then
#   ERRCOD=240 && Erro $ERRCOD
#else
#           chown ${twsut}:twsgroup ${MountPoint}
#chown ${twsfs}:twsgroup ${MountPoint}
#fi

Erro $ERRCOD
