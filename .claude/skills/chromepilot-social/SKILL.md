---
name: chromepilot-social
description: Drive social media web apps (LinkedIn, X/Twitter, Reddit) via chromepilot's HTTP API. Use when the user wants to post, comment, reply, react, or read feeds on any social platform in a real browser session. Knows the hidden selectors, lazy-mount timings, and React quirks that generic browser automation trips over. Requires the chromepilot HTTP server on 127.0.0.1:9223.
---

# Chromepilot Social

Platform-specific playbook for driving social networks through chromepilot. The base `chromepilot` skill handles generic browser control (navigate, recon, click, fill, eval). This skill adds the per-platform DOM knowledge needed because each social network hides its real composers behind non-obvious selectors, lazy mounts, and localized aria-labels.

**Prerequisite:** the chromepilot skill. Verify the server is up with `curl -s http://127.0.0.1:9223/health` before doing anything here. If it's down, follow the chromepilot skill's recovery steps.

## Universal rules (apply to every platform)

1. **Match on meaning, not literal strings.** Every label below is given in two forms (e.g. EN "Comment" / NL "Commentaar"). The user's browser may be in any language. If a hardcoded aria-label misses, do a `/recon` or `/eval` to discover the active locale's label.
2. **Prefer stable CSS classes and `role` over aria-label when both exist.** Class names like `comments-comment-box__submit-button--cr` survive language changes; aria-labels don't.
3. **Scope via nearest `<form>` or known wrapper.** Social pages have many look-alike elements (10 "Reply" buttons on a single post). Find the editor first, climb to its `<form>`, then query submit/cancel inside that scope.
4. **Composers mount lazily.** After clicking "Comment"/"Start a post" / navigating to a post detail page, wait 1–3 seconds before querying the composer. If it's still missing, scroll further into view.
5. **Submit buttons usually appear (or enable) only after the user types.** Type first, then re-query for the submit button.
6. **chromepilot's `/fill` already types character-by-character** — it triggers React input handlers on contenteditable. You do NOT need the Playwright `keyboard.type()` workaround that raw automation libraries need.
7. **/recon caps at ~200 elements by viewport proximity.** Below-the-fold action bars (like post Like/Comment/Share) are often missing. For those, use `/eval` with a targeted `querySelectorAll` instead.
8. **Verify every post action.** After submitting, re-check the DOM (did the composer clear? did a new comment with your text appear?). Never trust a click to mean "it posted".
9. **Never navigate-away until the permalink is captured.** Closing the tab loses the URN.

## Health + auth check (start of every session)

```bash
curl -s http://127.0.0.1:9223/health
```

Expected: `{"status":"ok","cdpConnected":true,...}`. If not, run `bash ./start-chromepilot.sh` (or `.ps1` on Windows) from the chromepilot repo root.

For each platform you're about to touch, do a `/recon` on its feed URL first. If you see a login form or `title` contains "Sign in" / "Log in" / "Inloggen", stop and tell the user to log in manually in the chromepilot Chrome window — this skill does not handle auth.

---

## LinkedIn

LinkedIn is an Ember + React SPA with heavy localization. All text below is confirmed in **NL** (the label the active browser shows) and **EN** (the label from `@linkedin.com` with English UI).

### URLs

| Purpose | URL pattern |
|---|---|
| Feed | `https://www.linkedin.com/feed/` |
| Post detail | `https://www.linkedin.com/feed/update/urn:li:activity:<ID>/` |
| Notifications | `https://www.linkedin.com/notifications/` |
| Profile | `https://www.linkedin.com/in/<slug>/` |
| Messaging (inbox) | `https://www.linkedin.com/messaging/` |
| Messaging thread | `https://www.linkedin.com/messaging/thread/<threadUrn>/` |

### Label map

| Element | NL aria-label / text | EN aria-label / text | Stable CSS (when available) |
|---|---|---|---|
| "Start a post" (feed) | "Bijdrage starten" | "Start a post" | `[data-testid="mainFeed"] > div:nth-of-type(1) button[role="button"]` (first) |
| Comment composer editor | `aria-label="Teksteditor voor het maken van content"` | `aria-label="Text editor for creating content"` | `div[role="textbox"][contenteditable="true"]` |
| Composer placeholder | `data-placeholder="Voeg commentaar toe…"` | `data-placeholder="Add a comment…"` | — |
| Comment **submit** button | text `Commentaar` | text `Comment` | `button.comments-comment-box__submit-button--cr` |
| Add photo to comment | `aria-label="Voeg foto toe"` | `aria-label="Add a photo"` | `.comments-comment-box__detour-icons` |
| Emoji picker in composer | `aria-label="Emoji-toetsenbord openen"` | `aria-label="Open emoji keyboard"` | `.comments-comment-box__emoji-picker-trigger` |
| Reaction shortcut | `aria-label^="Reageren met "` | `aria-label^="React with "` | — |
| Reply to a **comment** | `aria-label^="Reageren op het commentaar van "` | `aria-label^="Reply to "` (suffix `'s comment`) | — |
| Repost | text `Reposten` | text `Repost` | — |
| Send as DM | `aria-label="Versturen in een privébericht"` | `aria-label="Send in a private message"` | — |
| "More options" on our own comment | `aria-label^="Meer opties voor "` | `aria-label^="View more options for "` | — |
| Edit menu item | text `Bewerken` | text `Edit` | `[role="menuitem"]` |
| "Save changes" (edit comment) | text `Wijzigingen opslaan` | text `Save changes` | — |
| Reaction **count** under a post | `aria-label*="reactie"` | `aria-label*="reaction"` | `button[class*="comments-comment-social-bar__reactions-count"]` |
| DM composer (messaging) | `aria-label^="Schrijf een bericht"` | `aria-label^="Write a message"` | `div.msg-form__contenteditable` |
| DM send button | text `Verzenden` | text `Send` | `button.msg-form__send-button` |
| DM thread header (recipient name) | — | — | `.msg-entity-lockup__entity-title` |
| DM thread list item | — | — | `.msg-conversations-container__convo-item` |

### Flow: comment on an existing post

**Inputs:** `postUrl` (full `/feed/update/urn:li:activity:<ID>/` URL), `commentText`.

1. Navigate:
   ```bash
   curl -X POST http://127.0.0.1:9223/navigate -d '{"url":"<postUrl>","waitMs":3000}' -H "Content-Type: application/json"
   ```
2. Scroll to reveal the composer (it lives ~1000–1500px below the fold after the post body):
   ```bash
   curl -X POST http://127.0.0.1:9223/scroll -d '{"direction":"down","amount":1500}' -H "Content-Type: application/json"
   ```
3. Confirm composer is present via `/eval`:
   ```js
   document.querySelector('div[role="textbox"][contenteditable="true"][aria-label*="ekst" i], div[role="textbox"][contenteditable="true"][aria-label*="ext" i]') !== null
   ```
   (The `*=ekst` / `*=ext` lowercase fragment matches both "Teksteditor" and "Text editor".)
4. Fill the editor. chromepilot's `/fill` handles contenteditable correctly:
   ```bash
   curl -X POST http://127.0.0.1:9223/fill -d '{
     "fields":[{
       "selector":"div[role=\"textbox\"][contenteditable=\"true\"]",
       "value":"<commentText>"
     }]
   }' -H "Content-Type: application/json"
   ```
5. Submit. The submit button appears only after the editor has content. Target it by stable class:
   ```bash
   curl -X POST http://127.0.0.1:9223/click -d '{
     "selector":"button.comments-comment-box__submit-button--cr"
   }' -H "Content-Type: application/json"
   ```
6. **Verify.** Wait 2s then re-query: the submit button should be gone (composer collapsed/cleared) AND a new comment node with your `<commentText>` should be in the DOM. Never report "posted" on the click response alone — LinkedIn sometimes swallows clicks.

### Flow: extract the post's permalink

Use when you're on a post detail page or feed post and need the canonical URL to log.

```js
(function(){
  if (location.pathname.startsWith('/feed/update/')) return location.href.split('?')[0];
  var urn = null;
  document.querySelectorAll('*').forEach(function(e){
    for (var i=0;i<e.attributes.length;i++){
      var m = e.attributes[i].value.match(/urn:li:activity:\d+/);
      if (m && !urn) urn = m[0];
    }
  });
  if (urn) return 'https://www.linkedin.com/feed/update/' + urn + '/';
  var og = document.querySelector('meta[property="og:url"]');
  return og ? og.content : location.href;
})()
```

Send this via `/eval` and use the returned URL.

### Flow: create an original post — NOT SUPPORTED via browser automation

> ⚠️ **Do not attempt this via chromepilot.** LinkedIn injects a protection iframe (`li.protechts.net/index_stg.html?uc=postAction`) on every `/feed/` load that specifically guards the share/post-create flow. Under a CDP-attached session, the share modal fails to mount into a queryable DOM — `document.querySelector('.ql-editor')` and every dialog probe return empty even while the modal is visually open. Pixel-level clicks may work briefly but trigger account restrictions (the `m13v/social-autoposter` project hit exactly this and permanently moved post-creation to the REST API).
>
> **Only comment, DM, reaction, feed-read, and notification flows work reliably on LinkedIn via chromepilot** — those have no equivalent protection layer.
>
> **If the user needs programmatic post creation**, point them to LinkedIn's official REST API:
> - Register an OAuth app at https://www.linkedin.com/developers/
> - Request scope `w_member_social`
> - POST JSON to `https://api.linkedin.com/rest/posts` with `author: "urn:li:person:<id>"`, `commentary`, `visibility: "PUBLIC"`, `lifecycleState: "PUBLISHED"`.
> - Reference implementation: `m13v/social-autoposter/scripts/linkedin_api.py` (`create_post()`).
>
> Do not try to "find a selector that works this time" — the DOM gap is intentional on LinkedIn's side, not a chromepilot capability gap.

### Flow: edit our own comment on a post

Adapted from `m13v/social-autoposter` (`scripts/browser/edit_linkedin_comment.js`).

1. Navigate to the `postUrl`, wait 3s, scroll ~1500px.
2. Find the three-dot menu on our own comment:
   ```bash
   curl -X POST http://127.0.0.1:9223/click -d '{"selector":"button[aria-label^=\"Meer opties voor \"], button[aria-label^=\"View more options for \"]"}' -H "Content-Type: application/json"
   ```
   If multiple of our comments are visible, `/recon` + pick by proximity to the target thread.
3. Click the "Bewerken" / "Edit" menu item (`[role="menuitem"]`).
4. **Key quirk:** the edit textbox is always the **last** `div[role="textbox"][aria-label*="ekst" i], div[role="textbox"][aria-label*="ext" i]` on the page (the first one is the top-of-post "Add a comment" box).
5. Append text with `/fill`. For append-not-replace behaviour, read the current `innerText` via `/eval`, concat, and fill the full string.
6. Click "Wijzigingen opslaan" / "Save changes".
7. Verify: the save button is gone and the comment now contains your appended text.

### Flow: send a direct message (DM)

Confirmed live: LinkedIn's messaging composer accepts chromepilot's char-by-char `/fill` and its send button responds to a trusted `/mouse-click`.

1. Navigate to the inbox — LinkedIn auto-opens the most recent thread:
   ```bash
   curl -X POST http://127.0.0.1:9223/navigate -d '{"url":"https://www.linkedin.com/messaging/"}' -H "Content-Type: application/json"
   ```
   If you need a specific recipient and already know the thread URN, go direct: `https://www.linkedin.com/messaging/thread/<threadUrn>/`.
2. Verify the right thread is open via `/eval`:
   ```js
   (document.querySelector('.msg-entity-lockup__entity-title, .msg-thread__link-to-profile')||{}).innerText
   ```
   If the wrong conversation is open, you need the inbox search — that's not pinned yet; `/recon` on the inbox column to find it.
3. Fill the composer. The aria-label has a trailing ellipsis "…" (Unicode U+2026) that shells mangle — **use a prefix-match selector**:
   ```bash
   curl -X POST http://127.0.0.1:9223/fill -d '{
     "fields":[{
       "selector":"div.msg-form__contenteditable[aria-label^=\"Schrijf een bericht\"]",
       "value":"<messageText>"
     }]
   }' -H "Content-Type: application/json"
   ```
   For EN UI use `aria-label^="Write a message"`. Or bypass the aria-label entirely: `div.msg-form__contenteditable` + `:not(:empty)` check after fill.
4. Verify before sending. Send button is `button.msg-form__send-button` — it's `disabled` until the composer has text:
   ```js
   var b = document.querySelector('button.msg-form__send-button');
   ({dis: b.disabled, txt: b.innerText.trim()})
   ```
5. Send with a trusted click (LinkedIn's React rejects some synthetic clicks; `/mouse-click` dispatches real CDP `Input.dispatchMouseEvent`):
   ```bash
   curl -X POST http://127.0.0.1:9223/mouse-click -d '{"selector":"button.msg-form__send-button"}' -H "Content-Type: application/json"
   ```
6. Verify: after 2s, the composer is empty, send button is `disabled` again, and the last `.msg-s-event-listitem__body` in the thread contains your message text.

### Flow: scan notifications for URNs

Adapted from `m13v/social-autoposter` (`skill/engage-linkedin.sh`). Useful when the user asks "find the post where <X> mentioned me" — returns a list of `urn:li:activity:<ID>` that you can convert to permalinks.

1. Navigate to `https://www.linkedin.com/notifications/`.
2. Optionally scroll to load more; LinkedIn lazy-loads notifications:
   ```bash
   curl -X POST http://127.0.0.1:9223/scroll -d '{"direction":"down","amount":2000}' -H "Content-Type: application/json"
   ```
   If a "Show more results" / "Meer resultaten tonen" button is present, click it up to ~5×.
3. Extract URNs via `/eval`. The shell escape is picky — wrap the JS in an IIFE and return JSON:
   ```js
   (function(){
     var out = [];
     document.querySelectorAll('article, a[href*="urn:li:activity"], [data-urn]').forEach(function(el){
       var hay = (el.outerHTML||'') + ' ' + (el.getAttribute('data-urn')||'');
       var m = hay.match(/urn:li:activity:(\d+)/);
       var kind = (el.innerText||'').toLowerCase();
       if (m) out.push({
         urn: m[0],
         permalink: 'https://www.linkedin.com/feed/update/' + m[0] + '/',
         hint: /reageerde|replied|reacted|mentioned|genoemd|heeft gereageerd/.test(kind) ? kind.slice(0,80) : null
       });
     });
     var seen = {}; return out.filter(function(x){ return seen[x.urn] ? false : (seen[x.urn]=true); });
   })()
   ```
4. A separate query-param form exists for comment-level references: `commentUrn=([^&]+)`. Extract with `location.search.match(/commentUrn=([^&]+)/)` when you're already on a notification's landing page.

### Known LinkedIn pitfalls

- **Multiple "Bijdrage starten" matches.** There's one at the top of the feed and sometimes one in the right rail ("Your first post"). Use `[data-testid="mainFeed"]` scoping or `.click` index=0.
- **"Modal Window" dialog.** LinkedIn wraps many things (even caption settings on autoplay videos) in a `[role="dialog"][aria-label="Modal Window"]`. This is an a11y announcer, not the real composer. Don't scope to it — find the composer via `contenteditable` + nearest form.
- **Reactions vs replies.** `button[aria-label^="Reageren met "]` is a **reaction picker** ("React with liked/insightful/..."). `button[aria-label^="Reageren op het commentaar van "]` is **reply to comment**. Do not confuse them.
- **"Commentaar" overload.** The NL word "Commentaar" is used for both the reaction button on a post AND the comment submit button. Prefer the stable class `.comments-comment-box__submit-button--cr` for the submit action.
- **Submit button not found immediately.** It only renders / enables after text is typed. Always type first, then locate.
- **Permalink on a feed view.** `location.href` on `/feed/` is useless. Navigate to `/feed/update/urn:li:activity:<ID>/` first OR use the URN extractor `/eval` snippet above.
- **Signed-out or expired session.** A `/recon` returning a page with "Inloggen" / "Sign in" / "Join now" buttons means auth expired. Stop and tell the user.

---

## X / Twitter

X is a React-heavy SPA. Composers and buttons are keyed by `data-testid` rather than aria-label, so these selectors are locale-stable.

### URLs

| Purpose | URL pattern |
|---|---|
| Home / timeline | `https://x.com/home` |
| Tweet permalink | `https://x.com/<handle>/status/<id>` |
| Notifications (mentions) | `https://x.com/notifications/mentions` |
| Compose (modal) | hotkey `n` on x.com when not focused in an input |
| DM inbox | `https://x.com/i/chat` |
| DM thread | `https://x.com/i/chat/<conversationId>` |

### Label map

| Element | Selector / aria-label | `data-testid` |
|---|---|---|
| Tweet composer (reply + top-level) | `[role="textbox"]` with aria-label "Post text" | — |
| Tweet submit button (inline, reply or new post) | — | `[data-testid="tweetButtonInline"]` |
| DM composer | contenteditable `[role="textbox"]` with aria-label "Unencrypted message" | fallback: `div[contenteditable="true"]` inside thread |
| DM send | press `Enter` (no dedicated button on chat SPA) | — |
| DM encryption passcode | 4-digit `input` elements | filled via keyboard |

### Flow: reply to a tweet

From `m13v/social-autoposter` (tweet-reply logic in `bin/server.js`).

1. Navigate to the tweet: `https://x.com/<handle>/status/<id>`.
2. Wait for the React tree (~1.5s). Then fill:
   ```bash
   curl -X POST http://127.0.0.1:9223/fill -d '{
     "fields":[{"selector":"[role=\"textbox\"][aria-label=\"Post text\"]","value":"<replyText>"}]
   }' -H "Content-Type: application/json"
   ```
3. Submit:
   ```bash
   curl -X POST http://127.0.0.1:9223/click -d '{"selector":"[data-testid=\"tweetButtonInline\"]"}' -H "Content-Type: application/json"
   ```
4. Verify via DOM: the composer placeholder reappears AND a new reply with your text is in the thread. The autoposter repo also uses CDP `Network.responseReceived` to listen for the `CreateTweet` API call — that's the most reliable "did it post" signal but requires network instrumentation outside chromepilot's current endpoints.

### Flow: send a DM on X

1. Open `https://x.com/i/chat` — if an encryption passcode is required, X shows 4 `input` fields that you fill character by character (chromepilot `/type`).
2. Pick a thread (`a[href*="/i/chat/"]`) or navigate directly: `https://x.com/i/chat/<conversationId>`.
3. Fill the composer:
   ```bash
   curl -X POST http://127.0.0.1:9223/fill -d '{
     "fields":[{"selector":"[role=\"textbox\"][aria-label=\"Unencrypted message\"]","value":"<text>"}]
   }' -H "Content-Type: application/json"
   ```
   If that selector misses (aria-label varies for encrypted threads), fall back to any `div[contenteditable=\"true\"]` in the rightmost column.
4. Send with `Enter`:
   ```bash
   curl -X POST http://127.0.0.1:9223/dispatch -d '{
     "selector":"[role=\"textbox\"]",
     "type":"keydown","key":"Enter"
   }' -H "Content-Type: application/json"
   ```
5. Verify: the composer clears and the sent bubble appears at the bottom of the thread.

### Known X pitfalls

- **Post-create via browser is NOT in the autoposter repo.** Only reply-to-tweet is. Top-level tweet composer is the same modal opened with hotkey `n` (or clicking "Post" in the left rail); the composer/textbox selector is identical (`[role="textbox"]` with aria-label "Post text"), but the submit testid becomes `[data-testid="tweetButton"]` (without "Inline"). Unverified — confirm with `/recon` on first run.
- **Media upload / scheduling**: not pinned. The autoposter repo does not implement either.
- **Tweets cannot be edited via public UI** unless user has X Premium. Skip edit flows.
- **Encryption passcode**: if DM inbox prompts for a passcode, the user may have enabled encrypted DMs. Ask the user to enter it manually; don't brute-force.

---

## Reddit

Reddit has two web front-ends: `old.reddit.com` (classic HTML forms) and `www.reddit.com` / `new.reddit.com` (shreddit web components + shadow DOM). **Prefer `old.reddit.com` for posts/comments** — the DOM is ~10× simpler. For **DM/chat**, the new web app is required (`www.reddit.com/chat`).

The autoposter repo auto-rewrites `reddit.com` → `old.reddit.com` on navigation for post/comment work.

### URLs

| Purpose | URL pattern | Which front-end |
|---|---|---|
| Subreddit | `https://old.reddit.com/r/<name>/` | old |
| New text post | `https://old.reddit.com/r/<name>/submit` | old |
| Comment thread | `https://old.reddit.com/r/<name>/comments/<id>/` | old |
| Comment permalink | `https://old.reddit.com/r/<name>/comments/<threadId>/<slug>/<commentId>/` | old |
| Traditional PM inbox | `https://old.reddit.com/message/unread/` | old |
| Compose new PM | `https://www.reddit.com/message/compose/?to=<username>` | new (shadow DOM) |
| Chat inbox (SPA) | `https://www.reddit.com/chat` | new (shadow DOM) |
| Chat room | `https://www.reddit.com/chat/room/<id>` | new (shadow DOM) |

### Label map

| Element | Selector |
|---|---|
| Top-of-thread comment form (old) | `form.usertext.cloneable` (textarea `textarea[name="text"]`, submit `button.save[type="submit"]`) |
| Inline "reply" link on a comment (old) | `.flat-list a` with text `reply` |
| Inline "edit" link on own comment (old) | `.comment > .entry .flat-list a` with text `edit` |
| Reply textarea after clicking "reply" (old) | `.comment .usertext-edit textarea` |
| Save button after reply/edit (old) | `.comment .usertext-edit button[type="submit"]` |
| Locked thread marker (old) | `.locked-tagline` (reply form absent) |
| Banned/404 (old) | `.interstitial` |
| Shreddit post card (new) | `shreddit-post` web component (attrs: `score`, `comment-count`) |
| Compose-PM fields (new) | `faceplate-text-input` (subject, recipient), `faceplate-textarea-input` (body) — **inside shadow DOM** |
| Chat room composer (new) | `[role="textbox"]` with aria-label "Write message", or `div[contenteditable="true"]` fallback |
| Chat send | press `Enter`, or a button matching `aria-label*="Send"` |

### Flow: post a top-level comment on a thread (old.reddit)

1. Navigate to the thread URL (auto-rewrite to `old.reddit.com` if the user gave a `www.` link).
2. Check the thread isn't locked/banned via `/eval`:
   ```js
   ({locked:!!document.querySelector('.locked-tagline'), gone:!!document.querySelector('.interstitial'), form:!!document.querySelector('.commentarea form.usertext')})
   ```
   If `form` is false, the user can't comment here — stop.
3. Fill:
   ```bash
   curl -X POST http://127.0.0.1:9223/fill -d '{
     "fields":[{"selector":"form.usertext.cloneable textarea[name=\"text\"]","value":"<text>"}]
   }' -H "Content-Type: application/json"
   ```
4. Submit: `form.usertext.cloneable button.save[type="submit"]`.
5. Verify: a new comment with `a.author[href*="/<username>"]` appears near the top.

### Flow: reply to a specific comment (old.reddit)

1. Navigate to the comment permalink (`.../comments/<threadId>/<slug>/<commentId>/`).
2. **Dedup check** before typing — skip if you already replied:
   ```js
   (function(){
     var me = (document.querySelector('#header-bottom-right .user a')||{}).innerText;
     return !!document.querySelector('.comment .child .comment a.author[href*="/'+me+'"]');
   })()
   ```
   If true, do nothing.
3. Click the "reply" link scoped to the target comment: `.comment .flat-list a` with text `reply`.
4. The reply form appears inline. Multiple `.comment .usertext-edit textarea` may exist — use `:visible` (or iterate `.nth(i)` until one is visible).
5. Fill that textarea and submit `.comment .usertext-edit button[type="submit"]` in the same scope.
6. Verify: your reply appears as a child of the target comment.

### Flow: edit your own comment (old.reddit)

1. Navigate to the comment permalink.
2. Click the inline edit link: `.comment > .entry .flat-list a` with text `edit` (scoped to your own comment's `.entry`).
3. The textarea replaces the comment body — selector: `.comment > .entry .usertext-edit textarea`.
4. Read current text via `/eval` then fill with the new/appended text.
5. Submit: `.comment > .entry .usertext-edit button[type="submit"]` (text "save edits").
6. Verify: the textarea disappears and the rendered body shows the new text.

### Flow: send a traditional PM (old.reddit)

1. Navigate to `https://old.reddit.com/message/compose/?to=<username>`.
2. Fill subject + body:
   ```bash
   curl -X POST http://127.0.0.1:9223/fill -d '{
     "fields":[
       {"selector":"input[name=\"subject\"]","value":"<subject>"},
       {"selector":"textarea[name=\"text\"]","value":"<body>"}
     ]
   }' -H "Content-Type: application/json"
   ```
3. Click `button.save[type="submit"]` (text "send").
4. Verify: page redirects to "your message has been delivered" state.

### Flow: send a chat message (new.reddit, shadow DOM)

The new-reddit chat SPA is the only way to DM in a realtime thread (as opposed to a traditional PM).

1. Navigate to `https://www.reddit.com/chat` (pick a room `a[href^="/chat/room/"]`) or directly to `https://www.reddit.com/chat/room/<id>`.
2. Composer is inside a shadow root. chromepilot's `/fill` cannot pierce shadow DOM by default — use `/eval` with `deepQuerySelector`:
   ```js
   (function dq(sel, root){
     root = root || document;
     var hit = root.querySelector(sel); if (hit) return hit;
     var all = root.querySelectorAll('*');
     for (var i=0;i<all.length;i++) if (all[i].shadowRoot) {
       var r = dq(sel, all[i].shadowRoot); if (r) return r;
     }
     return null;
   })('[role="textbox"][aria-label="Write message"], div[contenteditable="true"]')
   ```
3. For filling shadow-DOM contenteditable, dispatch InputEvents from inside `/eval` rather than `/fill`. Confirmed working pattern: set `textContent`, then fire `input` + `change` events.
4. Send: press `Enter` via `/dispatch` with key=Enter, OR click a button inside the shadow root whose aria-label matches `/send/i`.
5. Verify: the new message bubble appears at the bottom of the thread.

### Flow: compose a new DM to a user not yet in your chat list (new.reddit)

1. Navigate to `https://www.reddit.com/message/compose/?to=<username>` — this is the new-reddit compose, which uses `faceplate-*` web components inside shadow DOM. (The `old.reddit.com` PM form is simpler — use that unless the user insists on the new UI.)
2. Fields: pierce shadow DOM to reach `faceplate-text-input` (subject/recipient) and `faceplate-textarea-input` (body).
3. Fire input events as above, then find the submit button inside the same faceplate form.

### Known Reddit pitfalls

- **Shadow DOM on new.reddit blocks `/fill`.** Either switch to `old.reddit.com` or use shadow-piercing `/eval`. The shadow-DOM traversal above works for compose PM + chat.
- **Locked / banned / private subs.** Always probe `.locked-tagline` / `.interstitial` / presence of `.commentarea form.usertext` BEFORE filling. Filling a form on a locked thread fails silently.
- **Multiple `.usertext-edit` forms visible at once.** Each comment's reply form shares classes. Always scope within `.comment[data-fullname="t1_<commentId>"]` or by the specific `.entry` you clicked.
- **Auto-rewrite URLs.** If the user pastes a `www.reddit.com/r/...` link, navigate to the `old.reddit.com` equivalent unless the task is chat-specific.
- **View counts / scores live in shreddit attributes.** On new.reddit, `<shreddit-post>` carries `score`, `comment-count`, and `view-count-text` as attributes — no DOM scrape needed, just attribute read.

---

## Extending this skill

When you discover new selectors that hold across sessions:

1. Append them to the right platform's **Label map** table.
2. If the flow is reusable, add a `### Flow: ...` block with the exact `curl` sequence.
3. If a known quirk tripped you up, record it under **Known pitfalls** so the next run skips that cost.
4. Keep language variants paired (NL + EN, or extend with DE/FR/ES as the user's locale demands).

Selectors that reference user-specific names (e.g. "View more options for Matthew") belong as **prefix patterns** (`aria-label^="..."`) not literal strings.
