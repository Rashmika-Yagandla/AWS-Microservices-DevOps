from flask import Flask, jsonify

app = Flask(__name__)
users = [{'id': 1, 'name': 'Asha'}]

@app.get("/health")
def health():
    return jsonify(service="user-service", status="healthy"), 200

@app.get("/")
def index():
    return jsonify(service="user-service", message="User Service is running"), 200

@app.get("/users")
def list_items():
    return jsonify(users=users), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8001)
