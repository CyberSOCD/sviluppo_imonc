rescanLUN() {
  if [[ "${flaglun}" = "" ]]; then
     echo -e "${r}ESEGUO RESCAN SCSI BUS${z}" | tee -a $LOGFILE
     ferma
     for i in $(ls /sys/class/fc_host); do echo $i && echo "- - -" > /sys/class/scsi_host/$i/scan; done
#     rescan-scsi-bus.sh -s | tee -a $LOGFILE
     flaglun="1"
  fi
}



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
