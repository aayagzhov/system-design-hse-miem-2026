PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha> .\fix-and-rebuild.ps1
0/8 git pull
Already up to date.
1/8 git config core.autocrlf false
2/8 fix entrypoint.sh CRLF -> LF
Fixed: patroni-master\docker\entrypoint.sh
Done. Rebuild: cd patroni-master; docker build --build-arg PG_MAJOR=15 -t patroni .
   hex: 23 21 2F 62 69 6E 2F 73 68 0A 0A 69 66 20 5B 20
   OK: LF line endings
3/8 vendor deps for offline build
   downloading etcd + confd on Windows...
Downloading C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha\patroni-master\vendor\etcd.tar.gz ...
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
  0      0   0      0   0      0      0      0                              0
  0      0   0      0   0      0      0      0                              0
  0      0   0      0   0      0      0      0           00:22              0
curl: (35) Recv failure: Connection was reset
   download failed: Download failed: https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz (curl exit 35). Try VPN, mobile hotspot, or download in browser.

   Download in browser and save to patroni-master\vendor\ :
   etcd:  https://github.com/coreos/etcd/releases/download/v3.3.13/etcd-v3.3.13-linux-amd64.tar.gz
          -> vendor\etcd.tar.gz
   confd: https://github.com/kelseyhightower/confd/releases/download/v0.16.0/confd-0.16.0-linux-amd64
          -> vendor\confd   (no extension!)
vendor files missing. Use VPN or browser download, then run again.
C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha\fix-and-rebuild.ps1:49 знак:9
+         throw "vendor files missing. Use VPN or browser download, the ...
+         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (vendor files mi...then run again.:String) [], RuntimeException
    + FullyQualifiedErrorId : vendor files missing. Use VPN or browser download, then run again.
 
PS C:\Users\User\CppProjects\system-design-hse-miem-2026\code\postgres-ha> 