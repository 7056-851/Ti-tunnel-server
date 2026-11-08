
from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)

# Permitir peticiones desde Flutter Web / DartPad
CORS(app, resources={
    r"/api/*": {
        "origins": "*",
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type"]
    }
})


# Comprobar servidor
@app.route("/api/status", methods=["GET"])
def status():
    return jsonify({
        "server": "Mi Tunnel",
        "status": "active"
    })


# Analizador de configuraciones
@app.route("/api/analyze", methods=["POST", "OPTIONS"])
@app.route("/api/detect", methods=["POST", "OPTIONS"])
def analyze():

    data = request.get_json(silent=True) or {}

    filename = str(data.get("filename", ""))
    content = str(data.get("content", ""))

    if len(content) > 100000:
        return jsonify({
            "status": "error",
            "message": "Archivo demasiado grande"
        }), 413

    text = content.lower()
    lines = content.splitlines()

    # Detectar WireGuard
    if "[interface]" in text and "[peer]" in text:

        file_type = "WireGuard"

        peers = sum(
            1 for line in lines
            if line.strip().lower() == "[peer]"
        )

        dns = any(
            line.strip().lower().startswith("dns")
            for line in lines
        )

        address = any(
            line.strip().lower().startswith("address")
            for line in lines
        )

        details = {
            "peers": peers,
            "dns_configured": dns,
            "address_configured": address
        }

    # Detectar OpenVPN
    elif "client" in text and (
        "remote " in text or "dev tun" in text
    ):

        file_type = "OpenVPN"

        remotes = sum(
            1 for line in lines
            if line.strip().lower().startswith("remote ")
        )

        details = {
            "remote_servers": remotes,
            "protocol_configured": any(
                line.strip().lower().startswith("proto ")
                for line in lines
            ),
            "device_configured": any(
                line.strip().lower().startswith("dev ")
                for line in lines
            )
        }

    else:
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


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=10000,
        debug=False
    )



