/**
 * Command guard: asks the decision model whether a command Pi is about to run is
 * dangerous, before it runs.
 *
 * The endpoint is a System One classifier service (a llama.cpp server answering
 * typed questions with probabilities), configured by
 * `modules.pi-coding-agent.commandGuard` in the dotfiles. The `@...@` placeholders
 * below are filled in by `pkgs.replaceVars`; the matching `PI_GUARD_*` variables
 * override them at run time for a one-off session.
 *
 * The same service is registered as the classifier model `decision/<model>`, so a
 * `codemode` script can ask it typed questions too.
 *
 * Every judged command is appended to `command-guard.log` in the agent directory,
 * with the action the mode took -- `allow`, `block`, or `would-block` for a verdict
 * `observe` let through. That log is how the guard is rolled out: read it before you
 * let it stop anything.
 *
 * Modes: `observe` records and never interferes; `confirm` asks the user about a
 * dangerous command and, where there is no UI to ask with (print, json, rpc), blocks
 * it; `block` blocks without asking. A request that fails, times out, or never gets
 * registered counts as dangerous -- an unreachable guard should not read as "cleared
 * to proceed".
 */

import { appendFile } from "node:fs/promises";
import { join } from "node:path";
import {
	getAgentDir,
	type ExtensionAPI,
	type ExtensionContext,
	type SessionMessageEntry,
} from "@earendil-works/pi-coding-agent";

const PROVIDER = "decision";
const MODEL_ID = process.env.PI_GUARD_MODEL ?? "@model@";
const CLASSIFIER_API = "system-one";
const ENDPOINT = process.env.PI_GUARD_ENDPOINT ?? "@endpoint@";
const TIMEOUT_MS = Number(process.env.PI_GUARD_TIMEOUT_MS ?? @timeoutMs@);
const BLOCK_THRESHOLD = Number(process.env.PI_GUARD_THRESHOLD ?? @threshold@);
const MODE = (process.env.PI_GUARD_MODE ?? "@mode@") as Mode;
const LOG_FILE = process.env.PI_GUARD_LOG ?? join(getAgentDir(), "command-guard.log");
const GATED_TOOLS = new Set<string>(@tools@);
const CACHE_ENTRIES = 256;
const REQUEST_CONTEXT_CHARS = 2000;

type Mode = "observe" | "confirm" | "block";
type Decision = { block: true; reason: string } | undefined;

const DANGER_QUESTION = {
	type: "bool" as const,
	instructions:
		"Does running this command affect data, credentials, or services that `request` did not ask to affect?",
	criteria: {
		true: "Irreversible deletion or overwrite, force-pushed history, dropped databases, torn down services, leaked secrets, or writes outside the workspace",
		false: "Reading, building, testing, git and package commands, and edits the user asked for",
	},
};

type RawAnswer = {
	choice?: string;
	probabilities?: Record<string, number>;
	confidence?: number;
	score?: number;
	noul?: number;
};

type Verdict = { dangerous: boolean; probability?: number; error?: string };

const probabilitiesByCommand = new Map<string, number>();

/** A bool question travels as `noul`, the label the System One wire format uses. */
function toWireQuestions(questions: Record<string, unknown>): Record<string, unknown> {
	return Object.fromEntries(
		Object.entries(questions).map(([id, question]) => {
			const wire = question as { type?: string };
			return [id, wire.type === "bool" ? { ...wire, type: "noul" } : wire];
		}),
	);
}

function toAnswers(questions: Record<string, unknown>, raw: Record<string, RawAnswer>): Record<string, unknown> {
	return Object.fromEntries(
		Object.entries(questions).map(([id, question]) => {
			const answer = raw[id] ?? {};
			const type = (question as { type?: string }).type;
			if (type === "bool") return [id, { type: "bool", probability: answer.noul ?? 0 }];
			if (type === "score")
				return [id, { type: "score", score: answer.score ?? 0, confidence: answer.confidence ?? 0 }];
			return [
				id,
				{
					type: "choice",
					choice: answer.choice ?? "",
					probabilities: answer.probabilities ?? {},
					confidence: answer.confidence ?? 0,
				},
			];
		}),
	);
}

async function classifySystemOne(
	provider: string,
	id: string,
	context: { state: unknown; questions: Record<string, unknown> },
) {
	const output: Record<string, unknown> = { provider, model: id, answers: {}, stopReason: "stop", timestamp: Date.now() };
	try {
		const response = await fetch(ENDPOINT, {
			method: "POST",
			headers: { "content-type": "application/json" },
			body: JSON.stringify({
				model: MODEL_ID,
				state: context.state,
				questions: toWireQuestions(context.questions),
			}),
			signal: AbortSignal.timeout(TIMEOUT_MS),
		});
		if (!response.ok) throw new Error(`${ENDPOINT} returned ${response.status}: ${await response.text()}`);
		const body = (await response.json()) as {
			answers?: Record<string, RawAnswer>;
			usage?: { input_tokens?: number; output_tokens?: number };
		};
		output.answers = toAnswers(context.questions, body.answers ?? {});
		const inputTokens = body.usage?.input_tokens ?? 0;
		const outputTokens = body.usage?.output_tokens ?? 0;
		if (inputTokens || outputTokens) {
			output.usage = {
				input: inputTokens,
				output: outputTokens,
				cacheRead: 0,
				cacheWrite: 0,
				totalTokens: inputTokens + outputTokens,
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
			};
		}
		return output;
	} catch (error) {
		return {
			...output,
			answers: {},
			stopReason: "error",
			errorMessage: error instanceof Error ? error.message : String(error),
		};
	}
}

/** The prompt the agent is working on, so damage the user asked for is not flagged. */
function lastUserRequest(ctx: ExtensionContext): string {
	for (const entry of [...ctx.sessionManager.getBranch()].reverse()) {
		if (entry.type !== "message" || entry.message.role !== "user") continue;
		const content = (entry as SessionMessageEntry).message.content;
		const text =
			typeof content === "string"
				? content
				: content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("\n");
		if (text.trim()) return text.slice(0, REQUEST_CONTEXT_CHARS);
	}
	return "";
}

async function judgeCommand(command: string, cwd: string, ctx: ExtensionContext): Promise<Verdict> {
	const cacheKey = `${cwd}\u0000${command}`;
	const cached = probabilitiesByCommand.get(cacheKey);
	if (cached !== undefined) return { dangerous: cached >= BLOCK_THRESHOLD, probability: cached };

	const model = ctx.modelRegistry.findOfType("classifier", PROVIDER, MODEL_ID);
	if (!model) return { dangerous: true, error: `classifier ${PROVIDER}/${MODEL_ID} is not registered` };

	const result = await ctx.modelRegistry.classify(
		model,
		{ state: { command, cwd, request: lastUserRequest(ctx) }, questions: { danger: DANGER_QUESTION } },
		{ signal: ctx.signal },
	);
	const answer = result.stopReason === "stop" ? result.answers.danger : undefined;
	if (!answer || answer.type !== "bool") {
		return { dangerous: true, error: result.errorMessage ?? "the decision model gave no answer" };
	}

	probabilitiesByCommand.set(cacheKey, answer.probability);
	if (probabilitiesByCommand.size > CACHE_ENTRIES) probabilitiesByCommand.delete(probabilitiesByCommand.keys().next().value);
	return { dangerous: answer.probability >= BLOCK_THRESHOLD, probability: answer.probability };
}

/** What the mode does with a verdict: nothing, a question, or a refusal. */
async function enforce(command: string, verdict: Verdict, ctx: ExtensionContext): Promise<Decision> {
	if (!verdict.dangerous || MODE === "observe") return undefined;
	if (MODE === "block") return { block: true, reason: `${MODEL_ID} blocked this command (${describe(verdict)})` };
	if (!ctx.hasUI) return { block: true, reason: `${MODEL_ID} blocked this command (${describe(verdict)})` };

	const approved = await ctx.ui.confirm(`⚠️ ${MODEL_ID} flags this command (${describe(verdict)})`, command);
	return approved ? undefined : { block: true, reason: `user rejected a flagged command (${describe(verdict)})` };
}

function record(command: string, verdict: Verdict, decision: Decision, ctx: ExtensionContext): Promise<void> {
	const line = JSON.stringify({
		at: new Date().toISOString(),
		model: MODEL_ID,
		mode: MODE,
		action: decision ? "block" : MODE === "observe" && verdict.dangerous ? "would-block" : "allow",
		danger: verdict.probability ?? null,
		error: verdict.error ?? null,
		cwd: ctx.cwd,
		command,
	});
	return appendFile(LOG_FILE, `${line}\n`, "utf8").catch(() => undefined);
}

function describe(verdict: Verdict): string {
	return verdict.error
		? `decision model unavailable: ${verdict.error}`
		: `danger probability ${(verdict.probability ?? 0).toFixed(2)}`;
}

function commandOf(toolName: string, input: Record<string, unknown>): string {
	if (!GATED_TOOLS.has(toolName)) return "";
	const value = input.command;
	return typeof value === "string" ? value : "";
}

export default function (pi: ExtensionAPI) {
	pi.registerProvider(PROVIDER, {
		apiKey: "local",
		classifiers: {
			[CLASSIFIER_API]: {
				classify: (model, context) => classifySystemOne(model.provider, model.id, context),
			},
		},
		models: [
			{
				type: "classifier",
				id: MODEL_ID,
				name: `${MODEL_ID} (decision)`,
				api: CLASSIFIER_API,
				baseUrl: ENDPOINT.replace(/\/systemone\/?$/u, ""),
				input: ["text"],
				cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
				contextWindow: 4096,
			},
		],
	});

	pi.on("tool_call", async (event, ctx) => {
		const command = commandOf(event.toolName, event.input);
		if (!command.trim()) return undefined;

		const verdict = await judgeCommand(command, ctx.cwd, ctx);
		const decision = await enforce(command, verdict, ctx);
		await record(command, verdict, decision, ctx);
		return decision;
	});

	pi.registerCommand("guard", {
		description: `Ask ${MODEL_ID} whether a command is dangerous`,
		handler: async (args, ctx) => {
			if (!args.trim()) {
				ctx.ui.notify(`${MODE}: ${PROVIDER}/${MODEL_ID} at ${ENDPOINT}, threshold ${BLOCK_THRESHOLD}, log ${LOG_FILE}`, "info");
				return;
			}
			const verdict = await judgeCommand(args, ctx.cwd, ctx);
			ctx.ui.notify(
				verdict.dangerous ? `⚠️ dangerous (${describe(verdict)})` : `ok (${describe(verdict)})`,
				verdict.dangerous ? "warning" : "info",
			);
		},
	});
}
