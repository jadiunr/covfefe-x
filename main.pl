use strict;
use warnings;
use utf8;
use Encode qw/ encode_utf8 /;
use feature 'say';

use Net::Twitter::Lite::WithAPIv1_1;
use YAML::Tiny;
use Furl;
use HTTP::Request::Common;
use File::Temp qw/ tempfile /;
use Parallel::ForkManager;

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $settings = YAML::Tiny->read('./settings.yml')->[0];
my $http = Furl->new();
my $pm = Parallel::ForkManager->new(8);

# Autoflush
$|=1;

# Authentication
my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
  consumer_key        => $settings->{credentials}{consumer_key},
  consumer_secret     => $settings->{credentials}{consumer_secret},
  access_token        => $settings->{credentials}{access_token},
  access_token_secret => $settings->{credentials}{access_token_secret}
);

say 'Initialize now.';
# Initialize
my $old_tweet_ids = [];
my $tweets = $nt->user_timeline({user_id => $settings->{target}, count => 30});
push(@$old_tweet_ids, $_->{id}) for @$tweets;

say 'Capture begin.';
# Crawling routine
while (1) {
  $tweets = eval { $nt->user_timeline({user_id => $settings->{target}, count => 30}) };
  warn "WARNING: $@" if $@;
  for my $i (reverse 0..5) {
    unless (grep {$_ eq $tweets->[$i]{id}} @$old_tweet_ids) {
      my $tweet;
      $tweet->{user} = $tweets->[$i]{user};
      $tweet->{text} = $tweets->[$i]{text};
      $tweet->{media} = $tweets->[$i]{extended_entities}{media};
      $tweet->{date} = $tweets->[$i]{created_at};
      if ($tweet->{media}) {
        notify($http, $settings, $tweet);
        for (@{$tweet->{media}}) {
          $pm->start and next;
          upload($http, $settings, $_);
          $pm->finish;
        };
      } else {
        notify($http, $settings, $tweet);
      }
      say '';
    }
  }
  my $latest_tweet_ids = [];
  push(@$latest_tweet_ids, $_->{id}) for @$tweets;
  $old_tweet_ids = $latest_tweet_ids;

  sleep(3);
}

sub notify {
  my ($http, $settings, $tweet) = @_;

  say $tweet->{user}{name};
  say $tweet->{text};
  say $tweet->{date};

  eval {
    $http->post(
      'https://slack.com/api/chat.postMessage',
      [],
      [
        token => $settings->{credentials}{slack_token},
        channel => $settings->{slack_channel_id},
        icon_url => $tweet->{user}{profile_image_url_https},
        username => encode_utf8 $tweet->{user}{name},
        text => encode_utf8 $tweet->{text}
      ]
    );
  };
  warn "WARNING: $@" if $@;
}

sub upload {
  my ($http, $settings, $media) = @_;
  say $media->{media_url};
  my $image = eval { $http->get($media->{media_url}) };
  warn "WARNING: $@" if $@;
  my ($tmpfh, $tmpfile) = tempfile(UNLINK => 1);
  say $tmpfh $image->content;
  close $tmpfh;
  eval {
    $http->request(POST (
      'https://slack.com/api/files.upload',
      'Content-Type' => 'form-data',
      'Content' => [
        token => $settings->{credentials}{slack_token},
        channels => $settings->{slack_channel_id},
        file => [$tmpfile]
      ]
    ));
  };
  warn "WARNING: $@" if $@;
  unlink $tmpfile;
}