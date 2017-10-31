#!/usr/bin/bash

cd /scm/scripts

echo -n "do XYZ" > /tmp/title


cat > /tmp/question << EOF
Should the TC do XYX?
EOF

cat > /tmp/description <<EOF
Please vote Yes if you agree with all of the following.
If you disagree, please vote No.
If you don't have an opinion, please vote Abstain.

I move that:
The TC agrees to do XYZ
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

./virtio-ballot.pl "$(cat /tmp/title)" "$(cat /tmp/question)" "$(cat /tmp/description)" | tee /tmp/ballot-issue-log

ballot=$(grep 'BALLOT CREATED' /tmp/ballot-issue-log)
