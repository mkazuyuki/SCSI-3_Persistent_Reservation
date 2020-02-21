#!/usr/bin/bash

while [ 1 ];do
	date > /mnt/a
	sync
	cat /mnt/a
	sleep 1
done
