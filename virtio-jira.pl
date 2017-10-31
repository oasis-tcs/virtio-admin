#!/usr/bin/perl

#See documentation:
#https://developer.atlassian.com/display/JIRADEV/Updating+an+Issue+via+the+JIRA+REST+APIs
#https://developer.atlassian.com/display/JIRADEV/JIRA+REST+API+Example+-+Edit+issues
use strict;
use warnings;
use LWP 5.64;
use URI::Escape;
use HTML::Entities;
use JSON;
use Data::Dumper;

{
	package RC;
	for my $file ("$ENV{HOME}/.virtio-tc-rc")
	{
		unless (my $return = do $file) {
			warn "couldn't parse $file: $@" if $@;
			warn "couldn't do $file: $!"    unless defined $return;
			warn "couldn't run $file"       unless $return;
		}
	}

}

if (not defined $RC::USERNAME or not defined $RC::PASSWORD) {
	print STDERR <<EOF
Unable to find username/password.
Please create $ENV{"HOME"}/.virtio-tc-rc
In the following format (without <>):
\$USERNAME = '<username>';
\$PASSWORD = '<password>';
EOF
}

my $USERNAME = $RC::USERNAME;
my $PASSWORD = $RC::PASSWORD;

sub help_and_exit {
	print "Usage: \n";
	print "   virtio-jira.pl [-o[pen]] [[-]-f[ix-versions][=| ]<version>]... [[-]-p[rint][=| ](s[ummary]|d[escription]|p[roposal]|r[esolution]|f[ixVersions]|v[ersions]|[s]t[atus]|a[ll])]... VIRTIO-<issue#>\n";
	exit 1;
}

if (not defined($ARGV[0])) {
	help_and_exit();
}

my @fix_version_names = ();
my @print_fields = ();

my $open = 0;
if (defined($ARGV[0]) and $ARGV[0] =~ m/^-?-o/) {
	$open = 1;
	shift;
}

while (defined($ARGV[0]) and $ARGV[0] =~ m/^-?-f/) {
	my $flag = shift @ARGV;
	if ($flag =~ m/=/) {
		$flag =~ s/^[^=]*=//;
		push @fix_version_names, $flag;
	} elsif (defined($ARGV[0])) {
		my $version = shift @ARGV;
		push @fix_version_names, $version;
	} else {
		help_and_exit();
	}
}

sub print_field {
	my $name = shift @_;

	if ($name =~ m/^t/) {
		return "status";
	}
	#Note: test st before s
	if ($name =~ m/^st/) {
		return "status";
	}
	if ($name =~ m/^s/) {
		return "summary";
	}
	if ($name =~ m/^d/) {
		return "description";
	}
	if ($name =~ m/^p/) {
		#proposal
		return "customfield_10001";
	}
	if ($name =~ m/^r/) {
		return "resolution";
	}
	if ($name =~ m/^f/) {
		return "fixVersions";
	}
	if ($name =~ m/^v/) {
		return "versions";
	}
	if ($name =~ m/^a/) {
		return "all";
	}

	help_and_exit();
}

while (defined($ARGV[0]) and $ARGV[0] =~ m/^-?-p/) {
	my $flag = shift @ARGV;
	if ($flag =~ m/=/) {
		$flag =~ s/^[^=]*=//;
		push @print_fields, print_field($flag);
	} elsif (defined($ARGV[0])) {
		my $field = shift @ARGV;
		push @print_fields, print_field($field);
	} else {
		help_and_exit();
	}
}

if ($#fix_version_names < 0 and $#print_fields < 0) {
	push @print_fields, "summary";
}

my $issue = $ARGV[0];
if (not defined($issue)
    or not ($issue =~ m/^VIRTIO-[0-9]+$/i)) {
	help_and_exit();
}

sub post_json {
	my ($browser, $url, $jsonhash) = @_;
	my $response;
	my $json;
	my $req;

	$json = encode_json($jsonhash);
	$req = HTTP::Request->new('POST', $url);
	$req->header('Content-Type' => 'application/json');
	$req->header('Accept', 'application/json');
	$req->content($json);
	$response = $browser->request( $req );
	die 'POST Error',
	    "\n ", $response->status_line, "\n at $url\n Aborting"
		    unless $response->code() eq 302 or $response->is_success;
}

sub put_json {
	my ($browser, $url, $jsonhash) = @_;
	my $response;
	my $json;
	my $req;

	$json = encode_json($jsonhash);
	$req = HTTP::Request->new('PUT', $url);
	$req->header('Content-Type' => 'application/json');
	$req->header('Accept', 'application/json');
	$req->content($json);
	$response = $browser->request( $req );
	die 'PUT Error: ',
	    "\n ", $response->status_line, "\n at $url\n Aborting"
		    unless $response->code() eq 302 or $response->is_success;
}

sub get_json {
	my ($browser, $url) = @_;
	my $response;
	my $json;
	my $req;

	$req = HTTP::Request->new('GET', $url);
	$req->header('Content-Type' => 'application/json');
	$req->header('Accept', 'application/json');
	$response = $browser->request($req);
	die 'GET Error',
	    "\n ", $response->status_line, "\n at $url\n Aborting"
		    unless $response->code() eq 302 or $response->is_success;

	return decode_json($response->content);
}

my $browser = LWP::UserAgent->new;

# enable cookies
$browser->cookie_jar({});

my $url;
my $issue_info;

#GET: can be normally be done without authentication
$url = "https://issues.oasis-open.org/rest/api/2/issue/$issue";

#optimization: skip get if we only need to put
if ($#print_fields >= 0) {
	$issue_info = get_json($browser, $url);
}

foreach my $field (@print_fields) {
	if ($field eq "all") {
		print Dumper($issue_info);
	} else {
		if (ref($$issue_info{'fields'}{$field}) eq 'ARRAY') {
			foreach my $n (@{$$issue_info{'fields'}{$field}}) {
				if (ref($n) eq 'HASH') {
					$n = $$n{'name'};
				}
				
				$n =~ s/\r//g;
				print $n, "\n";
			}
		} elsif (defined($$issue_info{'fields'}{$field})) {
			my $n = $$issue_info{'fields'}{$field};
			if (ref($n) eq 'HASH') {
				$n = $$n{'name'};
			}
			$n =~ s/\r//g;
			print $n, "\n";
		}
	}
}

if ($open or $#fix_version_names >= 0) {
#authenticate
	$url="https://issues.oasis-open.org/rest/auth/1/session";
	my %auth = ('username' => $USERNAME, 'password' => $PASSWORD);
	my $auth_info = post_json($browser, $url, \%auth);
}


if ($open) {
#	$url = "https://issues.oasis-open.org//rest/api/2/issue/$issue/transitions?expand=transitions.fields";
	$url = "https://issues.oasis-open.org//rest/api/2/issue/$issue/transitions";
	my $transitions_info = get_json($browser, $url);
	my $id;
	foreach my $t (@{$$transitions_info{"transitions"}}) {
		if ($$t{"name"} =~ m/^Open/) {
			$id = $$t{"id"};
			last;
		}
	}
	if (not(defined($id))) {
		print STDERR "Transition to Open state not enabled for this issue.\n";
		print STDERR "Possible transitions: ", Dumper($transitions_info), "\n";
		exit(3);
	}
	$url = "https://issues.oasis-open.org//rest/api/2/issue/$issue/transitions";
	my %status = ('id' => $id);
	my %transitions = ('transition' => \%status);
	post_json($browser, $url, \%transitions);
}

#get versions
$url = "https://issues.oasis-open.org/rest/api/2/project/VIRTIO/versions";
#Done unless we need to make changes
exit 0 unless $#fix_version_names >= 0;

#get versions
$url = "https://issues.oasis-open.org/rest/api/2/project/VIRTIO/versions";
my $versions_info = get_json($browser, $url);

my @vnames = ();
foreach my $fix_version (@fix_version_names) {
	my $found = 0;
	foreach my $version (@$versions_info) {
		if ($$version{'name'} =~ m/$fix_version/) {
			$found = 1;
			#push @{$$issue_info{'fields'}{'fixVersions'}}, $version;
			my %version = ('name' => $$version{'name'});
			push @vnames, \%version;
		}
	}
	if (not $found) {
		print STDERR "Version $fix_version not found in project.\n";
		print STDERR "Options: ", Dumper(@{$versions_info}), "\n";
		exit 3;
	}
}

$url = "https://issues.oasis-open.org/rest/api/2/issue/$issue";
my %fields = ('fixVersions' => \@vnames);
my %request = ('fields' => \%fields);
#print encode_json(\%request),"\n";
put_json($browser, $url, \%request);

exit (0);
