#!/bin/bash
NOW=`date`
/usr/bin/wget -t 10 -w 3 -S -O -T 15 - http://url/ &>/dev/null
if [ $? -ne 0 ] 
then
   echo $NOW
   /etc/init.d/apache stop
   sleep 5
   /etc/init.d/apache start
fi
