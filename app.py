
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "app": "Mi Tunnel",
        "status": "online",
        "message": "Servidor funcionando correctamente"
    })


@app.route("/api/status")
def status():
    return jsonify({
        "server": "Mi Tunnel",
        "status": "active"
    })


@app.route("/api/detect", methods=["POST"])
def detect():
    data = request.get_json(silent=True) or {}

    filename = str(data.get("filename", ""))
    content = str(data.get("content", ""))

    if len(content) > 100000:
        return jsonify({
            "error": "Archivo demasiado grande"
        }), 413

    name = filename.lower()
    text = content.lower()

    if "[interface]" in text and "[peer]" in text:
        file_type = "WireGuard"

    elif "client" in text and (
        "remote " in text or
        "dev tun" in text
    ):
        file_type = "OpenVPN"

    elif name.endswith(".ovpn"):
        file_type = "OpenVPN"

    elif name.endswith((".conf", ".wg")):
        file_type = "WireGuard (posible)"

    elif name.endswith(".ehi"):
        file_type = "HTTP Injector (posible)"

    elif name.endswith(".hc"):
        file_type = "HTTP Custom (posible)"

    elif name.endswith((".hat", ".tnl")):
        file_type = "Tunneling config (posible)"

    elif "ssh" in text or "payload" in text:
        file_type = "SSH/Tunnel (posible)"

    else:
        file_type = "Formato desconocido"

    return jsonify({
        "app": "Mi Tunnel",
        "detected": file_type,
        "filename": filename,
        "status": "success"
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)

