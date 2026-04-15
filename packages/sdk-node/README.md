# @dingit/client (Node.js)

Minimal Node.js send-only client for [Dingit](https://dingit.me).

Covers `POST /api/notifications`. For list/dismiss/devices use the
`dingit` CLI or talk to the API directly.

## Install

```bash
npm install git+https://github.com/wuyuxiangX/dingit.git#main -w packages/sdk-node
# or from local checkout:
npm install ./packages/sdk-node
```

(Not yet published to npm — that comes when the API surface stabilizes.)

## Usage

```javascript
import { Client } from "@dingit/client";

const client = new Client("http://localhost:8080", process.env.DINGIT_API_KEY);

const result = await client.send("Deploy complete", {
  body: "v1.2.0 is live on production",
  source: "ci",
  priority: "high",
  actions: [
    { label: "View Logs", value: "view_logs" },
    { label: "Rollback", value: "rollback" },
  ],
});

console.log(`Sent: ${result.id}`);
```

## Error handling

```javascript
import { Client, DingitError } from "@dingit/client";

try {
  await client.send("hello");
} catch (err) {
  if (err instanceof DingitError) {
    console.error(`Server said no: ${err.status}`);
  } else {
    console.error("Network blew up:", err);
  }
}
```

Status codes: `400` bad payload · `401` bad key · `429` rate limited · `5xx` server.

Requires Node 18+ (built-in `fetch`).
