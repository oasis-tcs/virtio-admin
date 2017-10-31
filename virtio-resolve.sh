#!/usr/bin/sh

if
	git log --format=%B -n 1 "$@"| grep git-svn-id:
then
	git log --format=%B -n 1 "$@"
else
	git log --format=%B -n 1 "$@"
	echo "Revision does not appear in svn: ""$@"
	echo "You probably forgot to commit:"
	echo "git svn dcommit"
	exit 1
fi

issue=`git log --format=%B -n 1 "$@"| sed -n 's/^.*\(VIRTIO-[0-9]*\).*/\1/p'`
git log --format=%B -n 1 "$@"| $HOME/scm/scripts/virtio-tc.pl -resolution $issue
