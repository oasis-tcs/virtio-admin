#!/usr/bin/bash

echo -n "Request a Special Majority Vote for the advancement of the draft virtio-1.0-wd04 as a Committee Specification virtio-1.0-cs04" > /tmp/title

cat > /tmp/question << EOF
Should the TC accept changes listed in the description as non material, and Request a Special Majority Vote for the advancement of the draft virtio-1.0-wd04 with these changes as a Committee Specification virtio-1.0-cs04?
EOF

cat > /tmp/description <<EOF
Please vote Yes if you agree with all of the following.
If you disagree, please vote No.
If you don't have an opinion, please vote Abstain.

I move that:

The TC accepts the following changes to the specification:
EOF

(cd /scm/virtio; git svn log -r 553:566) >> /tmp/description

cat >> /tmp/description <<EOF

The TC agrees to include the above change(s) in virtio-v1.0-cs04 and future
versions of the specification.

The TC resolves that the above changes to virtio-v1.0-csprd05 are all Non-Material.

The TC resolves to request a Special Majority Vote for the advancement of the draft
virtio-v1.0-wd04, with the above changes, as a Committee Specification virtio-v1.0-cs04.

Location of the specification draft with the above changes:

https://www.oasis-open.org/apps/org/workgroup/virtio/download.php/57543/virtio-v1.0-wd04.zip

This archive includes the editable Tex sources,
specification in PDF and HTML formats, as well as
versions with changes since CS03 highlighted. 

You can also use the "revision history" chapter to locate the changes more easily:
revision numbers 554 to 559 inclusive in this chapter refer to changes made
since virtio-v1.0-csprd05.

--------------------------------------

Reminder: A Voting Member must be active in a TC to maintain voting rights.  As
the Virtio TC has adopted a standing rule to conduct business only by
electronic ballot, without Meetings, a Voting Member who fails to cast a ballot
in two consecutive Work Product Ballots loses his or her voting rights at the
close of the second ballot missed.

--------------------------------------
EOF

vim /tmp/title
c=`wc -c </tmp/title`
if
	test $c -lt 6
then
	echo NO TITLE: ABORTING
	exit 4
fi

vim /tmp/question
c=`wc -c </tmp/question`
if
	test $c -lt 6
then
	echo NO QUESTION: ABORTING
	exit 5
fi
vim /tmp/description
c=`wc -c </tmp/description`
if
	test $c -lt 6
then
	echo NO DESCRIPTION: ABORTING
	exit 6
fi

./virtio-ballot.pl "$(cat /tmp/title)" "$(cat /tmp/question)" "$(cat /tmp/description)"
