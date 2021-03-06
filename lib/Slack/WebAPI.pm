package Slack::WebAPI;

use strict;
use warnings;
use utf8;
use Encode 'encode_utf8';
use feature 'say';
use File::Temp 'tempfile';
use HTTP::Request::Common;
use Furl;
use Parallel::ForkManager;
use Mouse;

has token => (is => 'ro', isa => 'Str');
has channel_id => (is => 'ro', isa => 'Str');

my $pm = new Parallel::ForkManager(16);
my $http = new Furl;

sub notify {
  my ($self, $tweet) = @_;

  $pm->start and return;

  my $reply_user = $tweet->{in_reply_to_user_id};
  my $reply_status = $tweet->{in_reply_to_status_id};
  my $reply_url = ($reply_user and $reply_status)
                  ? "\n\nIn reply to\nhttps://twitter.com/$reply_user/status/$reply_status"
                  : '';

  say encode_utf8 $tweet->{user}{name};
  say encode_utf8 $tweet->{text};
  say encode_utf8 $tweet->{created_at};

  eval {
    $http->post(
      'https://slack.com/api/chat.postMessage',
      [],
      [
        token => $ENV{COVFEFE_SLACK_TOKEN},
        channel => $ENV{COVFEFE_SLACK_CHANNEL_ID},
        icon_url => $tweet->{user}{profile_image_url_https},
        username => encode_utf8 $tweet->{user}{name}.' @'.$tweet->{user}{screen_name},
        text => encode_utf8 $tweet->{text}.$reply_url
      ]
    );
  };
  warn "WARNING: $@" if $@;

  $pm->finish;
}

sub upload {
  my ($self, $media) = @_;

  if (my $video = $media->[0]{video_info}{variants}) {
    $pm->start and return;

    for (@$video) { $_->{bitrate} = 0 unless $_->{bitrate} }
    my $url = (sort { $b->{bitrate} <=> $a->{bitrate} } @$video)[0]{url};
    say $url;
    my $binary = $http->get($url);
    die 'Cannot fetch video: '.$url
      if grep {$_ eq $binary->code} (404, 500);
    my ($tmpfh, $tmpfile) = tempfile(UNLINK => 1);
    say $tmpfh $binary->content;
    close $tmpfh;
    eval {
      $http->request(POST (
        'https://slack.com/api/files.upload',
        'Content-Type' => 'form-data',
        'Content' => [
          token => $ENV{COVFEFE_SLACK_TOKEN},
          channels => $ENV{COVFEFE_SLACK_CHANNEL_ID},
          file => [$tmpfile]
        ]
      ));
    };
    warn "WARNING: $@" if $@;
    unlink $tmpfile;

    $pm->finish;
  } else {
    for (@$media) {
      $pm->start and next;

      say $_->{media_url};

      my $binary = $http->get($_->{media_url});
      die 'Cannot fetch image: '.$_->{media_url}
        if grep {$_ eq $binary->code} (404, 500);
      my ($tmpfh, $tmpfile) = tempfile(UNLINK => 1);
      say $tmpfh $binary->content;
      close $tmpfh;
      eval {
        $http->request(POST (
          'https://slack.com/api/files.upload',
          'Content-Type' => 'form-data',
          'Content' => [
            token => $ENV{COVFEFE_SLACK_TOKEN},
            channels => $ENV{COVFEFE_SLACK_CHANNEL_ID},
            file => [$tmpfile]
          ]
        ));
      };
      warn "WARNING: $@" if $@;
      unlink $tmpfile;

      $pm->finish;
    }
  }
}