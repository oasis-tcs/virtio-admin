#!/usr/bin/perl
use strict;
use warnings;
use LWP 5.64;
use URI::Escape;
use HTML::Entities;

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

my $action;
my $program = $0;
if ($#ARGV >= 0 and $ARGV[0] =~ m/^-(comment|proposal|add-proposal|resolution|add-resolution|fix|version|add-fix|add-version)$/i) {
	$action = $1;
	shift @ARGV;
}
if ($program =~ m/(comment|proposal|add-proposal|resolution|add-resolution|fix|version|add-fix|add-version)$/i) {
	$action = $1;
}

my $issue = $ARGV[0];
my $comment = $ARGV[1];

if (not defined($action) or not defined($issue)
    or not ($issue =~ m/^VIRTIO-[0-9]+$/i)) {
	print "Usage: \n";
	print "   virtio-tc.pl (-comment|-proposal|add-proposal|resolution|add-resolution|fix|version|add-fix|add-version) VIRTIO-<issue#> [<comment>]\n";
	exit 1;
}

sub printform {
	my $name = shift;
	my %form = @_;
	foreach my $field (sort(keys(%form))) {
		if (ref($form{$field}) eq 'ARRAY') {
			foreach my $v (@{$form{$field}}) {
				print "form $name key $field = $v\n";
			}
		} else {
			print "form $name key $field = $form{$field}\n";
		}
	}
};

sub printforms {
	my $content = shift;
	my %form = ();
	my %fields = ();
	my $form_name;
	my $form_action;

	my @lines = split("<", $content);
	for my $l (@lines) {
		if ($l =~ m/^form[^>]*method="post"/i) {
			if ($l =~ m/^form[^>]*id="([^"]*)"/i) {
				$form_name = $1;
			} else {
				$form_name = undef;
			}
			if ($l =~ m/^form[^>]*action="([^"]*)"/i) {
				$form_action = $1;
			} else {
				$form_action = undef;
			}
			next unless defined($form_name) and defined($form_action);
			print "form $form_name action $form_action\n";
		} elsif ($l =~ m#^/form>#) {
			print "end of form\n";
			$form_name = undef;
		}

		if ($l =~ m/^(input|select)/i) {
			my $name;
			my $value = "";
			if ($l =~ m/type="button"/i) {
				next;
			}
			if ($l =~ m/name="([^"]*)"/i) {
				$name = $1;
			}
			if ($l =~ m/value="([^"]*)"/i) {
				$value = $1;
			}
			next unless defined $name;
			$value = decode_entities($value);
			print "form{$name} = $value\n";
		}
		if ($l =~ m/^(textarea)/i) {
			my $name;
			my $value = "";
			if ($l =~ m/name="([^"]*)"/i) {
				$name = $1;
			}
			if ($l =~ m/([^>\s][^>]*[^>\s])\s*$/i) {
				$value = $1;
			}
			next unless defined $name;
			$value = decode_entities($value);
			print "form{$name} = $value\n";
		}
		if ($l =~ m/^(a)/i) {
			my $id;
			my $href;
			if ($l =~ m/^a[^>]*id="([^"]*)"/i) {
				$id = $1;
			} else {
				$id = undef;
			}
			if ($l =~ m/^a[^>]*href="([^"]*)"/i) {
				$href = $1;
			} else {
				$href = undef;
			}
			my $text="";
			if ($l =~ m/([^>\s][^>]*[^>\s])\s*$/i) {
				$text = $1;
			}
			next unless defined $id and defined $href;
			print "url{$id} [$text] = $href\n";
		}
	}

}

sub printlinks {
	my $CONTENT = shift;
	my %form = ();
	my %fields = ();
	my $href;
	my $text;
	my $id;

	my @lines = split("<", $CONTENT);
	for my $l (@lines) {
		next unless ($l =~ m/^a/);
		$href = undef;
		$text = "";
		if ($l =~ m/href=\'([^']+)\'/i) {
			$href = $1;
		} elsif ($l =~ m#href=\"([^"]+)\"#i) {
			$href = $1;
		}
		if ($l =~ m/^a[^>]*id="([^"]*)"/i) {
			$id = $1;
		} else {
			$id = undef;
		}
		if ($l =~ m/([^>\s][^>]*[^>\s])\s*$/i) {
			$text = $1;
		}
		#used within javascript as template
		next if ($href =~ m/\{0\}/);

		next unless defined($href) and defined($id);

		print "text $text href $href id $id\n";

	}

}

sub getlink {
	my $CONTENT = shift;
	my $pattern = shift;
	my %form = ();
	my %fields = ();
	my $href;
	my $id;

	my @lines = split("<", $CONTENT);
	for my $l (@lines) {
		next unless ($l =~ m/^a/);
		$href = undef;
		if ($l =~ m/^a[^>]*id="([^"]*)"/i) {
			$id = $1;
		} else {
			$id = undef;
		}
		if ($l =~ m/href=\'([^']+)\'/i) {
			$href = $1;
		} elsif ($l =~ m#href=\"([^"]+)\"#i) {
			$href = $1;
		}

		next unless defined($href) and defined($id);
		next if ($href =~ m/\{0\}/);

		if ($id eq $pattern) {
			return $href
		}
	}
}

sub parseform {
	my $CONTENT = shift;
	my $FNAME = shift;
	my $ALLOPTIONS = shift;
	my @REQFIELDS = @_;
	my %form = ();
	my %fields = ();
	my $form_name;
	my $form_action;
	my $select_name;
	my $multiple;

	my @lines = split("<", $CONTENT);
	for my $l (@lines) {
		if ($l =~ m/^form[^>]*method="post"/i) {
			if ($l =~ m/^form[^>]*id="([^"]*)"/i) {
				$form_name = $1;
			} else {
				$form_name = undef;
			}
			if ($l =~ m/^form[^>]*action="([^"]*)"/i) {
				$form_action = $1;
			} else {
				$form_action = undef;
			}
			next unless defined($form_name) and defined($form_action);
		} elsif ($l =~ m#^/form>#i) {
			$form_name = undef;
		}
		next if (not(defined($form_name)) or $form_name ne $FNAME);

		if ($l =~ m/^(input|select)/i) {
			my $name;
			my $value = "";
			if ($l =~ m/type="button"/i) {
				next;
			}
			if ($l =~ m/name="([^"]*)"/i) {
				$name = $1;
			}
			if ($l =~ m/value="([^"]*)"/i) {
				$value = $1;
			}
			next unless defined $name;
			$value = decode_entities($value);
			$form{$name} = $value;
			if ($l =~ m/^(select)/i) {
				$select_name = $name;
				if ($l =~ m/multiple="multiple"/) {
					$multiple = 1;
					$form{$select_name} = [];
				} else {
					$multiple = undef;
				}
			}
		}
		if ($l =~ m#^/select#i) {
			$select_name = undef;
		}
		if ($l =~ m/^option/i) {
			my $value = undef;
			next unless defined $select_name;
			if (($ALLOPTIONS eq "") and (not $l =~ m/\sselected\b/i)) {
				next;
			}
			if ($l =~ m/value="([^"]*)"/i) {
				$value = $1;
			}
			next unless defined $value;
			if ($ALLOPTIONS eq "text") {
				$value = $l;
				if (not $value =~ s/^.*>\s*//go) {
					$value = "";
				}
			}
			$value = decode_entities($value);
			if (defined($multiple)) {
				push @{$form{$select_name}}, $value;
			} else {
				$form{$select_name} = $value;
			}
		}
		if ($l =~ m/^(textarea)/i or $l =~ m/data-fieldtype="textarea"/ ) {
			my $name;
			my $value = "";
			if ($l =~ m/id="([^"]*)"/i) {
				$name = $1;
			}
			if ($l =~ m/([^>\s][^>]*[^>\s])\s*$/i) {
				$value = $1;
			}
			next unless defined $name;
			$value = decode_entities($value);
			$form{$name} = $value;
		}
	}

	foreach my $reqfield (@REQFIELDS) {
		die unless defined($form{$reqfield});
	}
	return ($form_action, %form);
};

my $browser = LWP::UserAgent->new;

# enable cookies
$browser->cookie_jar({});

my $url;
my $response;
$url = 'https://issues.oasis-open.org/login.jsp?' .
	'os_destination=%2Fbrowse%2F' . $issue;
print "LOGIN as $USERNAME at $url\n";

$response = $browser->get($url);
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->is_success;

print "LOGIN successful\n";

my $LOGIN_USERNAME = 'os_username';
my $LOGIN_PASSWORD = 'os_password';

my ($login_action, %login_form) = parseform($response->content, "login-form", "",
					    $LOGIN_USERNAME, $LOGIN_PASSWORD);

$login_form{$LOGIN_USERNAME} = $USERNAME;
$login_form{$LOGIN_PASSWORD} = $PASSWORD;

$url = URI->new_abs($login_action, $url);
$response = $browser->post($url, \%login_form,);
#Server responds with a 302 Found redirect
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->code() eq 302;

$url = URI->new_abs($response->header('Location'), $url);

$response = $browser->get($url);
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->is_success;

my $edit_url = getlink($response->content, 'edit-issue');
my $comment_url = getlink($response->content, 'footer-comment-button');
$edit_url = URI->new_abs($edit_url, $url);
$comment_url = URI->new_abs($comment_url, $url);

if ($action eq "add-version") {
	$url = $edit_url;
}
if ($action eq "version") {
	$url = $edit_url;
}
if ($action eq "add-fix") {
	$url = $edit_url;
}
if ($action eq "fix") {
	$url = $edit_url;
}
if ($action eq "add-proposal") {
	$url = $edit_url;
}
if ($action eq "proposal") {
	$url = $edit_url;
}
if ($action eq "add-resolution") {
	$url = $edit_url;
}
if ($action eq "resolution") {
	$url = $edit_url;
}
if ($action eq "comment") {
	$url = $comment_url;
}
#print "Edit URL $url\n";
$response = $browser->get($url);
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->is_success;

$response = $browser->get($url);
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->is_success;

if (not defined($comment)) {
	print "Please type in your $action followed by EOF:\n";
	$comment = "";
	while (<STDIN>) {
		$comment .= $_;
	}
	chomp $comment;
}

die "No $action supplied: must include letters or digits"
	unless $comment =~ m/[a-z0-9]/i;

my $COMMENT_FORM = 'comment-add';
my $EDIT_FORM = 'issue-edit';
my $COMMENT_TEXT = 'comment';
my $PROPOSAL_TEXT = 'customfield_10001';
my $FIX_TEXT = 'fixVersions';
my $VERSION_TEXT = 'versions';
my $RESOLUTION_TEXT = 'customfield_10002';

my $comment_text;
my $comment_form;

if ($action eq "comment") {
	$comment_text = $COMMENT_TEXT;
	$comment_form = $COMMENT_FORM;
}
if ($action eq "add-version") {
	$comment_text = $VERSION_TEXT;
	$comment_form = $EDIT_FORM;
}
if ($action eq "version") {
	$comment_text = $VERSION_TEXT;
	$comment_form = $EDIT_FORM;
}
if ($action eq "add-fix") {
	$comment_text = $FIX_TEXT;
	$comment_form = $EDIT_FORM;
}
if ($action eq "fix") {
	$comment_text = $FIX_TEXT;
	$comment_form = $EDIT_FORM;
}
if ($action eq "proposal") {
	$comment_text = $PROPOSAL_TEXT;
	$comment_form = $EDIT_FORM;
}
if ($action eq "add-proposal") {
	$comment_text = $PROPOSAL_TEXT;
	$comment_form = $EDIT_FORM;
}
if ($action eq "resolution") {
	$comment_text = $RESOLUTION_TEXT;
	$comment_form = $EDIT_FORM;
}
if ($action eq "add-resolution") {
	$comment_text = $RESOLUTION_TEXT;
	$comment_form = $EDIT_FORM;
}

#printforms($response->content);
#print $response->content;

my ($comment_action, %comment_form) = parseform($response->content,
						    $comment_form, "", $comment_text);
my ($options_action, %options_form) = parseform($response->content,
						    $comment_form, "values", $comment_text);
my ($text_action, %text_form) = parseform($response->content,
						    $comment_form, "text", $comment_text);

#printform($comment_form, %text_form);

sub findtext {
	my $s = shift;
	my @text = @_;

	my $i;
	my $option;
	for ($i = 0; $i <= $#text; $i++) {
		if ($text[$i] =~ m/$s/) {
			if (defined($option)) {
				print STDERR "Ambigious version value. " .
					"Matches: [$text[$option]] " .
					"and [$text[$i]] \n";
				exit 3;
			}
			$option = $i;
		}
	}

	if (not defined($option)) {
		print STDERR "Invalid version value $s. Valid values:\n";
		for ($i = 0; $i <= $#text; $i++) {
			print STDERR "$text[$i]\n";
			
		}
		exit (2);
	}

	return $option;
}

if (($action =~ m/fix$/) or ($action =~ /version$/)) {
	die unless ref($text_form{$comment_text}) eq 'ARRAY';
	die unless ref($options_form{$comment_text}) eq 'ARRAY';
	my @text = @{$text_form{$comment_text}};
	my @options = @{$options_form{$comment_text}};

	die unless $#text eq $#options;
	
	my $option = findtext($comment, @text);

	$comment = $options[$option];
}

my $report_comment = $comment;

if (($action =~ m/^add-/) and defined($comment_form{$comment_text})) {
	if (ref($comment_form{$comment_text}) eq 'ARRAY') {
		push @{$comment_form{$comment_text}}, $comment;
		$report_comment = join ("\n", @{$comment_form{$comment_text}});
	} elsif ($comment_form{$comment_text} =~ m/\S/) {
		$comment = $comment_form{$comment_text} . "\n" . $comment;
		$report_comment = $comment;
	}
}
print "Adding $action at URL $url\n";
print "$action text: [\n" . $report_comment . "\n]\n";

$comment_form{$comment_text} = $comment;

$url = URI->new_abs($comment_action, $url);
$response = $browser->post($url, \%comment_form, );
#Server can respond with a 302 Found redirect
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->code() eq 302 or $response->is_success;

print "New $action submitted successfully\n";
exit(0);
