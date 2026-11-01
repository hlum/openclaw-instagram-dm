#!/bin/zsh
# Read Instagram DMs from a logged-in OpenClaw browser tab, without model calls.
#   ig-chat.sh list                 chat list as JSON {name: last preview}
#   ig-chat.sh read "<name>" [n]    last n (default 20) messages of the first chat whose name contains <name>
#   ig-chat.sh changes [n]          read every chat whose preview changed since the last `changes` (max 3), update state
# Only chats loaded in the inbox list (the ~10 most recent) can be found. Opening a chat marks it seen.
# Env: IG_ME (your username, shown as "You"), IG_STATE (state file), IG_BROWSER_PROFILE (OpenClaw browser profile)
set -u
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH
STATE=${IG_STATE:-$HOME/.openclaw/workspace/data/instagram-dm.json}; mkdir -p ${STATE:h}
INBOX=https://www.instagram.com/direct/inbox/
ME=${IG_ME:-}
OC=(openclaw browser); [[ -n ${IG_BROWSER_PROFILE:-} ]] && OC+=(--browser-profile $IG_BROWSER_PROFILE)

id=$($OC tabs --json 2>/dev/null | jq -r '[.tabs[] | select(.url | contains("instagram.com/direct")) | .targetId][0] // empty')
[[ -n $id ]] || { echo "no Instagram tab open" >&2; exit 1; }
ev() { $OC evaluate --target-id $id --fn "$1" 2>/dev/null; }

# rows of the thread list: name, preview ("Active 3m ago" = no message preview, skipped)
LIST='() => { const l=document.querySelector("[aria-label=\"Thread list\"]")||document; const o={};
  for (const r of l.querySelectorAll("div[role=button]")) { const s=(r.innerText||"").split("\n");
    if (s.length>=4 && s.includes("·") && !/^Active /.test(s[1])) o[s[0]] ??= s[1]; }
  return o; }'

list() { ev $LIST; }

read_chat() {  # $1 name substring, $2 count
  local q=$(jq -Rn --arg s "$1" '$s')
  local hit=$(ev "() => { const l=document.querySelector(\"[aria-label=\\\"Thread list\\\"]\")||document;
    const r=[...l.querySelectorAll(\"div[role=button]\")].find(e=>(e.innerText||\"\").split(\"\n\")[0].includes($q));
    if (!r) return \"\"; r.click(); return r.innerText.split(\"\n\")[0]; }" | jq -r .)
  [[ -n $hit ]] || { echo "no chat matching \"$1\" in the inbox list"; return 1; }
  $OC wait --target-id $id --time 3500 >/dev/null 2>&1
  echo "== $hit (last $2) =="
  # one line per message group: [time header] sender: text. Groups are role=group outside the thread list.
  ev "() => { const l=document.querySelector(\"[aria-label=\\\"Thread list\\\"]\");
    const gs=[...document.querySelectorAll(\"div[role=group]\")].filter(g=>!(l&&l.contains(g)) && !g.parentElement.closest(\"div[role=group]\"));
    return gs.slice(-$2).map(g=>{ const a=g.querySelector(\"[aria-label^=\\\"React to message from \\\"]\");
      let who=a? a.getAttribute(\"aria-label\").replace(\"React to message from \",\"\") : \"?\"; if (who===\"$ME\") who=\"You\";
      const h=g.parentElement.firstElementChild; const t=(h&&h!==g)? \"[\"+h.innerText.trim()+\"] \" : \"\";
      return t+who+\": \"+((g.innerText||\"\").trim().replace(/\n+/g,\" / \")||\"[photo/attachment]\"); }).join(\"\n\"); }" | jq -r .
  $OC navigate --target-id $id $INBOX >/dev/null 2>&1   # leave the tab on the inbox
}

case ${1:-} in
  list) list ;;
  read) read_chat "${2:?chat name}" ${3:-20} ;;
  changes)
    cur=$(list) || exit 0
    [[ -n $cur && $cur != null ]] || exit 0
    [[ -s $STATE ]] || echo '{}' > $STATE
    old=$(jq -c '.Instagram_previews // empty' $STATE)
    if [[ -z $old ]]; then   # first run: remember, report nothing
      jq --argjson c $cur '.Instagram_previews=$c' $STATE > $STATE.tmp && mv $STATE.tmp $STATE; exit 0
    fi
    changed=(${(f)"$(jq -rn --argjson c $cur --argjson o $old '$c | to_entries[] | select($o[.key] != .value) | .key')"})
    for name in ${changed[1,3]}; do read_chat $name ${2:-15}; echo; done
    (( ${#changed} > 3 )) && echo "(+$(( ${#changed} - 3 )) more changed chats not fetched: ${(j:, :)changed[4,-1]})"
    # remember all current previews (the agent gets told now, or has been for the rest)
    jq --argjson c $cur '.Instagram_previews = ((.Instagram_previews // {}) + $c)' $STATE > $STATE.tmp && mv $STATE.tmp $STATE
    ;;
  *) echo "usage: ig-chat.sh list | read <name> [n] | changes [n]" >&2; exit 2 ;;
esac
