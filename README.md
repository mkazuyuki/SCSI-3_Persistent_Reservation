# Exclusive control of shared-disk for HA cluster using SCSI-3 Persistent Reservation

# SCSI-3 Persistent Reservation を用いた HAクラスタ用 共有ディスク排他制御

EC does not provide the function for exclusive control of shared-disk by SCSI PR (SCSI-3 Persistent Reservation).
Therefore, the consistency of the data in the shared-disk is realized stochastically. In short, data may be lost.
This document introduces the "guarantee of no-data-loss on EC" by SCSI PR.

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
			sleep 10 (wsfc はここで 10秒の間を空けている。相手ノードに停止猶予時間を与えているように思える。)
			defender になる
		}
	}
}
```

PROUT コマンドの type 引数に 3 (exclusive access) を用いると意図した挙動が得られた。つまり、待機系の reserve 成功が 現用系に read/write 不能をもたらした。

参照:  
https://support.microsoft.com/ja-jp/help/309186/how-the-cluster-service-reserves-a-disk-and-brings-a-disk-online

----

## An Inconvenient Truth for EXPRESSCLUSTER

典型的な構成の 2ノード共有ディスク型クラスタ を用いて EC における NP解決 を説明する。

- 物理マシンとして PM-A, B を用いる
- 共有ディスクとして "SD" を用いる
- pingnp リソース (タイブレーカー) として ネットワークスイッチ "SW" のIPアドレスを用いる

## An Ideal Case

1. 各ノードは 定期的に HB (heartbeat) を (ethernet 経由で) 全ノードに送信する。
   FOG (faliover group) "G" は PM-A で稼動している。

   ```
	  [PM-A]G-----[SW]------[PM-B]
	      |                  |
	      +-------[SD]-------+
   ```

2. PM-A と スイッチ "SW" との間のネットワークが切断状態になる。
   つまり NP 状態 (両ノードがお互いに通信不能な状態) になる。

   ```
 	  [PM-A]G--x--[SW]------[PM-B]
	      |                  |
	      +-------[SD]-------+
   ```

3. PM-A (B) は PM-B (A) からの HB を受信しなくなり、設定時間経過後 HBTO (heartbeat timeout) を検知する。
4. **NP解決処理として** PM-A, PM-B は tie-breaker となる スイッチ SW (の IP address) に ping を投げ、「反応が有れば生残」し、「反応が無ければ自殺」する。この結果

   - PM-A は自殺する
   - PM-B は生残する

   ```
	     [x]---x--[SW]------[PM-B]
	      |                  |
	      +-------[SD]-------+
   ```

5. PM-B は failover を実行する (PM-B で FOG を起動させる)。

   ```
	     [x]---x--[SW]-----G[PM-B]
	      |                  |
	      +-------[SD]-------+
   ```

障害の発生が 一箇所 である限り、両ノードで FOG が起動状態となり、共有ディスクへ 同時/平行 書出しを行うような「システム・データ が一貫性を失う状況」は発生せず、また、FO により 業務も継続される。  


## An Inconvenient Case

「An Ideal Case」との異いは、サーバとして仮想マシン VM-A, B を用いることである。これもまた構成そのものは典型的と言える。

1. 各ノードは 定期的に HB (heartbeat) を (ethernet 経由で) 全ノードに送信する。
   FOG (faliover group) "G" は VM-A で稼動している。

   ```
	  [VM-A]G-----[SW]------[VM-B]
	      |                  |
	      +-------[SD]-------+
   ```

2. VM-A の動作が **遅延** する (HB送信、共有ディスクへの I/O が一時的停止する)。
3. VM-B は VM-A の HB を受信しなくなり、設定時間経過後 HBTO (heartbeat timeout) を検知する。
4. **NP解決処理として** VM-B は tie-breaker となる IP address (上図の [SW]) に ping を投げ、反応が有り 生残 を決断、failover を実行する (VM-B で FOG を起動させる)。

   ```
	  [VM-A]G-----[SW]-----G[VM-B]
	      |                  |
	      +-------[SD]-------+
   ```

5. VM-A の遅延が治まる (HB送信、共有ディスクへの I/O が再開する)。VM-B は再び VM-A の HB を受信するようになる。
6. 両ノードとも「自ノードで稼働中の FOG が 相手ノードでも稼動している」ことに気付き (業務継続よりデータ保護を優先するというお題目に従い) 自殺し、業務停止となる。

   ```
	     [x]------[SW]------[x]
	      |                  |
	      +-------[SD]-------+
   ```

4番で、両ノード共 FOG が起動状態となり、6番で自殺するまで、両ノードから共有ディスクへ write が 同時/並行 に行われる状況が発生してしまう。
両ノードから更新された共有ディスク上の領域 (ドライブ・パーティション等) は一貫性を失い、そこに保存されていたデータは「信頼できない状態」となる。(fsck 等で共有ディスク上の領域を検査すれば 要修正なファイルの発生 が判明するであろう)
この後、何れかのノードを起動し 共有ディスク上のファイルがエラー無く読み込めたとしても、読み込んだデータが化けている可能性は排除できない。

現実には、更新されてしまったのか否かを後から調査・検証することは困難で、fsck でファイルが復旧されたとしても そのファイルを用いて業務を再開できる保障は無い。
なので 殆どの場合、テープバックアップ等からのリストアによって安全な状態に戻すことになり、また、このリストアによって「バックアップが取得された以降に更新されたデータ」を失うことになる。

上記は 「典型的な構成でHAクラスタを使用しており、障害の発生が 一箇所 であるにも関わらず『業務継続』も『データ保護』も得られないケースの存在」、言い換えれば ECが **業務継続・データ保護 を確率的に行うこと** を示している。

物理マシンでこれが顕在化しにくいのは、「遅延が生じた PM-A は watchdog timer によって停止されるから」である。
仮想マシンで "noisy neighbour" 問題などで watchdog timer 諸共遅延する状況が起こるとき、ECはこれに対して脆弱である。


## 普通のフェイルオーバー型クラスタは如何に この不都合 を隠蔽するか

「An Incovenient Case」と同じ構成を用いる。

1. 各ノードは 定期的に HB (heartbeat) を (ethernet 経由で) 全ノードに送信する。
   FOG (faliover group) "G" は VM-A で稼動している。

   ```
	  [VM-A]G-----[SW]------[VM-B]
	      |                  |
	      +-------[SD]-------+
   ```

2. VM-A の動作が **遅延** する (HB送信、共有ディスクへの I/O が一時的停止する)。
3. VM-B は VM-A の HB を受信しなくなり、設定時間経過後 HBTO (heartbeat timeout) を検知する。
4. **NP解決処理として** VM-B は SCSI PR (SCSI-3 Persistent Reservation) を用いて、共有ディスクの排他的アクセスを獲得し、failover を実行する (VM-B で FOG を起動させる)。VM-A は共有ディスクへのアクセスを失う。

   ```
	  [VM-A]G-----[SW]-----G[VM-B]
	      |                  |
	      +-------[SD]-------+
   ```

5. VM-A の遅延が治まり、HB送信、共有ディスクへの I/O を再開するも、VM-A は共有ディスクへのアクセスを失っているため、I/O は失敗する。
6. VM-A は共有ディスクへのアクセス喪失を認識し、自殺する。

   ```
	     [x]------[SW]-----G[VM-B]
	      |                  |
	      +-------[SD]-------+
   ```

同様の障害が発生し、4番において 両ノードで FOG が起動状態となるが、SCSI PR により 共有ディスクへ 同時/平行 書出しは排除され、「システム・データ が一貫性を失う状況」は回避される。また、FO により 業務も継続される。


## EC で この不都合 を隠蔽する

- 自ノードで FOG が稼動したら、 Defender として SCSI PR を実行する カスタムモニタリソース を追加する。
- FOG に 「Atacker として SCSI PR を実行する exec リソース」を追加し、SDリソース (共有ディスク) を 当該 exec リソース に依存するよう設定する。
