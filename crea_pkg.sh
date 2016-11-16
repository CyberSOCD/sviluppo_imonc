#!/bin/env bash                                                                   #
# Version:3.01                                    #
# Author : LC                                     #
#                                                 #
###################################################

hapath="/opt/VRTS/bin"

ferma() {
 read -p "${r}Dai ENTER per continuare o CTRL-C per abortire ${z}" ; echo
}
probeRIS() {
echo -e "\n"
     echo -e ""${hapath}"/hares -probe $Risorsa -sys $SYSTH \n"
     "${hapath}"/hares -probe $1 -sys $SYSTH
     sleep 10
}

EnableRIS(){
echo -e " ${r}ABILITO LA RISORSA:${z} ${g}"${hapath}"/hares -modify${z} ${y}$Risorsa${z} ${g}Enabled 1 ${z} \n" | tee -a "${LOGFILE}"
 "${hapath}"/hares -modify $Risorsa Enabled 1 | tee -a "${LOGFILE}"
 stato $PKG | tee -a $LOGFILE
 sleep 5
}

onlineRISGRP() {
# DEBUG echo "RISORSA ONLINE risvg=$1 sys=$SYSTX[0]"
  echo -e "METTO ONLINE: "${hapath}"/hagrp -online $1 -sys $SYSTH \n"
  "${hapath}"/hagrp -online $1 -sys $SYSTH

  for i in {1..2}
  do
    stato $PKG
    sleep 5
  done

#sleep 10
#"${hapath}"/hares -online $1 -sys $SYSTX
}

onlineRIS() {
 SYSTX=$(hostname)
# echo -e " ${r}ABILITO LA RISORSA:${z} ${g}"${hapath}"/hares -modify${z} ${y}$Risorsa${z} ${g}Enabled 1 ${z} \n" | tee -a "${LOGFILE}"
# "${hapath}"/hares -modify $Risorsa Enabled 1 | tee -a "${LOGFILE}"

 echo -e "\n"
 for i in $("${hapath}"/hasys -list)
 do
   echo " PROBE SU $i"
   echo -e "${g}"${hapath}"/hares -probe $Risorsa -sys $i ${z}\n" | tee -a "${LOGFILE}"
   "${hapath}"/hares -probe $Risorsa -sys $i | tee -a "${LOGFILE}"
   sleep 10
 done
 echo -e " ${r}METTO ONLINE:${z} ${g}"${hapath}"/hares -online${z} ${y}$Risorsa${z} ${y}-sys${z} ${y}$SYSTX${z} \n" | tee -a "${LOGFILE}"
 "${hapath}"/hares -online $Risorsa -sys $SYSTX | tee -a "${LOGFILE}"
 for i in {1..2}
 do
  stato $PKG | tee -a $LOGFILE
  sleep 5
 done
}

TrMaiuscolo(){
local outM=`echo $1 | tr "[a-z]" "[A-Z]"`
echo "$outM"
}

TrMinuscolo(){
local outm=`echo $1 | tr "[A-Z]" "[a-z]"`
echo "$outm"
}

##################################################### * MAIN * ##################################
NOW=$(date +"%F")
LOGPARTIAL="/tmp/crea_pkg-vol-*"
LOGFILE="/tmp/crea_pkg-vol-$NOW.log"
tempfile="/tmp/SG_tempfile"
flag=""


if [[ -f "${LOGPARTIAL}" ]]; then
    rm  "${LOGPARTIAL}"
fi

if [[ -f "${tempfile}" ]]; then
   pkg=$(cat $tempfile)
   flag="X"
fi

if [[ -z "$pkg" ]]; then
   echo -e "inserisci nome Pacchetto: \n"
   read xpkg
   PKG=$(TrMaiuscolo "$xpkg")
   pkg=$(TrMinuscolo "$xpkg")
else
#trasformo la variabile arrivata dal crea_all
   PKG=`echo $pkg | tr "[a-z]" "[A-Z]"`
#   DEBUG echo "ARRIVO DAL CREA_ALL pkg=$pkg PKG=$PKG"
fi

if [[ -f "${tempfile}" ]]; then
    rm  "${tempfile}"
fi


echo -e "inserisci indirizzo IP o vai avanti: \n "
read xip
ADDRESS=$(TrMaiuscolo "$xip")
address=$(TrMinuscolo "$xip")
if [[ -n ${xip} ]]; then
   echo -e "inserisci Netmask(255.255.252.0): \n"
   read xnetm
   xnetm="${xnetm:=255.255.252.0}"
   NETMASK=$(TrMaiuscolo "$xnetm")
   netmask=$(TrMinuscolo "$xnetm")
fi

echo -e "inserisci indirizzo IP di BACKUP: \n "
read xipb
ADDRESSB=$(TrMaiuscolo "$xipb")
addressb=$(TrMinuscolo "$xipb")


if [[ -n ${xipb} ]]; then
   echo -e "inserisci Netmask di BACKUP(255.255.252.0): \n"
   read xnetmb
   xnetmb="${xnetmb:=255.255.252.0}"
   NETMASKB=$(TrMaiuscolo "$xnetmb")
   netmaskb=$(TrMinuscolo "$xnetmb")
fi

hapath="/opt/VRTS/bin"

if [[ "${PKG:5:1}" = "T" || "${PKG:5:1}" = "U" ]]; then
SYSTCL=$(${hapath}/hasys -list | { while read a; do [ -z "${k}" ] && k=0; syst[$k]="$a $k"; ((k++)); sleep 1 ; done; echo ${syst[@]}; })
  DEVICE="eth1"
  device=`echo ${DEVICE} | awk '{print tolower ($1)}'`
  DEVICEB="eth4"
  deviceb=`echo ${DEVICEB} | awk '{print tolower ($1)}'`
  tagb="bk862"
else
  SYSTCL="$(hostname) 0"
  DEVICE="bond0"
  device=`echo ${DEVICE} | awk '{print tolower ($1)}'`
  DEVICEB="eth5.860"
  deviceb=`echo ${DEVICEB} | awk '{print tolower ($1)}'`
  tagb="bk860"
fi


SYSTH=$(hostname)

ferma


#CREO SEVICE GROUP
if [[ -n ${address} ]]; then
   "${hapath}"/haconf -makerw
   "${hapath}"/hagrp -add $PKG
   "${hapath}"/hagrp -modify "${PKG}" SystemList $SYSTCL
   "${hapath}"/hagrp -modify $PKG FaultPropagation 0
   "${hapath}"/hagrp -modify $PKG OnlineRetryLimit 3
   "${hapath}"/hagrp -modify $PKG PreOnline        1
   "${hapath}"/hagrp -modify $PKG PreonlineTimeout 900
   ASLIST="${PKG:3:1}"
   echo "quarta lettera: $ASLIST"
   if [[ "${ASLIST}" = "A" ||  "${ASLIST}" = "V" ]]; then
      if [[ "${PKG:5:1}" = "P" ]]; then
         "${hapath}"/hagrp -modify $PKG AutoStartList $SYSTH
      elif [[ "${PKG:5:1}" = "T" ]]; then
         SYSTL=$("${hapath}"/hasys -list | grep -v $(hostname) | paste -s -d" ")
         "${hapath}"/hagrp -modify $PKG AutoStartList $SYSTH $SYSTL
      elif [[ "${PKG:5:1}" = "U" ]]; then
         SYSTL=$("${hapath}"/hasys -list | grep -v $(hostname) | paste -s -d" ")
         "${hapath}"/hagrp -modify $PKG AutoStartList $SYSTH $SYSTL
      else
         echo -e "ERRORE  $PKG non ha nè T nè P nè U in quinta posizione  "
         exit 1
      fi
   fi
   "${hapath}"/haconf -dump -makero

   #CREO RISORSA PROXY e IP
   "${hapath}"/haconf -makerw
   "${hapath}"/hares -add $pkg-PROXY Proxy $PKG
   "${hapath}"/hares -modify $pkg-PROXY Critical 0
   "${hapath}"/hares -modify $pkg-PROXY TargetResName NICGroup-NIC
   "${hapath}"/hares -modify $pkg-PROXY Enabled 0

   "${hapath}"/hares -add    $pkg-IP IP $PKG
   "${hapath}"/hares -modify $pkg-IP Critical 1
   "${hapath}"/hares -modify $pkg-IP Device $device
   "${hapath}"/hares -modify $pkg-IP Address "$address"
   "${hapath}"/hares -modify $pkg-IP NetMask "$netmask"
   "${hapath}"/hares -modify $pkg-IP ArpDelay 1
   "${hapath}"/hares -modify $pkg-IP Enabled 0

   "${hapath}"/hares -link $pkg-IP $pkg-PROXY

   "${hapath}"/haconf -dump -makero
fi
#CREO RISORSA PROXY E IP DI BACKUP
if [[ -n ${addressb} ]]; then
    Risorsa="$pkg-$tagb"
   "${hapath}"/haconf -makerw
   "${hapath}"/hares -add $Risorsa-PROXY Proxy $PKG
   "${hapath}"/hares -modify $Risorsa-PROXY Critical 0
   "${hapath}"/hares -modify $Risorsa-PROXY TargetResName NICGroup-NIC-BK
   "${hapath}"/hares -modify $Risorsa-PROXY Enabled 0

   "${hapath}"/hares -add    $Risorsa-IP IP $PKG
   "${hapath}"/hares -modify $Risorsa-IP Critical 1
   "${hapath}"/hares -modify $Risorsa-IP Device $deviceb
   "${hapath}"/hares -modify $Risorsa-IP Address "$addressb"
   "${hapath}"/hares -modify $Risorsa-IP NetMask "$netmaskb"
   "${hapath}"/hares -modify $Risorsa-IP ArpDelay 1
   "${hapath}"/hares -modify $Risorsa-IP Enabled 0

   "${hapath}"/hares -link $Risorsa-IP $Risorsa-PROXY

   "${hapath}"/haconf -dump -makero

   if [[ "${flag}" == "X" ]]; then
#      sleep 5
     "${hapath}"/haconf -makerw
      Risorsa="$pkg-$tagb-PROXY"
      EnableRIS $Risorsa
      sleep 5
      Risorsa="$pkg-$tagb-IP"
      EnableRIS $Risorsa
      onlineRIS $Risorsa
     "${hapath}"/haconf -dump -makero
   fi


fi

# ABILITO LE RISORSE
if [[ "${flag}" != "X" ]]; then
   sleep 5
   "${hapath}"/haconf -makerw
   "${hapath}"/hagrp -enableresources $PKG
#   "${hapath}"/haconf -dump -makero
   sleep 10
   "${hapath}"/haconf -dump -makero
   sleep 10
   # METTO ONLINE IL PACCHETTO
   onlineRISGRP "${PKG}"
fi


#CREO RISORSA VG
if [[ -n ${address} ]]; then
 "${hapath}"/haconf -makerw
 "${hapath}"/hares -add vg00_$pkg-VG LVMVolumeGroup $PKG
 "${hapath}"/hares -modify vg00_$pkg-VG VolumeGroup vg00_$pkg
 "${hapath}"/hares -modify vg00_$pkg-VG StartVolumes 1
 "${hapath}"/hares -modify vg00_$pkg-VG EnableLVMTagging 1
 "${hapath}"/hares -modify vg00_$pkg-VG Enabled 0
 "${hapath}"/haconf -dump -makero
fi
