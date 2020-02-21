# Exclusive control of shared-disk for HA cluster using SCSI-3 Persistent Reservation

# SCSI-3 Persistent Reservation を用いた HAクラスタ用 共有ディスク排他制御

ECX does not have the function for exclusive control of shared-disk by SCSI PR (SCSI-3 Persistent Reservation).
Therefore, the consistency of the data in the shared-disk is realized stochastically. In short, data may be lost.
This document introduces the "guarantee of no-data-loss on ECX" by SCSI PR.

----

## SCSI-3 Persist Reservation Command on Linux
Note: Linux sg3_utils packages are required.

To query all registrant keys for given device

	#sg_persist -i -k -d /dev/sdd

To query all reservations for given device

	#sg_persist -i -r -d /dev/sdd

To register the new *reservation key* 0x123abc

	#sg_persist -o -G -S 123abc -d /dev/sdd

To clear all registrants

	#sg_persist -o -C -K 123abc -d /dev/sdd

To reserve

	#sg_persist -o -R -K 123abc -T 5 -d /dev/sdd

To release

	#sg_persist -o -L -K 123abc -T 5 -d /dev/sdd

Common used reservation Types:  
5 - Write Exclusive, registrants only  
6 - Exclusive Access, registrants only 


This is copy of [this page][1]

[1]: http://aliuhui.blogspot.jp/2012/04/scsi-3-persist-reservation-command-on.html

----

## HAクラスタ用 共有ディスク排他制御

### 防御ノード (現用系) の処理
```
defender　{
	reservation key を登録する
	clear する
	while(1) {
		reservation key を登録する
		reserve する
		if (自身が reserve していない) {
			自殺 or atacker になる
		}
		sleep 3
	}
}
```

### 攻撃ノード (待機系) の処理
```
atacker {
	reservation key を登録する
	while (1) {
		clear する
		sleep 7
		reservation key を登録する
		reserve する
		if (自身が reserve している) {
			sleep 10 (wsfc はここで 10秒の間を空けている。理由不明ながら、相手に自殺猶予時間を与えているように思える。)
			defender になる
		}
	}
}
```

PROUT コマンドの type 引数に 3 (exclusive access) を用いると意図した挙動が得られた。つまり、待機系の reserve 成功が 現用系に read/write 不能をもたらした。

参照:  
https://support.microsoft.com/ja-jp/help/309186/how-the-cluster-service-reserves-a-disk-and-brings-a-disk-online
