"""Minimal send-only client for Dingit. See README for details."""

from __future__ import annotations

from typing import Any, Iterable, Mapping, Optional

import requests

__all__ = ["Client", "DingitError"]

__version__ = "0.1.0"


class DingitError(RuntimeError):
    """Raised when the server returns a non-2xx status."""

    def __init__(self, status: int, body: str):
        super().__init__(f"dingit server error (HTTP {status}): {body}")
        self.status = status
        self.body = body


class Client:
    def __init__(self, base_url: str, api_key: str, *, timeout: float = 30.0):
        if not base_url:
            raise ValueError("base_url is required")
        if not api_key:
            raise ValueError("api_key is required")
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout
        self._session = requests.Session()
        self._session.headers.update(
            {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
                "User-Agent": f"dingit-python/{__version__}",
            }
        )

    def send(
        self,
        title: str,
        *,
        body: str = "",
        source: Optional[str] = None,
        priority: str = "normal",
        icon: Optional[str] = None,
        actions: Optional[Iterable[Mapping[str, Any]]] = None,
        callback_url: Optional[str] = None,
        metadata: Optional[Mapping[str, Any]] = None,
        ttl: Optional[int] = None,
    ) -> dict:
        """Send a notification. Returns the created notification's ``data`` block.

        Raises :class:`DingitError` on non-2xx responses and
        ``requests.exceptions.RequestException`` on transport failures
        (including timeouts — catch ``requests.Timeout`` separately if
        you need to distinguish them).
        """
        if not title:
            raise ValueError("title is required")

        payload: dict[str, Any] = {"title": title, "priority": priority}
        if body:
            payload["body"] = body
        if source:
            payload["source"] = source
        if icon:
            payload["icon"] = icon
        if actions:
            payload["actions"] = [dict(a) for a in actions]
        if callback_url:
            payload["callback_url"] = callback_url
        if metadata:
            payload["metadata"] = dict(metadata)
        if ttl is not None:
            payload["ttl"] = ttl

        resp = self._session.post(
            f"{self.base_url}/api/notifications",
            json=payload,
            timeout=self.timeout,
        )
        if resp.status_code // 100 != 2:
            raise DingitError(resp.status_code, resp.text)

        envelope = resp.json()
        return envelope.get("data", envelope)
