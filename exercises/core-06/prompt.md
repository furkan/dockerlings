Directory: exercises/core-06

This exercise will introduce you to more `Dockerfile` instructions for adding metadata and making your images more configurable.

- `LABEL`: Adds metadata to an image, such as the maintainer's email or a version number.
- `ENV`: Sets persistent environment variables that are available during the build and when a container is run from the image.
- `CMD`: Specifies the default command to run when a container starts. We'll see how it can use environment variables.

## Your Task

In this directory, you will find a `Dockerfile` and a simple Python Flask application. Your task is to **modify the `Dockerfile`** to perform the following:

1.  **Add a `LABEL`** to the image. The key should be `org.dockerlings.author` and the value should be your name or email (e.g., `"Jane Doe <jane.doe@example.com>"`).
2.  **Set an `ENV`** variable named `PORT` with a value of `8000`.
3.  **Use the `EXPOSE`** instruction and use the `$PORT` environment variable to run the Flask application on the correct port. The application (`app.py`) is already written to read this environment variable.
4. **Set the default `CMD`** to run the Flask application when the container starts.

The verification script will build your `Dockerfile`, inspect it for the correct `LABEL` and `ENV`, and then run it to ensure the application starts on the port you specified.
