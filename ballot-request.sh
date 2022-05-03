#!/usr/bin/bash

echo -n "Approve virtio-1.2-csd02 and submit Working Draft virtio-1.2-wd02 for public review" > /tmp/title

cat > /tmp/question << EOF
Should the TC approve the working draft virtio-1.2-wd02 as a Committee Specification Draft, and approve submitting virtio-1.2-wd02 for a 30-day public review?
EOF

#how to get list of editorial changes from the changelog:
#git grep -e '^[0-9a-f]\+ &' -e 'Fixes: \\url' cl-os.tex  > list.txt
#now in vi
#:g/Fixes:/.-1,.d

cat > /tmp/description <<EOF
Please vote Yes if you agree with all of the following.
If you disagree, please vote No.
If you don't have an opinion, please vote Abstain.

I move that:

1. The TC accepts the following changes to the specification,
included in the Working Draft virtio-1.2-wd02:

acknowledgements: update for 1.2
See https://lists.oasis-open.org/archives/virtio-comment/202205/msg00000.html


2. The TC agrees to resolve the following specification issue:
------------------------------------------------------------------------
https://github.com/oasis-tcs/virtio-spec/issues/139

A recently defined queue_reset register has a little weird definition that we should improve.
When driver initiate queue reset, it writes queue_reset = 1.
When device is busy resetting the queue, on this driver request, it is expected to return queue_reset=0.
Once queue reset is completed it is expected to return queue_reset = 1.
(Polarity changed twice to same value as what was driver set).

The TC accepts the following proposed changes to the specification:

https://lists.oasis-open.org/archives/virtio-comment/202204/msg00119.html

already included in the Working Draft virtio-1.2-wd02.

------------------------------------------------------------------------

The TC agrees to include the above change(s) in virtio-v1.2-csd02 and future versions of the
specification.


2.  The TC approves Virtual I/O Device (VIRTIO) Version 1.2 Working Draft 02
(virtio-v1.2-wd02) and all associated artifacts packaged together in
https://www.oasis-open.org/apps/org/workgroup/virtio/document.php?document_id=69878
as a Committee Specification Draft virtio-v1.2-csd02 and designate the Tex
version of the specification as authoritative.

Note: should this working draft be approved as a Committee Specification Draft,
one or more claims disclosed to the TC admin and listed on the Virtio TC IPR
page https://github.com/oasis-tcs/virtio-admin/blob/master/IPR.md might become
Essential Claims.



3.  The TC approves submitting
Virtual I/O Device (VIRTIO) Version 1.2 Working Draft 02
contained in
https://www.oasis-open.org/apps/org/workgroup/virtio/document.php?document_id=69878
for a 30-day public review.


Location of the working draft:

https://www.oasis-open.org/apps/org/workgroup/virtio/document.php?document_id=69878

This archive includes the editable Tex sources,
specification in PDF and HTML formats, as well as
versions with changes since virtio-v1.1-cs01
as well as versions with changes since virtio-v1.1-wd02 highlighted.

You can also use the "revision history" chapter to locate the changes more easily.

4. This supercedes the previous decision
(https://www.oasis-open.org/committees/ballot.php?id=3693) to submit
virtio-v1.2-wd01 for a 30 day public review. virtio-v1.2-wd02 will be submitted
instead. virtio-v1.2-wd02 includes all changes in virtio-v1.2-wd01 with the
addition of the acknowledgements section change (1) above and the fix for
https://github.com/oasis-tcs/virtio-spec/issues/139 (2) above.



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
