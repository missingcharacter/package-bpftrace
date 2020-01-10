mkfile_path = $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir = $(dir $(mkfile_path))

main:
	docker run -v $(mkfile_dir):/mnt --workdir=/mnt --rm -it amazonlinux:2018.03.0.20191014.0-with-sources bash -x create-rpms.sh
