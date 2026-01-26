Directory: exercises/core-08

Containers are ephemeral, meaning any changes made inside them are lost when they are removed. For applications like databases, the data must persist. This exercise demonstrates how **volumes** solve this by having Docker create a volume it manages and lets you use with the container, ensuring data persistence even if the container is removed.

## Your Task

Your task is to create a persistent PostgreSQL database. You will run a container, add data to it, remove the container, and then verify that the data is still safe on your host machine.

1.  **Create a volume** on your host machine, via Docker, named `pgdata`. This volume will be created and managed by Docker and will hold your database files.
    `docker volume create pgdata`

2.  **Run a `postgres:16` container**. Name it `c8-postgres` and use the volume Docker created (`pgdata`) to mount to the container's data directory (`/var/lib/postgresql/data`).
    *(Wait 15-20 seconds for the database to initialize the first time).*

3.  **Create a table** using `docker exec` to run the `psql` client inside the container. The table should be named `dvd_rentals`.

4.  **Insert a row** into your new table. The row should contain the title `The Grand Budapest Hotel`.

### The "Aha" Moment (Highly Recommended)

This is the core concept of volumes. To see it in action:

1.  **Stop and remove the container**: `docker stop c8-postgres && docker rm c8-postgres`.
2.  Your container is gone, but the `pgdata` directory on your host remains.
3.  **Run a new container** using the *exact same `docker run` command* as before.
4.  **Verify your data**: `exec` into this new container and run `SELECT * FROM dvd_rentals;`. You will see the movie title you added earlier has reappeared!

### Final State

To complete the exercise, the checker needs to find the `pgdata` directory containing the database with the `dvd_rentals` table and the correct row. You can **leave the container running or stopped**, as the checker will only inspect the `pgdata` directory itself.
