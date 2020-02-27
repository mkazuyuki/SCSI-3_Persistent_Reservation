#!/usr/bin/bash

##
## Defender
##

key=abc001
dev=/dev/sdc
dev=/dev/disk/by-id/wwn-0x6001405cc0bdfcebdb045cbb3130ad33
interval=3	#sec

function clear () {
	sg_persist -o -C -K $key -d $dev > /dev/null
	ret=$?
	if [ $ret -eq 0 ]; then
		echo `date -I'seconds'` [I] [$ret] Clear succeeded
	else
		echo `date -I'seconds'` [E] [$ret] Clear failed
	fi
}

function register () {
	sg_persist -o -G -S $key -d $dev > /dev/null 2>&1
	#sg_persist -o -G -S $key -d $dev > /dev/null
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
		echo `date -I'seconds'` [I] [$ret] Reserve succeeded.
	else
		echo `date -I'seconds'` [E] [$ret] Reserve failed. Will become ATACKER
		exit 0 # Become atacker
	fi
}

register
while [ 1 ]; do
	echo `date -I'seconds'` [D] ----
	clear
	register
	reserve
	sg_persist -r $dev | grep -A 1 $key | grep  'Exclusive Access' > /dev/null
	ret=$?
	if [ $ret -eq 0 ]; then
		echo `date -I'seconds'` [I] [$ret] Reserve found.
	else
		echo `date -I'seconds'` [E] [$ret] Reserve not found.
	fi
	sleep $interval
done
