# VersunCMS

My CMS for my [website](https://versun.me).

This won't work out of the box for anyone else, but you're welcome to take a look at the code to see how it works.

## Requirements

- Ruby 3.x
- SQLite3
- Docker (for production deployment)

## Development

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Setup the database:
   ```bash
   bin/rails db:prepare
   ```

3. Start the development server:
   ```bash
   bin/dev
   ```

## Environment Variables

The following environment variables are required for production:

```
SECRET_KEY_BASE=
SOLID_QUEUE_IN_PUMA=1
```

- `SOLID_QUEUE_IN_PUMA`: Set to `1` to run the Solid Queue supervisor inside Puma (recommended for single-server deployments).

## Docker

To build and run the application using Docker Compose:

```bash
docker-compose up --build
```

## Deployment

Use the provided Dockerfile to build and deploy the application.

## Volume Mounts

For data persistence, you need to mount the following directories:
- `/rails/storage`: For storing uploaded files and assets
- `/rails/public`: For serving static files
