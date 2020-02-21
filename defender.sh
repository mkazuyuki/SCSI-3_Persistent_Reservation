#!/usr/bin/bash

##
## Defender
##

key=abc001
dev=/dev/sdc
interval=3	#sec

function register () {
	echo `date -I'seconds'` [D] [$?] Registering key.
        sg_persist -o -G -S $key -d $dev > /dev/null

	sg_persist -k $dev | grep $key > /dev/null
        ret=$?
        if [ $ret -ne 0 ] && [ $ret -ne 2 ]; then
                echo `date -I'seconds'` [E] [$ret] Register key failed.
                exit 1
        else
                echo `date -I'seconds'` [D] [$ret] Registered key.
        fi
}

function reserve () {
	sg_persist -o -R -K $key -T 3 -d $dev
	ret=$?
	if [ $ret -eq 0 ]; then
		echo `date -I'seconds'` [D] [$ret] Reserve success.
	else
		echo `date -I'seconds'` [E] [$ret] Reserve fail
		exit 1 # Become atacker
	fi
}

echo `date -I'seconds'` [I] Register key and Clear reservation and registration.
sg_persist -o -G -S $key -d $dev
sg_persist -o -C -K $key -d $dev

while [ 1 ]; do

	echo '####'
	sg_persist -k $dev | grep $key > /dev/null
	if [ $? -eq 0 ]; then
		echo `date -I'seconds'` [I] Key registration exists.
		sg_persist -r $dev | grep 'Exclusive Access' > /dev/null
		ret=$?
		if [ $ret -eq 0 ]; then
			echo `date -I'seconds'` [D] Reserve exists.
		else
			echo `date -I'seconds'` [D] [$ret] Reserve not found.
			reserve
		fi
	else
		echo `date -I'seconds'` [I] key registration NOT exists.
		register
		reserve
	fi
	sleep $interval
done

