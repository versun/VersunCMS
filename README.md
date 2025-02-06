# VersunCMS

My CMS for my [website](https://versun.me).

This won't work out of the box for anyone else, but you're welcome to take a look at the code to see how it works.

## Requirements

- Docker
- PostgreSQL database

## Environment Variables

The following environment variables are required:
```
SECRET_KEY_BASE=
PGHOST=
PGUSER=
PGPASSWORD=
DATABASE=
SOLID_QUEUE_IN_PUMA=1
```

## Deployment

Use the provided Dockerfile to build and deploy the application.