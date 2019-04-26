use strict;
use warnings;
use utf8;
use Net::Twitter::Lite::WithAPIv1_1;
use YAML::Tiny;

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

my $settings = YAML::Tiny->read('./settings.yml')->[0];
my $key = $settings->{'credentials'};
my $target = $settings->{'target'};

# Authentication
my $nt = Net::Twitter::Lite::WithAPIv1_1->new(
  consumer_key        => $key->{'consumer_key'},
  consumer_secret     => $key->{'consumer_secret'},
  access_token        => $key->{'access_token'},
  access_token_secret => $key->{'access_token_secret'}
);

print "Initialize now.\n";
# Initialize
my $old_tweet_ids = [];
my $tweets = $nt->user_timeline({user_id => $target, count => 30});
for (@$tweets) {
  push(@$old_tweet_ids, $_->{'id'});
}

print "Capture begin.\n";
# Crawling routine
while (1) {
  $tweets = $nt->user_timeline({user_id => $target, count => 30});
  for (my $i = 0; $i < 6; $i++) {
    unless(grep {$_ eq $tweets->[$i]{'id'}} @$old_tweet_ids) {
      my $name = $tweets->[$i]{'user'}{'name'};
      my $text = $tweets->[$i]{'text'};
      # my $media = $tweets->[$i]{'extended_entities'}{'media'};
      my $date = $tweets->[$i]{'created_at'};
      print $name, "\n",
            $text, "\n",
            $date, "\n\n";
    }
  }
  my $latest_tweet_ids = [];
  for (@$tweets) {
    push(@$latest_tweet_ids, $_->{'id'});
  }
  $old_tweet_ids = $latest_tweet_ids;

  sleep(3);
}