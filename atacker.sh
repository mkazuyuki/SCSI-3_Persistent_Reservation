#!/usr/bin/bash

##
## Atacker
##

key=abc002
dev=/dev/sdc
interval=7	#sec

function register () {
        echo `date -I'seconds'` [D] [$?] Registering key.
        sg_persist -o -G -S $key -d $dev > /dev/null

        sg_persist -k $dev | grep $key > /dev/null
        ret=$?
        if [ $ret -ne 0 ] && [ $ret -ne 2 ]; then
                echo `date -I'seconds'` [E] [$ret] Register key failed.
                ret=1
        else
                echo `date -I'seconds'` [D] [$ret] Registered key.
		ret=0
        fi
}

function reserve () {
        sg_persist -o -R -K $key -T 3 -d $dev
        ret=$?
        if [ $ret -eq 0 ]; then
                echo `date -I'seconds'` [D] [$ret] Reserve success.
                ret=0
        else
                echo `date -I'seconds'` [D] [$ret] Reserve fail
                ret=1
        fi
}

function clear () {
        sg_persist -o -C -K $key -d $dev > /dev/null
        ret=$?
        if [ $ret -eq 0 ]; then
                echo `date -I'seconds'` [D] Clear reservation and registration.
        else
                echo `date -I'seconds'` [E] [$ret] Clear reservation and registration failed.
                exit 1
        fi
}

# This registration is performed speculatively.
register
while [ 1 ]; do
        echo `date -I'seconds'` [D] ########
	clear
        sleep $interval

        register
	if [ $ret -eq 1 ]; then
		# Exit on fail of REGISTER
		exit 1;
	fi

        reserve
	if [ $ret -eq 0 ]; then
		## Exit on successful RESERVE
		# sleep 10
		## Become defender
		exit 0;
	fi
done
