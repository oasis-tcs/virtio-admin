#!/usr/bin/perl
use strict;
use warnings;
use Selenium::Remote::Driver;
use Selenium::Remote::WDKeys;
use Time::HiRes qw(sleep);

#This uses Selenium now, which one has to download and run separately.
#
#    See selenium.sh
#    
#    Also on fedora selenium is not packaged.
#    to get it from cpan, run this command:
#    
#            cpanm Selenium::Remote::Driver

print $#ARGV;
#argument parsing
if ($#ARGV != 2) {
	print STDERR "usage: virtio-ballot.pl <name> <question> <description>\n";
	exit 3;
}
###########################################################################
#helper functions
###########################################################################

# Custom wait function for selenium to wait for an element to appear
sub wait_for_element {
    my ($driver, $locator, $timeout) = @_;
    my $elapsed_time = 0;
    while ($elapsed_time < $timeout) {
        my $element = eval { $driver->find_element($locator, 'xpath') };
        return $element if $element;
        sleep 1;
        $elapsed_time += 1;
    }
    die "Element with locator '$locator' not found after $timeout seconds";
}
#scroll down until element is visible
sub wait_and_click {
    my ($driver, $element) = @_;
    my $elapsed_time = 0;
    while (1) {
        my $clicked = eval { $element->click(); 1; };
        return $clicked if $clicked;
	sleep(1);
    }
    die "Element with locator '$element' not clicked";
}
#scroll down until element is visible
sub scroll_and_click {
    my ($driver, $element) = @_;
    my $elapsed_time = 0;
    while (1) {
        my $clicked = eval { $element->click(); 1; };
        return $clicked if $clicked;
	$driver->execute_script("window.scrollBy(0,10)");
    }
    die "Element with locator '$element' not clicked";
}
sub wait_for_visible {
    my ($element, $timeout) = @_;
    my $elapsed_time = 0;
    while ($elapsed_time < $timeout) {
        return $element if !$element->is_hidden();
        sleep 1;
        $elapsed_time += 1;
    }
    die "Element '$element' not visible after $timeout seconds";
}
#set checkbox
sub set_checkbox {
	my ($checkbox, $value) = @_;
	my $is_checked = $checkbox->get_attribute("checked");
	if (!$is_checked) {
		# sending space to checkbox flips it
		$checkbox->send_keys(" ");
	}
	# Verify the checkbox is checked by re-checking the 'checked' attribute
	$is_checked = $checkbox->get_attribute('checked');
	print "CHECKED ", $is_checked, "\n";
	#die unless $is_checked;
}

#set checkbox
#sub set_checkbox {
#	my ($checkbox, $value) = @_;
#	my $is_checked = $checkbox->get_attribute("checked");
#	print $is_checked, " ", length($is_checked), "\n";
#	if ((!$is_checked) ne (!$value)) {
#		# sending space to checkbox flips it
#		$checkbox->send_keys(" ");
#		print "flip\n";
#	}
#	# Verify the checkbox is checked by re-checking the 'checked' attribute
#	$is_checked = $checkbox->get_attribute('checked');
#	print $is_checked, " ", length($is_checked), "\n";
#	die unless (!$is_checked) eq (!$value);
#}


sub set_date_time {
	my ($driver, $name, $day, $h, $m) = @_;
	my $index = $h * 4 + ($m + 14) / 15 + 1; #1st entry is "Time" with dummy value 0
	my $date = $driver->find_element('//input[@id="' . $name . '"]', 'xpath');
	$date->clear();
	$date->send_keys($day);
	$date->send_keys(KEYS->{'escape'});
	scroll_and_click($driver, $date);
	my $date_t = $driver->find_element('//select[@id="' . $name . '_t"]', 'xpath');
	$date_t->execute_script('arguments[0].selectedIndex=' . $index . ';');
	#TODO: we can actually validate time value here, not bothering now
	die unless $date_t->get_value() =~ m/(..):..:../;
}


# get current eastern time.
sub gettime {
	my $tnow=`TZ="America/Detroit" date +%H:%M`;
	$tnow =~ m/([0-9][0-9]):([0-9][0-9])/;
	my $hnow = $1;
	my $mnow = $2;
	return "$hnow:$mnow:00";
}

# get current date
sub getdate {
	my $mtime=shift;
	my $offset=shift;
	if (defined($offset)) {
		return `TZ="America/Detroit" date +%F --date="$mtime $offset"`;
	} else {
		return `TZ="America/Detroit" date +%F --date="$mtime"`;
	}
};

sub escape_for_html {
	my $s=shift;
	$s =~ s/&/&amp;/sg;
	$s =~ s/</&lt;/sg;
	$s =~ s/>/&gt;/sg;
	$s =~ s/"/&quot;/sg;
	$s =~ s/'/&apos;/sg;

	$s =~ s/\n/<br\/>/sg;
	$s =~ s/\\/\\\\/sg;
	return $s;
}

#some fields are different. Donnu why /shrugs
sub escape_for_title {
	my $s=shift;
	$s =~ s/\n/ /g;
	$s =~ s/'/"/sg;
	$s =~ s/\\/\\\\/sg;
	return $s;
}
###########################################################################
#create ballot
###########################################################################

#load ballot info
my $NAME=$ARGV[0];
#no line breaks in title
$NAME = escape_for_title($NAME);

my $QUESTION=$ARGV[1];
$QUESTION = escape_for_title($QUESTION);

my $DESCRIPTION=$ARGV[2];
$DESCRIPTION = escape_for_html($DESCRIPTION);

#text says there is a 750 maximum character limit,
#but things seem to work anyway ...


#load username and password
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


# Initialize the driver
my $driver = Selenium::Remote::Driver->new(
    remote_server_addr => 'localhost',
    port               => 4444,
    browser_name       => 'firefox'
);

my $url = 'https://groups.oasis-open.org/higherlogic/ws/groups/b3f5efa5-0e12-4320-873b-018dc7d3f25c/ballots/create_ballot';
print "LOGIN as $USERNAME at $url\n";

# Step 1: Navigate to the initial URL
$driver->get($url);

# Step 2: Explicitly wait for the login button to appear
my $login_button = wait_for_element($driver, '//button[contains(@class, "loginButton")]', 130);

# Step 3: Locate the username and password fields using placeholder text
my $username_field = $driver->find_element('//input[@placeholder="Username"]', 'xpath');
my $password_field = $driver->find_element('//input[@placeholder="Password"]', 'xpath');

# Step 4: Fill in the username and password
$username_field->send_keys($USERNAME);
$password_field->send_keys($PASSWORD);

# Step 5: Click the login button
$login_button->click;

# Step 6: wait until continue button
my $continue_button = wait_for_element($driver, '//input[@value="Continue"]', 130);

print "LOGIN successful\n";

my $timenow = gettime();
my $start = getdate($timenow);
my $remind1 = getdate($timenow, "3 days");
my $remind2 = getdate($timenow, "5 days");
my $remind3 = getdate($timenow, "6 days");
my $end = getdate($timenow, "7 days");
$timenow =~ m/(..):(..):00/;
my $h = $1;
my $m = $2;

my $title_field = $driver->find_element('//input[@id="name"]', 'xpath');
# not sure this is needed oh well
wait_for_visible($title_field, 30);

my $cookie_button = wait_for_element($driver, '//button[contains(@class, "btn btn-success")]', 130);
#Selenium bug: clicking buttons does not trigger onclick event
#invoke manually
$driver->execute_script("HigherLogic.Microsites.Ui.dropCookieNotification(arguments[0]);", $cookie_button);

$title_field->execute_script("arguments[0].value = '" . $NAME . "';");

my $question_field = $driver->find_element('//input[@id="question"]', 'xpath');

$question_field->execute_script("arguments[0].value = '" . $QUESTION . "';");

my $description_field = $driver->find_element('//textarea[@id="description"]', 'xpath'); #name is also description

$description_field->execute_script("arguments[0].value = '" . $DESCRIPTION . "';");

my $abstain_field = $driver->find_element('//input[@name="include_abstain"]', 'xpath');
scroll_and_click($driver, $abstain_field);
die unless $abstain_field->is_selected();

set_date_time($driver, "open_date", $start, $h, $m);
set_date_time($driver, "close_date", $end, $h, $m);

#voter management.
#Auto-update: second option is true
my $auto_update = $driver->find_element('//select[@name="auto_update"]', 'xpath');
$auto_update->execute_script('arguments[0].selectedIndex=0;');
die unless $auto_update->get_value() eq "true";


#official ballot - what else?
my $official_ballot = $driver->find_element('//input[@name="official_ballot"]', 'xpath');
scroll_and_click($driver, $official_ballot);
die unless $official_ballot->is_selected();

#enable revotes - why not?
my $enable_revotes = $driver->find_element('//select[@name="enable_revotes"]', 'xpath');
$enable_revotes->execute_script('arguments[0].selectedIndex=0;');
die unless $enable_revotes->get_value() eq "true";

#email non-voters
my $ballot_email_nonvoter = $driver->find_element('//select[@name="ballot_email_nonvoter[]"]', 'xpath');
$ballot_email_nonvoter->execute_script('arguments[0].options[0].selected=true;');
$ballot_email_nonvoter->execute_script('arguments[0].options[1].selected=true;');
#not sure how to validate, whatever

#reminders
my $send_reminder_field = $driver->find_element('//input[@name="send_reminder"]', 'xpath');
scroll_and_click($driver, $send_reminder_field);
die unless $send_reminder_field->is_selected();


set_date_time($driver, "remind_date", $remind1, $h, $m);

set_date_time($driver, "remind_date_2", $remind2, $h, $m);

set_date_time($driver, "remind_date_3", $remind3, $h, $m);

#print "ENTER to continue:";
#{ my $line = <STDIN>; }

print "CREATE BALLOT AT $url\n";
#OASIS Rate limits us now? Give them a second.
sleep(1);

scroll_and_click($driver, $continue_button);
#print "ENTER to accept:";
#{ my $line = <STDIN>; }

my $accept_button = wait_for_element($driver, '//input[@value="Accept"]', 130);

print "REVIEW BALLOT AT $url\n";

scroll_and_click($driver, $accept_button);

my $actions_link = wait_for_element($driver, '//a[contains(.,"Actions")]', 130);

my $ballot_url = $driver->get_current_url();

print "BALLOT VOTING AT URL: $ballot_url\n";
exit (11) unless $ballot_url =~ m/\?id=([0-9]+)$/;
my $id = $1;
my $publicurl = "https://groups.oasis-open.org/higherlogic/ws/public/ballot?id=" . $id;
print "BALLOT CREATED AT URL: $publicurl\n";

#print "ENTER to exit:";
#{ my $line = <STDIN>; }

#
#$edit_ballot{"admin_only_results"} = "0";
#$edit_ballot{"attendance_x"} = "3";
#$edit_ballot{"attendance_y"} = "5";
#$edit_ballot{"auto_update"} = "true";
#$edit_ballot{"ballot_email_close"} = "on";
#$edit_ballot{"ballot_email_nonvoter_close"} = "on";
#$edit_ballot{"ballot_email_nonvoter_open"} = "on";
#$edit_ballot{"ballot_email_open"} = "on";
#$edit_ballot{"ballot_email_present"} = "true";
#$edit_ballot{"close_date"} = $end;
#$edit_ballot{"close_date_t"} = $mtime;
#$edit_ballot{"comment_req_other"} = "Optional";
#$edit_ballot{"eligible_voters"} = "voters";
#$edit_ballot{"enable_revotes"} = "true";
#$edit_ballot{"enable_other_option"} = undef;
#$edit_ballot{"enforce_attendance_flag"} = undef;
#$edit_ballot{"include_abstain"} = "1";
#$edit_ballot{"members_view_results"} = "true";
#$edit_ballot{"official_ballot"} = "true";
#$edit_ballot{"open_date"} = $start;
#$edit_ballot{"open_date_t"} = $mtime;
#$edit_ballot{"option_count"} = "1";
#$edit_ballot{"option_style"} = "upto";
#$edit_ballot{"options_comment_req[]"} = undef;
#$edit_ballot{"options_comment_req[yes]"} = "Optional";
#$edit_ballot{"options_comment_req[no]"} = "Optional";
#$edit_ballot{"options_comment_req[abstain]"} = "Optional";
#$edit_ballot{"remind_date"} = $remind1;
#$edit_ballot{"remind_date_t"} = $mtime;
#$edit_ballot{"remind_date_2"} = $remind2;
#$edit_ballot{"remind_date_2_t"} = $mtime;
#$edit_ballot{"remind_date_3"} = $remind3;
#$edit_ballot{"remind_date_3_t"} = $mtime;
#$edit_ballot{"results_open"} = "after_opens";
#$edit_ballot{"send_reminder"} = "true";
#$edit_ballot{"show_result_details"} = "true";
#$edit_ballot{"time_zone_id"} = "1";
#$edit_ballot{"type"} = "yes_no";
#$edit_ballot{"update_list"} = undef;
#$edit_ballot{"add_more_wg_references"} = undef;
##form EDIT BALLOT OPTIONS key name = 
##form EDIT BALLOT OPTIONS key question = 
##form EDIT BALLOT OPTIONS key text = 
#$edit_ballot{"name"} = $NAME;
#$edit_ballot{"question"} = $QUESTION;
#$edit_ballot{"text"} = $DESCRIPTION;
#$edit_ballot{"show_review_page"} = "Continue &gt;&gt;";


# Print the result page's HTML
#my $result_page_html = $driver->get_page_source();
#print "Result Page HTML:\n$result_page_html\n";

exit(1);

# Close the driver
$driver->quit;
