## Appendix

### 防御ノード (現用系) が実行する SCSI PR の論理デザイン
```
defender　{
	register reservation key
	clear key and reservation
	while(1) {
		register reservation key
		reserve
		if (I do not have the reservation) {
			exit	# become atacker
		}
		sleep 3
	}
}
```

### 攻撃ノード (待機系) が実行する SCSI PR の論理デザイン
```
atacker {
	register reservation key
	while (1) {
		clear key and reservation
		sleep 7
		register reservation key
		reserve
		if (I have the reservation) {
			sleep 10 (wait for stop of defender)
			exit	#become defender
		}
	}
}
```

### SCSI-3 Persist Reservation Command on Linux

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

In my case, active node got impossible to read/write when standby node used 3 (exclusive access) as argument of *type* for *PROUT* command.  
PROUT コマンドの type 引数に 3 (exclusive access) を用いると、待機系の reserve 成功が 現用系に read/write 不能をもたらした。

参照:  
https://support.microsoft.com/ja-jp/help/309186/how-the-cluster-service-reserves-a-disk-and-brings-a-disk-online

### for Windows
To obtaion sg_persist for Windows, refer to [README.win32](https://github.com/hreinecke/sg3_utils/blob/master/README.win32) in sg3_utils repository. Once sg_persist is obtained, the same idea and the same way for Linux can be applied for Windows.
