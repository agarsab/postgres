#!/bin/bash
#
# FUNCTION      Makes a full backup (dump) of all PostgreSQL databases
# NOTES         The script has to be run with postgres user/owner
#               Tested in PostgreSQL 9.6 over CentOS 7.4
# ARGUMENTS     $1 = Path to store dump and log files
#               $2 = Number of days to preserve dumps

function print_log {
        DATE_HOUR=`date '+%Y-%m-%d %H:%M'`
        echo $DATE_HOUR" "$1
}

EXIT_OK=0
EXIT_ERROR=1
DATE_HOUR=`date '+%Y-%m-%d_%H-%M'`

if [ "$1" == "" ] || [ "$2" == "" ]; then
        print_log "ERROR: missing arguments."
        print_log "INFO: usage: "$0" </path/to/dumps> <days>"
        exit $EXIT_ERROR
fi

BACKUP_HOME=$1
BACKUP_DAYS=$2
BACKUP_CMD="/bin/pg_dumpall"
BACKUP_DUMP=$BACKUP_HOME"/"$DATE_HOUR"_"`hostname`".dmp"
BACKUP_LOG=$BACKUP_HOME"/"$DATE_HOUR"_"`hostname`".log"

if [[ ! $BACKUP_DAYS =~ ^[0-9]+$ ]] || [[ ! $BACKUP_DAYS -gt 1 ]]; then
        print_log "ERROR: number of days: "$BACKUP_DAYS
        exit $EXIT_ERROR
fi

if [ ! $PGDATA ]; then
        print_log "ERROR: PGDATA environment variable not set."
        exit $EXIT_ERROR
fi

if [ ! -d $PGDATA ]; then
        print_log "ERROR: data path not found: "$PGDATA
        exit $EXIT_ERROR
fi

if [ ! -w $BACKUP_HOME ]; then
        print_log "ERROR: backup path not writable: "$BACKUP_HOME
        exit $EXIT_ERROR
fi

if [ ! -f $BACKUP_CMD ]; then
        print_log "ERROR: backup command not found: "$BACKUP_CMD
        exit $EXIT_ERROR
fi

print_log "INFO: Starting dump..." >> $BACKUP_LOG
$BACKUP_CMD > $BACKUP_DUMP
print_log "`ls -lh $BACKUP_DUMP`" >> $BACKUP_LOG
print_log "INFO: Dump finished." >> $BACKUP_LOG

print_log "INFO: Compressing dump..." >> $BACKUP_LOG
nice gzip $BACKUP_DUMP
print_log "`ls -lh $BACKUP_DUMP.gz`" >> $BACKUP_LOG
print_log "INFO: Compression finished." >> $BACKUP_LOG

print_log "INFO: Removing old dumps and logs..." >> $BACKUP_LOG
OLD_FILES=`find $BACKUP_HOME -iname '20*.dmp.gz' -mtime +$BACKUP_DAYS`
for FILE in $OLD_FILES; do
        print_log "INFO: Removing file "$FILE >> $BACKUP_LOG
        rm $FILE
done
OLD_FILES=`find $BACKUP_HOME -iname '20*.log' -mtime +$BACKUP_DAYS`
for FILE in $OLD_FILES; do
        print_log "INFO: Removing file "$FILE >> $BACKUP_LOG
        rm $FILE
done

print_log "INFO: Finished." >> $BACKUP_LOG
exit $EXIT_OK
