#!/bin/bash
# sourceforge initial sync script to make it faster

if [[ -z "$1" || -z "$2" ]]; then
	exit 1
fi
numprocs=$1
listfile=$2

HOME="/home/boj"
LOCKDIR="$HOME/lock"
LOGDIR="$HOME/log/sourceforge"

FIFO="$LOCKDIR/sourceforge.fifo"
if [ -e $FIFO ]; then
	echo "$FIFO already exists"
	exit 1
fi

mkfifo $FIFO
cat $listfile > $FIFO &

## run $numproc instances
for i in `seq 1 $numprocs`; do
(
	echo "thread $i begin"
	while true; do
		## should lock file to prevent race conditions
		LOCK="$LOCKDIR/sourceforge.lock"
		lockfile -r-1 $LOCK
		read d
		rm -f $LOCK

		## finished? 
		if [ -z "$d" ]; then
			echo "thread $i finished"
			exit 0
		fi

		## bind local IP for different routes
		if [ $(($RANDOM % 2)) -eq 1 ]; then
			address=10.8.140.2
		else
			address=10.8.10.2
		fi

		## if log directory not exist, create it
		LOGFILE="$LOGDIR/$d.log"
		if [ ! -f `dirname $LOGFILE` ]; then
			mkdir -p `dirname $LOGFILE`
		fi

		command="rsync -aP --address=$address mirrorservice.org::downloads.sourceforge.net/$d/ /srv/array/exports/sourceforge/$d/ >$LOGFILE 2>&1"
		echo $command
		eval $command
	done
) <$FIFO >$LOGDIR/dispatcher.log &

done ## end threads loop

wait
rm -f $FIFO

