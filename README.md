# covfefe-x
Covfefeは不滅

## Get started

```
cp settings.yml.sample settings.yml
vim settings.yml
  # credentials: Your Twitter and Slack API tokens
  # target: Your target Twitter "User ID" (Not "Screen name")
  # slack_channel_id: Slack channel ID of destination to notify (Not channel name)

docker-compose build
docker-compose run --rm app carton install
docker-compose up -d
```