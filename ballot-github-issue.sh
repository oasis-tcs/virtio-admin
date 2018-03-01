#!/usr/bin/bash

cd /scm/scripts

ISSUE=$1

if
	./virtio-jira.pl -p t $ISSUE > /tmp/summary
then
	TITLE=$(cat /tmp/summary)
else
	exit 1
fi

echo -n "Resolve $ISSUE: $TITLE" > /tmp/title

if
	./virtio-github.pl -p f $ISSUE > /tmp/fixVersions
then
	versions="specification version(s) "
	for v in "$(cat /tmp/fixVersions)"
	do
		versions="$versions\"$v\", "
	done
	versions="${versions}and "
else
	versions=""
fi

cat > /tmp/question << EOF
Should the TC accept changes listed in the description to resolve issue $ISSUE,
for inclusion in ${versions}future versions of the specification?
EOF

if
	./virtio-github.pl -p d $ISSUE > /tmp/prob
then
	prob=1
else
	exit 2
fi
if
	./virtio-github.pl -p p $ISSUE > /tmp/proposal
then
	res=1
else
	exit 3
fi

cat > /tmp/description <<EOF
Please vote Yes if you agree with all of the following.
If you disagree, please vote No.
If you don't have an opinion, please vote Abstain.

I move that:
The TC agrees to resolve the following specification issue:
$ISSUE: $TITLE
--------------------------------------
EOF
cat /tmp/prob >> /tmp/description
cat >> /tmp/description <<EOF
--------------------------------------

The TC accepts the following proposed changes to the specification:
--------------------------------------
EOF

cat /tmp/proposal >> /tmp/description

cat >> /tmp/description <<EOF
--------------------------------------

The TC agrees to include the above change(s) in ${versions}future versions of the
specification.

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
./virtio-github.pl -comment "$ballot" $ISSUE 
