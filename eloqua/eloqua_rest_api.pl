#!/usr/bin/perl -w
#
#

use LWP::Simple;
use LWP::UserAgent;
use HTML::TokeParser;
use HTML::Parser;
use HTTP::Headers;
use HTTP::Request::Common;
use HTTP::Cookies;
use Data::Dumper;
use JSON;
use strict;

my $url = 'https://secure.eloqua.com/API/REST/1.0/assets/email/deployment/123';

my $ua = LWP::UserAgent->new;
$ua->agent("Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)");


my $req1 = HTTP::Request->new(GET => $url);

my	$h = new HTTP::Headers;
	$h->authorization_basic('Organization\User.Name', 'password');

	my $request = HTTP::Request->new(GET => $url, $h);	
	my $response = $ua->request($request);


if ( $response->is_error ) {
    print "GET failed: " . $response->as_string;
    exit 1;
}
my @content = $response->content;
my $json = decode_json(@content);

#print Dumper $json;
#print "\n\n";
#print @content;
print (  $json->{successfulSendCount}  );
print "\n";
#my $point = $json->{total};

exit 0;

