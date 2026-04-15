// @dingit/client — minimal Node.js send-only client.
//
// Covers POST /api/notifications. Uses the built-in fetch API (Node 18+),
// no dependencies. For list/dismiss/devices use the `dingit` CLI or hit
// the HTTP API directly.

export class DingitError extends Error {
  constructor(status, body) {
    super(`dingit server error (HTTP ${status}): ${body}`);
    this.name = "DingitError";
    this.status = status;
    this.body = body;
  }
}

export class Client {
  constructor(baseUrl, apiKey, { timeoutMs = 30000 } = {}) {
    if (!baseUrl) throw new Error("baseUrl is required");
    if (!apiKey) throw new Error("apiKey is required");
    this.baseUrl = baseUrl.replace(/\/+$/, "");
    this.apiKey = apiKey;
    this.timeoutMs = timeoutMs;
  }

  async send(title, opts = {}) {
    if (!title) throw new Error("title is required");

    const {
      body = "",
      source,
      priority = "normal",
      icon,
      actions,
      callbackUrl,
      metadata,
      ttl,
    } = opts;

    const payload = { title, priority };
    if (body) payload.body = body;
    if (source) payload.source = source;
    if (icon) payload.icon = icon;
    if (actions && actions.length) payload.actions = actions;
    if (callbackUrl) payload.callback_url = callbackUrl;
    if (metadata) payload.metadata = metadata;
    if (ttl != null) payload.ttl = ttl;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      const resp = await fetch(`${this.baseUrl}/api/notifications`, {
        method: "POST",
        signal: controller.signal,
        headers: {
          Authorization: `Bearer ${this.apiKey}`,
          "Content-Type": "application/json",
          "User-Agent": "dingit-node/0.1.0",
        },
        body: JSON.stringify(payload),
      });

      if (!resp.ok) {
        const text = await resp.text().catch(() => "");
        throw new DingitError(resp.status, text);
      }

      const envelope = await resp.json();
      return envelope.data ?? envelope;
    } catch (err) {
      // Node's fetch aborts as AbortError directly in some versions
      // and as TypeError("fetch failed") wrapping AbortError via
      // err.cause in others. Walk the cause chain so callers only
      // need to catch DingitError for timeouts.
      if (controller.signal.aborted || err?.name === "AbortError" || err?.cause?.name === "AbortError") {
        throw new DingitError(0, `request timed out after ${this.timeoutMs}ms`);
      }
      throw err;
    } finally {
      clearTimeout(timer);
    }
  }
}
