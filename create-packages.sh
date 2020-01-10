#!/usr/bin/env bash
set -eEu -o pipefail
shopt -s extdebug
IFS=$'\n\t'

builddir=/mnt/builddir	# change to suit your system: needs about 2 Gbytes free

if [[ ${EUID} -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

function update_ld_cache() {
  if [ -f /etc/ld.so.cache ]; then
    rm /etc/ld.so.cache
  fi
  #if [ -f /etc/ld.so.conf.d/llvm6.0-x86_64.conf ]; then
  #  rm /etc/ld.so.conf.d/llvm6.0-x86_64.conf
  #fi
  if grep '/usr/local/lib' /etc/ld.so.conf 2> /dev/null; then
    echo "/usr/local/lib is already in /etc/ld.so.conf"
  else
    echo /usr/local/lib >> /etc/ld.so.conf
  fi
  ldconfig -v
}

# dependencies
yum install -y epel-release
yum-config-manager --enable epel
yum clean all
yum install -y git cmake3 gcc64-c++.x86_64 llvm6.0-libs bison flex wget vim diffutils help2man texinfo file ruby-devel gcc make rpm-build rubygems bcc*
#yum install -y git cmake3 gcc64-c++.x86_64 llvm6.0-libs bison flex wget vim diffutils help2man texinfo file ruby-devel gcc make rpm-build rubygems ethtool iperf libstdc++-static python36-devel gcc gcc-c++ zlib-devel elfutils-libelf-devel luajit luajit-devel python36-pip ncurses-devel python-netaddr python-pip python-pyroute2
#yum install -y http://repo.iovisor.org/yum/extra/mageia/cauldron/x86_64/netperf-2.7.0-1.mga6.x86_64.rpm

# Installing fpm EFFing Package Manager
cd ${builddir}
gem install --no-ri --no-rdoc fpm
fpm --version

# llvm
# we may no longer need to download clang6.0 and just `yum install clang6.0`
#cd ${builddir}
#
#if [ -f "${builddir}/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27.tar.xz" ]; then
#  echo "no need to download clang again"
#else
#  wget http://releases.llvm.org/6.0.0/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27.tar.xz
#fi
#
#if [ -d "${builddir}/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27" ]; then
#  echo "no need to untar clang"
#else
#  tar xf clang*
#fi
#
#(cd clang* && cp -R * /usr/local/)
#cp -p /usr/lib64/llvm6.0/lib/libLLVM-6.0.so /usr/lib64/libLLVM.so
#
#update_ld_cache
#
## bcc
#cd ${builddir}
#
#if [ -d "${builddir}/bcc" ]; then
#  echo "no need to clone bcc repo"
#else
#  git clone https://github.com/iovisor/bcc.git
#fi
#
#cd bcc
#
#if [ -d "${builddir}/bcc/build" ]; then
#  echo "${builddir}/bcc/build exists I will remove it now, to start from scratch"
#  rm -rf ${builddir}/bcc/build
#else
#  echo "${builddir}/bcc/build does not exist, we can begin now"
#fi
#
#mkdir build; cd build
#
#cmake3 .. -DCMAKE_INSTALL_PREFIX=/opt/bcc
#time make
#make install
#echo '/opt/bcc/lib' > /etc/ld.so.conf.d/bcc.conf

# libtinfo.so.6 (comes from ncurses)
cd ${builddir}

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
#echo '/opt/ncurses/lib' > /etc/ld.so.conf.d/ncurses.conf

# Building ncurses rpm
cd ${builddir}
fpm -s dir -t rpm -n ncurses -v '6.0' --license "MIT" -a native --url "ftp://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz" --iteration '0' --provides "libtinfo.so.6()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'Ncurses support utilities' /opt/ncurses/=/usr/local
yum localinstall -y ncurses*.rpm

# bison
cd ${builddir}

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
#echo '/opt/bison/lib' > /etc/ld.so.conf.d/bison.conf

# Building bison rpm
cd ${builddir}
fpm -s dir -t rpm -n bison -v '3.1' --license "GPLv3+" -a native --url "http://ftp.gnu.org/gnu/bison/bison-3.1.tar.gz" --iteration '0' -m 'wikibuy-tech@capitalone.com' --description 'A GNU general-purpose parser generator' /opt/bison/=/usr/local
yum localinstall -y bison*.rpm

#export PATH="/opt/bcc/bin:/opt/ncurses/bin:/opt/bison/bin:${PATH}"
update_ld_cache

# bpftrace
cd ${builddir}

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
cmake3 -DSTATIC_LINKING:BOOL=ON ..
make -j8
make install DESTDIR=/opt/bpftrace
# echo /usr/local/lib >> /etc/ld.so.conf
ldconfig -v

## directories at the end of the line below follow a similar logic to rsync, see https://linux.die.net/man/1/rsync
fpm -s dir -t rpm -n bpftrace -v '0.9.2' --license "Apache v2" -a native --url "https://github.com/iovisor/bpftrace" --iteration '0' -d "libtinfo.so.5()(64bit)" -d "libbcc.so.0()(64bit)" -d "libelf.so.1()(64bit)" -d "libLLVM-6.0.so()(64bit)" -d "libclang.so.6()(64bit)" -d "libstdc++.so.6()(64bit)" -d "libm.so.6()(64bit)" -d "libgcc_s.so.1()(64bit)" -d "libc.so.6()(64bit)" -d "libclangFrontend.so.6()(64bit)" -d "libclangSerialization.so.6()(64bit)" -d "libclangDriver.so.6()(64bit)" -d "libclangParse.so.6()(64bit)" -d "libclangSema.so.6()(64bit)" -d "libclangCodeGen.so.6()(64bit)" -d "libclangAnalysis.so.6()(64bit)" -d "libclangRewrite.so.6()(64bit)" -d "libclangEdit.so.6()(64bit)" -d "libclangAST.so.6()(64bit)" -d "libclangLex.so.6()(64bit)" -d "libclangBasic.so.6()(64bit)" -d "libz.so.1()(64bit)" -d "librt.so.1()(64bit)" -d "libdl.so.2()(64bit)" -d "libpthread.so.0()(64bit)" -d "ld-linux-x86-64.so.2()(64bit)" -d "libffi.so.6()(64bit)" -d "libedit.so.0()(64bit)" -d "libtinfo.so.6()(64bit)" -d "libncurses.so.5()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'High-level tracing language for Linux eBPF' /opt/bpftrace/=/

builddir/bpftrace/build-release/src/bpftrace
fpm -s dir -t rpm -n bpftrace -v '0.9.2' --license "Apache v2" -a native --url "https://github.com/iovisor/bpftrace" --iteration '0' -m 'wikibuy-tech@capitalone.com' --description 'High-level tracing language for Linux eBPF' builddir/bpftrace/build-release/src/bpftrace=/usr/local/bin/bpftrace builddir/bpftrace/build-release/man/man8=/usr/local/share/man/ builddir/bpftrace/tools/*.bt=/usr/local/share/bpftrace/tools/

fpm -s dir -t deb -n bpftrace -v '0.9.2' --license "Apache v2" -a native --url "https://github.com/iovisor/bpftrace" --iteration '0' -d "libncurses.so.5()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'High-level tracing language for Linux eBPF' /opt/bpftrace/=/

# we no longer need to create the clang6.0 RPM because amazon linux now has clang6.0 version 6.0.1 available, I'm leaving it here just for reference
#fpm -s dir -t rpm -n 'clang6.0' -v '6.0.0' --license "NCSA" -a native --url "http://releases.llvm.org/6.0.0/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27.tar.xz" --iteration '0' -d "libtinfo.so.6()(64bit)" -d "libLLVM-6.0.so()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'A C language family front-end for LLVM' ${builddir}/clang+llvm-6.0.0-x86_64-linux-gnu-Fedora27/=/usr/local
