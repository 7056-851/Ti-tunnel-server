
from flask import Flask, jsonify

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

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)
