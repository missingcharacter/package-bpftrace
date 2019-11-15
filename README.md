# Simple build bpftrace rpm for Amazon Linux

```
$ git clone https://github.com/missingcharacter/package-bpftrace.git
$ cd package-bpftrace
$ bash create-rpms.sh
...
wait a loooooooooong time
...
$ find . -type f -name "*.rpm"
./builddir/bpftrace/build/ncurses-6.0-0.x86_64.rpm
./builddir/bpftrace/build/bpftrace-0.9.2-0.x86_64.rpm
./builddir/bpftrace/build/bison-3.1-0.x86_64.rpm
```
