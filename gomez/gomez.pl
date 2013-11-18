#!/usr/bin/perl -w
#
# gomez.pl - pull some page stats from Gomez through the painful XML API
#
# <insert rant about Perl XML parsing libraries in general>
#
# Rod Cordova (@gitrc)
#

use strict;
use LWP::UserAgent;
use Data::Dumper;
use URI::Escape;
use HTTP::Headers;
use RRDs;

my $debug;
$debug = exists( $ENV{SSH_CLIENT} ) ? 1 : 0;

# too many perl ways to do this
my $begintime = qx(date -d '1 hour ago' +%Y-%m-%dT%H:%M:00);
my $endtime   = qx(date -d 'now' +%Y-%m-%dT%H:%M:00);

# Pagename/ID hash

my %pageIds = (
    '1234567' => 'Support',
    '1234567' => 'Homepage',
);

my $xml_payload =
qq {<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:web="http://gomeznetworks.com/webservices/">
   <soapenv:Header>
      <web:CredentialSoapHeader>
         <web:Username>api_username</web:Username>
         <web:Password>password</web:Password>
      </web:CredentialSoapHeader>
   </soapenv:Header>
   <soapenv:Body>
      <web:GetMetricTime>
         <web:pageList>
            <web:int>5100524</web:int>
            <web:int>5211217</web:int>
            <web:int>5126998</web:int>
            <web:int>5100525</web:int>
            <web:int>5100536</web:int>
            <web:int>5139666</web:int>
         </web:pageList>
          <web:startTime>$begintime</web:startTime>
<web:endTime>$endtime</web:endTime> 
	<web:timeBreakdown>60</web:timeBreakdown> 
<web:dataType>Average</web:dataType> 
         <web:srcType>RAW</web:srcType>
      </web:GetMetricTime>
   </soapenv:Body>
</soapenv:Envelope>};

my $post_url =
"http://gpn.webservice.gomez.com/axfwebservice/AXFDataExportServiceChart.asmx";

my $headers = new HTTP::Headers(
    'SOAPAction' => 'http://gomeznetworks.com/webservices/GetMetricTime', );
my $request = new HTTP::Request( "POST", $post_url, $headers );

$request->content($xml_payload);
$request->content_type('text/xml');

my $ua = LWP::UserAgent->new;

my $response = $ua->request($request);
my $content  = $response->content;

#print Dumper $content;
#print "\n";
#exit 0;

$content =~ /(\w+)="(\d+)"/g;

my %pages;

#print Dumper $content;
$content =~ s/"//g;
while ( $content =~
    /Page_id=(\d+).+Page_load_time_avg=(\d+).+Page_load_time_valid_views=(\d+)/g
  )
{
    my $time = ( $2 / 1000 );
    print "$pageIds{$1}: time:$time samples:$3\n" if $debug;
    $pages{ $pageIds{$1} } = $time;
}

#
# RRDUpdate
#

my $rrdir = "/path/to/metrics/gomez";

# if rrdtool database doesn't exist, create it
if ( !-e "$rrdir/gomez.rrd" ) {
    print "creating rrd database ...\n";
    RRDs::create "$rrdir/gomez.rrd", "-s 300", "DS:Login:GAUGE:600:U:U",
      "DS:Search:GAUGE:600:U:U",    "DS:View:GAUGE:600:U:U",
      "DS:MyAccount:GAUGE:600:U:U", "DS:Registration:GAUGE:600:U:U",
      "DS:Index:GAUGE:600:U:U",     "RRA:AVERAGE:0.5:1:600",
      "RRA:AVERAGE:0.5:6:700",      "RRA:AVERAGE:0.5:24:775",
      "RRA:AVERAGE:0.5:288:797";
}

# do the update
RRDs::update "$rrdir/gomez.rrd", "-t",
  "Support:Homepage",
"N:$pages{'Support'}:$pages{'Homepage'}" unless $debug;

