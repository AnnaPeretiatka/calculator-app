from flask import Flask, jsonify, redirect, url_for
app = Flask(__name__)
@app.get("/health")
def health():
    return jsonify({"status": "ok"}), 200
@app.get("/")
def root():
    return redirect(url_for('health'))
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
