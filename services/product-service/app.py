from flask import Flask, jsonify

app = Flask(__name__)
products = [{'id': 1, 'name': 'Laptop', 'price': 55000}]

@app.get("/health")
def health():
    return jsonify(service="product-service", status="healthy"), 200

@app.get("/")
def index():
    return jsonify(service="product-service", message="Product Service is running"), 200

@app.get("/products")
def list_items():
    return jsonify(products=products), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8002)
