#!/usr/bin/bash

echo -n "Approve virtio-1.2-csd01 and submit Working Draft virtio-1.2-wd01 for public review" > /tmp/title

cat > /tmp/question << EOF
Should the TC approve the working draft virtio-1.2-wd01 as a Committee Specification Draft, and approve submitting virtio-1.2-wd01 for a 30-day public review?
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
committed directly into git under the "Minor changes" TC standing rule,
and included in the Working Draft virtio-1.2-wd01:

4237d22cd5b1 : 08 Sep 2019 : Nikos Dragazis :  content: fix typo
1571d741f300 : 08 Sep 2019 : Dr. David Alan Gilbert :  shared memory: Typo fix
1e30753d53d2 : 12 Oct 2019 : Jan Kiszka :  Fix \textasciicircum= in example code
f9bed5bcb25e : 12 Oct 2019 : Jan Kiszka :  Lift "Driver Notifications" to section level
f1f2f85c1482 : 27 Oct 2019 : Jan Kiszka :  Console Device: Add a missing word
acfe7bd5bcbe : 27 Oct 2019 : Michael S. Tsirkin :  README.md: document the minor cleanups standing rule
4be5d38ad692 : 24 Nov 2019 : Stefan Fritsch :  Fix typo
2c77526beb13 : 24 Nov 2019 : Cornelia Huck :  virtio-net: add missing articles for new hdr_len feature
50049af040d4 : 20 Jan 2020 : Michael S. Tsirkin :  virtio_pci_cap64: bar/BAR cleanups
8361dd6eb0f4 : 20 Jan 2020 : Michael S. Tsirkin :  virtio-net: receive-side scaling
1efcda892193 : 20 Jan 2020 : Michael S. Tsirkin :  virtio-net: missing "." for feature descriptions
6914d2df75ec : 28 Jan 2020 : Keiichi Watanabe :  content: Reserve device ID for video encoder and decoder device
f42cc75d0725 : 01 Mar 2020 : Michael S. Tsirkin :  virtio-net/rss: maximal -> maximum
089bc5911dea : 04 May 2020 : Jean-Philippe Brucker :  virtio-iommu: Remove invalid requirement about padding
7a46ee550d70 : 01 Sep 2020 : David Hildenbrand :  conformance: make driver conformance list easier to read and maintain
9abf00ff4654 : 01 Sep 2020 : David Hildenbrand :  conformance: Reference RPMB Driver Conformance
9164d35e4b2a : 13 Nov 2020 : Alexander Duyck :  content: Minor change to clarify free_page_hint_cmd_id
6ee5e4b54c8e : 26 Jan 2021 : Felipe Franciosi :  content: Fix driver/device wording on ISR bits
a17c29e2201b : 26 Jan 2021 : Alex Bennée :  virtio-gpu.tex: fix some UTF-8 damage
f144e1847b95 : 06 Apr 2021 : Cornelia Huck :  title: list myself as Chair
0711d7f18fa7 : 14 Apr 2021 : Cornelia Huck :  editorial: fix missing escape of '\#'
5749014a3d50 : 17 May 2021 : Yuri Benditovich :  virtio-net: fix mistake: segmentation -> fragmentation
a57fb86cdb03 : 10 Jun 2021 : Jiang Wang :  virtio-net: fix a display for num_buffers
63236f177602 : 08 Jul 2021 : Stefan Hajnoczi :  virtio-fs: add file system device to Conformance chapter
eb6ef453af9b : 26 Jul 2021 : Cornelia Huck :  Reserved feature bits: fix missing verb
74822ee60ea9 : 27 Jul 2021 : Gaetan Harter :  content: fix a typo
23d3f7a3a7c9 : 27 Jul 2021 : Gaetan Harter :  virtio-gpu: fix a typo
247709f69260 : 29 Jul 2021 : Gaetan Harter :  virtio-crypto: fix missing conjunction and verb
1dc3ff82ab18 : 10 Aug 2021 : Max Gurtovoy :  virtio-blk: fix virtqueues accounting
f5a8d38acbd0 : 04 Oct 2021 : Max Gurtovoy :  Fix copy/paste bug in PCI transport paragraph
bcf4bddb256e : 07 Oct 2021 : Jean-Philippe Brucker :  content: Remove duplicate paragraph
591eb4c2f76e : 07 Oct 2021 : Cornelia Huck :  PCI: fix level for vendor data capability
b5115a8fc8ed : 15 Oct 2021 : David Hildenbrand :  virtio-mem: simplify statements that express unexpected behavior on memory access
708ef827b092 : 15 Oct 2021 : David Hildenbrand :  virtio-mem: rephrase remaining memory access statements
f579906e7364 : 15 Oct 2021 : David Hildenbrand :  virtio-mem: document basic memory access to plugged memory blocks
48340e86b087 : 29 Nov 2021 : Halil Pasic :  split-ring: clarify the field len in the used ring
ec3997b8a402 : 30 Nov 2021 : Cornelia Huck :  pmem: correct wording
5e1c3fa81e29 : 21 Jan 2022 : Arseny Krasnov :  virtio-vsock: use C style defines for constants
1a90fc6e4228 : 21 Jan 2022 : Stefano Garzarella :  virtio-vsock: add VIRTIO_VSOCK_F_STREAM feature bit
6708e0fc2f7d : 07 Apr 2022 : Michael S. Tsirkin :  virtio-gpio: offered -> negotiated
a214ffb64f45 : 11 Apr 2022 : Cornelia Huck :  introduction: add more section labels
79f705b96040 : 11 Apr 2022 : Cornelia Huck :  conformance: hook up GPU device normative statements
26f15550226b : 19 Apr 2022 : Michael S. Tsirkin :  packed-ring: fix some typos
b13f67fca90e : 20 Apr 2022 : Michael S. Tsirkin :  packed-ring.tex: link conformance statements
3a7f07897958 : 20 Apr 2022 : Michael S. Tsirkin :  content.tex: drop space after \textbackslash field

The TC agrees to include the above change(s) in virtio-v1.2-cs01 and future
versions of the specification.

2.  The TC approves Virtual I/O Device (VIRTIO) Version 1.2 Working Draft 01
(virtio-v1.2-wd01) and all associated artifacts packaged together in
https://www.oasis-open.org/committees/document.php?document_id=69844&wg_abbrev=virtio
as a Committee Specification Draft virtio-v1.2-csd01 and designate the Tex
version of the specification as authoritative.

Note: should this working draft be approved as a Committee Specification Draft,
one or more claims disclosed to the TC admin and listed on the Virtio TC IPR
page https://github.com/oasis-tcs/virtio-admin/blob/master/IPR.md might become
Essential Claims.



3.  The TC approves submitting
Virtual I/O Device (VIRTIO) Version 1.2 Working Draft 01
contained in
https://www.oasis-open.org/committees/document.php?document_id=69844&wg_abbrev=virtio
for a 30-day public review.


Location of the working draft:

https://www.oasis-open.org/committees/download.php/69844/virtio-v1.2-wd01.zip

This archive includes the editable Tex sources,
specification in PDF and HTML formats, as well as
versions with changes since virtio-v1.1-cs01 highlighted. 

You can also use the "revision history" chapter to locate the changes more easily.

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
