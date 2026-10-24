Directory: exercises/core-06

This exercise will introduce you to more `Dockerfile` instructions for adding metadata and making your images more configurable.

- `LABEL`: Adds metadata to an image, such as the maintainer's email or a version number.
- `ENV`: Sets persistent environment variables that are available during the build and when a container is run from the image.
- `EXPOSE`: Documents which port the application listens on.
- `CMD`: Specifies the default command to run when a container starts.

## Your Task

In this directory, you will find a `Dockerfile` and a simple Python Flask application. Your task is to **modify the `Dockerfile`** to perform the following:

1.  **Add a `LABEL`** to the image. The key should be `org.dockerlings.author` and the value should be your name or email (e.g., `"Jane Doe <jane.doe@example.com>"`).
2.  **Set an `ENV`** variable named `PORT` with a value of `8000`.
3.  **Add an `EXPOSE` instruction** for port `8000`.
4.  **Set the `CMD`** to start the Flask application. The application (`app.py`) already reads the `PORT` environment variable to determine which port to listen on.

The verification script will build your `Dockerfile`, inspect it for the correct `LABEL` and `ENV`, and then run it to ensure the application starts on the port you specified.
