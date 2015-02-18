#!/bin/bash

DBLIST=""
DS1_BACKUP_DIR=/lfs/datastage/1/MySQLBackup/AllCourseraNovoEdMoocDb_Feb17_2015

DS_BACKUP_DIR=$DS1_BACKUP_DIR

USAGE='Usage: '`basename $0`' [-u localMySQLUser][-p][-pLocalMySQLPwd] backupDirPath'

if [[ $# < 1  || $1 == "-h" || $1 == "--help" ]]
then
    echo "Back up all user-level databases to given backup directory."
    echo  $USAGE
    exit
fi

# If option -p is provided, script will request password for
# local MySQL db.

MYSQL_PWD=''
USERNAME=`whoami`

LOG_FILE=`mktemp /tmp/courseraNovoEdMoocDbBackup.XXXXXXXXXX` || exit 1
theDate=$(date | sed -n -e 's/[ :]/_/gp')
TAR_FILE="${DS_BACKUP_DIR}/backup_${theDate}.tar.gz"

needLocalPasswd=false
# Get directory in which this script is running,
# and where its support scripts therefore live:
currScriptsDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ ! -f $LOG_FILE ]
then
    # Create directories to log file as needed:
    DIR_PART_LOG_FILE=`dirname $LOG_FILE`
    mkdir --parents $DIR_PART_LOG_FILE
    touch $LOG_FILE
fi

echo "Logging to $LOG_FILE"

# ------------------ Process Commandline Options -------------------

# Check whether given -pPassword, i.e. fused -p with a 
# pwd string:

for arg in $@
do
   # The sed -r option enables extended regex, which
   # makes the '+' metachar wor. The -n option
   # says to print only if pattern matches:
   MYSQL_PWD=`echo $arg | sed -r -n 's/-p(.+)/\1/p'`
   if [ -z $MYSQL_PWD ]
   then
       continue
   else
       #echo "MYSQL_PWD is:"$MYSQL_PWD
       break
   fi
done

# Now check for '-p' and '-r' without explicit pwd;
# the leading colon in options causes wrong options
# to drop into \? branch:
NEXT_ARG=0

while getopts ":pu:" opt
do
  case $opt in
    p)
      needLocalPasswd=true
      NEXT_ARG=$((NEXT_ARG + 1))
      ;;
    u)
      USERNAME=$OPTARG
      NEXT_ARG=$((NEXT_ARG + 2))
      ;;
    \?)
      # If $MYSQL_PWD is set, we *assume* that 
      # the unrecognized option was a
      # -pMyPassword and don't signal
      # an error. Therefore, if $MYSQL_PWD is set
      # and *then* an illegal option
      # is on the command line, it is quietly
      # ignored:
      if [ ! -z $MYSQL_PWD ]
      then 
	  continue
      else
	  echo $USAGE
	  exit 1
      fi
      ;;
  esac
done

# Shift past all the optional parms:
shift ${NEXT_ARG}

# ------------------ Ask for Passwords if Requested on CL -------------------

# Ask for local pwd, unless was given
# a fused -pLocalPWD:
if $needLocalPasswd && [ -z $MYSQL_PWD ]
then
    # The -s option suppresses echo:
    read -s -p "Password for "$USERNAME" on local MySQL server: " MYSQL_PWD
    echo
elif [ -z $MYSQL_PWD ]
then
    # Get home directory of whichever user will
    # log into MySQL, except for root:

    if [[ $USERNAME == 'root' ]]
    then
        HOME_DIR=$(getent passwd `whoami` | cut -d: -f6)
        if test -f $HOME_DIR/.ssh/mysql_root && test -r $HOME_DIR/.ssh/mysql_root
        then
                MYSQL_PWD=`cat $HOME_DIR/.ssh/mysql_root`
        fi
    else
        HOME_DIR=$(getent passwd $USERNAME | cut -d: -f6)
        # If the home dir has a readable file called mysql in its .ssh
        # subdir, then pull the pwd from there:
        if test -f $HOME_DIR/.ssh/mysql && test -r $HOME_DIR/.ssh/mysql
        then
                MYSQL_PWD=`cat $HOME_DIR/.ssh/mysql`
        fi
    fi
fi

#**********
#echo 'Local MySQL uid: '$USERNAME
#echo 'Local MySQL pwd: '$MYSQL_PWD
#exit 0
#**********

# ------------------ Signin -------------------
echo `date`": Start backing up ..."  | tee --append $LOG_FILE

mysql -s -r -p${MYSQL_PWD} --user=${USERNAME} -e 'show databases' |
   while read db
   do 
      echo `date`": Backing up $db..." |  tee --append $LOG_FILE
      mysqldump -p${MYSQL_PWD} --user=${USERNAME} $db > ${DS_BACKUP_DIR}/${db}.sql
      echo `date`": Done backing up $db..." | tee --append $LOG_FILE
      DBLIST="$DBLIST $DB"
   done;
   echo `date`": tar all sql files..." |  tee --append $LOG_FILE
   tar -czf $TAR_FILE "$DBLIST"
   echo `date`": done tarring all sql files..." |  tee --append $LOG_FILE

echo `date`": Done backup." | tee --append $LOG_FILE
