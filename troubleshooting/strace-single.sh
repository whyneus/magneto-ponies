#! /bin/bash

# will.parsons@rackspace.co.uk

# To run directly:
# . <(curl -s https://raw.githubusercontent.com/whyneus/magneto-ponies/master/troubleshooting/strace-single.sh)


STRACE_ARGS="-s4096 -tt  -e trace=sendto,connect,write,open"

echo -ne  "\n You are in $PWD. Is this the DocumentRoot? [y/n] : "

read a
if [[ $a == "Y" || $a == "y" || $a = "yes" ]]; then
        echo "Good."
else
  echo -e "\n That would be a good start.\n"
  exit 0
fi

echo -ne  "\nEnter the HTTP_HOST (full domain name this site uses) : "
read HTTP_HOST
if [ -z "$HTTP_HOST" ]; then
   echo "Empty host will usually redirect immediately.
   curl -I localhost    might help\n\n:
   "
   curl -I localhost 2>/dev/null | egrep -i '30[12]|location'
   exit 0
   
fi
export HTTP_HOST=$HTTP_HOST

echo -ne  "\nEnter the REQUEST_URI (including the slash) : "
read REQUEST_URI

if [ -z "$REQUEST_URI" ]; then
   echo "Defaulting to homepage / "
   REQUEST_URI="/"
fi

export REQUEST_URI="$REQUEST_URI"


echo -ne  "\n Does this site require/redirect to HTTPS for $REQUEST_URI ?  [y/n] : "

read b
if [[ $b == "Y" || $b == "y" || $b = "yes" || $b = "on" || $b = "On" ]]; then
        export HTTPS=on
fi

echo -ne  "\nRemote Address (e.g. for geoIP purposes) [127.0.0.1] : "
read REMOTE_ADDR

if [ -z "$REMOTE_ADDR" ]; then
   echo "Defaulting to 127.0.0.1 "
   REMOTE_ADDR="127.0.0.1"
fi

export REMOTE_ADDR="$REMOTE_ADDR"



echo -ne  "\nStrace output file name (leave blank for default /home/rack/<date>.strace) : "
read STRACE_OUTPUT
if [ -z "$STRACE_OUTPUT" ]; then
   DATE=$(date +%Y%m%d%H%M%S)
   STRACE_OUTPUT=/home/rack/${DATE}.strace
   echo "Defaulting to $STRACE_OUTPUT "
fi


time strace $STRACE_ARGS -o $STRACE_OUTPUT php index.php

echo -e "\n\n Strace output saved to $STRACE_OUTPUT \n"

echo "

Analysis examples:

How many SELECT queries? : grep -c SELECT $STRACE_OUTPUT
Show all SELECT queries  : cat $STRACE_OUTPUT | egrep -o 'SELECT.*\ =\ '
Show all PHP file opens  : cat $STRACE_OUTPUT | egrep -o 'open.*php'
Repetative SELECT queries: cat $STRACE_OUTPUT | egrep -o 'SELECT.*\)\"\,' | sed 's/[1234567890]\+/N/g' | sort | uniq -c | sort -rn | head

Examples for Magento: 

- Show PHP file opens, excluding the usual Magento base classes.
- Use the timings to see which modules might be slow:
cat $STRACE_OUTPUT | egrep 'open.*php' | egrep -v 'app\/code\/core\/|Zend|Varien|lib64|etc/php|license'



- Show number of queries after each PHP file open, excluding base classes:
cat $STRACE_OUTPUT | egrep -o  'open.*php|SELECT' | egrep -v 'app\/code\/core\/|lib\/Magento\/|Zend|Varien|lib64|etc/php|license' | uniq -c

- ...boil down to those with >10 SELECTS, and what might be calling them:
cat $STRACE_OUTPUT | egrep -o  'open.*php|SELECT' | egrep -v 'app\/code\/core\/|lib\/Magento\/|Zend|Varien|lib64|etc/php|license' | uniq -c | egrep -B1 '[0-9][0-9] SELECT' 

- ...include templates, which is sometimes useful
cat $STRACE_OUTPUT | egrep -o  'open.*php|open.*phtml|SELECT' | egrep -v 'app\/code\/core\/|lib\/Magento\/|Zend|Varien|lib64|etc/php|license' | uniq -c | egrep -B2 '[0-9][0-9] SELECT' 
"

