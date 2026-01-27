Follow this sequence of commands to set up the persistent database.

1.  **Create the host directory:**
    `docker volume create pgdata`

2.  **Run the first container instance:**
    The `-v pgdata:/var/lib/postgresql/data` flag maps your new volume into the container.
    ```bash
    docker run -d \
      --name c8-postgres \
      -e POSTGRES_PASSWORD=mysecretpassword \
      -v pgdata:/var/lib/postgresql/data \
      postgres:16
    ```
    *(Wait about 20 seconds for the database to initialize. Check its status with `docker logs c8-postgres`.)*

3.  **Create a table inside the database:**
    Use `docker exec` to run the `psql` command as the default `postgres` user.
    ```bash
    docker exec c8-postgres psql -U postgres -c "CREATE TABLE dvd_rentals (title TEXT);"
    ```

4.  **Insert the specific row of data:**
    ```bash
    docker exec c8-postgres psql -U postgres -c "INSERT INTO dvd_rentals (title) VALUES ('The Grand Budapest Hotel');"
    ```

---

### How to Verify for Yourself (The "Aha" Moment)

1.  **Destroy the container:**
    ```bash
    docker stop c8-postgres && docker rm c8-postgres
    ```

2.  **Run a new container instance on the same data:**
    ```bash
    docker run -d \
      --name c8-postgres \
      -e POSTGRES_PASSWORD=mysecretpassword \
      -v "$(pwd)/pgdata":/var/lib/postgresql/data \
      postgres:16
    ```
    *(Wait a few moments for it to start.)*

3.  **Check if your data is still there:**
    ```bash
    docker exec c8-postgres psql -U postgres -c "SELECT * FROM dvd_rentals;"
    ```
