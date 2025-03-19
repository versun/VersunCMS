dev:
  env $(cat .env.dev | xargs) bin/rails s
prod:
  env $(cat .env.prod | xargs) bin/rails s
lint:
  bin/rubocop -A
