options= ${array[@]}


for K in "${options[@]}"; do
   if [[ "${options[$K]}" != " " ]]; then
   ERRCOD="0"
     case "$K" in
       0)  chiediVOL "${options[K]}"
           echo -e "Creo risorsa MNT ${options[K]}"
           Risorsa="oradata_${SID}_database-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database"
           BlockDevice="/dev/mapper/${vg}-${sid}database"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           creaClusDir "$MountPoint"
           chown ${orauser}:dba ${MountPoint}
           ;;
       1)  chiediVOL "${options[K]}"
           echo -e "Creo risorsa MNT ${options[K]}"
           Risorsa="oradata_${SID}_archive-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database/archive"
           BlockDevice="/dev/mapper/${vg}-${sid}archive"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${orauser}:dba ${MountPoint}
           ;;
       4)  chiediVOL "${options[K]}"
           echo -e "Creo risorsa MNT ${options[K]}"
           Risorsa="oradata_${SID}_home-${pkg}-MNT"
           MountPoint="/oradata/${SID}/home/${dbuser}"
           BlockDevice="/dev/mapper/${vg}-${sid}home"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           creaClusDir "$MountPoint"
           chown ${dbuser}:dba ${MountPoint}
           ;;
       5)  chiediVOL "${options[K]}"
           echo -e "Creo risorsa MNT ${options[K]}"
           Risorsa="oradata_${SID}_tmp-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database/system/tmp"
           BlockDevice="/dev/mapper/${vg}-${sid}tmp"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${orauser}:dba ${MountPoint}
           chown ${orauser}:dba "/oradata/${SID}/database/system"
           ;;
       6)  chiediVOL "${options[K]}"
           echo -e "Creo risorsa MNT ${options[K]}"
           Risorsa="oradata_${SID}_undo-${pkg}-MNT"
           MountPoint="/oradata/${SID}/database/system/undo"
           BlockDevice="/dev/mapper/${vg}-${sid}undo"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${orauser}:dba ${MountPoint}
           chown ${orauser}:dba "/oradata/${SID}/database/system"
           ;;
       7)  chiediVOL "${options[K]}"
           echo -e "Creo risorsa MNT ${options[K]}"
           Risorsa="oradata_${SID}_app-${pkg}-MNT"
           MountPoint="/oradata/${SID}/app"
           BlockDevice="/dev/mapper/${vg}-${sid}app"
           creaRisorsa $MountPoint $BlockDevice $Risorsa
           onlineRIS $Risorsa
           chown ${dbuser}:users ${MountPoint}
           ;;
       8)  chiediVOL "${options[K]}"
#          echo -e "Creo risorsa MNT ${options[K]}"
#          Risorsa="oradata_${SID}_data-${pkg}-MNT"
#          MountPoint="/oradata/${SID}/database/datafile/data"
#          BlockDevice="/dev/mapper/${vg}-${sid}data"
#          creaRisorsa $MountPoint $BlockDevice $Risorsa
#          onlineRIS $Risorsa
#          chown ${orauser}:dba ${MountPoint}
           echo -e " chown datafile"
           chown ${orauser}:dba /oradata/${SID}/database/datafile
           dataf="/oradata/${SID}/database/datafile"
           echo -e "DEBUG: creo directory e cambio propietario e gruppo sui tutti i nodi del cluster"
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
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          arg1="${twsfs}-${pkg}-APP"
          arg2="${twsfs}-${pkg}-MNT"
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       1) arg1="agentOEM-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       2) arg1="oradata_${SID}_database-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       3) arg1="oradata_${SID}_archive-${pkg}-MNT"
          arg2="oradata_${SID}_database-${pkg}-MNT"
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       4) arg1="oradata_${SID}_home-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       5) arg1="oradata_${SID}_tmp-${pkg}-MNT"
          arg2="oradata_${SID}_database-${pkg}-MNT"
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       6) arg1="oradata_${SID}_undo-${pkg}-MNT"
          arg2="oradata_${SID}_database-${pkg}-MNT"
          echo -e "++++++++++Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
          creaLink $arg1 $arg2
          ;;
       7) arg1="oradata_${SID}_app-${pkg}-MNT"
          arg2="vg00_${pkg}-VG"
          echo -e "Creo LINK TRA ${arg1}--->${arg2}" | tee -a $LOGFILE
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
