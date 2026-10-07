# herdr + pi agent rig

`herdr` owns the terminals; **pi stays pi** — no wrapper, no permission layer, no
substitute. The queue runs a hand-written list of coding tasks through pi one at a
time, each in its own git worktree, gated on a non-LLM verifier. Nothing merges.
Nothing auto-approves. `green` means the verifier exited 0 — never that an agent
"finished a turn".

```
one task = one worktree = one fresh pi agent = one verifier command
```

The isolation is the point: running a coding agent without permission prompts is
defensible only because the blast radius is a throwaway checkout of one repo on one
branch that a human reviews. Two controls hold that up — the worktree, and a
verifier that cannot reach anything live.

## Files

| Path | What it is |
| --- | --- |
| `default.nix` | `modules.herdr`: package, `config.toml`, pi integration, `agent-queue` |
| `agent-queue` | the driver — plain bash, portable, `@vars@` filled by the module |

Enabled on `elcungem` in `hosts/elcungem/home.nix`.

## Use it

```bash
nixos-rebuild switch --flake .#elcungem   # installs herdr, config, pi extension, driver
herdr                                     # starts the server + TUI; ctrl+b q detaches
cd ~/builds/some-repo
mkdir -p tasks && $EDITOR tasks/010-first.md
agent-queue --dry-run
agent-queue
```

## Pass Phase 0 before trusting it

Everything downstream inherits the state detector's errors, so the detector gets a
gate. After the rebuild, with a real task in a real repo **inside herdr**:

- [ ] a running pi shows `working`, and `done`/`idle` when it stops;
- [ ] a pi that asks a question is recognisable — **and note that it will not be
      `blocked`**. Measured here: a task whose entire point was "ask which of two
      names I want, then stop" ended with `agent_status: done`. pi has no permission
      prompts (that is why it is here), so to herdr a question and a finished turn are
      the same event. `blocked` only appears for UI pi never shows. The driver
      therefore reads the transcript for a question and refuses to retry into it;
- [ ] `herdr agent explain <target>` reports a matched rule, **not**
      `fallback_reason: default_known_agent_idle_fallback`;
- [ ] detach, wait a minute, reattach: it kept running;
- [ ] `herdr integration status` reads **`pi: current (vN)`** — `outdated` or
      `missing` means the extension predates the binary and state is screen-derived
      again.

`agent-queue` checks that last one at startup and refuses to run otherwise.

Measured on this machine with a bare server and no integration, `herdr agent explain`
reported exactly `rule: none` + `default_known_agent_idle_fallback` — pi was only
recognised at all from its terminal title. That is why the driver refuses to start
without the integration (`--allow-screen-detection` overrides, and you should have a
reason).

Two defaults worth knowing, both verified:

- herdr ships `ui.toast.delivery = "off"`, and *every* toast mode delivers through a
  **foreground attached client**. An unattended queue therefore reaches you through
  ntfy, not through herdr. The driver warns once per run when neither channel works,
  and logs every push. Anything that needs a human is pushed at `X-Priority: 5`,
  which is what makes Android pop it over the screen instead of filing it in the shade.

## Notifications and remote access

ntfy runs in the cluster as general infrastructure: `homelab/base/ntfy` +
`apps/ntfy.yaml`, exposed on the tailnet as `ntfy.tail2f38ea.ts.net` (tailscale
Ingress, `tailscale-stream` proxy class because ntfy holds long-poll/WebSocket
connections).

**No auth, deliberately.** The instance has no public listener — the tailnet is the
boundary, so there are no credentials to rotate. The consequence is that **the topic
name is the only gate**: anything on the tailnet can publish to or subscribe to any
topic it knows. So the topic URL never goes in this (public) repo. The driver reads it
from `~/.config/herdr/ntfy-topic` (`modules.herdr.queue.ntfyTopicFile`), created once
per machine:

```bash
mkdir -p ~/.config/herdr
printf 'https://ntfy.tail2f38ea.ts.net/%s\n' "$(head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n')" \
  > ~/.config/herdr/ntfy-topic
chmod 600 ~/.config/herdr/ntfy-topic
```

**There is no herdr web UI** — verified against the 0.9.3 binary: no HTTP listener, no
dashboard. Remote access is SSH-shaped, and "outside" means the tailnet:

```bash
herdr --remote elcungem     # from any tailnet machine; uploads its binary if needed
```

elcungem already allows 22/443 on `tailscale0`, so this works as soon as the module is
switched on. On a phone, ntfy answers "what happened / who needs me" and SSH answers
"I want to steer". Do not put herdr itself in the cluster: it exists to own PTYs where
the repos, git credentials and pi live, and the only thing a Service could expose for
it is a shell — a far worse hole than the worktree isolation this rig depends on. If a
browser view is ever genuinely needed, that is ntfy's own web app (served at the URL
above) plus `herdr --remote` from a machine you trust.
- `update.version_check` and `update.manifest_check` default to on. This module turns
  both off: `herdr update` would install a mutable binary over a store path it cannot
  own, and `manifest_check` pulls remote regexes that decide when an agent counts as
  blocked. Refresh manifests deliberately with `herdr server update-agent-manifests`.

### The two documents the rig produces travel inside the notification

Nobody watching a terminal has a terminal, and `.agent-queue/010-foo.md` is not a
readable answer on a phone: a path says where something lives, not what happened. So
the two files this rig writes *for a human* are sent as the ntfy message body itself —
`curl --data-binary @file`, never `-d @file`, which strips CR/LF and would flatten the
fenced blocks that make the artifact worth reading (see curl(1)).

Pushed as the message body (`notify_md`):

- `.agent-queue/<name>.md`, the review artifact, on the four pushes that end a task:
  `⚠ <name> setup failed` (worktree create), `⚠ <name>` (pi never became ready),
  `✅ <name>`, and the not-green `⚠ <name> — <outcome>`. The toast on the machine is
  still the old one-liner; only the phone gets the document.
- `tasks/proposed/v<id>-<slug>.md`, the intake draft, on the one accepted-draft push
  `📝 #<id> drafted|queued`, with `repo <repo> · verify (<source>) confirmed red on
  <base>` on the line above it — the routing and provenance the old one-liner carried.

Everything else stays a one-line `-d` push, because it is not a document or there is
nothing yet to read: `▶ <name>` (a run starting), `⏭ … refused` (the verifier was
refused, so the task never ran and no artifact was written), `⏭ … invalid name` (the
whole message is "rename the file"), `⛔ … needs input` (the answer is typed into the
pane, not read off a phone), `⚠ … verify timed out`, `⏳ … overran` and unknown-state
(all fire inside the retry loop, before `write_artifact` runs for this outcome), and the
`💥` from `die` (preflight fails before there is a file at all).

**Budget: `NTFY_MD_MAX_BYTES=4000`** — an env override like every other tunable in these
scripts, not a Nix option. It counts **bytes, not characters**: ntfy's maximum message
size is 4096 *bytes*, the artifacts carry UTF-8 emoji, and `wc -c` is the only honest
measure (the helper counts with `LC_ALL=C` for exactly that reason). 96 bytes are
headroom for the trailer, and in intake the `repo …/verify …` preamble counts inside
the budget too (`NTFY_MD_PREAMBLE_BYTES=200` is reserved for it before the draft is
clipped).

**Why truncate instead of attach.** Overshooting 4096 bytes does not fail: the server
notices the size (or non-UTF-8) and delivers the message as an *attachment file*
instead, so a too-big artifact silently changes delivery mode rather than erroring.
Attachments are enabled on this server — `attachment-cache-dir` plus a tailnet-reachable
`base-url`, in `homelab/base/ntfy/deployment.yaml`, which is cluster infrastructure and
not a dotfiles change — and the rig still refuses to use them: nothing in these scripts
sets `Attach:`/`X-Attach`, because an attachment is a link your phone has to fetch, from
a host it may not be able to reach at 3am, and it expires
(`attachment-expiry-duration`, 72h). A body is the message. Truncated text plus a path
is readable the instant it lands; an unservable attachment URL is a mystery with a title.

So an oversized artifact is cut at a **line** boundary below the budget — whole lines
only, because `0x0A` never occurs inside a multi-byte character, which makes a line
boundary the one cut that cannot emit half an emoji and make the body non-UTF-8 — and
gains a last line naming what was dropped:

```text
… truncated (11902 bytes total) — full file: /home/elia/builds/homelab/.agent-queue/010-x.md
```

Titles stay short (≤ ~120 bytes) and never contain the file: ntfy 2.28 rejects a title
over 1 KB, or tags over 512 bytes combined, with HTTP 400 (`40057`/`40058`), and a
rejected push is invisible precisely when nobody is watching.

**Markdown is client-side only**, so it is not a licence to write anything richer: ntfy
added Markdown formatting in the **web app**, Android support arrived later and is
reported incomplete, and there is no `Markdown:` publish header to set. `write_artifact`
therefore emits headings, bullet lists and fenced blocks that stay legible as plain
text in a notification shade — the same reason the artifact leads with outcome, branch
and verifier rather than a prose summary.

## Starting a run by writing a file (opt-in, off by default)

```nix
modules.herdr.queue.watch = {
  enable = true;
  paths = [ "/home/elia/builds/homelab" ];
};
```

Each repo gets `agent-queue-<repo>.path` + `.service`: a systemd user path unit on
`<repo>/tasks` and one oneshot that runs the same `agent-queue` you would type, with
`--wait-lock 21600 --drain --allow-empty`. No daemon, no polling, no second scheduler.

Measured on this machine with a probe unit, not inferred from the man page:

| event in `<repo>/tasks` | fires? |
| --- | --- |
| create a task file | yes |
| edit an existing task file | yes |
| delete a task file | yes |
| change something one directory down (`tasks/sub/x.md`) | no — only the watched directory level |

Consequences that are worth thinking about before switching it on:

- **Write access becomes run access.** Anyone or anything that can save a file in one
  of those directories starts an agent on this machine, under your identity, on your
  GPU. The worktree and the verifier deny list still apply; nobody watching does not.
- **A batch is not interrupted by systemd.** `TimeoutStartSec=infinity` is deliberate:
  the manager default (90 s, and `ManagerDefaultTimeoutStartSec` on newer systemd)
  would SIGTERM a run in the middle of a model turn.
- **Exit 1 is success as far as systemd is concerned** (`SuccessExitStatus=0 1`) — "not
  everything is green" is an honest outcome, not a crash. Only exit 2 (preflight) shows
  a failed unit.
- **Two triggers do not interleave.** The second run waits on the per-repo lock
  (`--wait-lock`) and then re-scans the whole directory, so it costs time rather than
  losing work. `--drain` covers the file saved while the last task was already running.
- **It needs a herdr server.** With `server.startOnLogin = false` a trigger that fires
  while nobody is logged in dies in preflight — loudly, via a `💥` push, then nothing.
  Turn `startOnLogin` on if you want triggers to land unattended.

Look at it with `systemctl --user status agent-queue-<repo>.path` and
`journalctl --user -u agent-queue-<repo>.service`.

### Watching a whole directory of repos instead

A path unit needs the directory named at eval time, so "every repo in `~/builds`"
is not expressible that way. Sweeping is:

```nix
modules.herdr.queue.watch.roots = [ "/home/elia/builds" ];   # + intervalSecs, exclude
```

One timer (`OnBootSec=90s`, `OnUnitActiveSec=120s`, `Persistent`) per root runs
`agent-queue-sweep`, which walks the tree at run time — so a repository cloned this
afternoon is watched without a rebuild. Discovery is deliberately cheap because
systemd asks every interval: a repository is entered only if it is a git repo, has
`tasks/`, and contains a task whose `agent/<name>` branch does not exist yet.
Everything else about a run is still the driver's decision.

Measured: 3 repos with `tasks/` in the sweep root, 1 entered, 0 s. Repositories that
were already answered — green *or* red, both leave a branch — are never re-entered.

One subtlety worth knowing: a task **refused** by the verifier deny list never gets a
branch, so it would be rediscovered forever. The driver therefore records the refused
file's hash in `.agent-queue/refused/<task>`, and the sweep ignores a task until its
bytes change. Verified: pass 1 pushed once, pass 2 reported `0 run` and pushed nothing.
That means the fix for a refused verifier is to edit the task file — not to re-run the
same file and expect a different answer.

## Nobody has to be logged in

User units — the herdr server, the timers, the path units — belong to your *user
manager*, which by default starts only when you log in and can be torn down when you
log out. So the whole thing needs lingering, which is declarative here:

```nix
users.users.elia.linger = true;   # hosts/elcungem/default.nix
modules.herdr.server.startOnLogin = true;
```

With that, boot brings up the user manager, then the server, then the first sweep 90 s
later; agents keep running with no GUI session and no SSH connection. Two things this
does *not* do, both worth checking before relying on it:

- **It does not authenticate you.** Anything the queue needs must be a file the user
  already owns. A verifier or a `pi` model that needed a GNOME keyring, a smartcard
  `gpg-agent`, `LoadCredential=`, or a home directory unlocked by PAM would fail only
  in the unattended case — the annoying kind. This rig is fine because the model lives
  on llama-swap over the tailnet and git credentials are plain files.
- **The verifier runs in a `herdr` pane, not a login shell**, so it inherits the
  server's environment. Measured on this machine, a systemd-started user service gets
  `PATH=/run/wrappers/bin:~/.nix-profile/bin:/nix/profile/bin:
  ~/.local/state/nix/profile/bin:/etc/profiles/per-user/elia/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin`
  — `nix`, `git` and `jq` are there. It does *not* get whatever `~/.bashrc` exports,
  so a verifier that depends on shell init needs `bash -lc` at the front of it.

## Feeding the queue from Vikunja (opt-in)

```nix
modules.herdr.queue.intake = { enable = true; root = "/home/elia/builds"; };
```

One timer polls Vikunja (`agent-queue-intake`, every 10 min) and turns tasks labelled
`agent-in` into task files. The contract lives in the task description, same keys as a
task file:

```markdown
repo: homelab
verify: kubeconform -strict -summary base/ntfy
base: main

Add an ntfy page explaining the tailnet-only topic model…
```

`agent-in` **is** the intent: label a task and intake plans it. Nothing else is required
of whoever writes the task — "oxicloud" plus a vague paragraph is the normal case, and
turning that into a workable brief is precisely the job. The one thing that cannot be
inferred is *which repository*, so that is either written down or comes from the map:

```nix
modules.herdr.queue.intake.projectMap = {
  "Home Lab" = "homelab";  "Self hosting" = "homelab";  dotfiles = "dotfiles";
};
```

A model never picks the repository. It is stated, it is mapped, or intake stops and asks.

| what the Vikunja task looks like | what happens |
| --- | --- |
| `repo:` + `verify:` + prose | contract taken as written, red-checked, queued |
| `repo:` + prose, no `verify:` | planner proposes the verifier; file stamped `verify-source: planner` |
| prose only, project in `projectMap` | routed by project name, then as above |
| no `repo:`, project unmapped | comment + `agent-needs-info` + `⏭` push asking for exactly one line |
| `repo:` that is not a repo under `intake.root` | refused, with the path it tried |
| `base:` that does not exist | refused: "base branch `x` does not exist in repo" |
| verifier matching the deny list | planner-authored → **one repair turn**; human-authored → refused, rule quoted back |
| verifier names a program that is not installed | same: repair once, then refuse with the `nix run nixpkgs#<tool> -- …` form |
| verifier exits 127 / 126 / hangs / prints a usage error | same: repair once, then refuse — it was never a runnable oracle |
| verifier already green on `base` | refused: **already passes, so it cannot detect this task** |
| planner reply with no frontmatter | refused; the `pi.out` path goes in the push |
| description edited after queuing | skipped with a note — one file per task id (`v<id>-*.md`); delete it, and the `agent/` branch, to re-plan |
| token without write scope | reads fine, every comment/label 401s; run `--no-ack` or mint a write token |

Then: parse → planner → **`validate_oracle` in a pristine worktree** (no agent involved:
it must be a runnable command, offline, and red on an untouched `base`) → one bounded
repair turn if it is not → `<repo>/tasks/v<id>-<slug>.md` → the sweep runs it within a
couple of minutes → comment + `agent-queued` + ntfy push. With `intake.staging = true` drafts land
in `tasks/proposed/` instead, which the queue never reads.

**The planner browses.** It gets `read` plus web search/fetch through MCP
(`queue.intake.plannerTools`) and is told to check tool names, flags and current idioms
rather than guess. It does **not** get `bash` or `write`: verified against the binary,
its tool list is exactly what the allowlist says. Both absences are measured responses,
not caution — given a write tool it wrote the *deliverable* and returned no draft; given
no contract discipline it ignored `<<<TASK-BEGIN>>>` markers and emitted the finished
page in a code fence. Worktrees are discarded either way, but a drafting agent that does
the work is not drafting.

Browsing makes the oracle the target, so the deny list hardened with it. A verifier is
*executed* — by the red-check and again by the queue — and `curl http://x/y.sh | sh`
used to pass every rule here. Now refused outright, alongside `sh -c`, `python -c`,
`npm|pnpm|yarn|pip|uv|cargo|go install`, `docker run`:

| refused | still allowed |
| --- | --- |
| `curl -sSL https://x/y.sh \| sh`, `wget -qO- … \| bash` | `nix run nixpkgs#kubeconform -- -strict -summary base/ntfy` |
| `sh -c 'make test'`, `python3 -c …`, `eval` | `go test ./...`, `npm test`, `pytest -q && grep -q x f` |
| `pip install -r requirements.txt`, `docker run …` | `test -f docs/x.md && grep -qi ntfy mkdocs.yml` |

Side effect worth knowing: **no `curl` in verifiers at all**, including a localhost
health probe. That follows from "the oracle is offline" rather than from the injection
risk, and `--allow-verify '(\^|[;&|[:space:]])(curl|wget|fetch)([[:space:]]|$)'` reopens
it per task when you really mean it.

### A verifier has to be a *command* (`validate_oracle`)

The red-check used to ask one question: did it exit non-zero? That is the wrong question,
and this repository's own example is the proof. `verify: kubeconform -strict -summary
base/ntfy` is a good oracle for a GitOps repo — but kubeconform is **not installed** here;
it exists only as `nix run nixpkgs#kubeconform --`. The shell answered **127**, the
red-check saw "not zero", announced *confirmed red*, queued the task, and told the coding
agent "the verifier is still failing — fix it" against an oracle that could never go
green. Every retry after that is a model turn spent on a command that was never runnable.

Measured on this machine: `kubeconform`, `statix`, `deadnix`, `pytest`, `go`, `cargo` and
`npm` are all absent from the verifier PATH, which makes the right-hand column of the
table above (`go test ./...`, `npm test`, `pytest -q`) *permitted by policy and
unrunnable in practice*. They are still allowed — the point is that policy-permitted is
not the same as executable, and nothing used to check the difference.

So an oracle now clears four things before a task is queued, in one place:

| check | rejected as |
| --- | --- |
| matches no deny rule | "must be offline and must not shell out" |
| every program it names resolves on PATH (`test`/`[` and friends are builtins, `FOO=1 cmd` prefixes and `\|`/`&&`/`;` segments are handled) | "not on the verifier PATH; reach it as `nix run nixpkgs#<tool> -- …`" |
| exits non-zero on an untouched `base`, in **its own** detached worktree | "exits 0 … so it cannot detect this task" |
| exit is not 127 / 126 / 124, and the first lines are not a usage error | "the shell could not run it at all" / "a usage error, not a failing check" |

**Which PATH?** Not intake's. The verifier is typed into a herdr **pane**, so it runs under
the herdr server's environment, which differs from a user unit's (measured: the server
prepends `~/.config/carapace/bin` and `~/.local/bin/`). Intake reads the running server's
`PATH` out of `/proc` and validates and red-checks against *that*; with no server running
it falls back to its own and says so in the refusal. The list of oracle programs that
actually resolve is computed per run and put in the planner's prompt — currently `git nix
nixos-rebuild helm jq rg fd grep awk sed test just` — with the `nix run` idiom as the way
to reach anything else. That is the difference between a model guessing a binary exists
and being told the truth about the machine.

**Refusals go back to the planner first** (`intake.oracleRepairs`, default 1): one cheap
turn whose prompt carries the exact reason — the matched rule, the 127 line, the usage
error — asking for one line and nothing else. The driver has always retried the *worker*
with the real failure output; intake never retried the *planner*, which is why every
refusal became a human edit in Vikunja. A repaired candidate goes through
`validate_oracle` again, so a model that answers in prose is refused by the argv0 check
rather than queued, and returning the same command ends it immediately. **A human's
`verify:` is never repaired** — intake already forces that line back in when the planner
edits it, so silently "improving" it would be worse than the refusal. Tunables:
`QUEUE_INTAKE_REPAIRS`, `QUEUE_INTAKE_REDCHECK_TIMEOUT`, and
`QUEUE_INTAKE_ALLOW_USAGE_RC=1` if the usage-error heuristic ever rejects a real one (it
is the only judgement call in the table; 127/126/124 are shell-level facts).

### When intake refuses — and it will

A refusal is intake working, not breaking: the `verify:` on offer could touch live
infrastructure, could already pass, or — now that this is checked too — could be a program
that does not exist. `bash -c` is the usual hit, because a deploy task invites
`bash -c 'kubectl rollout status …'` or `bash -c 'curl -sf localhost:8080/healthz'` and the
wrapper alone matches; anything can hide inside it. A planner-authored oracle gets its
repair turn first (see above), so what reaches you has already failed twice.

The push carries the whole story. That mattered because the Vikunja comment holding the
explanation 401s with a read-only token, so "verifier refused" used to arrive with nothing
but the task title:

```
⏭ #313 verifier refused
verify: kubeconform -strict -summary base/ntfy
names kubeconform, which is not on the verifier PATH; reach it as
`nix run nixpkgs#kubeconform -- …` or check files instead
Write verify: yourself as a check on files, or use nix run nixpkgs#<tool> -- …
Delete ~/.local/state/herdr/intake/313 to retry.
```

(the 127 case, run against the live list; the fuller evidence — matched rule, red-check
exit and first output line, repairs used, the oracle PATH and what resolved on it — goes
beside the rejected draft in `~/.local/state/herdr/intake/rejected/v<id>-oracle-rejected.txt`)

`bash -c` refusal, for comparison, reports the rule that tripped rather than guessing:

```
verify: bash -c 'echo hi'
matches the deny rule (^|[;&|[:space:]])(sh|bash|zsh|dash)[[:space:]]+-[A-Za-z]*c([[:space:]]|$) — the oracle must be offline and must not shell out
```

What to do: accept the `nix run nixpkgs#<tool> -- …` form the refusal names, or write the
`verify:` yourself as a check on files — in a GitOps repo the deliverable *is* files, so
this is not a compromise:

```
verify: test -f apps/<name>/application.yaml && grep -q kind: Application apps/<name>/application.yaml
```

Editing the task is also the only way to retry. A refusal records the task's hash in
`~/.local/state/herdr/intake/<id>`, so intake leaves those bytes alone until they change;
`rm` that file to force a retry without editing. Before this, a refused task was planned
again on every tick — ten minutes of model time and a fresh priority-5 push each time,
which is how one task burned three planner turns in twenty minutes. If you wrote both the
contract and the brief, the planner is pure overhead: `agent-queue-intake --no-planner`
uses your `verify:` verbatim and skips the turn entirely.

## Weak verifiers are still honest verifiers

The verifier is the only oracle, but it does not have to be a strong one — nothing
merges automatically, so a weak oracle filters nonsense and hands you a review artifact
rather than certifying correctness. What it *must* do is fail before the work and pass
after it, offline.

| repository | verifier | what it really proves |
| --- | --- | --- |
| dotfiles | `nix flake check --impure --no-build` | every output still evaluates (measured: 14 s on this repo) |
| dotfiles | `nixos-rebuild --flake .#elcungem build` | the system closure builds, including every generated file — slow, store-heavy |
| nix repos | `nix run nixpkgs#deadnix -- -e .` / `nix run nixpkgs#statix -- check .` | no dead code / style |
| k8s | `kubeconform -strict -summary base/…` | manifests match the schemas |
| docs | `test -f docs/…/_index.md && grep -qi ntfy mkdocs.yml` | the thing you asked for exists |

`nixos-rebuild switch|boot|test` stays denied; `nix flake check`, `nix eval` and
`nixos-rebuild build` are allowed on purpose: they evaluate and build, they do not
activate. If you want the cheap tier for a repo, say so in the task file's `verify:`
line and let the artifact carry the judgement.

## Task files

Machine-read frontmatter, prompt in the body, lexical order.

```markdown
---
title: Add bounded retry with backoff to the ingest client
verify: pnpm vitest run test/ingest
timeout_ms: 900000
max_retries: 2
base: main
model: qwen3.8-flash-next
---

`src/ingest/client.ts` fails hard on 429 and 5xx.

- retry up to 4 times, exponential backoff + jitter, respect `Retry-After`
- non-429/5xx errors must not retry; no new dependencies; add tests

Definition of done: `pnpm vitest run test/ingest` exits 0.
```

`gate:` is optional and lists the paths the verifier judges (comma- or space-separated,
repository-relative). It names what gate integrity protects; leave it out and the driver
derives a guess from `verify:` and prints that guess in the artifact.
See "Gate integrity".

`verify:` is **required**. If you cannot write that line, the task is not ready for a
queue — the driver says so rather than guessing. Keep the definition of done in the
body too: agents follow an explicit one better than they infer it.

`model:` exists because one inference unit serves everything. elcungem's pi defaults to
`qwen3.8-flash-next` via llama-swap on the Strix Halo; parallel agents would serialise
on it anyway, and an "LLM judges the worker" step has no headroom above it. Pin the
model per task rather than inheriting whatever the default happens to be.

## What the driver does

Per task: check the verifier is offline-only → refuse if the branch already exists →
`worktree create` → split a **second pane for the verifier** → `agent start` → prompt →
verify on exit code → retry with the real failure output → commit whatever the agent
left uncommitted → write `.agent-queue/<task>.md` (commits, diffstat, outcome, panes) →
notify.

The rules it encodes, each of which is a failure mode someone paid for:

| rule | why |
| --- | --- |
| verifier exit code is the only oracle | `done` means "finished a turn"; `unknown` is not success |
| one fresh agent per task | `agent prompt --wait` does not track turns — an already-running turn's completion satisfies your wait |
| read the agent before re-sending | a timed-out wait is not proof the prompt was withheld |
| unique sentinel per attempt | `pane wait-output` searches the snapshot it already has |
| ids come from JSON responses | `worktree create` → `.result.*`; never predict them |
| `agent start` needs a prompt-ready pane | it never creates layout |
| `attempt=$((attempt + 1))` | `((attempt++))` returns 0 on the first turn and trips `pipefail` |
| the agent commits; the queue commits what it forgets | a branch whose work is only *staged* reads as an empty `base..HEAD`, and "uncommitted" is not a reviewable deliverable |

Three things beyond the original brief, because the naive version breaks:

- **A verifier cannot reach the cluster.** `verify:` matching
  `modules.herdr.queue.verifyDeny` (`kubectl`, `argocd`, `helm install|upgrade|apply`,
  `terraform apply`, `nixos-rebuild`, `home-manager switch`, `git push|reset|clean`,
  `ansible`, …) is refused *before any prompt is sent*. A worktree bounds the repo, not
  the control plane, and infra repos are exactly where a "just check it" verifier turns
  into `kubectl apply`. `--allow-verify <pat>` for a deliberate exception.
- **The verifier gets its own pane.** An idle pi still owns its terminal and is not
  sitting at a shell prompt; typing the verifier into it lands inside the agent.
- **`blocked` is a first-class wait state, and it is not enough.** Passing `--until`
  *replaces* herdr's default set (`idle`, `done`, `blocked`), so `--until idle --until
  done` waits out the entire timeout whenever pi stops to ask. The driver waits on all
  three — but since pi reports a question as `done` (see Phase 0), a red verifier also
  triggers a transcript check: if the agent's last lines look like a question, the task
  becomes `needs input` and is **not** re-prompted. Sending "the verifier is still
  failing, fix it" at an agent that asked a legitimate question is how a queue quietly
  answers its own questions.

### How a stalled turn is handled

`herdr` answers errors as JSON on stdout with exit 1, so the driver branches on
`.error.code` and re-reads `herdr agent get` before deciding anything:

| result | state | action |
| --- | --- | --- |
| `agent_blocked` | pi was asked for input and herdr refused to send | notify, keep the pane, never re-send |
| `timeout` / `agent_prompt_stalled` | still `working` | leave it alone, notify — it may finish |
| `timeout` / `agent_prompt_stalled` | `idle`/`done` | `--on-stall skip\|abort\|retry` (default skip) |
| anything else | `unknown` | stop this task; refusing to guess is cheaper than a wrong commit |

### How a truncated response is handled (`output truncated`)

Pi caps every model response at the model definition's `maxTokens` and falls back to
**16384** when the field is absent (`core/provider-composer.js`). A model that designs out
loud can spend that entire budget on prose and stop mid-sentence **without ever calling a
tool**. Nothing is written, yet herdr still reports `done` and the verifier is still red —
indistinguishable from a wrong attempt. Measured on `v350-gate-integrity-check-before-green`:
three attempts, ~47k output tokens, zero files touched, and the artifact reported
`(clean)` because there was genuinely nothing to commit.

| signal | source | action |
| --- | --- | --- |
| last assistant turn has `stopReason: "length"` | pi's session journal, keyed by the worktree path | one retry, prefixed with an instruction to make **one small edit** and say nothing else |
| a second `length` | same | outcome `output truncated`, **no further retry**, notify |
| journal unreadable | pane text containing pi's `Response was truncated before completion.` | same, as a weaker fallback |
| any other `stopReason` (`stop`, `toolUse`, `aborted`) | journal | not truncation — normal retry path |

The journal is preferred because pi paints that sentence once and the scrollback moves on;
the journal never lies about *which* turn ended how. Reading it is the one place the driver
couples itself to pi's storage layout (`~/.pi/agent/sessions/<encoded cwd>/`), so the path
is guessed by two encodings and then by worktree name before giving up.

Why no retry past the nudge: an identical prompt reproduces an identical cut-off, so every
further attempt is a full turn on the one inference unit the queue exists to ration. The fix
lives in the task, not the loop — split it, or raise `maxTokens`
(`modules.pi-coding-agent` sets it explicitly for the agent model for this reason).

### Gate integrity: green only if the files the verifier judged are intact

The invariant, stated exactly: **the verifier's exit code is still the only oracle, and
`green` is reported only when the working-tree content of every *gate* path also hashes
identical to the task's `base:`.** A mismatch is a failed run — outcome `gate tampered`,
its own `🚧 <task> gate tampered — verifier was green` push at priority 5, its own section
in the artifact — never a reviewable ✅.

That is the hole this closes. `pnpm vitest run test/ingest`,
`test -f docs/x/_index.md && grep -qi ntfy mkdocs.yml` and `nix flake check --no-build`
all judge files sitting in the tree the agent is editing, and the retry prompt merely
*asks* the one party with an incentive not to touch them. Asking is not checking.

Per gate path, in the worktree:

```bash
expected=$(git -C "$wt" rev-parse --verify -q "$base:$path" 2>/dev/null || true)
actual=$(git -C "$wt" hash-object -- "$path" 2>/dev/null || true)
```

Blob hashes, so what is compared is content and never a patch:

| trick | a patch-based check | this check | measured |
| --- | --- | --- | --- |
| `git update-index --assume-unchanged test/a.sh`, then edit it | `git diff` *and* `git status` come back empty, the tampered gate still runs | tampered | yes, synthetic repo |
| commit the tamper | staged diff empty; the patch a human reviews looks like progress | tampered | yes |
| `diff.mnemonicPrefix=true` | headers rewritten to `i/…`, `w/…` | tampered — hashing ignores diff config | yes |
| `rm` the gate | nothing left to diff | tampered: a gate that vanished is a modification | yes |
| the check itself cannot decide (unreadable `base`, a path neither side produced, an `ls-tree`-quoted name) | usually reads as "no changes" | tampered, and listed under **not compared, the check did not decide** | yes |

An unperformed check is never reported as a passed one. For the same reason `no gate`
(nothing declared, nothing derivable) and `allowed` (integrity switched off) are two
different strings in the artifact: the operator turning the check off must not read the
same as a task that declared nothing.

The check runs on every attempt, immediately after the verdict — between `pane wait-output`
returning the exit code and the hashing there is only the log's `pane read`, so nothing the
agent controls executes in that window. It uses `git` and nothing else.

**Which paths.** `gate:` in the task frontmatter, comma- or space-separated and
repository-relative, wins. Without it the driver derives a conservative list from `verify:`
itself — every path-looking argument under `modules/`, `tasks/`, `test*/`, `tests/`,
`spec/`, plus `*_test.*`, `*.bats`, `*.sh` — and adds `Makefile`, `justfile` and
`.github/workflows` when the repo has them. Directories expand to their files, which is
what makes an added workflow file show up. The resolved list, where it came from and the
verdict all land in the artifact under `## gate integrity`, so a reviewer reads what was
*actually* protected instead of what the task claimed. Deriving is deliberately imperfect
(first bullet below): it is a filter on nonsense plus a review aid, not a proof.

**Escape hatch.** `--allow-gate-self-modification`, `QUEUE_ALLOW_GATE_MOD=1`, or
`modules.herdr.queue.gateIntegrity = false`, for a task whose whole point is to change a
test. Turning it off is never silent: the artifact says
`allowed (gate integrity off: N path(s) not compared)`.

**What it does not close.**

- A gate the derivation missed. `test -f docs/x/_index.md && grep -qi ntfy mkdocs.yml`
  protects *nothing* by default — neither `docs/x/_index.md` nor `mkdocs.yml` matches a
  recognisable shape, so that run reports `no gate` (measured). Declare
  `gate: mkdocs.yml, docs/x/_index.md` for tasks like it.
- A file the verifier reads outside the worktree, or through an absolute path or symlink.
- The `verify:` string itself: it is read from the task file before the agent starts and
  never re-read, so the check is only as good as the task file you wrote.
- Tasks that legitimately edit their own gate: they are flagged, and the escape hatch is
  the answer. The check is meant to be noisy in that direction, not quiet.

Unverified, and written as unverified: everything above the table was exercised against
synthetic repositories and the driver's own functions, plus `bash -n`. No live herdr + pi
run has yet been caught tampering a gate, so nothing here shows an agent *would* have —
only that the three git operations above no longer hide one.

### How the agent is told to edit

Prevention goes in the same place as the commit contract: an unconditional block appended
to every prompt, whose whole job is to stop the model spending its response on text that
changes no files.

```text
## Editing rules (set by the queue, not by the task)

- Reply text is not progress. Do not put plans, designs or pseudocode in your reply; put
  the change in a file. Save any explanation for two sentences at the end.
- Never rewrite an existing file. Use targeted edits with the smallest unique old text.
- Keep every tool call small: one function or one config block, under roughly 80 lines.
  A response that runs out of budget half way through changes NOTHING -- the file stays
  exactly as it was and the run is lost.
- One edit, then the next. Stop early with a working tree rather than emit one huge block.
```

It must not contain pi's truncation sentence: the prompt is echoed into the pane, and
`agent_truncated()` greps the pane whenever the journal is unreadable — the contract would
otherwise flag every single run.

### The branch must hold the work (`agentCommits`, on by default)

The branch *is* the deliverable, so the branch has to contain the work. Every prompt the
queue sends — first attempt and every retry — ends with a fixed contract that is **not**
part of the task body, so a task file never has to remember rig policy:

```text
## Commit contract (set by the queue, not by the task)

- Commit your work on the CURRENT branch before you finish. Leave the working tree clean.
- Do not push. Do not amend, rebase, reset, or clean. Do not change git config.
- End every commit message with this exact trailer:

    Agent-run: <run-id>

- If you cannot finish, commit what you have anyway and say what is missing.
- Commit after each step that works, not only at the end. Several small commits survive a
  response that runs out of budget; one large commit that never happens does not.
```

Then, whatever the outcome, the queue commits anything still unstaged (`git add -A` + a
commit carrying the same `Agent-run:` trailer). Two decisions in there, both deliberate:

- **It commits on red runs too.** Work sitting on a failed task is still work: losing it
  to a discarded checkout is worse than a `wip:` subject on a branch nobody merges.
- **The identity is yours, unchanged.** A commit made by the queue is signed by exactly
  the identity the agent already edits and stages with, so committing neither adds nor
  removes a signature — which is why provenance went into the trailer rather than the
  author field, where it would make your own `git log` and `git push` surprising.

**Verified on this machine, because it had to be:** `commit.gpgsign` is unset globally and
per-repo, and there are no hooks, so an unattended `git commit` cannot fail on a keyring,
a PIN or a TTY. That is precisely the failure class "Nobody has to be logged in" warns
about — if you ever turn on signing with a smartcard-backed `gpg-agent`, unattended
commits will fail *only* overnight, so set `queue.agentCommits = false` in the same commit.

`write_artifact` now leads with the commits themselves (`## commits`, capped at 20 because
the artifact is also an ntfy body; the header line carries the full count) and keeps
`## uncommitted` as the honesty check — after a green run it should read `(clean)`, and a
name there means the queue could not commit, not that the agent was tidy. `--no-commits`
establishes the old behaviour for one run.

### Patience, deliberately: 6 hours, and a separate hang detector

A turn gets **6 hours** (`defaultTimeoutMs`) and a verifier gets **6 hours**
(`verifyTimeoutMs`). That is not laziness about timeouts — the work *is* one long tool
call. "Build the system and make the evals pass" spends 40 minutes inside `nix build`;
cutting that at 15 minutes destroys the work in progress and then reports a verdict
nobody earned. herdr caps `agent start --timeout` at 300s but places no cap on `agent
prompt --timeout` or `pane wait-output --timeout` (both verified with `21600000`).

Patience and hang detection are separate knobs, because with a 6h timeout a wedged agent
is silently six hours of nothing else running:

```nix
modules.herdr.queue.stallAfterSecs = 900;   # default 0 = off
```

When on, the driver polls the agent's pane and stops waiting when the visible region has
produced nothing for that long. It ends the **wait**, never the turn — `agent cancel`
would throw away a build, and the stall table above already handles "still working":
leave it, notify, no verifier, no retry.

The trade-off is one-sided and worth reading twice: a *silent* tool call — a build that
buffers output, a retry that sleeps — looks exactly like a hang. That is why it is off
by default. Measured with `stallAfterSecs=10`, poll 5s:

```
! no pane output for 10s -- treating this turn as stalled
» tiny: no pane output for 10s -- leaving it alone, not re-sending
» ⏳ tiny went quiet
```

The verifier did not run, the pane kept its working agent, and nothing was retried.

## Module options

| option | default | note |
| --- | --- | --- |
| `modules.herdr.package` | `pkgs.herdr` | 0.9.3 in the current pin, prebuilt on cache.nixos.org |
| `modules.herdr.settings` | see `default.nix` | written to `~/.config/herdr/config.toml`; validate with `herdr config check` |
| `modules.herdr.piIntegration.enable` | — | runs `herdr integration install pi` at activation |
| `modules.herdr.queue.defaultBase` | `main` | branch every task forks |
| `modules.herdr.queue.defaultTimeoutMs` | `21600000` (6h) | per-turn budget; a long build is the work, not a hang |
| `modules.herdr.queue.verifyTimeoutMs` | `21600000` (6h) | a verifier may compile the project; a hung one reports as needing a human |
| `modules.herdr.queue.stallAfterSecs` | `0` (off) | stop waiting on a pane with no output for N seconds; never cancels the turn |
| `modules.herdr.queue.defaultRetries` | `2` | verifier retries per task |
| `modules.herdr.queue.defaultModel` | none (pi's own default) | must be `provider/id`; a bare id exits 0 printing nothing |
| `modules.herdr.queue.agentCommits` | `true` | commit contract + commit whatever the agent leaves uncommitted, on green *and* red runs |
| `modules.herdr.queue.gateIntegrity` | `true` | veto `green` when the files the verifier judges differ from `base:`; `--allow-gate-self-modification` per run |
| `modules.herdr.server.startOnLogin` | `false` | user service so panes survive reboot |
| `modules.herdr.queue.watch.enable` | `false` | path units that start a run when `<repo>/tasks` changes |
| `modules.herdr.queue.watch.paths` | `[ ]` | exact repos to watch; one `agent-queue-<repo>.{path,service}` pair each, instant |
| `modules.herdr.queue.watch.roots` | `[ ]` | parent dirs to sweep; one `agent-queue-sweep-<root>.{timer,service}` each |
| `modules.herdr.queue.watch.intervalSecs` | `120` | sweep period per root |
| `modules.herdr.queue.watch.startDelaySecs` | `90` | delay after boot before the first sweep |
| `modules.herdr.queue.watch.exclude` | `""` | regex of repo paths a sweep skips |
| `modules.herdr.queue.intake.enable` | `false` | poll Vikunja and draft task files from labelled tasks |
| `modules.herdr.queue.intake.root` | first `watch.roots` | what a task's `repo:` line resolves against |
| `modules.herdr.queue.intake.model` | `llhalo/qwen3.8-flash-next` | planner model; the bare id silently matches nothing in `pi -p` |
| `modules.herdr.queue.intake.plannerTools` | `read` + web search/fetch | planner allowlist; no `bash`, no `write` |
| `modules.herdr.queue.intake.plannerTimeoutSecs` | `21600` (6h) | one planning turn; a wedged planner holds only the intake lock |
| `modules.herdr.queue.intake.oracleRepairs` | `1` | extra planner turns when a `verify:` is refused or will not run (planner-authored only; `0` = refuse immediately) |
| `modules.herdr.queue.intake.staging` | `false` | `true` drafts into `tasks/proposed/`, which the queue never reads |
| `modules.herdr.queue.intake.projectMap` | `{ }` | Vikunja project title → repo, used only when a task has no `repo:` |
| `modules.herdr.queue.intake.tokenFile` | `~/.config/herdr/vikunja-token` | Vikunja API token, 600, not in the repo |
| `modules.herdr.queue.watch.args` | `--drain --allow-empty` | extra args for the triggered run |
| `modules.herdr.queue.watch.lockWaitSecs` | `21600` | how long a triggered run queues behind a running batch |

New driver flags for unattended use: `--wait-lock SEC`, `--drain`, `--allow-empty`; a
preflight `die` now also pushes `💥 agent-queue failed` at priority 5, because a watched
queue that never starts is otherwise invisible.

The pi extension lives at `~/.pi/agent/extensions/herdr-agent-state.ts` and ships
*inside the herdr binary*, so the module installs it with the binary instead of
vendoring a copy that would drift from it. Home-manager would not know about that file
otherwise, and a rebuild that silently drops it degrades state detection to screen
reading — the failure this whole setup exists to avoid.

## Verified CLI surface

Checked against herdr 0.9.0 (the pin's version) and 0.9.3 — identical for everything
used here, socket protocol 22. Re-run this table after any herdr bump; the brief this
module replaces was written from docs and guessed *nothing* wrong, but it guessed from
afar.

| surface | result |
| --- | --- |
| `worktree create --cwd --branch --base --label --no-focus` → `.result.{workspace,root_pane,worktree}` | ✅ verified live |
| `pane split <pane> --direction --ratio --cwd --no-focus` → `.result.pane.pane_id` | ✅ verified live |
| `pane run` + `pane wait-output --regex --timeout` → `.result.matched_line` | ✅ verified live, including the immediate-match trap |
| `agent start <name> --kind pi --pane --timeout`, `pi` a valid kind | ✅ verified live |
| `agent prompt --wait --until (repeatable) --timeout`; "it does not track turns" | ✅ verbatim in `--help` |
| `--until` replaces the default `idle,done,blocked` set | ✅ from `--help`, and the reason for the third `--until` |
| errors as JSON on stdout, exit 1 (`agent_not_found`, `timeout`, …) | ✅ verified live |
| `integration install pi` → `~/.pi/agent/extensions/herdr-agent-state.ts`, reports state | ✅ verified live + docs |
| `ui.toast.delivery` default `off`; delivery needs a foreground client | ✅ default config + docs |
| `herdr config check`, `status server --json`, `notification show` | ✅ verified live |
| `[server] headless_cols/rows`, `[ui] status_indicators`, `[worktrees] directory` | ✅ all real keys |

## Not verified yet

- **A real pi turn.** The prompt/wait/verify loop was checked against a live herdr
  server for every primitive (worktree, split, `pane run`, `wait-output`, `agent start`,
  artifacts, locking, deny list), but no turn was sent to the local model — that is
  Phase 0, and it wants a human watching the sidebar. `agent-queue --only <task>` is
  the smallest version of it.
- **Gate integrity end to end.** The comparison, the four failure modes in its table and
  the artifact section were each run against synthetic repositories; the wiring into the
  green path is `bash -n` deep, not a live agent deep. The first real `gate tampered` push
  will be the first test of the notify path itself.
- **Fan-out.** Serial on purpose. Parallel needs provably disjoint tasks *and* a second
  inference unit.
- **`herdr --approve` for project-local trust** (`queue.approveProject`) is off, so a
  first run in a fresh worktree may surface as `blocked` on pi's trust prompt. That is
  the correct safe default; the queue notifies instead of hanging.
