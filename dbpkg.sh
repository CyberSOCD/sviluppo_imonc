flagp=""
chiedi_cls
msg="ATTENZIONE: prima del lancio. nod_sca=$nod_sca"
#         countdown 3
ssh -t $nod_sca "$(</opt/gest/SCRIPT_CREA_SG/FINALE/crea_PKG)"

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
