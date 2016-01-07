#! /bin/bash

# will.parsons@rackspace.co.uk

STRACE_ARGS="-s4096 -tt  -e trace=sendto,connect,write,open"

echo -ne  "\n You are in $PWD. Save traces here? [y/n] : "

read a
if [[ $a == "Y" || $a == "y" || $a = "yes" ]]; then
        echo "OK."
else
  echo -e "\n Recommend /home/rack/strace/ or something.\nmkdir and cd, then run this again.\n\n"
  exit 0
fi

echo -e "\nDetected PHP-FPM pools running:"
POOLS=$(ps aux | grep fpm | grep pool | awk '{print $13}' | sort | uniq)
echo "$POOLS"

MAINPOOL=$(ps aux | grep fpm | grep pool | awk '{print $13}' | sort | uniq -c | sort -rn  | head -1 | awk '{print $2}')
echo -e "\nPool '$MAINPOOL' has the most processes running right now. "


echo -ne  "\n Which pool do you want to trace? [default $MAINPOOL] : "
read TRACEPOOL
if [ -z "$TRACEPOOL" ]; then
   TRACEPOOL=$MAINPOOL
fi
echo "Will trace processes from pool: $TRACEPOOL ."

for pid in $( ps aux | grep fpm | grep "fpm: pool ${TRACEPOOL}$" | awk '{print $2}'); do 
    strace $STRACE_ARGS -o ./strace.$pid -p $pid &
done

echo -e "\n\nTraces running. - see $PWD/strace.<pid> . 

killall strace when done.



Analysis examples:

How many SELECT queries? : grep -c SELECT strace.1234
Show all SELECT queries  : cat strace.1234 | egrep -o 'SELECT.*\ =\ '
Show all PHP file opens  : cat strace.1234 | egrep -o 'open.*php'

Note: Tracing live processes may not show many PHP file opens if there's an Opcode Cache running. 
See also 'strace-single.sh' to trace a single run from the command line. 


!! Don't forget to delete them after analysis. !!"
