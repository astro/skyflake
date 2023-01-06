{ lib, writeScript, runtimeShell, ceph }:

writeScript "make-ceph" ''
  #! ${runtimeShell} -e

  PATH=${lib.makeBinPath [ ceph ]}

  ceph-authtool --create-keyring ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'

  ceph-authtool --create-keyring ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
''
