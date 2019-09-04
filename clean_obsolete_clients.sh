#!/usr/bin/bash
PATH_VHOST="/mnt/nfs/share/"
PATH_BACKUP="/mnt/nfs/share/backup/"
MX_NM_EASYNET="mail.easynet.es."
MX_IP_EASYNET="62.93.189.74 62.93.189.75"
MXBCK_NM_EASYNET="mx1.es.easynet.net. mx2.es.easynet.net."
LDAP_SERVER="master"
LDAP_SEARCH="/usr/bin/ldapsearch"
LDAP_MODIFY="/usr/bin/ldapmodify"
TS=`date "+%Y-%m-%d_%H-%M"`
LDAP_MODIFY_DOMAINS="/opt/easynet/var/ldap_modify_domains-$TS.ldif"
LDAP_MODIFY_ACCOUNTS="/opt/easynet/var/ldap_modify_accounts-$TS.ldif"
LDAP_MODIFY_ACCOUNTS_PARSED="/opt/easynet/var/ldap_modify_accounts_parsed-$TS.ldif"
LDAP_PW="********"
LDAP_BASE="o=easynet.net"
LDAP_BINDDN="cn=systems,ou=accounts,company=Easynet ES,o=easynet.net"
COUNTER=0
COUNTER_REMOVED=0
LOG="/opt/easynet/var/clean_mail-$TS.log"

_getIP()
{
    /usr/sbin/dig +short @dnsnsa $1 | /usr/bin/sed -n '$p'
}

_evalMAINMX()
{
    in_name=$(echo $1 | /usr/bin/tr -d '[[:space:]]')
    if [ $MX_NM_EASYNET = $in_name ]
    then
        echo "true";
    else
        echo "false";
    fi
}

_evalBCKMX()
{
    _result="false";
    for EASYNET_MX in $MXBCK_NM_EASYNET
    do
        if [ $EASYNET_MX = $in_name ]
        then
            _result="true";
        fi
    done
    echo $_result;
}

_evalIP()
{
    in_ip=$(echo $1 | /usr/bin/tr -d '[[:space:]]')
    _result="false";
    for ip in $MX_IP_EASYNET
    do
        if [ $ip = $in_ip ] 
        then
            _result="true"; 
        fi
    done
    echo $_result;
}

_getLDAP()
{
    $LDAP_SEARCH -w $LDAP_PW -h $LDAP_SERVER -b "$LDAP_BASE" -D "$LDAP_BINDDN" -L "(&(status=active)(domain=$1)(mailRelayType=primary))" domain | /usr/xpg4/bin/grep -q "domain: "
    if [ $? -eq 0 ] 
    then
       echo "true";
    else 
       echo "false";
    fi
}

_deactivateLDAPDOM()
{
     $LDAP_SEARCH -w $LDAP_PW -h $LDAP_SERVER -b "$LDAP_BASE" -D "$LDAP_BINDDN" -L "domain=$1" dn | /usr/bin/grep dn >> $LDAP_MODIFY_DOMAINS
     cat >> $LDAP_MODIFY_DOMAINS <<EOF
changetype: modify
replace: status
status: inactive

EOF
}

_deactivateLDAPACCOUNTS()
{
    $LDAP_SEARCH -w $LDAP_PW -h $LDAP_SERVER -D "$LDAP_BINDDN" -b "ou=users,domain=$1,vip=easynet-es-virtuals,o=easynet.net" -L "(&(uid=*$1)(status=active))" dn >> $LDAP_MODIFY_ACCOUNTS
     cat >> $LDAP_MODIFY_ACCOUNTS <<EOF

EOF
}

_parseLDAPACCOUNTS()
{
    /usr/bin/sed "s/^version: 1//" $LDAP_MODIFY_ACCOUNTS | /usr/bin/uniq | /usr/bin/sed -e "1d" | /usr/bin/sed "s/^$/changetype: modify\\
replace: status \\
status: inactive \\
/" > $LDAP_MODIFY_ACCOUNTS_PARSED
}

_removeMailDir()
{
    mv $1 $PATH_BACKUP$2.bak
    /usr/sbin/tar cvf $PATH_BACKUP$2.bak.tar $PATH_BACKUP$2.bak
    /usr/bin/gzip -q --fast $PATH_BACKUP$2.bak.tar
    rm -r $PATH_BACKUP$2.bak
}

# Start date
echo $TS

# Clean old files
if [ -f $LDAP_MODIFY_DOMAINS ]
then
    rm $LDAP_MODIFY_DOMAINS
fi
if [ -f $LDAP_MODIFY_ACCOUNTS ]
then
    rm $LDAP_MODIFY_ACCOUNTS
fi
if [ -f $LDAP_MODIFY_ACCOUNTS_PARSED ]
then
    rm $LDAP_MODIFY_ACCOUNTS_PARSED
fi 
/usr/bin/touch $LDAP_MODIFY_DOMAINS
/usr/bin/touch $LDAP_MODIFY_ACCOUNTS
/usr/bin/touch $LDAP_MODIFY_ACCOUNTS_PARSED

for client_dir in $(ls -d $PATH_VHOST*)
do
    COUNTER=`/usr/bin/expr $COUNTER + 1`
    domain=$(echo $client_dir | cut -d"/" -f5);
    # ignore backup dir
    if [ $domain = "backup" ]
    then
        echo "IGNORED $domain"
        continue 1
    fi

    if [ $domain = "coit.es" ]
    then
        echo "IGNORED $domain"
        continue 1
    fi

    i=1
    for mx_register in $(/usr/sbin/dig +short @dnsnsa $domain mx | /usr/bin/sort -n -k 1 | cut -d" " -f2)
    do
        clean_name=$(echo $mx_register | /usr/bin/sed "s/\.$//")
        # if is main mx register
        if [ $i -eq 1 ]
        then
            result=$(_evalMAINMX $mx_register)
            if [ $result = "false" ]
            then
               ip_register=$(_getIP $mx_register)
               ip_result=$(_evalIP $ip_register)
               if [ $ip_result = "true" ]
               then
                   ldap_result=$(_getLDAP $domain)
                   if [ $ldap_result = "false" ]
                   then
                      echo "DNS incorrecto. Apunta a nosotros pero esta inactivo en ldap: $domain"
                   fi
               else 
                   ldap_result=$(_getLDAP $domain)
                   if [ $ldap_result = "true" ]
                   then
                       # ignore new directories (newer than 1 month)
                       if [ `PATH_MAX=1 find $client_dir -type d -name $domain -ctime -30 | wc -l` -eq 0 ]
                       then
                           echo "$domain $ip_register LDAP active REMOVING... "
                           _deactivateLDAPDOM $domain
                           _deactivateLDAPACCOUNTS $domain
                           _removeMailDir $client_dir $domain
                           COUNTER_REMOVED=`/usr/bin/expr $COUNTER_REMOVED + 1`
                       fi
                   else
                       echo "$domain $ip_register LDAP inactive REMOVING... "
                       _removeMailDir $client_dir $domain
                   fi
               fi
            fi
        fi
        # end if is main mx register
        i=`/usr/bin/expr $i + 1`
    done
done

_parseLDAPACCOUNTS
# ldapmodify -h "master" -D "cn=systems,ou=accounts,company=Easynet ES,o=easynet.net" -f /opt/easynet/var/ldap_modify_accounts_raw.ldif -wcr1ms0n
$LDAP_MODIFY -h $LDAP_SERVER -D "$LDAP_BINDDN" -f $LDAP_MODIFY_DOMAINS -w$LDAP_PW 
$LDAP_MODIFY -h $LDAP_SERVER -D "$LDAP_BINDDN" -f $LDAP_MODIFY_ACCOUNTS_PARSED -w$LDAP_PW

echo "Dominios chequeados: $COUNTER"
echo "Dominios eliminados: $COUNTER_REMOVED"
