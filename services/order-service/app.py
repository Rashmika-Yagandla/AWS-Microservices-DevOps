from flask import Flask, jsonify

app = Flask(__name__)
orders = [{'id': 1, 'user_id': 1, 'product_id': 1, 'status': 'created'}]

@app.get("/health")
def health():
    return jsonify(service="order-service", status="healthy"), 200

@app.get("/")
def index():
    return jsonify(service="order-service", message="Order Service is running"), 200

@app.get("/orders")
def list_items():
    return jsonify(orders=orders), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8003)
