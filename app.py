
import json
import base64
from urllib.parse import urlparse

from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)

CORS(app, resources={
    r"/api/*": {
        "origins": "*",
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type"]
    }
})


@app.route("/api/status", methods=["GET"])
def status():
    return jsonify({
        "server": "Mi Tunnel",
        "status": "active"
    })


def decode_vmess(content):
    """Decodifica el JSON de un enlace vmess://."""
    encoded = content[8:].strip()

    # Soportar enlaces con datos Base64
    padding = "=" * (-len(encoded) % 4)
    decoded = base64.urlsafe_b64decode(
        encoded + padding
    ).decode("utf-8")

    return json.loads(decoded)


def analyze_config():
    data = request.get_json(silent=True) or {}

    filename = str(data.get("filename", ""))
    content = str(data.get("content", "")).strip()

    if len(content) > 100000:
        return jsonify({
            "status": "error",
            "message": "Archivo demasiado grande"
        }), 413

    if not content:
        return jsonify({
            "status": "error",
            "message": "Configuración vacía"
        }), 400

    text = content.lower()
    lines = content.splitlines()

    file_type = None
    details = {}

    # WireGuard
    if "[interface]" in text and "[peer]" in text:
        file_type = "WireGuard"

        details = {
            "peers": sum(
                1 for line in lines
                if line.strip().lower() == "[peer]"
            ),
            "dns_configured": any(
                line.strip().lower().startswith("dns")
                for line in lines
            ),
            "address_configured": any(
                line.strip().lower().startswith("address")
                for line in lines
            )
        }

    # OpenVPN
    elif "client" in text and (
        "remote " in text or "dev tun" in text
    ):
        file_type = "OpenVPN"

        details = {
            "remote_servers": sum(
                1 for line in lines
                if line.strip().lower().startswith("remote ")
            ),
            "protocol_configured": any(
                line.strip().lower().startswith("proto ")
                for line in lines
            ),
            "device_configured": any(
                line.strip().lower().startswith("dev ")
                for line in lines
            )
        }

    # VMess
    elif content.lower().startswith("vmess://"):
        try:
            vmess = decode_vmess(content)

            file_type = "VMess"
            details = {
                "protocol": "VMess",
                "server_configured": bool(vmess.get("add")),
                "port_configured": bool(vmess.get("port")),
                "uuid_configured": bool(vmess.get("id")),
                "transport": vmess.get("net", "tcp")
            }
        except Exception:
            return jsonify({
                "app": "Mi Tunnel",
                "status": "error",
                "message": "Enlace VMess inválido o no se pudo decodificar"
            }), 400

    # VLESS
    elif content.lower().startswith("vless://"):
        try:
            parsed = urlparse(content)

            file_type = "VLESS"
            details = {
                "protocol": "VLESS",
                "server_configured": bool(parsed.hostname),
                "port_configured": bool(parsed.port),
                "uuid_configured": bool(parsed.username),
                "transport": dict(
                    item.split("=", 1)
                    for item in parsed.query.split("&")
                    if "=" in item
                ).get("type", "tcp")
            }
        except Exception:
            return jsonify({
                "app": "Mi Tunnel",
                "status": "error",
                "message": "Enlace VLESS inválido"
            }), 400

    # JSON de V2Ray / Xray
    elif content.startswith("{"):
        try:
            config = json.loads(content)

            if isinstance(config, dict) and (
                "inbounds" in config or "outbounds" in config
            ):
                file_type = "V2Ray / Xray JSON"

                details = {
                    "inbounds": len(config.get("inbounds", [])),
                    "outbounds": len(config.get("outbounds", [])),
                    "valid_json": True
                }
        except json.JSONDecodeError:
            pass

    if not file_type:
        return jsonify({
            "app": "Mi Tunnel",
            "status": "unsupported",
            "filename": filename,
            "message": "Formato no compatible o no reconocido"
        }), 200

    return jsonify({
        "app": "Mi Tunnel",
        "filename": filename,
        "detected": file_type,
        "details": details,
        "status": "success"
    })


@app.route("/api/analyze", methods=["POST", "OPTIONS"])
@app.route("/api/detect", methods=["POST", "OPTIONS"])
def analyze():
    return analyze_config()


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=10000,
        debug=False
    )



