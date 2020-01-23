#!/bin/bash
#================================================================
# AUTHOR        Angel Garcia-Galan (angelgs@gmail.com)
# COPYRIGHT     Cabildo de Tenerife (http://www.tenerife.es)
# LICENSE       European Union Public Licence (EUPL) (https://joinup.ec.europa.eu/collection/eupl/)
# SOURCE        https://github.com/agarsab/postgres
#
# FUNCTION      Makes a full backup (dump) of all PostgreSQL databases
# NOTES         The script has to be run with postgres user/owner
#               Tested in PostgreSQL 9.6 over CentOS 7.4
#
# ARGUMENTS     $1 = Path to store dump and log files
#               $2 = Number of days to preserve dumps

function print_log {
        NOW=`date '+%Y-%m-%d %H:%M:%S'`
        echo $NOW" "$1" "$2
}

EXIT_OK=0
EXIT_ERROR=1
TODAY=`date '+%Y-%m-%d'`

if [ "$1" == "" ] || [ "$2" == "" ]; then
        print_log "ERROR: missing arguments."
        print_log "INFO: usage: "$0" </path/to/dumps> <days>"
        exit $EXIT_ERROR
fi

BACKUP_HOME=$1
BACKUP_DAYS=$2
BACKUP_DBS=`psql -lt | grep -v : | cut -d \| -f 1 | grep -v template | grep -v -e '^\s*$' | sed -e 's/  *$//'|  tr '\n' ' '`
BACKUP_LOG=$BACKUP_HOME"/"$TODAY"_"`hostname`".log"
BACKUP_CMD="/bin/pg_dump"

if [[ ! $BACKUP_DAYS =~ ^[0-9]+$ ]] || [[ ! $BACKUP_DAYS -gt 1 ]]; then
        print_log "ERROR: number of days:" $BACKUP_DAYS
        exit $EXIT_ERROR
fi

if [ ! $PGDATA ]; then
        print_log "ERROR: PGDATA environment variable not set."
        exit $EXIT_ERROR
fi

if [ ! -d $PGDATA ]; then
        print_log "ERROR: data path not found:" $PGDATA
        exit $EXIT_ERROR
fi

if [ ! -w $BACKUP_HOME ]; then
        print_log "ERROR: backup path not writable:" $BACKUP_HOME
        exit $EXIT_ERROR
fi

if [ ! -f $BACKUP_CMD ]; then
        print_log "ERROR: backup command not found:" $BACKUP_CMD
        exit $EXIT_ERROR
fi

if [ -z "$BACKUP_DBS" ]; then
        print_log "ERROR: empty database list"
        exit $EXIT_ERROR
fi

BACKUP_DB="globals"
BACKUP_SQL=$BACKUP_HOME"/"$TODAY"_"`hostname`"_"$BACKUP_DB".sql"
print_log "INFO: Starting backup database" $BACKUP_DB >> $BACKUP_LOG
BACKUP_CMD="pg_dumpall --globals-only"
$BACKUP_CMD > $BACKUP_SQL 2>> $BACKUP_LOG
print_log "`ls -lh $BACKUP_SQL`" >> $BACKUP_LOG
BACKUP_RESULT=`tail -5 "$BACKUP_SQL" | grep 'database dump complete'`
if [ -z "BACKUP_RESULT" ]; then
        print_log "ERROR: Backup failed in database" $BACKUP_DB >> $BACKUP_LOG
else
        print_log "INFO: Completed backup database" $BACKUP_DB >> $BACKUP_LOG
fi
print_log "INFO: Compressing file "$BACKUP_DB"..." >> $BACKUP_LOG
nice gzip $BACKUP_SQL
print_log "`ls -lh $BACKUP_SQL.gz`" >> $BACKUP_LOG

for BACKUP_DB in $BACKUP_DBS; do
        BACKUP_SQL=$BACKUP_HOME"/"$TODAY"_"`hostname`"_"$BACKUP_DB".sql"
        print_log "INFO: Starting backup database" $BACKUP_DB >> $BACKUP_LOG
        BACKUP_CMD="pg_dump --format=p "$BACKUP_DB
        $BACKUP_CMD > $BACKUP_SQL 2>> $BACKUP_LOG
        print_log "`ls -lh $BACKUP_SQL`" >> $BACKUP_LOG
        BACKUP_RESULT=`tail -5 "$BACKUP_SQL" | grep 'database dump complete'`
        if [ -z "BACKUP_RESULT" ]; then
                print_log "ERROR: Backup failed in database" $BACKUP_DB >> $BACKUP_LOG
        else
                print_log "INFO: Completed backup database" $BACKUP_DB >> $BACKUP_LOG
        fi
        print_log "INFO: Compressing file "$BACKUP_DB"..." >> $BACKUP_LOG
        nice gzip $BACKUP_SQL
        print_log "`ls -lh $BACKUP_SQL.gz`" >> $BACKUP_LOG
done

print_log "INFO: Removing old dumps and logs..." >> $BACKUP_LOG
OLD_FILES=`find $BACKUP_HOME -iname '20*.sql.gz' -mtime +$BACKUP_DAYS`
for FILE in $OLD_FILES; do
        print_log "INFO: Removing file" $FILE >> $BACKUP_LOG
        rm $FILE
done
OLD_FILES=`find $BACKUP_HOME -iname '20*.log' -mtime +$BACKUP_DAYS`
for FILE in $OLD_FILES; do
        print_log "INFO: Removing file" $FILE >> $BACKUP_LOG
        rm $FILE
done

print_log "INFO: Finished." >> $BACKUP_LOG
exit $EXIT_OK
