# Exclusive control of shared-disk for HA cluster using SCSI-3 Persistent Reservation

EC does not use SCSI PR (SCSI-3 Persistent Reservation) for exclusive control of shared-disk.
Therefore, the consistency cannot be kept in a specific configuration and situation, and Data Loss may occur.
This document describes "how EC fail to keep the consistency", then "how to introduce SCSI PR into EC and guarantee No Data Loss".
<!--
この文書は EC が共有ディスクの排他制御に SCSI PR (SCSI-3 Persistent Reservation) を用いないために「如何に一貫性を失うか」そして「EC に SCSI PR を導入し データ損失が無いことを保障する方法」を述べる。
-->
<!--
EC は共有ディスクの排他制御に SCSI PR (SCSI-3 Persistent Reservation) を使用しない。
このため、特定の構成・状況で一貫性を失い、データ損失を起こしうる。
この文書は「EC が如何に一貫性を失うか」そして「EC に SCSI PR を導入し データ損失が無いことを保証する方法」を述べる。
-->

----

## An Inconvenient Truth of EXPRESSCLUSTER

典型的・理想的な構成の 2ノード共有ディスク型クラスタ を用いて EC における NP解決 を説明する。

- 物理マシンとして PM-A, B を用いる
- 共有ディスクとして "SD" を用いる
-  Tie Breaker として pingnp リソース にネットワークスイッチ "SW" のIPアドレスを用いる

### An Ideal Case

1. 各ノードは 定期的に HB (heartbeat) を (ethernet 経由で) 全ノードに送信する。
   FOG (faliover group) "G" は PM-A で稼動している。

   ```
	     G
	PM-A[o]-----[SW]-----[o]PM-B
	     |                |
	     +------[SD]------+
   ```

2. PM-A と スイッチ "SW" との間のネットワークが切断状態になる。
   つまり NP 状態 (両ノードがお互いに通信不能な状態) になる。

   ```
	     G
	PM-A[o]--x--[SW]-----[o]PM-B
	     |                |
	     +------[SD]------+
   ```

3. PM-A (B) は PM-B (A) からの HB を受信しなくなり、設定時間経過後 HBTO (heartbeat timeout) を検知する。

4. **NP解決処理として** PM-A, PM-B は Tie Breaker となる スイッチ SW (の IP address) に ping を投げ、「反応が有れば生残」し、「反応が無ければ自殺」する。この結果

   - PM-A は自殺する
   - PM-B は生残する

   ```
	
	PM-A[x]--x--[SW]-----[o]PM-B
	     |                |
	     +------[SD]------+
   ```

5. PM-B はフェイルオーバを実行する (PM-B で FOG を起動させる)。

   ```
	                      G
	PM-A[x]--x--[SW]-----[o]PM-B
	     |                |
	     +------[SD]------+
   ```

障害の発生が 一箇所 である限り、両ノードで FOG が起動状態となり、共有ディスクへ 同時/平行 に I/O を行うような「システム・データ が一貫性を失う状況」は発生せず、また、FO により 業務も継続される。  


### An Inconvenient Case

「An Ideal Case」との違いは、サーバとして仮想マシン VM-A, B を用いることと 発生する障害の種類である。これもまた構成そのものは典型的と言える。

1. 各ノードは 定期的に HB (heartbeat) を (ethernet 経由で) 全ノードに送信する。
   FOG "G" は VM-A で稼動している。

   ```
	     G
	VM-A[o]-----[SW]-----[o]VM-B
	     |                |
	     +------[SD]------+
   ```

2. VM-A の動作が **遅延** する (HB送信、共有ディスクへの I/O が一時的停止する)。

3. VM-B は VM-A の HB を受信しなくなり、設定時間経過後 HBTO (heartbeat timeout) を検知する。

4. **NP解決処理として** VM-B は tie-breaker となる IP address (上図の [SW]) に ping を投げ、反応が有り 生残 を決断、フェイルオーバを実行する (VM-B で FOG を起動させる)。

   ```
	     G                G
	VM-A[o]-----[SW]-----[o]VM-B
	     |                |
	     +------[SD]------+
   ```

5. VM-A の遅延が治まる (HB送信、共有ディスクへの I/O が再開する)。VM-B は再び VM-A の HB を受信するようになる。

6. 両ノードとも「自ノードで稼働中の FOG が 相手ノードでも稼動している」ことに気付き (業務継続よりデータ保護を優先するというお題目に従い) 自殺し、業務停止となる。

   ```
	
	VM-A[x]-----[SW]-----[x]VM-B
	     |                |
	     +------[SD]------+
   ```

4番で、両ノード共 FOG が起動状態となり、6番で自殺するまで、両ノードから共有ディスクへ I/O が 同時/並行 に行われる状況が発生してしまう。
両ノードから更新された共有ディスク上の領域 (ドライブ・パーティション等) は一貫性を失い、そこに保存されていたデータは「信頼できない状態」となる。(fsck 等で共有ディスク上の領域を検査すれば 要修正なファイルの発生 が判明するであろう)
この後、何れかのノードを起動し 共有ディスク上のファイルがエラー無く読み込めたとしても、読み込んだデータが「化けている」可能性は排除できない。

現実には、更新されてしまったのか否かを後から調査・検証することは困難で、たとえ fsck でファイルが復旧されたとしても そのファイルを用いて業務を再開できる保障は無い。
殆どの場合、テープバックアップ等からのリストアによって安全な状態に戻すことになり、また、このリストアによっても「バックアップが取得された以降に更新されたデータ」を失うことになる。
<!--
上記は 「EC を理想的な構成で使用し、障害の発生が 一箇所 であるにも関わらず『業務継続』も『データ保護』も得られないケースの存在」、言い換えれば「EC が業務継続・データ保護 を確率的に行うこと」を示している。
-->
尚、仮想マシンを使用したのは「物理マシンの場合、遅延が生じた PM-A は watchdog timer によって停止されるケースが殆どで、問題が顕在化しにくいから」である。仮想マシンでは watchdog timer 諸共に遅延し、停止に至らない状況が起こりやすい。

### How general failover cluster software avoid the inconvenience

「An Incovenient Case」と同じ構成を用いる。

1. 各ノードは 定期的に HB (heartbeat) を (ethernet 経由で) 全ノードに送信する。
   FOG "G" は VM-A で稼動している。

   ```
	     G
	VM-A[o]-----[SW]-----[o]VM-B
	     |                |
	     +------[SD]------+
   ```

2. VM-A の動作が **遅延** する (HB送信、共有ディスクへの I/O が一時的停止する)。

3. VM-B は VM-A の HB を受信しなくなり、設定時間経過後 HBTO (heartbeat timeout) を検知する。

4. **NP解決処理として** VM-B は SCSI PR (SCSI-3 Persistent Reservation) を用いて、共有ディスクの排他的アクセスを獲得する。その結果 VM-A は共有ディスクへのアクセスを失う。

5. 共有ディスクへの排他的アクセスを獲得した VM-B はフェイルオーバを実行する (VM-B で FOG を起動させる)。

   ```
	     G                G
	VM-A[o]-----[SW]-----[o]VM-B
	     |                |
	     +------[SD]------+
   ```

6. VM-A は遅延が治まり、HB送信、共有ディスクへの I/O を再開するも、共有ディスクへのアクセスを失っているため I/O は失敗し、これを機に VM-A は自殺する。

   ```
	                      G
	VM-A[x]-----[SW]-----[o]VM-B
	     |                |
	     +------[SD]------+
   ```

例え 同様の障害が発生し、5番において 両ノードで FOG が稼働状態となろうとも、SCSI PR により VM-A による共有ディスクへの I/O は排除され、「システム・データ が一貫性を失う状況」は回避される。また、フェイルオーバにより 業務も継続される。


### Avoiding the Inconvenience in EC

sg3_utils パッケージの sg_persist コマンドを使用し、以下を行うことで、一般的なフェイルオーバー型クラスタと同じ状況が得られる。

- カスタムモニタリソース を追加、活性時監視に設定し、自ノードで FOG が稼動したら SCSI PR を防御ノードとして実行する。(defender.sh はカスタムモニタリソースに登録するスクリプト genw.sh のサンプル)

- FOG に exec リソース を追加し、FOG 起動時に SCSI PR を攻撃ノードとして実行する。(atacker.sh は execリソースに登録するスクリプト start.sh のサンプル)

- FOG の SDリソース (共有ディスク) を上記 exec リソース に依存するよう設定する。

#### 防御ノード (現用系) が実行する SCSI PR の論理デザイン
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

#### 攻撃ノード (待機系) が実行する SCSI PR の論理デザイン
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

----
## Appendix

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
