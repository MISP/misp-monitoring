#!/bin/bash
# livestats.sh
# 2021-02-19 Sascha Rommelfangen
#
#

# Default values, can be overwritten with command line parameters
# LOGFILE: this should be set to avoid to enter it on command line
LOGFILE=""

# LOGSCOPE: if log file contains several MISP backend hostnames
LOGSCOPE=""

# INTERVAL: refresh interval in seconds
INTERVAL=2

# LOGLINES: number of log lines to display
LOGLINES=10

# LOGLIMIT: any string that limits the result. Typically 'GET /events/' or 'POST /events/restSearch'
# This array can be extended.
LOGLIMITS[0]="GET /events/"
LOGLIMITS[1]="POST /events/restSearch"

# Defaul LOGLIMIT
LOGLIMIT=${LOGLIMITS[0]}

declare -A old
declare -A new
declare -A total

# Hide Ctrl-C
stty -echoctl

# trap Ctrl-C and show menu
trap show_menu INT

ORDER="-r"
SORT_IP="-n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4"
SORT_LINES="-n -k 3"
SORT_DELTA="-n -k 4"
SORT_REQ="-n -k 5"
SORT_TOTAL="-n -k 6"
SORT="$SORT_REQ"

function reset() {
# This doesn't work yet as expected.
#  unset old
#  unset new
#  unset total
#  declare -A old
#  declare -A new
#  declare -A total
 echo ""
}

function show_menu() {
  echo -e "\n 	        q - quit"
  echo "	        i - edit interval"
  echo " 	        r - reset values"
  echo "	        s - sort"
  echo "	        l - edit loglimit"
  echo "	        o - toggle order"
  echo "   	        any other key to resume"
  read -p "Command: " -n1 char

  case $char in
    q)	echo -e "\n\nThank you for flying MISP" && rm "$OLDFILE" && rm "$NEWFILE" && exit 0
    ;;
    i)  echo -e "\n"
        read -p "Seconds: " -n1 seconds
        INTERVAL=$seconds
	sleep 1
    ;;
    r)  reset
    ;;
    s)  echo -e "\n"
	echo "	          i - IP"
	echo "	          t - Total lines"
	echo "	          r - req/s"
	echo "	          l - increase"
	read -p "Sort by: " -n1 sort
	case $sort in
	  i) SORT="$SORT_IP"
	  ;;
	  t) SORT="$SORT_LINES"
	  ;;
	  r) SORT="$SORT_REQ"
	  ;;
	  l) SORT="$SORT_TOTAL"
	  ;;
	esac
    ;;
    l)  i=0
        echo -e "\n"
	for opt in "${LOGLIMITS[@]}"
	do
	  echo -e "[$i] $opt"
	  i=$((i+1))
        done
	read -p "Selection: " -n1 limit
	case $limit in
	  [0-9])  if [ -v LOGLIMITS[$limit] ]
	          then
		    LOGLIMIT=${LOGLIMITS[$limit]}
                    reset
		  fi
	  ;;
	esac
    ;;
    o)  if [[ $ORDER == "-r" ]]; then ORDER=""; else ORDER="-r" ; fi
    ;;
  esac

}


POSITIONAL=()
while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -f|--logfile)
      LOGFILE="$2"
      shift # past argument
      shift # past value
    ;;
    -s|--scope)
      LOGSCOPE="$2"
      shift # past argument
      shift # past value
    ;;
    -l|--limit)
      LOGLIMIT="$2"
      shift # past argument
      shift # past value
    ;;
    -n|--lines)
      LOGLINES="$2"
      shift # past argument
      shift # past value
    ;;
    -i|--interval)
      INTERVAL="$2"
      shift # past argument
      shift # past value
    ;;
    -h|--help)
      echo "Usage: $0 [ -f | --logfile <filename> ] [ -s | --scope <scope> ] [ -l | --limit <searchterm> ] [ -n | --lines <number> ] [ -i | --interval <seconds> ]"
      exit 0
    ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
    ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ -z $LOGFILE ]
then
  echo "LOGFILE must be specified. Aborting."
  exit 1
else
  if [ ! -r $LOGFILE ]
  then
    echo "Logfile $LOGFILE is not readable. Aborting."
    exit 2
  fi
fi


# Fixing position of IP address when file with scope give
if [[ $LOGSCOPE == "" ]]
then
  POS_IP=1
else
  POS_IP=2
fi


# Setting up temp files
OLDFILE=$(mktemp /tmp/live.old.XXXXXX)
exec 3>"$OLDFILE"
rm "$OLDFILE"
NEWFILE=$(mktemp /tmp/live.new.XXXXXX)
exec 3>"$NEWFILE"
rm "$NEWFILE"


echo "Collecting data... please wait"
while true
do
  cat "$LOGFILE" | grep "$LOGSCOPE" | grep "$LOGLIMIT" | cut -d " " -f $POS_IP | sort | uniq -c | sort | tail -$LOGLINES > $OLDFILE
  while read entry
  do
    count=`echo ${entry} | cut -d " " -f 1`
    ip=`echo ${entry} | cut -d " " -f 2`
    old["${ip}"]="$count"
  done < ${OLDFILE}
  sleep $INTERVAL
  cat "$LOGFILE"| grep "$LOGSCOPE" | grep "$LOGLIMIT" | cut -d " " -f $POS_IP | sort | uniq -c | sort | tail -$LOGLINES > $NEWFILE
  while read entry
  do
    count=`echo ${entry} | cut -d " " -f 1`
    ip=`echo ${entry} | cut -d " " -f 2`
    new["${ip}"]="$count"
  done < ${NEWFILE}

  clear
  echo -e "IP Address\tlines (t-${INTERVAL}s)\tlines (t=now)\tdelta\treq/s\ttotal increase"| expand -t 38,54,72,79,87
  echo "------------------------------------------------------------------------------------------------------------"
  buffer=""
  for ip in "${!old[@]}"
  do
    count_old=${old[$ip]}
    count_new=${new[$ip]}
    count_delta=$(($count_new-$count_old))
    total[$ip]=$((${total[$ip]}+$count_delta))
    ratio=`echo "scale=2;${count_delta} / $INTERVAL" | bc|sed 's/^\./0./'`
    if [[ $count_delta -ge 0 ]]
    then
      buffer+="$ip\t $count_old\t $count_new\t $count_delta\t $ratio\t ${total[$ip]}\n"
    fi
  done
  echo -e $buffer | awk NF | sort $SORT $ORDER| expand -t 41,57,72,79,90
  echo -e "\nLogfile:\t$LOGFILE"
  if [ $LOGSCOPE ]
  then
    echo -e "Scope:\t\t$LOGSCOPE"
  else
    echo -e "Scope:\t\t(none)"
  fi
  echo -e "Search:\t\t$LOGLIMIT"
  echo -e "\n(refreshing in $INTERVAL seconds - Ctrl-C for pause and options)"
done
