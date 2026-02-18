#!/usr/bin/perl
use strict;
use warnings;
use LWP::UserAgent;
use HTTP::Cookies;
use HTML::Form;
use URI;
use URI::Escape qw(uri_unescape);
use JSON qw(decode_json encode_json);

if ($#ARGV != 2) {
	print STDERR "usage: virtio-ballot.pl <name> <question> <description>\n";
	exit 3;
}

sub escape_for_html {
	my $s = shift;
	$s =~ s/&/&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/"/&quot;/g;
	$s =~ s/'/&apos;/g;
	$s =~ s/\n/<br\/>/g;
	return $s;
}

sub escape_for_title {
	my $s = shift;
	$s =~ s/\n/ /g;
	$s =~ s/'/"/g;
	return $s;
}

sub gettime {
	my $tnow = `TZ="America/Detroit" date +%H:%M`;
	chomp $tnow;
	$tnow =~ m/([0-9][0-9]):([0-9][0-9])/ or die "Unable to parse time";
	my $h = $1;
	my $m = $2 - ($2 % 15);
	return sprintf("%02d:%02d:00", $h, $m);
}

sub getdate {
	my ($mtime, $offset) = @_;
	my $d;
	if (defined($offset)) {
		$d = `TZ="America/Detroit" date +%F --date="$mtime $offset"`;
	} else {
		$d = `TZ="America/Detroit" date +%F --date="$mtime"`;
	}
	chomp $d;
	return $d;
}

sub find_form {
	my ($html, $base, $pred) = @_;
	my @forms = HTML::Form->parse($html, $base);
	for my $form (@forms) {
		return $form if $pred->($form);
	}
	return undef;
}

sub add_cookie_string {
	my ($jar, $cookie_str) = @_;
	return unless defined($cookie_str) && length($cookie_str);
	for my $pair (split /\s*;\s*/, $cookie_str) {
		next unless $pair =~ /^([^=]+)=(.*)$/;
		my ($k, $v) = ($1, $2);
		for my $domain (qw(groups.oasis-open.org o-o.my.site.com .oasis-open.org .my.site.com)) {
			$jar->set_cookie(0, $k, $v, "/", $domain, 443, 0, 0, time + 86400, 0);
		}
	}
}

sub load_rc_creds {
	my ($user, $pass);
	{
		package RC;
		for my $file ("$ENV{HOME}/.virtio-tc-rc") {
			unless (my $return = do $file) {
				warn "couldn't parse $file: $@" if $@;
				warn "couldn't do $file: $!" unless defined $return;
				warn "couldn't run $file" unless $return;
			}
		}
		$user = $RC::USERNAME;
		$pass = $RC::PASSWORD;
	}
	return ($user, $pass);
}

sub extract_js_redirect {
	my ($html) = @_;
	if ($html =~ /url = '([^']+)'/) {
		return $1;
	}
	if ($html =~ /window\.location\.replace\("([^"]+)"\)/) {
		return $1;
	}
	return undef;
}

sub find_form_with_inputs {
	my ($html, $base, @required) = @_;
	my @forms = HTML::Form->parse($html, $base);
	for my $form (@forms) {
		my $ok = 1;
		for my $n (@required) {
			if (!defined $form->find_input($n)) {
				$ok = 0;
				last;
			}
		}
		return $form if $ok;
	}
	return undef;
}

sub do_noninteractive_login {
	my ($ua, $start_url, $username, $password) = @_;
	my $debug = $ENV{VIRTIO_DEBUG_AUTH};
	my $dbg = sub {
		return unless $debug;
		print STDERR "[auth] ", @_, "\n";
	};
	return 0 unless defined($username) && defined($password);

	$dbg->("start ", $start_url);
	my $resp = $ua->get($start_url);
	$dbg->("GET start status=", $resp->code, " url=", $resp->request->uri);
	return 0 unless $resp->is_success;

	my $saml_req_form = find_form_with_inputs($resp->decoded_content, $resp->base, "SAMLRequest", "RelayState");
	$dbg->("have SAMLRequest form=", defined($saml_req_form) ? 1 : 0);
	return 0 unless $saml_req_form;

	my $idp_resp = $ua->request($saml_req_form->click);
	$dbg->("POST SAMLRequest status=", $idp_resp->code, " url=", $idp_resp->request->uri);
	if ($idp_resp->is_redirect) {
		my $loc = $idp_resp->header('Location');
		$dbg->("POST SAMLRequest redirect=", defined($loc) ? $loc : "<none>");
		$idp_resp = $ua->get(URI->new_abs($loc, $idp_resp->request->uri)->as_string) if defined $loc;
		$dbg->("GET idp redirect status=", $idp_resp->code, " url=", $idp_resp->request->uri);
	}
	my $idp_html = $idp_resp->decoded_content;
	my $login_url = extract_js_redirect($idp_html);
	$dbg->("login_url=", defined($login_url) ? $login_url : "<none>");
	return 0 unless defined $login_url;

	my $login_resp = $ua->get($login_url);
	$dbg->("GET login status=", $login_resp->code, " url=", $login_resp->request->uri);
	return 0 unless $login_resp->is_success;
	my $login_html = $login_resp->decoded_content;
	my $login_uri = URI->new($login_resp->request->uri->as_string);

	$login_html =~ m{/s/sfsites/l/([^/]+)/inline\.js} or return 0;
	my $cfg_json = uri_unescape($1);
	my $cfg = decode_json($cfg_json);
	my $aura_context = encode_json({
		mode   => $cfg->{mode},
		fwuid  => $cfg->{fwuid},
		app    => $cfg->{app},
		loaded => $cfg->{loaded},
		dn     => [],
		globals => {},
		uad    => JSON::true,
	});

	my %qp = $login_uri->query_form;
	my $start_url_param = uri_unescape($qp{startURL} // "");
	$dbg->("start_url_param=", $start_url_param);
	return 0 unless length $start_url_param;

	my $msg = encode_json({
		actions => [{
			id => "1;a",
			descriptor => "apex://applauncher.LoginFormController/ACTION\$login",
			callingDescriptor => "markup://salesforceIdentity:loginForm2",
			params => {
				username => $username,
				password => $password,
				startUrl => $start_url_param,
			},
			version => "66.0",
		}],
	});

	my $aura_resp = $ua->post(
		"https://o-o.my.site.com/s/sfsites/aura?r=1&applauncher.LoginForm.login=1",
		{
			message => $msg,
			'aura.context' => $aura_context,
			'aura.pageURI' => $login_uri->path_query,
			'aura.token' => 'null',
		}
	);
	$dbg->("POST aura login status=", $aura_resp->code);
	return 0 unless $aura_resp->is_success;

	my $aura_json = eval { decode_json($aura_resp->decoded_content) };
	$dbg->("aura json parse=", $aura_json ? 1 : 0);
	return 0 unless $aura_json && ref($aura_json->{events}) eq 'ARRAY' && @{$aura_json->{events}};
	my $frontdoor = $aura_json->{events}[0]{attributes}{values}{url};
	$dbg->("frontdoor=", defined($frontdoor) ? $frontdoor : "<none>");
	return 0 unless defined($frontdoor) && $frontdoor =~ m{^https://};

	my $frontdoor_resp = $ua->get($frontdoor);
	$dbg->("GET frontdoor status=", $frontdoor_resp->code, " url=", $frontdoor_resp->request->uri);
	return 0 unless $frontdoor_resp->is_success;
	my $redir_path = extract_js_redirect($frontdoor_resp->decoded_content);
	$dbg->("redir_path=", defined($redir_path) ? $redir_path : "<none>");
	return 0 unless defined $redir_path;
	my $idp_url = ($redir_path =~ m{^https?://}) ? $redir_path : URI->new_abs($redir_path, "https://o-o.my.site.com")->as_string;
	my $idp_login_resp = $ua->get($idp_url);
	$dbg->("GET idp status=", $idp_login_resp->code, " url=", $idp_login_resp->request->uri);
	return 0 unless $idp_login_resp->is_success;

	my $saml_resp_form = find_form_with_inputs($idp_login_resp->decoded_content, $idp_login_resp->base, "SAMLResponse", "RelayState");
	$dbg->("have SAMLResponse form=", defined($saml_resp_form) ? 1 : 0);
	return 0 unless $saml_resp_form;
	my $consume_resp = $ua->request($saml_resp_form->click);
	$dbg->("POST SAMLResponse status=", $consume_resp->code, " url=", $consume_resp->request->uri);
	return 0 unless $consume_resp->is_success || $consume_resp->is_redirect;

	my $check = $ua->get($start_url);
	$dbg->("GET check status=", $check->code, " url=", $check->request->uri, " has_form=", ($check->decoded_content =~ /add_edit_ballot_form/) ? 1 : 0);
	return ($check->is_success && $check->decoded_content =~ /add_edit_ballot_form/);
}

my $NAME = escape_for_title($ARGV[0]);
my $QUESTION = escape_for_title($ARGV[1]);
my $DESCRIPTION = escape_for_html($ARGV[2]);

my $jar = HTTP::Cookies->new;
add_cookie_string($jar, $ENV{VIRTIO_COOKIE});

my $ua = LWP::UserAgent->new(
	agent => "virtio-ballot-lwp/1.0",
	cookie_jar => $jar,
	max_redirect => 10,
	timeout => 60,
);

my $url = 'https://groups.oasis-open.org/higherlogic/ws/groups/b3f5efa5-0e12-4320-873b-018dc7d3f25c/ballots/create_ballot';
my $resp = $ua->get($url);
die "GET failed: " . $resp->status_line . "\n" unless $resp->is_success;

my $edit_form = find_form(
	$resp->decoded_content,
	$resp->base,
	sub {
		my ($f) = @_;
		return (($f->attr("id") || "") eq "add_edit_ballot_form") ||
		       (($f->attr("name") || "") eq "add_edit_ballot_form");
	}
);

if (!$edit_form) {
	my ($username, $password) = load_rc_creds();
	my $ok = do_noninteractive_login($ua, $url, $username, $password);
	if (!$ok) {
		die "Authentication failed. Check ~/.virtio-tc-rc credentials.\n";
	}
	$resp = $ua->get($url);
	die "GET failed after login: " . $resp->status_line . "\n" unless $resp->is_success;
	$edit_form = find_form(
		$resp->decoded_content,
		$resp->base,
		sub {
			my ($f) = @_;
			return (($f->attr("id") || "") eq "add_edit_ballot_form") ||
			       (($f->attr("name") || "") eq "add_edit_ballot_form");
		}
	);
	die "Authenticated, but ballot form was not found.\n" unless $edit_form;
}

my $mtime = gettime();
my $start = getdate($mtime);
my $remind1 = getdate($mtime, "3 days");
my $remind2 = getdate($mtime, "5 days");
my $remind3 = getdate($mtime, "6 days");
my $end = getdate($mtime, "7 days");

$edit_form->value("name", $NAME);
$edit_form->value("question", $QUESTION);
$edit_form->value("description", $DESCRIPTION);
$edit_form->value("include_abstain", "1");
$edit_form->value("open_date", $start);
$edit_form->value("open_date_t", $mtime);
$edit_form->value("close_date", $end);
$edit_form->value("close_date_t", $mtime);
$edit_form->value("auto_update", "true");
$edit_form->value("official_ballot", "true");
$edit_form->value("enable_revotes", "true");
$edit_form->value("send_reminder", "true");
$edit_form->value("remind_date", $remind1);
$edit_form->value("remind_date_t", $mtime);
$edit_form->value("remind_date_2", $remind2);
$edit_form->value("remind_date_2_t", $mtime);
$edit_form->value("remind_date_3", $remind3);
$edit_form->value("remind_date_3_t", $mtime);
$edit_form->value("show_review_page", "Continue");

print "CREATE BALLOT AT $url\n";
my $review_req = $edit_form->click("show_review_page");
my $review_resp = $ua->request($review_req);
die "Review step failed: " . $review_resp->status_line . "\n" unless $review_resp->is_success;

my $review_form = find_form(
	$review_resp->decoded_content,
	$review_resp->base,
	sub {
		my ($f) = @_;
		return defined $f->find_input("show_done_page");
	}
);
die "Unable to locate review/accept form\n" unless $review_form;

$review_form->value("show_done_page", "Accept");
print "REVIEW BALLOT AT $url\n";
my $done_req = $review_form->click("show_done_page");
my $done_resp = $ua->request($done_req);
die "Accept step failed: " . $done_resp->status_line . "\n" unless $done_resp->is_success || $done_resp->code == 302;

my $ballot_url = $done_resp->request->uri->as_string;
if (my $loc = $done_resp->header('Location')) {
	$ballot_url = URI->new_abs($loc, $done_resp->request->uri)->as_string;
}
if ($ballot_url !~ /\?id=\d+$/) {
	my $html = $done_resp->decoded_content;
	if ($html =~ m{(https://groups\.oasis-open\.org/[^\s"'<>]*ballot\?id=\d+)}i) {
		$ballot_url = $1;
	} elsif ($html =~ m{(/higherlogic/ws/groups/[^\s"'<>]*/ballot\?id=\d+)}i) {
		$ballot_url = URI->new_abs($1, $done_resp->request->uri)->as_string;
	}
}
print "BALLOT VOTING AT URL: $ballot_url\n";
exit(11) unless $ballot_url =~ /\?id=([0-9]+)(?:$|[&])/;
my $id = $1;
my $publicurl = "https://groups.oasis-open.org/higherlogic/ws/public/ballot?id=" . $id;
print "BALLOT CREATED AT URL: $publicurl\n";

exit 0;
