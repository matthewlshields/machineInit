#!/bin/bash
set -e
set -o pipefail

export DEBAIN_FRONTEND=noninteractive

readonly TARGET_USER="matthew"

# Disable screen shutdown
xset s noblank

check_is_sudo() {
	if [ "$EUID" -ne 0 ]; then
		echo "This command must be run as root."
		exit
	fi
}

#
# This is the bare minimum needs to start installing other software.
#
setup_bare_sources() {
	
	cat <<-EOF > /etc/apt/source.list
	deb http://deb.debian.org/debian stretch main contrib non-free
	deb-src http://deb.debian.org/debian stretch main contrib non-free

	deb http://deb.debian.org/debian stretch-updates main contrib non-free
	deb-src http://deb.debian.org/debian stretch-updates main contrib non-free

	deb http://security.debian.org/debian-security/ stretch/updates main contrib non-free
	deb-src http://security.debian.org/debian-security/ stretch/updates main contrib non-free
	EOF

}

install_bare_min() {
	apt update
	apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dirmngr \
		lsb-release \
		--no-install-recommends

	# turn off translations, speed up apt update
	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations
}



install_base() {
	apt update
	apt upgrade -y

	apt install -y \
		adduser \
		automake \
		bash-completion \
		bzip2 \
		coreutils \
		curl \
		dnsutils \
		file \
		findutils \
		gcc \
		git \
		gnupg \
		gnupg2 \
		gnupg-agent \
		grep \
		gzip \
		hostname \
		jq \
		less \
		lsof \
		make \
		mount \
		openresolv \
		openvpn \
		pinentry-curses \
		silversearcher-ag \
		ssh \
		strace \
		sudo \
		tar \
		tree \
		tzdata \
		unzip \
		xclip \
		xcompmgr \
		xz-utils \
		zip \
		--no-install-recommends

	setup_sudo

	apt autoremove
	apt autoclean
	apt clean
}

setup_sudo() {

	# add user to sudoers
	adduser "matthew" sudo

	# add user to systemd groups
	# then you wont need sudo to view logs and shit
	gpasswd -a "matthew" systemd-journal
	gpasswd -a "matthew" systemd-network
}


# installs docker master
# and adds necessary items to boot params
# https://docs.docker.com/install/linux/docker-ce/debian/
install_docker() {

	# get GPG key
	curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

	# add the repository
	add-apt-repository \
	   "deb [arch=amd64] https://download.docker.com/linux/debian \
	   $(lsb_release -cs) \
	   stable"

	apt-get update
	apt-get install -y docker-ce

	# create docker group
	groupadd docker
	useradd -aG docker $TARGET_USER

	# Include contributed completions
	mkdir -p /etc/bash_completion.d
	curl -sSL -o /etc/bash_completion.d/docker https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker

	systemctl daemon-reload
	systemctl enable docker
}


install_wifi() {

	# Install Wireless Drivers for Dell 7570
	# Run as root
	# https://wiki.debian.org/iwlwifi
	echo "deb http://httpredir.debian.org/debian/ stretch main contrib non-free" > 	/etc/apt/sources.list.d/non-free.list
	apt-get update && apt-get install firmware-iwlwifi
	modprobe -r iwlwifi ; modprobe iwlwifi
}

install_pia() {
	# Install Private Internet Access
	# Run as root

	apt-get install -y \
		network-manager-openvpn \
		network-manager \
		network-manager-gnome \
		network-manager-openvpn-gnome

	mkdir -p /tmp/pia-install/{installer, extract}
	wget --https-only \
		https://www.privateinternetaccess.com/openvpn/openvpn-strong.zip \
		-O /tmp/pia-install/installer/openvpn-strong.zip

	unzip /tmp/pia-install/installer/openvpn-strong.zip -d /tmp/pia-install/extract/

	cp /tmp/pia-install/extract/*.ovpn /etc/openvpn/
	cp /tmp/pia-install/extract/*.pem /etc/openvpn/
	cp /tmp/pia-install/extract/*.crt /etc/openvpn/

	# Update all of the ovpn files to use the credentials file
	sed -i 's/^auth-user-pass$/& creds/' *.ovpn

	# Add the commands to update the DNS entries in /etc/resolv.conf
	#script-security 2
	#up /etc/openvpn/update-resolv-conf
	#down /etc/openvpn/update-resolv-conf

	# Keeping it clean
	rm -rf /tmp/pia-install

}

usage() {
	echo -e "install.sh\\n\\tThis script installs my basic setup for a debian laptop\\n"
	echo "Usage:"
	echo "  base                                - setup sources & install base pkgs"
	echo "  baremin                             - setup sources & install base min pkgs"
	echo "  sudo                                - setup user as sudoer"
	echo "  docker                              - install Docker CE"
	echo "  wifi                                - install wifi drivers"
	echo "  pia                                 - configure Private Internet Access with OpenVPN"
}

main() {

	local cmd=$1

	if [[ -z "$cmd" ]]; then
		usage
		exit 1
	fi

	if [[ $cmd == "baremin" ]]; then
		check_is_sudo
		install_bare_min
	elif [[ $cmd == "base" ]]; then
		check_is_sudo
		install_bare_min
		install_base
	elif [[ $cmd == "sudo" ]]; then
		check_is_sudo
		setup_sudo
	elif [[ $cmd == "docker" ]]; then
		check_is_sudo
		install_docker	
	elif [[ $cmd == "wifi" ]]; then
		check_is_sudo
		install_wifi
	elif [[ $cmd == "pia" ]]; then
		check_is_sudo
		install_pia
	else
		usage
	fi

	
}

main "$@"


