#!/bin/bash

UBUNTU_RELEASE=focal
ROS_RELEASE=noetic
PYTHON_EXEC=python3

function usage()
{
    echo "
COMMAND LINE USAGE
    sudo ./install_ros.sh MODE
MODE
    desktop
        This mode will perform a full ROS installation, intended for a 
        laptop/desktop computer
    rpi
        This mode will perform a minimal ROS installation, intended for 
        a fresh Raspberry Pi with Ubuntu Server image
    "
}

function setup_ros_env() {
    ROS_ENV_COMMAND="source /opt/ros/$ROS_RELEASE/setup.bash"
    if [[ "$(cat $HOME/.bashrc | grep -oE "^$ROS_ENV_COMMAND")" == "" ]]
    then
        echo "$ROS_ENV_COMMAND" >> $HOME/.bashrc
    else
        echo "Skipping: ROS environment already in .bashrc"
    fi
    SOURCE_WS_COMMAND="alias sws='source ./devel/setup.bash'"
    if [[ "$(cat $HOME/.bashrc | grep -oE "^$SOURCE_WS_COMMAND")" == "" ]]
    then
        echo "$SOURCE_WS_COMMAND" >> $HOME/.bashrc
    else
        echo "Skipping: Source Workspace alias, already in .bashrc"
    fi
}

function setup_ros_keys() {
    sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu '"$UBUNTU_RELEASE"' main" > /etc/apt/sources.list.d/ros-latest.list'
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
}

function install_ros_full() {
    sudo apt install git vim meld build-essential libfontconfig1 mesa-common-dev libglu1-mesa-dev curl
    setup_ros_keys
    sudo apt update
    sudo apt install -y ros-$ROS_RELEASE-desktop-full
    sudo apt install -y \
        $PYTHON_EXEC-rosdep \
        $PYTHON_EXEC-rosinstall \
        $PYTHON_EXEC-rosinstall-generator \
        $PYTHON_EXEC-wstool \
        $PYTHON_EXEC-catkin-tools \
        $PYTHON_EXEC-osrf-pycommon \
        $PYTHON_EXEC-pip
    setup_ros_env
    source $HOME/.bashrc
    sudo rosdep init
    rosdep update --rosdistro $ROS_RELEASE
}

function get_mac_address() {
    res=''
    res=$(ifconfig $1 2>/dev/null)
    if [[ -n $res ]]
    then
        echo $res | \
            grep -P -o 'ether \w+:\w+:\w+:\w+:\w+:\w+' | \
            sed -e 's/ether //' -e 's/://g'
    fi
}

function setup_rpi_wap() {
    sudo apt install -y network-manager net-tools
    local hotspot_cfg_file=/etc/netplan/10-hotspot-config.yaml
    if [ -f $hotspot_cfg_file ]; then
        echo 'Hotspot already configured. Skipping.'
    else
        sudo bash -c "echo 'network: {config: disabled}' > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg"
        cat >$hotspot_cfg_file << EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    eth0:
      dhcp4: true
      optional: true
  wifis:
    wlan0:
      dhcp4: true
      optional: true
      access-points:
        "RPi-$(get_mac_address wlan0 | tail -c 5)":
          password: "robotseverywhere"
          mode: ap
EOF
        sudo netplan generate
        sudo netplan apply
    fi
}

function setup_ros_network_autoconfig() {
    if [[ "$(cat $HOME/.bashrc | grep -oE "^ROS_INTERFACE")" == "" ]]
    then
        echo "export ROS_INTERFACE=auto" >> $HOME/.bashrc
        cd /tmp 
        mkdir -p network_autoconfig && cd network_autoconfig
        git clone https://github.com/LucidOne/network_autoconfig.git src
	cd /tmp
        mkdir /opt/ros/$ROS_RELEASE/pkgs
        sudo mv /tmp/network_autoconfig /opt/ros/$ROS_RELEASE/pkgs/
        local pkgdir=/opt/ros/$ROS_RELEASE/pkgs/network_autoconfig
        cd $pkgdir
        local source_cmd="source /opt/ros/$ROS_RELEASE/setup.bash"
        local build_cmd="catkin_make -DCMAKE_INSTALL_PREFIX=/opt/ros/$ROS_RELEASE install"
        sudo bash -c "$source_cmd && $build_cmd"
    else
        echo "Skipping: ROS package network_autoconfig already installed."
    fi
}

function setup_teensy_udev() {
    sudo usermod -aG dialout $USER
    cd /tmp/
    wget https://www.pjrc.com/teensy/00-teensy.rules
    sudo mv 00-teensy.rules /etc/udev/rules.d/
}

function install_ros_rpi() {
    setup_ros_keys
    sudo apt update
    sudo apt install -y ros-$ROS_RELEASE-ros-base
    sudo apt install -y \
        $PYTHON_EXEC-rosdep \
        $PYTHON_EXEC-catkin-tools \
        $PYTHON_EXEC-osrf-pycommon \
        $PYTHON_EXEC-pip \
        ros-$ROS_RELEASE-socketcan-interface \
        ros-$ROS_RELEASE-rosserial-server \
        ros-$ROS_RELEASE-ros-control \
        ros-$ROS_RELEASE-sensor-msgs \
        ros-$ROS_RELEASE-joint-state-publisher \
        ros-$ROS_RELEASE-joy \
        ros-$ROS_RELEASE-twist-mux \
        ros-$ROS_RELEASE-teleop-twist-joy
    setup_ros_network_autoconfig
    setup_ros_env
    source $HOME/.bashrc
    sudo rosdep init
    rosdep update --rosdistro $ROS_RELEASE
}

function install_all_rpi() {
    sudo apt update
    sudo apt dist-upgrade -y
    sudo apt install -y \
        build-essential \
        openssh-server \
        git \
        vim \
        net-tools \
        can-utils \
        avahi-daemon \
        libusb-1.0-0-dev \
        screen
    setup_teensy_udev
    install_ros_rpi
    setup_rpi_wap
}

if [[ $# -ne 1 || ($1 == "--help") || ($1 == "-h") ]]
then
    usage
    exit 1
fi

if [[ "$(whoami)" != "root" ]]; then
    echo "Error: Script must be run as super user or with sudo."
    exit 1
else
    if [[ $1 == "full" ]]; then
        install_ros_full
    elif [[ $1 == "rpi" ]]; then
        install_all_rpi
    fi
fi

