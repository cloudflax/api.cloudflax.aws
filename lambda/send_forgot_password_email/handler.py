import json
import os

import boto3
from botocore.exceptions import ClientError

TEMPLATE_REL = ("templates", "auth-forgot-password.html")


def _load_template() -> str:
    base = os.path.dirname(os.path.abspath(__file__))
    path = os.path.join(base, *TEMPLATE_REL)
    with open(path, encoding="utf-8") as f:
        return f.read()


def _parse_payload(event):
    if event is None:
        return None
    if isinstance(event, str):
        try:
            event = json.loads(event)
        except json.JSONDecodeError:
            return None
    if not isinstance(event, dict):
        return None
    body = event.get("body")
    if isinstance(body, str) and body.strip():
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            return None
    return event


def handler(event, context):
    payload = _parse_payload(event)
    if not payload:
        return {"ok": False, "error": "invalid_event"}

    to_email = payload.get("email")
    name = payload.get("name")
    link = payload.get("link")
    expires_in = payload.get("expiresIn")
    if not to_email or not name or not link or expires_in is None or expires_in == "":
        return {
            "ok": False,
            "error": "missing_fields",
            "need": ["email", "name", "link", "expiresIn"],
        }

    from_addr = os.environ.get("SES_FROM_ADDRESS", "").strip()
    if not from_addr:
        return {"ok": False, "error": "SES_FROM_ADDRESS_not_configured"}

    region = os.environ.get("AWS_REGION", "us-east-1")
    subject_template = os.environ.get(
        "SES_EMAIL_SUBJECT_TEMPLATE", "Reset your password, {name}"
    )
    subject = subject_template.format(name=name)

    expires_str = str(expires_in)

    try:
        html = (
            _load_template()
            .replace("{{name}}", name)
            .replace("{{link}}", link)
            .replace("{{expiresIn}}", expires_str)
        )
    except OSError as e:
        print(f"template_read_error: {e}")
        return {"ok": False, "error": "template_read_failed"}

    client = boto3.client("sesv2", region_name=region)
    try:
        resp = client.send_email(
            FromEmailAddress=from_addr,
            Destination={"ToAddresses": [to_email]},
            Content={
                "Simple": {
                    "Subject": {"Data": subject, "Charset": "UTF-8"},
                    "Body": {
                        "Html": {"Data": html, "Charset": "UTF-8"},
                    },
                }
            },
        )
    except ClientError as e:
        code = e.response.get("Error", {}).get("Code", "")
        print(f"ses_send_error: {code} {e}")
        err = "message_rejected" if code == "MessageRejected" else "send_failed"
        return {"ok": False, "error": err, "code": code}

    mid = resp.get("MessageId")
    print(f"ses_ok to={to_email} messageId={mid}")
    return {
        "ok": True,
        "messageId": mid,
    }
