use strict;
use warnings;
use utf8;

use Net::Twitter::Lite::WithAPIv1_1;
use YAML::Tiny;
use Furl;
use HTTP::Request::Common;
use File::Temp qw/ tempfile /;

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $settings = YAML::Tiny->read('./settings.yml')->[0];
my $keys = $settings->{'credentials'};

my $http = Furl->new();

# Authentication
my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
  consumer_key        => $keys->{'consumer_key'},
  consumer_secret     => $keys->{'consumer_secret'},
  access_token        => $keys->{'access_token'},
  access_token_secret => $keys->{'access_token_secret'}
);

print "Initialize now.\n";
# Initialize
my $old_tweet_ids = [];
my $tweets = $nt->user_timeline({user_id => $settings->{'target'}, count => 30});
for (@$tweets) {
  push(@$old_tweet_ids, $_->{'id'});
}

print "Capture begin.\n";
# Crawling routine
while (1) {
  $tweets = $nt->user_timeline({user_id => $settings->{'target'}, count => 30});
  for (my $i = 0; $i < 6; $i++) {
    unless (grep {$_ eq $tweets->[$i]{'id'}} @$old_tweet_ids) {
      my $name = $tweets->[$i]{'user'}{'name'};
      my $text = $tweets->[$i]{'text'};
      my $media = $tweets->[$i]{'extended_entities'}{'media'};
      my $date = $tweets->[$i]{'created_at'};
      print $name, "\n", $text, "\n", $date, "\n\n";

      if ($media) {
        $http->post(
          'https://slack.com/api/chat.postMessage',
          [],
          [
            token => $keys->{'slack_token'},
            channel => $settings->{'slack_channel_id'},
            text => "${name}\n${text}\n${date}"
          ]
        );
        for (@$media) {
          my $image = $http->get("$_->{'media_url'}:large");
          my ($tmpfh, $tmpfile) = tempfile(UNLINK => 1);
          print $tmpfh $image->content;
          close $tmpfh;
          my $res = $http->request(POST (
            'https://slack.com/api/files.upload',
            'Content-Type' => 'form-data',
            'Content' => [
              token => $keys->{'slack_token'},
              channels => $settings->{'slack_channel_id'},
              file => [$tmpfile]
            ]
          ));
          unlink $tmpfile;
        }
      } else {
        $http->post(
          'https://slack.com/api/chat.postMessage',
          [],
          [
            token => $keys->{'slack_token'},
            channels => $settings->{'slack_channel_id'},
            text => "${name}\n${text}\n${date}"
          ]
        );
      }
    }
  }
  my $latest_tweet_ids = [];
  for (@$tweets) {
    push(@$latest_tweet_ids, $_->{'id'});
  }
  $old_tweet_ids = $latest_tweet_ids;

  sleep(3);
}