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
my $old_tweet_ids = [];
my $tweets = $nt->user_timeline({user_id => $ENV{COVFEFE_TWITTER_TARGET_ID}, count => 30});
push(@$old_tweet_ids, $_->{id}) for @$tweets;

say 'Capture begin.';
# Crawling routine
while (1) {
  my $tmp_tweets = eval { $nt->user_timeline({user_id => $ENV{COVFEFE_TWITTER_TARGET_ID}, count => 30}) };
  warn "WARNING: $@" and next if $@;
  $tweets = $tmp_tweets;
  for my $i (reverse 0..5) {
    unless (grep {$_ eq $tweets->[$i]{id}} @$old_tweet_ids) {
      $slack->notify($tweets->[$i]);
      my $media = $tweets->[$i]{extended_entities}{media};
      $slack->upload($media) if $media;
    }
  }
  my $latest_tweet_ids = [];
  push(@$latest_tweet_ids, $_->{id}) for @$tweets;
  $old_tweet_ids = $latest_tweet_ids;

  sleep(2);
}