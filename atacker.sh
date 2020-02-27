#!/usr/bin/bash

##
## Atacker
##

key=abc002
dev=/dev/disk/by-id/wwn-0x6001405cc0bdfcebdb045cbb3130ad33
interval=7	#sec

function clear () {
        sg_persist -o -C -K $key -d $dev > /dev/null
        ret=$?
        if [ $ret -eq 0 ]; then
                echo `date -I'seconds'` [I] [$ret] Clear reservation and registration succeeded
        else
                echo `date -I'seconds'` [E] [$ret] Clear reservation and registration failed
        fi
}

function register () {
        #sg_persist -o -G -S $key -d $dev > /dev/null 2>&1
        sg_persist -o -G -S $key -d $dev > /dev/null
        ret=$?
        if [ $ret -eq 0 ] || [ $ret -eq 2 ]; then
                echo `date -I'seconds'` [I] [$ret] Register key succeeded
        else
                echo `date -I'seconds'` [E] [$ret] Register key failed
        fi
}

function reserve () {
        sg_persist -o -R -K $key -T 3 -d $dev > /dev/null
        ret=$?
        if [ $ret -eq 0 ]; then
                echo `date -I'seconds'` [I] [$ret] Reserve succeeded
        else
                echo `date -I'seconds'` [E] [$ret] Reserve failed
        fi
}

register
while [ 1 ]; do
	clear
	sleep $interval
	echo `date -I'seconds'` [D] ----
	register
	sg_persist -k $dev | grep $key > /dev/null
	if [ $? -ne 0 ]; then
		echo `date -I'seconds'` [E] [$ret] Registered Key not found
	else
		echo `date -I'seconds'` [I] [$ret] Registered Key found
	fi
	reserve
	sg_persist -r $dev | grep -A 1 $key | grep  'Exclusive Access' > /dev/null
	ret=$?
	if [ $ret -eq 0 ]; then
		echo `date -I'seconds'` [I] [$ret] Reserve found. Will become DEFENDER.
		# sleep 10
		exit 0 # Become defender
	else
		echo `date -I'seconds'` [D] [$ret] Reserve not found.
	fi
done
