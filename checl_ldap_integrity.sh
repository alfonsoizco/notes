#!/bin/bash

function do_randomisation {
    while read line; do
        echo "$RANDOM $line"
    done | sort -n | cut -d ' ' -f '2-'
}

SERVERS="master ldap1"
LDAPSEARCH="/usr/bin/ldapsearch"
PW="****"
NUMCHECKS=50
PORT=9009

# Sacar la lista de dominios a ficheros y todas las cuentas por dominio para el servidor master
for server in $SERVERS
do
    DOMAINS="/usr/easynet/var/$server/list_domains"
    ACCOUNTS="/usr/easynet/var/$server/accounts"
    REPORT="/usr/easynet/var/$server/report"

    rm $REPORT
    rm $DOMAINS
    rm -r $ACCOUNTS/*

    $LDAPSEARCH -w $PW -H "ldap://$server:$PORT/" -x -b "o=easynet.net" "(domain=*)" domain | grep "^domain:*" | sed 's/^domain: //' | sort > $DOMAINS
    echo "Lista dominios obtenida para servidor $server"
    echo "num_domains `cat  $DOMAINS | wc -l`" > $REPORT
    echo "Obteniendo cuentas por dominio... "
    for domain in `cat $DOMAINS`
    do
        if [ $domain = "easynet.es" ]
        then
            $LDAPSEARCH -w $PW -H "ldap://$server:$PORT/" -x -b "ou=users,domain=$domain,vip=easynet-es,o=easynet.net" "(&(uid=*$domain)(status=active))" uid | grep "^uid: " | sed 's/^uid: //' | sort > $ACCOUNTS/$domain
        elif [ $domain = "blah.es" ]
        then
            echo "Ignorando cuentas de blah.es"
        else 
            $LDAPSEARCH -w $PW -H "ldap://$server:$PORT/" -x -b "ou=users,domain=$domain,vip=easynet-es-virtuals,o=easynet.net" "(&(uid=*$domain)(status=active))" uid | grep "^uid: " | sed 's/^uid: //' | sort > $ACCOUNTS/$domain
        fi
        echo "$domain | `cat $ACCOUNTS/$domain | wc -l`" >> $REPORT
    done
done

# Hacer chequeos de integridad entre varias cuentas
for ((  i = 0 ;  i <= $NUMCHECKS;  i++  ))
do
    # extraner una cuenta alieatoria, hacer un ldapsearch a cada servidor y un diff
    randomain=`find /usr/easynet/var/master/accounts/ -type f  | do_randomisation | tail -n 1`
    while [ $(wc -l < $randomain) -eq 0 ]
    do
        randomain=`find /usr/easynet/var/master/accounts/ -type f  | do_randomisation | tail -n 1`
    done
    
    ranaccount=`cat $randomain | do_randomisation | tail -n 1` 
    for server in $SERVERS
    do
        TMPFILE="/usr/easynet/var/$server/temfile"
        $LDAPSEARCH -w $PW -H "ldap://$server:$PORT/" -x -b "o=easynet.net" "(uid=$ranaccount)" | sort > $TMPFILE
    done
    
    echo "Diferencias entre master y ldap1 para la cuenta $ranaccount"
    diff /usr/easynet/var/master/temfile /usr/easynet/var/ldap1/temfile
done;

echo "Diferencia de dominios entre master y ldap1:"
diff /usr/easynet/var/master/list_domains /usr/easynet/var/ldap1/list_domains

echo "Si todo ha ido bien para slapd en master y arrancalo normal:"
echo "/etc/init.d/slapd start"
echo "Despues cambia la ruta estatica al nuevo servidor y haz las pruebas de herramientas."
echo "Suerte!"
