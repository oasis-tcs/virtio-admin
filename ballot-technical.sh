#!/usr/bin/bash

#usage ./ballot-technical.sh 471 475 virtio-v1.0-cs03
FROM=$1
TO=$2
VERSION=$3

if
	test $(expr "$FROM" : '^[0-9]*$') -eq 0
then
	echo NO FIRST REVISION: ABORTING
	echo Usage: ballot-technical.sh 100 200 virtio-v1.0-cs03
	exit 9
fi

if
	test $(expr "$TO" : '^[0-9]*$') -eq 0
then
	echo NO LAST REVISION: ABORTING
	echo Usage: ballot-technical.sh 100 200 virtio-v1.0-cs03
	exit 8
fi

if
	test $(expr "$VERSION" : '^virtio-v') -eq 0
then
	echo NO VERSION, should match virtio-vXXXXXXXX: ABORTING
	echo Usage: ballot-technical.sh 100 200 virtio-v1.0-cs03
	exit 7
fi

echo -n "Accept changes r$FROM to r$TO" > /tmp/title

cat > /tmp/question << EOF
Should the TC accept svn changes r$FROM to r$TO inclusive
for inclusion in $VERSION and future versions of the specification?
EOF

cat > /tmp/description <<EOF
Please vote Yes if you agree with all of the following.
If you disagree, please vote No.
If you don't have an opinion, please vote Abstain.

I move that:

The TC accepts the following changes to the specification:
EOF

(cd /scm/virtio; git svn log -r $1:$2) >> /tmp/description

cat >> /tmp/description <<EOF

The TC agrees to include the above change(s) in ${VERSION} and future versions of the
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

./virtio-ballot.pl "$(cat /tmp/title)" "$(cat /tmp/question)" "$(cat /tmp/description)"
