#!/usr/bin/env perl
use utf8;
use strict;
use warnings;

my $version = "v1.2.4";
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

    my $res = api_call($ua, "sendMessage", $content);
    my $msg = $res->{result};

    printf "%s(%d:%d):%s> %s\n", $msg->{chat}->{title} || $msg->{chat}->{username},
                        $msg->{chat}->{id},
                        $msg->{message_id},
                        $msg->{from}->{username},
                        $msg->{text};
}

sub reply {
    my ($reply_to, $ua, $reply_text, $rot13, $parse_mode) = @_;
    $rot13 && $reply_text =~ tr/N-ZA-Mn-za-m/A-Za-z/;
    send_message(text => $reply_text,
                 chat_id => $reply_to->{chat}->{id},
                 reply_id => $reply_to->{message_id},
                 parse_mode => $parse_mode,
                 ua => $ua);
}

sub kindof_reply {
    my ($reply_to, $ua, $reply_text, $rot13, $parse_mode) = @_;
    $rot13 && $reply_text =~ tr/N-ZA-Mn-za-m/A-Za-z/;
    send_message(text => $reply_text,
                 chat_id => $reply_to->{chat}->{id},
                 parse_mode => $parse_mode,
                 ua => $ua);
}

my %commands = (
    "ping" => sub {
        my ($ua, $msg, $rot13) = @_;
        reply($msg, $ua, "pong", $rot13);
    },
    "snowman" => sub {
        my ($ua, $msg, $rot13) = @_;
        my ($parse_mode, $snowman) = $msg->{text} =~ m/\/snowman_?(\w+)?\S*\s+(.+)/s;
        if (not defined $snowman) {
            reply($msg, $ua, "https://github.com/keyboardfire/snowman-lang", $rot13);
            return;
        }

        $SIG{CHLD}="";
        open my $file, '>', "/tmp/$$.snowman";
        print $file $snowman;
        close $file;

        open my $input, '>', "/tmp/$$.snowman.in";
        print $input $msg->{reply_to_message}->{text};
        close $input;

        my $output = `timeout -k 5 3 snowman /tmp/$$.snowman < /tmp/$$.snowman.in 2>&1`;

        if ($? >> 8 == 124) {
            reply($msg, $ua, "Error: Timeout", $rot13);
        } elsif ($output eq "") {
            reply($msg, $ua, "No output", $rot13);
        } elsif (length $output > 4096) {
            reply($msg, $ua, "Output longer than 4096 characters", $rot13);
        } else {
            $parse_mode = "markdown" if defined $parse_mode and
                                        $parse_mode eq "md";
            reply($msg, $ua, $output, $rot13, $parse_mode);
        }
        unlink "/tmp/$$.snowman";
        unlink "/tmp/$$.snowman.in";
    },
    "info" => sub {
        my ($ua, $msg, $rot13) = @_;
        reply($msg, $ua,
            "https://github.com/0e4ef622/anbot\n" .
            "Running $version", $rot13);
    }
);


sub on_message {
    my $msg = $_[0];
    my $rot13 = $_[1];
    $rot13 && $msg->{text} =~ tr/N-ZA-Mn-za-m/A-Za-z/;
    $rot13 && $msg->{caption} =~ tr/N-ZA-Mn-za-m/A-Za-z/;
    my $text = $msg->{text} || $msg->{caption};
    my $responded = 0;
    return unless defined $text;

    my $ua = LWP::UserAgent->new();


    my $ltext = lc $text;
    if ($ltext =~ m/^\/vim.*wan$/s) {
        kindof_reply($msg, $ua, ("​" x (rand() * 5 + 1)) . "d" . ("​" x (rand() * 5 + 1)) . "o" . ("​" x (rand() * 5 + 1)) . "w" . ("​" x (rand() * 5 + 1)) . "s" . ("​" x (rand() * 5 + 1)), $rot13);
        $responded = 1;
    } elsif ($ltext =~ m/^\/([A-Za-z]+)(?:_\w+)?(\@tehanbot\b)?(?:\s*.*?)?$/s) {

        if (defined $commands{$1}) {
            $commands{$1}->($ua, $msg, $rot13);
        } elsif (defined $2) {
            reply($msg, $ua, "Unknown command /$1", $rot13);
        }

    } elsif (defined $msg->{reply_to_message} and
             $msg->{reply_to_message}->{from}->{username} eq "tehAnBot" and
             $msg->{reply_to_message}->{text} eq "an*") {
             # if someone replied to an "an*"

        reply($msg, $ua, ".-.") if not $text =~ m/^\%+/;

        $responded = 1;

    } elsif (defined $msg->{reply_to_message} and
             $msg->{reply_to_message}->{from}->{username} eq "tehAnBot" and
             $msg->{reply_to_message}->{text} eq ".-.") {

        reply($msg, $ua, "pls") if $text == "._.";

        $responded = 1;

    } elsif (defined $msg->{reply_to_message} and
             $msg->{reply_to_message}->{from}->{username} eq "tehAnBot" and
             $msg->{reply_to_message}->{text} eq "pls") {

        reply($msg, $ua, ":)") if $text == "slp";

        $responded = 1;

    } elsif (defined $msg->{reply_to_message} and
             $msg->{reply_to_message}->{from}->{username} eq "tehAnBot" and
             $msg->{reply_to_message}->{text} eq ":)") {

        reply($msg, $ua, "mfw") if $text == ":(";

        $responded = 1;

    } elsif (defined $msg->{reply_to_message} and
             $msg->{reply_to_message}->{from}->{username} eq "tehAnBot" and
             $msg->{reply_to_message}->{text} eq "mfw") {

        reply($msg, $ua, ".-.") if $text == "tfw";

        $responded = 1;

    } elsif (my $c =()= $ltext =~ m/\b{wb}(a|а)\b{wb}/g) {

        reply($msg, $ua, "an*", $rot13) if rand() < .05;

        $responded = 1;

#    } elsif ($ltext eq "qbec") {
#        reply($msg, $ua, "V nterr");
#        $responded = 1;
    } elsif ($ltext eq "dorp") {
        reply($msg, $ua, "I agree", $rot13);
        $responded = 1;
    } elsif ($ltext eq "meems") {
        kindof_reply($msg, $ua, "meems", $rot13);
        $responded = 1;
#    } elsif ($ltext eq "zrrzf") {
#        kindof_reply($msg, $ua, "zrrzf");
#        $responded = 1;
    }
    return $responded;
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
            print STDERR "Error " . $res->{error_code} . ": " . $res->{description};
            next;
        }

        for my $update (@{ $res->{result} }) {
            $offset = $update->{update_id} + 1;

            my $msg = $update->{message};
            next if not defined $msg;

            rand;
            # the reason for the existence of the
            # above line is left as an exercise to
            # the reader ;)
            if (not fork) {
                printf "%s(%d:%d):%s> %s\n", $msg->{chat}->{title} || $msg->{chat}->{username},
                                             $msg->{chat}->{id},
                                             $msg->{message_id},
                                             $msg->{from}->{username},
                                             $msg->{text} || $msg->{caption};
                on_message($msg) or on_message($msg, 1);
                exit 0;
            }
        }
    }
} else {

    my $ua = LWP::UserAgent->new();

    while (<STDIN>) {

        if ($_ =~ /^msg (-?\d+) (.+)$/) {
            send_message(chat_id => $1,
                    text => $2,
                    ua => $ua);
        } elsif ($_ =~ /^reply (-?\d+):(-?\d+) (.+)$/) {
            send_message(chat_id => $1,
                    reply_id => $2,
                    text => $3,
                    ua => $ua);
        }
    }
}
