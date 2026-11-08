
from flask import Flask, jsonify, request

app = Flask(__name__)


from flask import Flask, jsonify, request
from flask_cors import CORS

app = Flask(__name__)

CORS(app, resources={
    r"/api/*": {
        "origins": "*"
    }
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
        return jsonify({"error": "Archivo demasiado grande"}), 413

    name = filename.lower()
    text = content.lower()

    if "[interface]" in text and "[peer]" in text:
        detected = "WireGuard"
    elif "client" in text and (
        "remote " in text or "dev tun" in text
    ):
        detected = "OpenVPN"
    elif name.endswith(".ehi"):
        detected = "HTTP Injector (posible)"
    elif name.endswith(".hc"):
        detected = "HTTP Custom (posible)"
    elif name.endswith((".ovpn",)):
        detected = "OpenVPN (posible)"
    elif name.endswith((".conf", ".wg")):
        detected = "WireGuard (posible)"
    elif "ssh" in text or "payload" in text:
        detected = "SSH/Tunnel (posible)"
    else:
        detected = "Formato desconocido"

    return jsonify({
        "app": "Mi Tunnel",
        "filename": filename,
        "detected": detected,
        "status": "success"
    })



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)


