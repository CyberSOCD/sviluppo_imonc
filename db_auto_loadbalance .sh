#!/bin/bash
# Version:3.01                                    #
# Author : albert trebla alias LC                 #
#                                                 #
###################################################



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
xcls=$1
if [[ -n $xcls ]]; then
   cls=`echo $xcls | tr [A-Z] [a-z]`
   host $cls
   if [[ $? == 1 ]]; then
      echo -e "${ERR} IL CLUSTER $cls  NON E'RISOLVIBILE SUL DNS ${Z}"
      exit 1
   fi
   nodo=$(ssh $cls 'hostname')
   VARS=$(cerca_nodo $nodo)
#   echo "VAR=$VARS" >/dev/tty
   nod_sca=$(echo "$VARS" | cut -f1 -d" ")
   npkg=$(echo "$VARS" | cut -f2 -d" ")

   echo -e "$nod_sca ${Z} ${IY}con${Z} ${CM} $npkg ${Z} ${IY}pacchetti ONLINE.\n\
fi
}


 ####### MAIN #########

flagp=""
arg=$1
chiedi_cls $arg
