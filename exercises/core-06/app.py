import os
from flask import Flask

app = Flask(__name__)


@app.route("/")
def hello_world():
    return "Hello from a configurable app!"


if __name__ == "__main__":
    # Read the required PORT environment variable.
    port = int(os.environ["PORT"])
    # Run the app, listening on all interfaces
    app.run(host="0.0.0.0", port=port)
