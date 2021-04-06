#!/usr/bin/perl
# ./virtio-ballot.pl "$(cat /tmp/title)" "$(cat /tmp/question)" "$(cat /tmp/desc)"
use strict;
use warnings;
use LWP 5.64;
use URI::Escape;
use HTML::Entities;

if ($#ARGV != 2) {
	print STDERR "usage: virtio-ballot.pl <name> <question> <description>\n";
	exit 3;
}

my $NAME=$ARGV[0];
$NAME =~ s/\n/ /g;
$NAME =~ s/^\s*//;
$NAME =~ s/\s*$//;
my $QUESTION=$ARGV[1];
$QUESTION =~ s/^\s*//;
$QUESTION =~ s/\s*$//;
my $DESCRIPTION=$ARGV[2];
$DESCRIPTION =~ s/^\s*//;
$DESCRIPTION =~ s/\s*$//;

$DESCRIPTION =~ s/&/&amp;/sg;
$DESCRIPTION =~ s/</&lt;/sg;
$DESCRIPTION =~ s/>/&gt;/sg;
$DESCRIPTION =~ s/"/&quot;/sg;
$DESCRIPTION =~ s/'/&apos;/sg;

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

sub printform {
	my $name = shift;
	my %form = @_;
	foreach my $field (sort(keys(%form))) {
		if (ref($form{$field}) eq 'ARRAY') {
			foreach my $v (@{$form{$field}}) {
				print "form $name key $field = $v\n";
			}
		} elsif (defined($form{$field})) {
			print "form $name key $field = $form{$field}\n";
		} else {
			print "form $name key $field = <UNDEF>\n";
		}
	}
};

sub printforms {
	my $CONTENT = shift;
	my %form = ();
	my %fields = ();
	my $form_name;
	my $form_action;

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
			print "Form $form_name Action $form_action\n";
		} elsif ($l =~ m#^/form>#) {
			print "End of Form\n";
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
			print "form{$name} = $value\n";
		}
	}

};
#sub printforms {
#	my $content = shift;
#	my %form = ();
#	my %fields = ();
#	my $form_name;
#	my $form_action;
#
#	my @lines = split("<", $content);
#	for my $l (@lines) {
#		if ($l =~ m/^form[^>]*method="post"/i) {
#			if ($l =~ m/^form[^>]*id="([^"]*)"/i) {
#				$form_name = $1;
#			} else {
#				$form_name = undef;
#			}
#			if ($l =~ m/^form[^>]*action="([^"]*)"/i) {
#				$form_action = $1;
#			} else {
#				$form_action = undef;
#			}
#			next unless defined($form_name) and defined($form_action);
#			print "form $form_name action $form_action\n";
#		} elsif ($l =~ m#^/form>#) {
#			print "end of form\n";
#			$form_name = undef;
#		}
#
#		if ($l =~ m/^(input|select)/i) {
#			my $name;
#			my $value = "";
#			if ($l =~ m/type="button"/i) {
#				next;
#			}
#			if ($l =~ m/name="([^"]*)"/i) {
#				$name = $1;
#			}
#			if ($l =~ m/value="([^"]*)"/i) {
#				$value = $1;
#			}
#			next unless defined $name;
#			$value = decode_entities($value);
#			print "form{$name} = $value\n";
#		}
#		if ($l =~ m/^(textarea)/i) {
#			my $name;
#			my $value = "";
#			if ($l =~ m/name="([^"]*)"/i) {
#				$name = $1;
#			}
#			if ($l =~ m/([^>\s][^>]*[^>\s])\s*$/i) {
#				$value = $1;
#			}
#			next unless defined $name;
#			$value = decode_entities($value);
#			print "form{$name} = $value\n";
#		}
#		if ($l =~ m/^(a)/i) {
#			my $id;
#			my $href;
#			if ($l =~ m/^a[^>]*id="([^"]*)"/i) {
#				$id = $1;
#			} else {
#				$id = undef;
#			}
#			if ($l =~ m/^a[^>]*href="([^"]*)"/i) {
#				$href = $1;
#			} else {
#				$href = undef;
#			}
#			my $text="";
#			if ($l =~ m/([^>\s][^>]*[^>\s])\s*$/i) {
#				$text = $1;
#			}
#			next unless defined $id and defined $href;
#			print "url{$id} [$text] = $href\n";
#		}
#	}
#
#}

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

	if (not defined($ALLOPTIONS)) {
		$ALLOPTIONS = "";
	}

	my @lines = split("<", $CONTENT);
	for my $l (@lines) {
		my $trace = 0;
		if ($l =~ m/^form[^>]*method=['"]post['"]/i) {
			if ($l =~ m/^form[^>]*id=['"]([^"']*)['"]/i) {
				$form_name = $1;
			} elsif ($l =~ m/^form[^>]*name=['"]([^"']*)['"]/i) {
				$form_name = $1;
			} else {
				$form_name = undef;
			}
			if ($l =~ m/^form[^>]*action=['"]([^"']*)['"]/i) {
				$form_action = $1;
			} else {
				$form_action = undef;
			}
#			next unless defined($form_name) and defined($form_action);
		} elsif ($l =~ m#^/form>#i) {
			$form_name = undef;
		}
		next if (not(defined($form_name)) or $form_name ne $FNAME);

		if ($l =~ m/^(input|select)/i) {
			my $name;
			my $value = "";
			if ($l =~ m/type=['"]button['"]/i) {
				next;
			}
			if ($l =~ m/name=["']([^"']*)['"]/i) {
				$name = $1;
			}
			if ($l =~ m/value=['"]([^"']*)['"]/i) {
				$value = $1;
			} elsif ($l =~ m/value=([^"'\s]*)/i) {
				$value = $1;
			}
			print STDERR "skip input: $l\n" unless defined $name;
			next unless defined $name;
			if ($l =~ m/type=['"](checkbox|radio)['"]/i) {
				if (($ALLOPTIONS eq "") and not($l =~ m/\schecked\b/i)) {
					next;
				}
				if (not(defined($value))) {
					$value = "on";
				}
			}

			$value = decode_entities($value);
			if (defined($form{$name})) {
				if (not(ref($form{$name}) eq 'ARRAY')) {
					my $tmp = $form{$name};
					$form{$name} = [];
					push @{$form{$name}}, $tmp;
				}
				push @{$form{$name}}, $value;
			} else {
				$form{$name} = $value;
			}
			if ($l =~ m/^(select)/i) {
				$select_name = $name;
				if (($l =~ m/multiple=['"]multiple['"]/) or not ($ALLOPTIONS eq "")) {
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
			print STDERR "skip option $l\n" unless defined $select_name;
			next unless defined $select_name;
			if (($ALLOPTIONS eq "") and (not $l =~ m/\sselected\b/i)) {
				next;
			}
			if ($l =~ m/value=['"]([^"']*)['"]/i) {
				$value = $1;
			} elsif ($l =~ m/value=([^"'\s]*)/i) {
				$value = $1;
			}
			print STDERR "skip v: $l\n" unless defined $value;
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
				if (defined($form{$select_name})) {
					if (not(ref($form{$select_name}) eq 'ARRAY')) {
						my $tmp = $form{$select_name};
						$form{$select_name} = [];
						push @{$form{$select_name}}, $tmp;
					}
					push @{$form{$select_name}}, $value;
				} else {
					$form{$select_name} = $value;
				}
			}
		}
		if ($l =~ m/^(textarea)/i or $l =~ m/data-fieldtype=['"]textarea['"]/ ) {
			my $name;
			my $value = "";
			if ($l =~ m/id=['"]([^"]*)['"]/i) {
				$name = $1;
			}
			if ($l =~ m/name=["']([^"']*)['"]/i) {
				$name = $1;
			}
			if ($l =~ m/([^>\s][^>]*[^>\s])\s*$/i) {
				$value = $1;
			}
			print STDERR "skip: $l\n" unless defined $name;
			next unless defined $name;
			$value = decode_entities($value);
			if (defined($form{$name})) {
				if (not(ref($form{$name}) eq 'ARRAY')) {
					my $tmp = $form{$name};
					$form{$name} = [];
					push @{$form{$name}}, $tmp;
				}
				push @{$form{$name}}, $value;
			} else {
				$form{$name} = $value;
			}
		}
	}

	foreach my $reqfield (@REQFIELDS) {
		die "required field $reqfield missing" unless defined($form{$reqfield});
	}
	return ($form_action, %form);
};

sub findtext {
	my $s = shift;
	my @text = @_;

	my $i;
	my $option;
	for ($i = 0; $i <= $#text; $i++) {
		if ($text[$i] =~ m/$s/) {
			if (defined($option)) {
				print STDERR "Ambigious field value. " .
					"Matches: [$text[$option]] " .
					"and [$text[$i]] \n";
				exit 3;
			}
			$option = $i;
		}
	}

	if (not defined($option)) {
		print STDERR "Invalid field value $s. Valid values:\n";
		for ($i = 0; $i <= $#text; $i++) {
			print STDERR "$text[$i]\n";
			
		}
		exit (2);
	}

	return $option;
}

my $browser = LWP::UserAgent->new;

# enable cookies
$browser->cookie_jar({});

my $url;
my $response;
$url = 'https://www.oasis-open.org//login?' .
       'back=https%3a%2f%2fwww.oasis-open.org%2fapps%2forg%2fworkgroup%2fvirtio%2fcreate_ballot.php';
print "LOGIN as $USERNAME at $url\n";

$response = $browser->get($url);
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->is_success;

print "LOGIN successful\n";

my $LOGIN_USERNAME = '__ac_name';
my $LOGIN_PASSWORD = '__ac_password';

my ($login_action, %login_form) = parseform($response->content, "login_loginform", "",
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

my ($edit_action_dummy, %edit_ballot_options) = parseform($response->content, "add_edit_ballot_form", "1");
my ($edit_action, %edit_ballot) = parseform($response->content, "add_edit_ballot_form");

#sanity checks
#findtext("", @{$edit_ballot_options{$comment_text}})
#printform("EDIT BALLOT OPTIONS", %edit_ballot_options);
#printform("EDIT BALLOT", %edit_ballot);

#print $response->content;
sub gettime {
	my $tnow=`TZ="America/Detroit" date +%H:%M`;
	$tnow =~ m/([0-9][0-9]):([0-9][0-9])/;
	my $hnow = $1;
	my $mnow = $2;
	my $mround = sprintf("%02.2d", $mnow - $mnow % 15);
	my $hround = $hnow;
	my $ampm = "am";
	my $noon = "am";
	return "$hnow:$mround:00";
}

sub getdate {
	my $mtime=shift;
	my $offset=shift;
	if (defined($offset)) {
		return `TZ="America/Detroit" date +%F --date="$mtime $offset"`;
	} else {
		return `TZ="America/Detroit" date +%F --date="$mtime"`;
	}
};

my $mtime = gettime();
my $start = getdate($mtime);
my $remind1 = getdate($mtime, "3 days");
my $remind2 = getdate($mtime, "5 days");
my $remind3 = getdate($mtime, "6 days");
my $end = getdate($mtime, "7 days");

$edit_ballot{"admin_only_results"} = "0";
$edit_ballot{"attendance_x"} = "3";
$edit_ballot{"attendance_y"} = "5";
$edit_ballot{"auto_update"} = "true";
$edit_ballot{"ballot_email_close"} = "on";
$edit_ballot{"ballot_email_nonvoter_close"} = "on";
$edit_ballot{"ballot_email_nonvoter_open"} = "on";
$edit_ballot{"ballot_email_open"} = "on";
$edit_ballot{"ballot_email_present"} = "true";
$edit_ballot{"close_date"} = $end;
$edit_ballot{"close_date_t"} = $mtime;
$edit_ballot{"comment_req_other"} = "Optional";
$edit_ballot{"eligible_voters"} = "voters";
$edit_ballot{"enable_revotes"} = "true";
$edit_ballot{"enable_other_option"} = undef;
$edit_ballot{"enforce_attendance_flag"} = undef;
$edit_ballot{"include_abstain"} = "1";
$edit_ballot{"members_view_results"} = "true";
$edit_ballot{"official_ballot"} = "true";
$edit_ballot{"open_date"} = $start;
$edit_ballot{"open_date_t"} = $mtime;
$edit_ballot{"option_count"} = "1";
$edit_ballot{"option_style"} = "upto";
$edit_ballot{"options_comment_req[]"} = undef;
$edit_ballot{"options_comment_req[yes]"} = "Optional";
$edit_ballot{"options_comment_req[no]"} = "Optional";
$edit_ballot{"options_comment_req[abstain]"} = "Optional";
$edit_ballot{"remind_date"} = $remind1;
$edit_ballot{"remind_date_t"} = $mtime;
$edit_ballot{"remind_date_2"} = $remind2;
$edit_ballot{"remind_date_2_t"} = $mtime;
$edit_ballot{"remind_date_3"} = $remind3;
$edit_ballot{"remind_date_3_t"} = $mtime;
$edit_ballot{"results_open"} = "after_opens";
$edit_ballot{"send_reminder"} = "true";
$edit_ballot{"show_result_details"} = "true";
$edit_ballot{"time_zone_id"} = "1";
$edit_ballot{"type"} = "yes_no";
$edit_ballot{"update_list"} = undef;
$edit_ballot{"add_more_wg_references"} = undef;
#form EDIT BALLOT OPTIONS key name = 
#form EDIT BALLOT OPTIONS key question = 
#form EDIT BALLOT OPTIONS key text = 
$edit_ballot{"name"} = $NAME;
$edit_ballot{"question"} = $QUESTION;
$edit_ballot{"text"} = $DESCRIPTION;
$edit_ballot{"show_review_page"} = "Continue &gt;&gt;";

#print "ACTION $edit_action\n";
#$url = URI->new_abs($edit_action, $url);
#arrays can't be used with mutlipart
foreach my $field (sort(keys(%edit_ballot))) {
	if (ref($edit_ballot{$field}) eq 'ARRAY') {
		my @tmp = @{$edit_ballot{$field}};
		$edit_ballot{$field} = $tmp[0];
	}
}

#printform("create_ballot", %edit_ballot);

$url = "https://www.oasis-open.org/apps/org/workgroup/virtio/create_ballot.php";
print "CREATE BALLOT AT $url\n";
$response = $browser->post($url, \%edit_ballot, 'Content_Type' => 'form-data', );
die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->code() eq 302 or $response->is_success;

#printforms($response->content);

my ($review_action, %review_ballot) = parseform($response->content, "ballot_review_form");
my @review_keys = keys %review_ballot;
if ($#review_keys < 0) {
	my @resp = split("\n", $response->content);
	my @errors = grep(/\'error\'/, @resp);
	my $error = join('\n', @errors);
	print "RETURNED errors: $error\n";
	die 'Unable to find review form - Aborting';
}

#print $response->content;

foreach my $field (sort(keys(%review_ballot))) {
	if (ref($review_ballot{$field}) eq 'ARRAY') {
		my @tmp = @{$review_ballot{$field}};
		$review_ballot{$field} = $tmp[0];
	}
}

#printform("review", %review_ballot);

$review_ballot{"create_and_create_another"} = undef;
$review_ballot{"show_create_page"} = undef;
$review_ballot{"show_done_page"} = "Accept &gt;&gt;";
print "REVIEW BALLOT AT $url\n";
$response = $browser->post($url, \%review_ballot, 'Content_Type' => 'form-data', );
if ($response->code() ne 302) {
	my @resp = split("\n", $response->content);
	my @errors = grep(/\'error\'/, @resp);
	my $error = join('\n', @errors);
	print "RETURNED errors: $error\n";
}

die 'Error accessing',
    "\n ", $response->status_line, "\n at $url\n Aborting"
    unless $response->code() eq 302;

#print $response->content, "\n";
$url = URI->new_abs($response->header('Location'), $url);
print "BALLOT VOTING AT URL: $url\n";
exit (11) unless $url =~ m/\?id=([0-9]+)$/;
my $id = $1;
my $publicurl = "https://www.oasis-open.org/committees/ballot.php?id=" . $id;
print "BALLOT CREATED AT URL: $publicurl\n";

exit 0;
