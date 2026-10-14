import { execFile } from "node:child_process"
import { basename } from "node:path"

export default {
  id: "mac-notifications",
  setup(ctx) {
    const project = basename(ctx.location.directory)
    const controller = new AbortController()
    const messages = {
      "session.execution.succeeded": "Response finished",
      "permission.asked": "Permission approval needed",
      "form.created": "Waiting for your answer",
      "session.execution.failed": "Session encountered an error",
    }

    const notify = async (event) => {
      const message = messages[event.type]
      if (!message) return

      try {
        // Durable execution events may omit location; resolve it from the session.
        const completed = event.type === "session.execution.succeeded"
        let session
        if (!event.location || completed) {
          const sessionID = event.data.sessionID ?? event.data.form?.sessionID
          if (!sessionID) return
          session = await ctx.session.get({ sessionID })
        }
        // Each location has its own plugin instance, but the event stream is global.
        const directory = event.location?.directory ?? session?.location?.directory
        if (directory !== ctx.location.directory) return

        // Child agents finishing are not the end of the main response.
        if (completed && session.parentID) return

        // Send AppleScript on stdin, so project names never enter a shell command.
        const quote = (text) => JSON.stringify(text)
        const script = `display notification ${quote(`${project}: ${message}`)} with title "OpenCode"`
        await new Promise((resolve, reject) => {
          const child = execFile(
            @ssh@,
            [
              "-i", @identityFile@,
              "-o", "IdentitiesOnly=yes",
              "-o", "BatchMode=yes",
              "-o", "ConnectTimeout=5",
              @destination@,
              "/usr/bin/osascript -",
            ],
            { timeout: 15000 },
            (error) => error ? reject(error) : resolve(),
          )
          child.stdin.on("error", () => {})
          child.stdin.end(script + "\n")
        })
      } catch (error) {
        // Notification delivery must not interrupt an OpenCode response.
        console.warn(`Could not send macOS notification: ${error.message}`)
      }
    }

    void (async () => {
      for await (const event of ctx.event.subscribe({
        types: Object.keys(messages),
        signal: controller.signal,
      })) {
        await notify(event)
      }
    })().catch((error) => {
      if (!controller.signal.aborted) {
        console.warn(`mac-notifications event subscription failed: ${error.message}`)
      }
    })

    return () => controller.abort()
  },
}
