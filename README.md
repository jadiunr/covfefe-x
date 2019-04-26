# covfefe-x
Covfefeは不滅

## Get started

```
cp settings.yml.sample settings.yml
vim settings.yml
  # credentials: Your Twitter API keys
  # target: Your target Twitter "User ID" (Not "Screen name")

docker-compose build
docker-compose run --rm app carton install
docker-compose up -d
```