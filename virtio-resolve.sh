#!/usr/bin/sh

issue=`git log --format=%B -n 1 "$@"| sed -n 's/^.*\(VIRTIO-[0-9]*\).*/\1/p'`
git show -s "$@"| $HOME/scm/scripts/virtio-tc.pl -resolution $issue
