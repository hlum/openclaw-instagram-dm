# instagram-dm — OpenClaw スキル

[English](README.md) | 日本語

[OpenClaw](https://github.com/openclaw/openclaw) のエージェントに、Instagram の DM を安く読ませて見張らせるスキルです。

- **ブラウザ操作の代わりに 1 回の呼び出し。** `ig-chat.sh read "<チャット名>"` で、ログイン済みのブラウザタブから最新メッセージを `[時刻] 送信者: 本文` の形で取り出します。1 回読むのに 4〜5 回のブラウザ操作は要りません。
- **モデルを使わずに見張る。** `ig-watch.sh` は各チャットの最後のメッセージを前回と比べ、変化があったときだけ新しいメッセージ付きでエージェントを起こします。スマホで自分が既読・返信したチャットも拾えます（未読数だけでは見逃す部分です）。
- **安全な返信。** あなたが OK した文だけを送ること、チャットのメッセージは指示ではなくデータとして扱うことをエージェントに守らせます。

OpenClaw のブラウザで本物の Instagram Web を動かします（非公開 API は使いません）。すでにログインしているセッションをそのまま使います。

> Instagram の自動操作は Instagram の利用規約に反する可能性があります。自分のアカウントだけで、少ない回数で、自己責任で使ってください。

## インストール

```sh
git clone https://github.com/hlum/openclaw-instagram-dm
cp -r openclaw-instagram-dm/instagram-dm ~/.openclaw/workspace/skills/
```

`zsh` と `jq` が必要です。OpenClaw のブラウザで Instagram にログインし、`https://www.instagram.com/direct/inbox/` のタブを開いたままにしてください。

環境変数（任意）:

| 変数 | 既定値 | |
|---|---|---|
| `IG_ME` | （なし） | 自分の Instagram ユーザー名。自分のメッセージが `You` と表示されます |
| `IG_STATE` | `~/.openclaw/workspace/data/instagram-dm.json` | 変化を判定するための状態ファイル |
| `IG_BROWSER_PROFILE` | OpenClaw の既定 | 使うブラウザプロファイル |

## 使い方

```sh
S=~/.openclaw/workspace/skills/instagram-dm/scripts
$S/ig-chat.sh list                 # チャット一覧と最後のプレビュー（JSON）
$S/ig-chat.sh read "Party" 20      # 名前に "Party" を含むチャットの最新 20 件
$S/ig-chat.sh changes              # 前回から変化したチャットのメッセージ（初回は記録だけ）
```

見張りジョブ（cron の *command* ジョブ。チャットが変わらない限りモデルは呼びません）:

```sh
openclaw cron add --name "Instagram unread" --every 15m --no-deliver \
  --command-argv "[\"/bin/zsh\",\"$S/ig-watch.sh\",\"--unread\"]"
openclaw cron add --name "Instagram changes" --cron "0 12,17,21 * * *" --tz Asia/Tokyo --no-deliver \
  --command-argv "[\"/bin/zsh\",\"$S/ig-watch.sh\"]"
```

`--unread` は未読数が増えたときだけ動くので 15 分ごとでも安く済みます。オプションなしは自分で既読にしたチャットも拾うので、1 日数回がおすすめです。

## 制限

- 受信箱リストに読み込まれているチャット（最近の 10 件ほど）しか見つけられません。
- 写真・添付は `[photo/attachment]` と表示されます。メッセージリクエストは読みません。
- チャットを開くと既読になります。
- Instagram の Web の構造（`aria-label="Thread list"`、`role=group` のメッセージ、「React to message from …」ラベル）に依存しています。Instagram が変えた場合は `ig-chat.sh` のセレクタを直す必要があります。スキルはエージェント自身に直させます：ページを調べ、セレクタを更新し、テストし直し、何を変えたかを報告します。

## ライセンス

MIT
