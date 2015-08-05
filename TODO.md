# TODO list

## Read this

* [MQTT Version 3.1.1](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html)

## Features

* Qos0,1,2対応
    * ダウングレード
    * リトライ回数
* DUPフラグ対応(重複送信)
    * > QoS0
    * PUBLISH / PUBREL / SUBSCRIBE / UNSUBSCRIBE
    * 確認応答が必須
    * メッセージIDが含まれる
* RETAINフラグ対応
    * PUBLISHメッセージにのみ使用
    * クライアントがサーバーにRETAINフラグが(1)に設定されているPUBLISHメッセージを送信すると、サーバーは該当メッセージがサブスクライバーに送信された後もメッセージを保持する。
* KeepAliveTimer対応
* Clean Session対応
* Will対応[^1]
  * QoS0,1,2
  * QoSダウングレード
* Auth対応
    * Username/Password対応
* WebSocket対応
* ACL対応
* クラスタ

[^1]: Will

