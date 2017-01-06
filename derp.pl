#!/usr/bin/env perl
use utf8;
use strict;
use warnings;

my $timeout = 200;

use IO::Select;

use JSON;
use LWP::UserAgent;

$SIG{CHLD} = "IGNORE";

my $fh;
open $fh, "<", "apikey" or die "Could not open file `apikey': $!\nPlease place your api key in an file named `apikey'.\n";
my $apikey = <$fh>;
chomp $apikey;
close $fh;

sub api_call {
    my ($ua, $method, $content) = @_;

    my $req = HTTP::Request->new("POST", "https://api.telegram.org/bot$apikey/$method");
    $req->header("Content-Type" => "application/json");
    $req->content(encode_json($content));

    my $http_response = $ua->request($req);
    if ($http_response->code != 200) {
        printf STDERR "NON-OK HTTP STATUS: %s\n", $http_response->status_line;
        print STDERR $http_response->content, "\n";
    }
    my $response;
    my $asdf = eval {
        $response = decode_json($http_response->content);
    };
    if (not defined $asdf) {
        $response = {
            ok => 0,
            description => "Error parsing JSON\n$@",
            result => []
        };
    }

    if (!$response->{ok}) {
        print STDERR "Error calling method $method with content\n$content\n" . $response->{description} . "\n";
    }

    return $response;
}

sub send_message {
    my %args = @_;
    my $text = $args{text};
    my $chat_id = $args{chat_id};
    my $reply_id = $args{reply_id};
    my $parse_mode = $args{parse_mode};
    my $ua = $args{ua};

    my $content = {
        chat_id => $chat_id,
        text => $text
    };
    $content->{reply_to_message_id} = $reply_id if defined $reply_id;
    $content->{parse_mode} = $parse_mode if defined $parse_mode;

    api_call($ua, "sendMessage", $content);
}

sub reply {
    my ($reply_to, $ua, $reply_text, $parse_mode) = @_;
    send_message(text => $reply_text,
                 chat_id => $reply_to->{chat}->{id},
                 reply_id => $reply_to->{message_id},
                 parse_mode => $parse_mode,
                 ua => $ua);
}

my %commands = (
    "ping" => sub {
        my ($ua, $msg) = @_;
        reply($msg, $ua, "pong");
    },
    "snowman" => sub {
        my ($ua, $msg) = @_;
        my ($parse_mode, $snowman) = $msg->{text} =~ m/\/snowman_?(\w+)?\S*\s+(.+)/s;
        if (not defined $snowman) {
            reply($msg, $ua, "https://github.com/keyboardfire/snowman-lang");
            return;
        }

        $SIG{CHLD}="";
        open my $file, '>', "/tmp/$$.snowman";
        print $file $snowman;
        close $file;

        my $output = `timeout -k 5 3 snowman /tmp/$$.snowman 2>&1`;

        if ($? >> 8 == 124) {
            reply($msg, $ua, "Error: Timeout");
        } elsif ($output eq "") {
            reply($msg, $ua, "No output");
        } else {
            $parse_mode = "markdown" if defined $parse_mode and
                                        $parse_mode eq "md";
            reply($msg, $ua, $output, $parse_mode);
        }
        unlink "/tmp/$$.snowman";
    },
    "info" => sub {
        my ($ua, $msg) = @_;
        reply($msg, $ua, "https://github.com/0e4ef622/anbot");
    }
);

sub on_message {
    my $msg = $_[0];
    return unless defined $msg->{text};

    my $ua = LWP::UserAgent->new();


    my $text = $msg->{text};
    my $ltext = lc $text;
    if ($ltext =~ m/^\/vim.*wan$/s) {
        send_message(text => ("​" x (rand() * 5 + 1)) . "d" . ("​" x (rand() * 5 + 1)) . "o" . ("​" x (rand() * 5 + 1)) . "w" . ("​" x (rand() * 5 + 1)) . "s" . ("​" x (rand() * 5 + 1)),
                     chat_id => $msg->{chat}->{id},
                     ua => $ua);
    } elsif ($ltext =~ m/^\/([A-Za-z]+)(?:_\w+)?(\@tehanbot\b)?(?:\s*.*?)?$/s) {

        if (defined $commands{$1}) {
            $commands{$1}->($ua, $msg);
        } elsif (defined $2) {
            reply($msg, $ua, "Unknown command /$1");
        }

    } elsif (defined $msg->{reply_to_message} and
             $msg->{reply_to_message}->{from}->{username} eq "tehAnBot" and
             $msg->{reply_to_message}->{text} eq "an*") {
             # if someone replied to an "an*"

        reply($msg, $ua, ".-.") if not $text =~ m/^\%+/;

    #} elsif (rand() < .01 * scalar($ltext =~ m/\b{wb}(a|а)\b{wb}/g)) {
    } elsif (my $c =()= $ltext =~ m/\b{wb}(a|а)\b{wb}/g) {

        reply($msg, $ua, "an*") if rand() < .05*$c;

    } elsif ($ltext eq "qbec") {
        reply($msg, $ua, "V nterr");
    } elsif ($ltext eq "dorp") {
        reply($msg, $ua, "I agree");
    }
    printf "%s(%d):%s> %s\n", $msg->{chat}->{title} || $msg->{chat}->{username},
                        $msg->{chat}->{id},
                        $msg->{from}->{username},
                        $msg->{text};
}

if (!fork) {

    my $ua = LWP::UserAgent->new(timeout => $timeout, keep_alive => 1);
    my $offset = 0;
    while (1) {

        my $res = api_call($ua, "getUpdates", {
                offset => $offset,
                timeout => $timeout,
                allowed_updates => []
            });

        if (not $res->{ok}) {
            print STDERR "Error (" . $res->{error_code} . ": " . $res->{description};
            next;
        }

        for my $update (@{ $res->{result} }) {
            $offset = $update->{update_id} + 1;

            my $msg = $update->{message};
            next if not defined $msg;

            if (not fork) {
                on_message($msg);
                exit 0;
            }
        }
    }
} else {

    #my $select = IO::Select->new();
    #$select->add(\*STDIN);
    my $ua = LWP::UserAgent->new();

    while (<STDIN>) {

        if ($_ =~ /^msg (-?\d+) (.+)$/) {
            send_message(chat_id => $1,
                    text => $2,
                    ua => $ua);
        }
    }
}
