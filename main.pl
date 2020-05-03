use strict;
use warnings;
use utf8;
use feature 'say';

use Net::Twitter;

use lib 'lib';
use Slack::WebAPI;

# Autoflush
$|=1;

my $nt = Net::Twitter->new(
  traits              => ['API::RESTv1_1'],
  consumer_key        => $ENV{COVFEFE_TWITTER_CK},
  consumer_secret     => $ENV{COVFEFE_TWITTER_CS},
  access_token        => $ENV{COVFEFE_TWITTER_AT},
  access_token_secret => $ENV{COVFEFE_TWITTER_ATS}
);

my $slack = Slack::WebAPI->new(
  token => $ENV{COVFEFE_SLACK_TOKEN},
  channel_id => $ENV{COVFEFE_SLACK_CHANNEL_ID}
);

say 'Initialize now.';
# Initialize
my $tweets = $nt->user_timeline({user_id => $ENV{COVFEFE_TWITTER_TARGET_ID}, count => 30});
my $since_id = $tweets->[0]{id};

say 'Capture begin.';
# Crawling routine
while(1) {
  $tweets = eval { $nt->user_timeline({user_id => $ENV{COVFEFE_TWITTER_TARGET_ID}, count => 30, since_id => $since_id}) };
  warn "WARNING: $@" and next if $@;

  if (@$tweets) {
    for my $tweet (reverse @$tweets) {
      $slack->notify($tweet);
      my $media = $tweet->{extended_entities}{media};
      $slack->upload($media) if $media;
    }
    $since_id = $tweets->[0]{id}
  }

  sleep 2;
}