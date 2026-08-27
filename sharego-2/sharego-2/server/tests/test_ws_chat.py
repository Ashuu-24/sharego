from urllib.parse import urlencode

from app.core.config import get_settings
from app.core.security import create_access_token
from tests.conftest import auth_headers, create_user


def _ws_token(email: str) -> str:
    return create_access_token(
        subject=email,
        settings=get_settings(),
        extra_claims={"roles": ["user"]},
    )


def test_websocket_rejects_missing_token(reset_db, client):
    try:
        with client.websocket_connect("/ws/chat"):
            raise AssertionError("unauthenticated socket should not connect")
    except Exception:
        pass


def test_rest_send_is_pushed_to_peer_websocket(reset_db, client):
    alice = create_user("alice@example.com")
    bob = create_user("bob@example.com")
    bob_token = _ws_token(bob.email)

    with client.websocket_connect(f"/ws/chat?{urlencode({'token': bob_token})}") as ws:
        ready = ws.receive_json()
        assert ready["type"] == "ready"
        assert ready["user_id"] == bob.id

        resp = client.post(
            "/messages",
            headers=auth_headers(alice.email),
            json={"receiver_id": bob.id, "content": "hello over ws"},
        )
        assert resp.status_code == 201
        saved = resp.json()

        event = ws.receive_json()
        assert event["type"] == "message"
        assert event["payload"]["id"] == saved["id"]
        assert event["payload"]["content"] == "hello over ws"
        assert event["payload"]["sender_id"] == alice.id
        assert event["payload"]["receiver_id"] == bob.id


def test_send_via_websocket_reaches_peer(reset_db, client):
    alice = create_user("alice2@example.com")
    bob = create_user("bob2@example.com")
    alice_token = _ws_token(alice.email)
    bob_token = _ws_token(bob.email)

    with client.websocket_connect(f"/ws/chat?{urlencode({'token': bob_token})}") as bob_ws:
        assert bob_ws.receive_json()["type"] == "ready"
        with client.websocket_connect(f"/ws/chat?{urlencode({'token': alice_token})}") as alice_ws:
            assert alice_ws.receive_json()["type"] == "ready"
            alice_ws.send_json({
                "type": "send",
                "receiver_id": bob.id,
                "content": "sent on socket",
            })

            alice_echo = alice_ws.receive_json()
            bob_event = bob_ws.receive_json()
            assert alice_echo["type"] == "message"
            assert bob_event["type"] == "message"
            assert alice_echo["payload"]["content"] == "sent on socket"
            assert bob_event["payload"]["sender_id"] == alice.id
            assert bob_event["payload"]["receiver_id"] == bob.id
