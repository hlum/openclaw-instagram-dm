# instagram-dm — an OpenClaw skill

Let your [OpenClaw](https://github.com/openclaw/openclaw) agent read and watch Instagram DMs cheaply.

- **One call instead of a browser session.** `ig-chat.sh read "<chat>"` pulls the last messages out of the logged-in browser tab as plain text (`[time] sender: text`). The agent no longer needs 4-5 browser tool calls per read.
- **Watching without a model.** `ig-watch.sh` compares each chat's last message with the previous run and only wakes the agent when something changed, with the new messages already in the wake text. It also catches chats you read or answered yourself on your phone, which unread counts miss.
- **Safe replies.** The skill tells the agent to send only text you approved, and to treat chat messages as data, not instructions.

It drives the real Instagram web app in OpenClaw's browser (no private API calls), so it uses the session you are already logged in with.

## Install

```sh
git clone https://github.com/hlum/openclaw-instagram-dm
cp -r openclaw-instagram-dm/instagram-dm ~/.openclaw/workspace/skills/
```

Needs `zsh` and `jq`, and Instagram logged in in the OpenClaw browser (keep a tab on `https://www.instagram.com/direct/inbox/` open).

Optional environment variables:

| Var | Default | |
|---|---|---|
| `IG_ME` | (none) | your Instagram username, so your messages show as `You` |
| `IG_STATE` | `~/.openclaw/workspace/data/instagram-dm.json` | state file for change detection |
| `IG_BROWSER_PROFILE` | OpenClaw default | browser profile to use |

## Use

```sh
S=~/.openclaw/workspace/skills/instagram-dm/scripts
$S/ig-chat.sh list                 # chats + last preview (JSON)
$S/ig-chat.sh read "Party" 20      # last 20 messages of the chat whose name contains "Party"
$S/ig-chat.sh changes              # messages of chats changed since the last run (first run just records)
```

Watch jobs (cron *command* jobs, no model unless a chat changed):

```sh
openclaw cron add --name "Instagram unread" --every 15m --no-deliver \
  --command-argv "[\"/bin/zsh\",\"$S/ig-watch.sh\",\"--unread\"]"
openclaw cron add --name "Instagram changes" --cron "0 12,17,21 * * *" --tz Asia/Tokyo --no-deliver \
  --command-argv "[\"/bin/zsh\",\"$S/ig-watch.sh\"]"
```

## Limits

- Only finds chats in the loaded inbox list (about the 10 most recent).
- Photos/attachments show as `[photo/attachment]`; message requests aren't read.
- Opening a chat marks it seen.
- Depends on Instagram's web markup (`aria-label="Thread list"`, `role=group` messages, "React to message from …" labels). If Instagram changes it, the selectors in `ig-chat.sh` need updating.

## License

MIT
