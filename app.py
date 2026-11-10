
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
        "allow_headers": "*",
        "max_age": 86400
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

    if request.method == "OPTIONS":
        return "", 204

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
    lower_lines = [line.strip().lower() for line in lines]
    extension = filename.lower().split(".")[-1] if "." in filename else ""

    file_type = None
    details = {}

    # WireGuard
    if "[interface]" in text and "[peer]" in text:
        file_type = "WireGuard"

        details = {
            "peers": sum(
                1 for line in lower_lines
                if line == "[peer]"
            ),
            "dns_configured": any(
                line.startswith("dns")
                for line in lower_lines
            ),
            "address_configured": any(
                line.startswith("address")
                for line in lower_lines
            )
        }

    # OpenVPN
    elif "client" in text and (
        "remote " in text or "dev tun" in text
    ):
        file_type = "OpenVPN"

        details = {
            "remote_servers": sum(
                1 for line in lower_lines
                if line.startswith("remote ")
            ),
            "protocol_configured": any(
                line.startswith("proto ")
                for line in lower_lines
            ),
            "device_configured": any(
                line.startswith("dev ")
                for line in lower_lines
            )
        }

    # SSH + Payload
    elif (
        any(
            line.startswith(("ssh:", "ssh=", "ssh server:"))
            for line in lower_lines
        )
        and any(
            line.startswith(("port:", "port=", "ssh port:"))
            for line in lower_lines
        )
    ):

        file_type = "SSH + Payload"

        details = {
            "server_configured": True,
            "port_configured": True,
            "username_configured": any(
                line.startswith(("user:", "username:", "user="))
                for line in lower_lines
            ),
            "password_configured": any(
                line.startswith(("password:", "pass:", "password="))
                for line in lower_lines
            ),
            "payload_configured": any(
                "payload:" in line or "payload=" in line
                for line in lower_lines
            )
        }

    # HTTP Custom / HTTP Injector - exportaciones de texto
    elif (
        any(
            "payload:" in line or "payload=" in line
            for line in lower_lines
        )
        and any(
            line.startswith(("host:", "server:", "proxy:"))
            for line in lower_lines
        )
        and any(
            line.startswith(("port:", "proxy port:"))
            for line in lower_lines
        )
    ):

        if extension == "hc":
            file_type = "HTTP Custom (texto)"
        elif extension == "ehi":
            file_type = "HTTP Injector (texto)"
        else:
            file_type = "SSH + Payload"

        details = {
            "server_configured": True,
            "port_configured": True,
            "payload_configured": True,
            "format": "text"
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

            query = {}

            for item in parsed.query.split("&"):
                if "=" in item:
                    key, value = item.split("=", 1)
                    query[key] = value

            file_type = "VLESS"

            details = {
                "protocol": "VLESS",
                "server_configured": bool(parsed.hostname),
                "port_configured": bool(parsed.port),
                "uuid_configured": bool(parsed.username),
                "transport": query.get("type", "tcp")
            }

        except Exception:
            return jsonify({
                "app": "Mi Tunnel",
                "status": "error",
                "message": "Enlace VLESS inválido"
            }), 400

    # JSON V2Ray / Xray
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

    # Formato no reconocido
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



