#!/bin/bash

lock_file=/tmp/backup.lock
export RSYNC_PASSWORD=replaceme
name=`hostname -s`
target='nas' # Hostname or IP address of backup server

function log {
        date=`date`
        echo "${date}: $1" >> /var/log/backup.log
}

function forward_port {
        log 'Forwarding port...'
        ssh -N remote_backup@${target} -i /root/.ssh/remote_backup-id_rsa -L 8730:127.0.0.1:873 &
        ssh_pid=$!
        sleep 2
}

function check_port {
        log 'Checking port...'
        netcat -z 127.0.0.1 8730
        return $?
}

function start_sync {
        log 'Starting rsync...'

        rsync -S --delete -aAX /* rsync://${name}@localhost:8730/${name}/ --exclude={/home/kjohnson/Music/*,/dev/*,/proc/*,/sys/*,/tmp/*,/run/*,/mnt/*,/media/*,/lost+found,/var/log/journal}

        if [ $? == 0 ]; then
                log 'Backup successful...'
        else
                log 'Backup did not exit 0...'
        fi
}

function kill_ssh {
        log 'Killing the tunnel...'
        kill $ssh_pid
}

function check_lock {
        if [ -a $lock_file ]; then
                log 'Lock file exists.  Exiting...'
                exit
        fi
}

function create_lock {
        log 'Creating lock file...'
        touch $lock_file
}

function delete_lock {
        log 'Deleting lock file...'
        rm $lock_file
}

# Check if lock file exists, then create it
check_lock && create_lock

# Check if port is forwarded, else forward it
check_port || forward_port

# Check if port is forwarded, then sync the data
check_port && start_sync

# Kill the tunnel
if [ $ssh_pid ]; then
        kill_ssh
fi

# Delete the lock file
delete_lock

unset RSYNC_PASSWORD
