#!/usr/bin/env bash
set -eEu -o pipefail
shopt -s extdebug
IFS=$'\n\t'

builddir=/mnt/builddir	# change to suit your system: needs about 2 Gbytes free

if [[ ${EUID} -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

LLVM_VERSION=9

# dependencies
apt-get update && apt-get install -y curl gnupg &&\
    llvmRepository="\n\
deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic main\n\
deb-src http://apt.llvm.org/bionic/ llvm-toolchain-bionic main\n\
deb http://apt.llvm.org/bionic/ llvm-toolchain-bionic-${LLVM_VERSION} main\n\
deb-src http://apt.llvm.org/bionic/ llvm-toolchain-bionic-${LLVM_VERSION} main\n" &&\
    printf $llvmRepository >> /etc/apt/sources.list && \
    curl -L https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4052245BD4284CDD && \
    echo "deb https://repo.iovisor.org/apt/bionic bionic main" | tee /etc/apt/sources.list.d/iovisor.list

apt update && apt install -y \
      bison \
      cmake \
      flex \
      g++ \
      git \
      libelf-dev \
      zlib1g-dev \
      libbcc \
      clang-${LLVM_VERSION} \
      libclang-${LLVM_VERSION}-dev \
      libclang-common-${LLVM_VERSION}-dev \
      libclang1-${LLVM_VERSION} \
      llvm-${LLVM_VERSION} \
      llvm-${LLVM_VERSION}-dev \
      llvm-${LLVM_VERSION}-runtime \
      libllvm${LLVM_VERSION} \
      systemtap-sdt-dev \
      python3 \
      ruby \
      ruby-dev \
      rubygems \
      build-essential

# bpftrace
export LIBRARY_PATH='/usr/include/bcc'
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
cmake ..
make -j8
make install DESTDIR=/opt/bpftrace

# Installing fpm EFFing Package Manager
cd ${builddir}
gem install --no-ri --no-rdoc fpm
fpm --version
## directories at the end of the line below follow a similar logic to rsync, see https://linux.die.net/man/1/rsync
fpm -s dir -t deb -n bpftrace -v '0.9.2' --license "Apache v2" -a native --url "https://github.com/iovisor/bpftrace" --iteration '0' -d "libncurses.so.5()(64bit)" -m 'wikibuy-tech@capitalone.com' --description 'High-level tracing language for Linux eBPF' /opt/bpftrace/=/
