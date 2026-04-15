# dingit (Python)

Minimal Python send-only client for [Dingit](https://dingit.me).

Covers `POST /api/notifications`. For list/dismiss/devices use the
`dingit` CLI or talk to the API directly.

## Install

```bash
pip install git+https://github.com/wuyuxiangX/dingit.git#subdirectory=packages/sdk-python
```

(Not yet published to PyPI — that comes when the API surface stabilizes.)

## Usage

```python
from dingit import Client

client = Client(
    base_url="http://localhost:8080",
    api_key="your-api-key",
)

result = client.send(
    title="Deploy complete",
    body="v1.2.0 is live on production",
    source="ci",
    priority="high",
    actions=[
        {"label": "View Logs", "value": "view_logs"},
        {"label": "Rollback", "value": "rollback"},
    ],
)
print(f"Sent: {result['id']}")
```

## Error handling

```python
from dingit import Client, DingitError
import requests

try:
    client.send(title="hello")
except DingitError as e:
    print(f"Server said no: {e.status}")
except requests.RequestException as e:
    print(f"Network blew up: {e}")
```

Status codes: `400` bad payload · `401` bad key · `429` rate limited · `5xx` server.
