/**
 * toragents-inbox — incoming Tor messages become user turns in this session.
 *
 * The problem this solves:
 *   The toragents daemon already accepts signed messages from an allowlisted
 *   peer and writes them to <state>/inbox/*.json. But nothing told the agent.
 *   Every message sat there until a human typed "check your inbox", which makes
 *   the channel a mailbox, not a conversation. This closes that gap: a message
 *   arriving over the onion appears in the session by itself.
 *
 * Why an extension and not the daemon calling something:
 *   Only the process that owns the session can put a message into it. pi
 *   exposes exactly that as pi.sendUserMessage(), so the receiving side has to
 *   poll. The daemon stays dumb on purpose: it writes files, this watches them.
 *   That also means it works for any peer, over any transport the daemon uses.
 *
 * Design notes:
 *   - started on session_start, stopped on session_shutdown: the docs are
 *     explicit that a factory must not start timers, because pi loads
 *     extensions in invocations that have no session.
 *   - <state>/announced.json remembers which ids were already delivered, so a
 *     restart does not replay history. On the very first run it seeds with what
 *     is already on disk and says so, rather than dumping 10 old messages.
 *   - a file that is mid-write or unparseable is SKIPPED and not marked seen,
 *     so the next poll retries it. Marking it seen on a parse error would lose
 *     the message permanently.
 *   - delivery is followUp when the agent is busy, so a message never
 *     interrupts a running turn or wedges the session.
 *
 * Honest caveat, deliberately not hidden: the body is text from a remote
 * machine, and it is delivered as a user message. For an allowlisted,
 * signature-verified peer that is the whole point — but it means the peer's
 * content can instruct this agent. It is fenced with a visible marker so the
 * origin is never ambiguous.
 */

import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

/**
 * Which directory is the daemon actually writing to?
 *
 * Two layouts exist and guessing wrong means the watcher silently watches an
 * empty directory forever: an install keeps <home>/state/inbox, while a daemon
 * driven from the control port (TORAGENTS_STATE) keeps identity.json, peers.json
 * and inbox/ flat in one directory. So probe for a real inbox instead of
 * assuming, and report which one was chosen.
 */
function resolveState(): { dir: string; why: string } {
	const home = process.env.TORAGENTS_HOME || join(homedir(), ".toragents");
	// Explicit configuration always wins outright. Only the DEFAULTS get scored,
	// because an explicit path outranking nothing is the whole point of setting
	// it -- scoring an explicit TORAGENTS_HOME against /var/lib would silently
	// watch the wrong directory on a machine that has both.
	if (process.env.TORAGENTS_STATE) {
		return { dir: process.env.TORAGENTS_STATE, why: "TORAGENTS_STATE (explicit)" };
	}
	if (process.env.TORAGENTS_HOME) {
		return { dir: join(home, "state"), why: "TORAGENTS_HOME/state (explicit)" };
	}
	// No explicit config: score the defaults. A stray empty <home>/state/inbox
	// (left by a previous run of this very extension) must not outrank the
	// directory that actually holds the daemon's identity and messages.
	const candidates: [string, string][] = [];
	for (const [dir, why] of [
		[join(home, "state"), "~/.toragents/state"],
		["/var/lib/toragents-inbox", "flat state dir"],
	] as [string, string][]) {
		if (!candidates.some(([d]) => d === dir)) candidates.push([dir, why]);
	}
	const score = (dir: string): number => {
		let n = 0;
		try {
			if (existsSync(join(dir, "identity.json"))) n += 2;
			if (existsSync(join(dir, "inbox"))) n += 1;
			if (readdirSync(join(dir, "inbox")).some((f) => f.endsWith(".json"))) n += 1;
		} catch {
			return 0;
		}
		return n;
	};
	let best = { dir: candidates[0][0], why: "default, created on first run" };
	let bestScore = 0;
	for (const [dir, why] of candidates) {
		const sc = score(dir);
		if (sc > bestScore) {
			bestScore = sc;
			best = { dir, why: `${why} (score ${sc})` };
		}
	}
	return best;;
}

const RESOLVED = resolveState();
const STATE = RESOLVED.dir;
const INBOX = join(STATE, "inbox");
const ANNOUNCED = join(STATE, "announced.json");
const POLL_MS = Number(process.env.TORAGENTS_POLL_MS || 3000);
/** This session's name, for addressing only (TORAGENTS_SESSION). */
function autoSession(): string {
	const explicit = (process.env.TORAGENTS_SESSION || "").trim();
	if (explicit) return explicit.slice(0, 64);
	const pairs: Array<[string, string]> = [
		["CLAUDE_CODE_SESSION_ID", "claude"],
		["PI_SESSION_ID", "pi"],
		["CODEX_SESSION_ID", "codex"],
		["CODEX_THREAD_ID", "codex"],
	];
	for (const [key, prefix] of pairs) {
		const id = (process.env[key] || "").trim();
		if (id) return `${prefix}-${id.replace(/-/g, "").slice(0, 8)}`;
	}
	return "";
}

/**
 * Which session we are, derived from what the harness already tells its
 * children. Nobody types a name; two sessions on one machine still differ.
 */
const MY_SESSION = autoSession();
const MAX_BODY = 4000;
const MAX_BATCH = 5;

/**
 * How much of this machine's mail this session wants.
 *
 *   all      (default) everything, including untargeted mail
 *   targeted only messages addressed to this session by name
 *
 * The default is right for the two-person case the transport exists for. It is
 * wrong on a box running a dozen sessions: untargeted mail used to reach every
 * one of them, so one peer talking at 20-second intervals flooded all of them.
 */
const RECEIVE = (process.env.TORAGENTS_RECEIVE || "all").trim().toLowerCase();

/** Set by /toragents-mute. Survives restarts, per session, no config file. */
const MUTE_DIR = join(STATE, "muted");
function muteKey(): string {
	return (MY_SESSION || `pid-${process.pid}`).replace(/[^A-Za-z0-9._-]/g, "_");
}
function isMuted(): boolean {
	try {
		return existsSync(join(MUTE_DIR, muteKey()));
	} catch {
		return false;
	}
}
function setMuted(on: boolean): boolean {
	try {
		mkdirSync(MUTE_DIR, { recursive: true });
		const f = join(MUTE_DIR, muteKey());
		if (on) writeFileSync(f, String(Date.now()));
		else if (existsSync(f)) unlinkSync(f);
		return true;
	} catch {
		return false;
	}
}

interface RemoteMessage {
	id: string;
	body: string;
	from_label?: string;
	from_session?: string;
	to_session?: string;
	from_fingerprint?: string;
	from_onion?: string;
	received?: number;
}

function readAnnounced(): Set<string> | null {
	try {
		const d = JSON.parse(readFileSync(ANNOUNCED, "utf8"));
		if (Array.isArray(d)) return new Set(d.filter((x) => typeof x === "string"));
		return null;
	} catch {
		return null;
	}
}

function writeAnnounced(ids: Set<string>): void {
	// atomic: a truncated announced.json would replay history on next start
	try {
		const tmp = `${ANNOUNCED}.tmp`;
		writeFileSync(tmp, JSON.stringify([...ids]));
		renameSync(tmp, ANNOUNCED);
	} catch {
		/* losing the memo is survivable; never break the session over it */
	}
}

/** Every inbox file currently on disk, newest last. Unparseable ones are ignored. */
function scanInbox(): { ids: string[]; messages: RemoteMessage[] } {
	const ids: string[] = [];
	const messages: RemoteMessage[] = [];
	let names: string[] = [];
	try {
		names = readdirSync(INBOX).filter((n) => n.endsWith(".json"));
	} catch {
		return { ids, messages }; // no inbox dir yet
	}
	for (const name of names) {
		try {
			const m = JSON.parse(readFileSync(join(INBOX, name), "utf8")) as RemoteMessage;
			if (!m || typeof m.id !== "string") continue;
			ids.push(m.id);
			messages.push(m);
		} catch {
			// mid-write or corrupt: leave it unseen so a later poll retries it
		}
	}
	messages.sort((a, b) => (a.received || 0) - (b.received || 0));
	return { ids, messages };
}

/**
 * Untargeted mail is first-come. Targeted mail belongs to the session it names,
 * and an unnamed session does not take it -- otherwise a polling session steals
 * mail addressed to another one before it can look.
 */
function addressedToMe(m: RemoteMessage): boolean {
	const target = (m.to_session || "").trim();
	if (!target) return true;
	return MY_SESSION !== "" && target === MY_SESSION;
}

/**
 * A reply must go back to the session that wrote to us, not to the machine.
 * Built from the bare label: "box · session x" is not a valid --to value.
 */
function replyLine(m: RemoteMessage): string {
	const label = m.from_label || "peer";
	let out = `inbox_agent.py send --to ${label}`;
	if (m.from_session) out += ` --to-session ${m.from_session}`;
	out += " --body-file <path>";
	if (!m.from_session) out += "   (peer named no session; this reply cannot be targeted)";
	return out;
}

function render(m: RemoteMessage): string {
	const who = m.from_session ? `${m.from_label || "peer"} · session ${m.from_session}` : (m.from_label || "peer");
	const fp = (m.from_fingerprint || "").slice(0, 8);
	const body = (m.body || "").slice(0, MAX_BODY);
	const more = (m.body || "").length > MAX_BODY ? "\n…(truncated)" : "";
	return [
		`📨 Incoming message over Tor — this is from a REMOTE PEER, not from your user.`,
		`from: ${who}${fp ? ` (${fp}…)` : ""}`,
		`id:   ${m.id}`,
		...(m.to_session ? [`to:   ${m.to_session}`] : []),
		``,
		`<<< BEGIN PEER MESSAGE`,
		body + more,
		`END PEER MESSAGE >>>`,
		``,
		// The reply line is the most consequential string here: an agent copies
		// it. Untargeted, one polite answer fans out to every session on the
		// peer's machine -- which is exactly how a build lane flooded seventeen
		// sessions for forty minutes.
		`Reply with: ${replyLine(m)}`,
	].join("\n");
}

export default function (pi: ExtensionAPI) {
	let timer: ReturnType<typeof setInterval> | null = null;
	let announced: Set<string> = new Set();
	const attempts = new Map<string, number>();
	let running = false;
	let seedNotice = "";

	const deliver = async (ctx: ExtensionContext, msgs: RemoteMessage[]) => {
		const shown = msgs.slice(0, MAX_BATCH);
		let text = shown.map(render).join("\n\n― ― ―\n\n");
		if (msgs.length > shown.length) {
			const rest = msgs.slice(shown.length);
			text +=
				`\n\n― ― ―\n\n${rest.length} more message(s) waiting, newest from ` +
				`${rest[rest.length - 1].from_label || "peer"}. ` +
				`Run: inbox_agent.py inbox`;
		}
		try {
			// followUp when busy: never interrupt a turn or wedge the session
			await pi.sendUserMessage(text, ctx.isIdle() ? undefined : { deliverAs: "followUp" });
			for (const m of msgs) attempts.delete(m.id);
		} catch {
			// Delivery failed. Retry, but not forever: a permanently failing id
			// would otherwise re-fire every tick and hammer the session. After a
			// few tries give up loudly and leave it to /toragents-check.
			for (const m of msgs) {
				const n = (attempts.get(m.id) || 0) + 1;
				if (n >= 3) {
					attempts.delete(m.id);
					try {
						ctx.ui.notify(
							`toragents: could not deliver ${m.id} after 3 tries; run /toragents-check`,
							"warning",
						);
					} catch {}
				} else {
					attempts.set(m.id, n);
					announced.delete(m.id); // retry next tick
				}
			}
		}
	};

	const poll = async (ctx: ExtensionContext) => {
		if (running) return; // a slow delivery must not overlap the next tick
		running = true;
		try {
			// Muted: say nothing and mark nothing -- a muted session must not
			// consume mail the peer meant for it, so it stays unread.
			if (isMuted()) return;
			const { messages } = scanInbox();
			// RECEIVE=targeted keeps a busy box quiet: only mail that names this
			// session is delivered. Default "all" is right for two people.
			const wanted =
				RECEIVE === "targeted"
					? messages.filter((m) => (m.to_session || "").trim() !== "" && addressedToMe(m))
					: messages;
			const fresh = wanted.filter((m) => !announced.has(m.id) && addressedToMe(m));
			// Nothing new. Deliberately no pruning: dropping ids whose files are
			// gone would re-deliver them if an archive is ever restored.
			if (fresh.length === 0) return;
			for (const m of fresh) announced.add(m.id);
			writeAnnounced(announced);
			await deliver(ctx, fresh);
			writeAnnounced(announced);
		} finally {
			running = false;
		}
	};

	pi.on("session_start", async (_event, ctx) => {
		try {
			mkdirSync(INBOX, { recursive: true });
		} catch {
			/* daemon will create it */
		}
		const prior = readAnnounced();
		if (prior) {
			announced = prior;
		} else {
			// First run on this machine: adopt what is already on disk instead of
			// replaying it as a burst of user turns.
			const { ids } = scanInbox();
			announced = new Set(ids);
			writeAnnounced(announced);
			if (ids.length > 0) {
				seedNotice = `${ids.length} existing message(s) marked as already seen`;
			}
		}
		if (seedNotice) {
			try {
				ctx.ui.notify(
					`toragents: watching ${INBOX} (via ${RESOLVED.why}); ${seedNotice}`,
					"info",
				);
			} catch {
				/* notify is best-effort */
			}
		}
		timer = setInterval(() => {
			void poll(ctx).catch(() => {
				/* poll never throws past here */
			});
		}, POLL_MS);
	});

	pi.on("session_shutdown", async () => {
		if (timer) clearInterval(timer);
		timer = null;
		running = false;
	});

	// Manual check that does not wait for the next tick.
	pi.registerCommand("toragents-check", {
		description: "Check the Tor inbox now and deliver anything new",
		handler: async (_args, ctx) => {
			await poll(ctx);
			try {
				ctx.ui.notify(`toragents: checked ${INBOX}`, "info");
			} catch {
				/* ignore */
			}
		},
	});

	pi.registerCommand("toragents-mute", {
		description: "Stop delivering Tor messages into this session (they stay unread)",
		handler: async (_args, ctx) => {
			const ok = setMuted(true);
			try {
				ctx.ui.notify(
					ok
						? `toragents: muted as ${muteKey()}; messages stay unread and can be drained with --print`
						: "toragents: could not write the mute marker",
					ok ? "info" : "warning",
				);
			} catch {}
		},
	});

	pi.registerCommand("toragents-unmute", {
		description: "Resume delivering Tor messages into this session",
		handler: async (_args, ctx) => {
			const ok = setMuted(false);
			try {
				ctx.ui.notify(ok ? "toragents: unmuted" : "toragents: could not remove the mute marker", "info");
			} catch {}
		},
	});

	pi.registerCommand("toragents-status", {
		description: "Show Tor inbox watching state",
		handler: async (_args, ctx) => {
			const { messages } = scanInbox();
			const unread = messages.filter((m) => !announced.has(m.id)).length;
			const lines = [
				`watching    ${timer ? "yes" : "no"} every ${POLL_MS}ms`,
				`inbox       ${INBOX}`,
				`resolved by ${RESOLVED.why}`,
				`on disk     ${messages.length}`,
				`undelivered ${unread}`,
				`state       ${existsSync(ANNOUNCED) ? "memo present" : "memo missing (will seed)"}`,
			];
			try {
				ctx.ui.notify(lines.join("\n"), "info");
			} catch {
				/* ignore */
			}
		},
	});
}
