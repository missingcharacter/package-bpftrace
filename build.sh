#!/usr/bin/env bash
set -eEu -o pipefail
shopt -s extdebug
IFS=$'\n\t'

builddir=/mnt/builddir	# change to suit your system: needs about 2 Gbytes free

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# dependencies
yum install -y git cmake3 gcc64-c++.x86_64 bison flex bcc-devel wget vim diffutils help2man texinfo file ruby-devel gcc make rpm-build rubygems

# llvm
# we may no longer need to download clang6.0 and just `yum install clang6.0`
cd $builddir

if [ -f "${builddir}/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27.tar.xz" ]; then
  echo "no need to download clang again"
else
  wget http://releases.llvm.org/6.0.0/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27.tar.xz
fi

if [ -d "${builddir}/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27" ]; then
  echo "no need to untar clang"
else
  tar xf clang*
fi

(cd clang* && cp -R * /usr/local/)
cp -p /usr/lib64/llvm6.0/lib/libLLVM-6.0.so /usr/lib64/libLLVM.so

# libtinfo.so.6 (comes from ncurses)
cd $builddir

if [ -f "${builddir}/ncurses-6.0.tar.gz" ]; then
  echo "no need to download ncurses again"
else
  wget ftp://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz
fi

if [ -d "${builddir}/ncurses-6.0" ]; then
  echo "no need to untar ncurses"
else
  tar xvf ncurses-6.0.tar.gz
fi

cd ncurses-6.0
./configure --with-shared --with-termlib --prefix=/opt/ncurses
make -j8
make install
echo '/opt/ncurses/lib' > /etc/ld.so.conf.d/ncurses.conf

# bison
cd $builddir

if [ -f "${builddir}/bison-3.1.tar.gz" ]; then
  echo "no need to download bison again"
else
  wget http://ftp.gnu.org/gnu/bison/bison-3.1.tar.gz
fi

if [ -d "${builddir}/bison-3.1" ]; then
  echo "no need to untar bison"
else
  tar xf bison*
fi

cd bison-3.1
./configure --prefix=/opt/bison
make -j4
make install
echo '/opt/bison/lib' > /etc/ld.so.conf.d/bison.conf

export PATH="/opt/ncurses/bin:/opt/bison/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/lib:/opt/bison/lib:/opt/ncurses/lib"
rm /etc/ld.so.cache
rm /etc/ld.so.conf.d/llvm6.0-x86_64.conf
echo /usr/local/lib >> /etc/ld.so.conf
ldconfig -v
# bpftrace
cd $builddir
export STATIC_LINKING=ON

if [ -d "${builddir}/bpftrace" ]; then
  echo "no need to clone bpftrace repo"
else
  git clone https://github.com/iovisor/bpftrace
fi

cd bpftrace

if [ -d "${builddir}/bpftrace/build" ]; then
  echo "${builddir}/bpftrace/build exists I will remove it now, to start from scratch"
  rm -rf ${builddir}/bpftrace/build
else
  echo "${builddir}/bpftrace/build does not exist, we can begin now"
fi

mkdir build; cd build
cmake3 ..
make -j8
make install DESTDIR=/opt/bpftrace
# echo /usr/local/lib >> /etc/ld.so.conf
ldconfig -v

# Installing fpm EFFing Package Manager
gem install --no-ri --no-rdoc fpm
fpm --version
cp -r ${builddir}/bpftrace/build/man/man8 ${builddir}/bpftrace/build/man/man9
ls ${builddir}/bpftrace/build/man/man9 | grep -v '8.gz' | xargs -I{} rm -rf ${builddir}/bpftrace/build/man/man9/{}
## directories at the end of the line below follow a similar logic to rsync, see https://linux.die.net/man/1/rsync
fpm -s dir -t rpm -n bpftrace -v '0.9.2' --license "Apache v2" -a native --url "https://github.com/iovisor/bpftrace" --iteration '0' -d "libtinfo.so.5()(64bit)" -d "libbcc.so.0()(64bit)" -d "libelf.so.1()(64bit)" -d "libLLVM-6.0.so()(64bit)" -d "libclang.so.6()(64bit)" -d "libstdc++.so.6()(64bit)" -d "libm.so.6()(64bit)" -d "libgcc_s.so.1()(64bit)" -d "libc.so.6()(64bit)" -d "libclangFrontend.so.6()(64bit)" -d "libclangSerialization.so.6()(64bit)" -d "libclangDriver.so.6()(64bit)" -d "libclangParse.so.6()(64bit)" -d "libclangSema.so.6()(64bit)" -d "libclangCodeGen.so.6()(64bit)" -d "libclangAnalysis.so.6()(64bit)" -d "libclangRewrite.so.6()(64bit)" -d "libclangEdit.so.6()(64bit)" -d "libclangAST.so.6()(64bit)" -d "libclangLex.so.6()(64bit)" -d "libclangBasic.so.6()(64bit)" -d "libz.so.1()(64bit)" -d "librt.so.1()(64bit)" -d "libdl.so.2()(64bit)" -d "libpthread.so.0()(64bit)" -d "ld-linux-x86-64.so.2()(64bit)" -d "libffi.so.6()(64bit)" -d "libedit.so.0()(64bit)" -d "libtinfo.so.6()(64bit)" -d "libncurses.so.5()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'High-level tracing language for Linux eBPF' /opt/bpftrace/=/
rm -rf builddir/bpftrace/build/man/man9

# we no longer need to create the clang6.0 RPM because amazon linux now has clang6.0 version 6.0.1 available, I'm leaving it here just for reference
#fpm -s dir -t rpm -n 'clang6.0' -v '6.0.0' --license "NCSA" -a native --url "http://releases.llvm.org/6.0.0/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27.tar.xz" --iteration '0' -d "libtinfo.so.6()(64bit)" -d "libLLVM-6.0.so()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'A C language family front-end for LLVM' ${builddir}/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27/=/usr/local

fpm -s dir -t rpm -n ncurses -v '6.0' --license "MIT" -a native --url "ftp://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz" --iteration '0' --provides "libtinfo.so.6()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'Ncurses support utilities' /opt/ncurses/=/usr/local

fpm -s dir -t rpm -n bison -v '3.1' --license "GPLv3+" -a native --url "http://ftp.gnu.org/gnu/bison/bison-3.1.tar.gz" --iteration '0' -m 'wikibuy-tech@capitalone.com' --description 'A GNU general-purpose parser generator' /opt/bison/=/usr/local
