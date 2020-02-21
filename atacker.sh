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
                exit 1
        else
                echo `date -I'seconds'` [D] [$ret] Reserve fail
        fi
}

while [ 1 ]; do

        echo '####'
        register

        # Clear
        sg_persist -o -C -K $key -d $dev
        ret=$?
        if [ $ret -eq 0 ]; then
                echo `date -I'seconds'` [I] Clear reservation and registration.
        else
                echo `date -I'seconds'` [E] Clear reservation and registration failed. [$ret]
                exit 1
        fi


        sleep $interval

        register
        reserve
done
