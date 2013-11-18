#!/usr/bin/perl -w
#
# soap xml for Eloqua
#
# Rod Cordova (@gitrc)
#

use strict;
use LWP::UserAgent;
use Data::Dumper;
use URI::Escape;
use HTTP::Headers;
use XML::Simple;
use JSON;

my $debug;
$debug = exists( $ENV{SSH_CLIENT} ) ? 1 : 0;

# too many perl ways to do this
my $begintime = qx(date -d '-7 day' +%Y-%m-%d);
my $endtime   = qx(date -d 'now' +%Y-%m-%d);

chop $begintime;
chop $endtime;

my $soap_header = '<SOAP-ENV:Envelope 
xmlns:arr="http://schemas.microsoft.com/2003/10/Serialization/Arrays"
xmlns:ns0="https://secure.eloqua.com/API/1.2"
xmlns:ns1="http://schemas.xmlsoap.org/soap/envelope/"
xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/">
   <SOAP-ENV:Header>
      <wsse:Security mustUnderstand="true">
         <wsse:UsernameToken>
            <wsse:Username>Org\username</wsse:Username>
            <wsse:Password>password</wsse:Password>
         </wsse:UsernameToken>
      </wsse:Security>
   </SOAP-ENV:Header>
';

my $xml_payload =

qq {<ns1:Body>
      <ns0:GetEmailsSentInTimeRange>
        <ns0:startDate>$begintime</ns0:startDate>
        <ns0:endDate>$endtime</ns0:endDate>
      </ns0:GetEmailsSentInTimeRange>
   </ns1:Body>
</SOAP-ENV:Envelope>};


my $post_url =
"https://secure.eloqua.com/API/1.2/EmailService.svc";

my $headers = new HTTP::Headers(
    'SOAPAction' => 'https://secure.eloqua.com/API/1.2/EmailService/GetEmailsSentInTimeRange', );
my $request = new HTTP::Request( "POST", $post_url, $headers );


$request->content($soap_header . $xml_payload);
$request->content_type('text/xml');

my $ua = LWP::UserAgent->new;

my $response = $ua->request($request);
my $content  = $response->content;

#print Dumper $content;

my $emails = XMLin($content);
my @emailIds;

foreach my $hash ($emails->{'s:Body'}->{GetEmailsSentInTimeRangeResponse}->{GetEmailsSentInTimeRangeResult}->{Email})
{
foreach my $email (@$hash) 
{
push @emailIds, $email->{Id};
}
}

#print Dumper %test;
#exit 0;

# get the counts
$xml_payload =

qq {<ns1:Body>
      <ns0:GetMetricsForEmails>
       <ns0:emailIds>};
foreach my $emailId (@emailIds) {
$xml_payload .= "<arr:int>$emailId</arr:int>\n";
}
$xml_payload .= qq {
       </ns0:emailIds>
        <ns0:startDate>$begintime</ns0:startDate>
        <ns0:endDate>$endtime</ns0:endDate>
      </ns0:GetMetricsForEmails>
   </ns1:Body>
</SOAP-ENV:Envelope>};

#print $soap_header . $xml_payload . "\n";
#exit 0;

$headers = new HTTP::Headers(
    'SOAPAction' => 'https://secure.eloqua.com/API/1.2/EmailService/GetMetricsForEmails', );
$request = new HTTP::Request( "POST", $post_url, $headers );


$request->content($soap_header . $xml_payload);
$request->content_type('text/xml');

$ua = LWP::UserAgent->new;

$response = $ua->request($request);
#print Dumper $response;
$content  = $response->content;

#print Dumper $content;


