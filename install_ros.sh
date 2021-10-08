#! /bin/bash

INSTALLER_VERSION=0.0.1
LOG_FILE="install_ros"

function show_help()
{
    echo "

    COMMAND LINE USAGE
        sudo ./install_ros.sh [OPTIONS]

    OPTIONS
        --reinstall
            This option will cause all ROS packages to be reinstalled if they are
            currently installed.

    OUTPUT FILES
        A log is generated is generated when an operation other than
        help specified.

    "
}

# convert a list of comma separated values to a list of space separated values.
# args:
#   arg1: string with comma separated list
# echo return
#   string with space seaparted list
function comma_list_to_space_list()
{
    local comma_list="$1"

    local space_list="$(printf "%s" "$comma_list" | sed 's#\,#\ #g')"

    printf "%s" "$space_list"
}

# parse a string of command line arguments and look for a specific option
# that is without a corresponding value.
# args:
#   arg1: option to find
#   arg2: command line arguement string
# echo return
#   true : the options was found
#   false: the option was not found
function has_option_novalue()
{
    local options="$1"
    local args="$2"

    local option_list="$(comma_list_to_space_list "$options")"

    local option=""
    local grep_option=""
    local option_arg=""
    local return_value="false"
    for option in $option_list; do
        grep_option="$(printf "%s" "$option" |  sed "s@\-@\\\\-@g")"
        option_arg="$(printf "%s" "$args" | grep -oE "$grep_option"'([\ ]{1}|$)')"
        if [[ "$option_arg" != "" ]]; then
            return_value="true"
            break
        fi
    done

    printf "%s" "$return_value"
}

# parse a string of command line arguments and look for
# option whose form is option=value.
# args:
#   arg1: option for which a value is needed
#   arg2: command line arguement string
# echo return
#   true if option value was found
#   false if not found
function has_option_value()
{
    local options="$1"
    local args="$2"

    local option_list="$(comma_list_to_space_list "$options")"

    local option=""
    local grep_option=""
    local option_arg=""
    local return_value="false"
    for option in $option_list; do
        grep_option="$(printf "%s" "$option" |  sed "s@\-@\\\\-@g")"
        option_arg="$(printf "%s" "$args" | grep -oE "$grep_option="'([^\ ]+|$)')"
        if [[ "$option_arg" != "" ]]; then
            return_value="true"
            break
        fi
    done

    echo "$return_value"
}

# parse a string of command line arguments and retieve the value of an
# option whose form is option=value.
# args:
#   arg1: option for which a value is needed
#   arg2: command line arguement string
# echo return
#   the options value.
#   empty string if option not found or no value specified.
function get_option_value()
{
    local options="$1"
    local args="$2"

    local option_list="$(comma_list_to_space_list "$options")"

    local option=""
    local grep_option=""
    local option_arg=""
    local option_value=""
    for option in $option_list; do
        if [[ "$(has_option_value "$option" "$args")" == false ]]; then
            continue
        fi
        grep_option="$(printf "%s" "$option" |  sed "s@\-@\\\\-@g")"

        option_arg="$(printf "%s" "$args" | grep -oE "$grep_option="'([^\ ]+|$)')"
        option_value="$(printf "%s" "$option_arg" | grep -oE '[^=]+$')"

        break
    done
    printf "%s" "$option_value"
}

# parse help text string and extract list of valid command line args and options
# args:
#   arg1: string containing help text
# echo return
#   space separated list of valid arguments and options. Each option will have '-'
#   or '--' prefix. valid options and arguments may be repeated.
function valid_args_from_help()
{
    local help_text="$1"

    local valid_args=""

    while read help_line; do
        help_line="$(printf "%s" "$help_line" | grep -oE '^[-]{1,2}[^=^.]+')"
        if [[ "$help_line" != "" ]]; then
            help_line="$(printf "%s" "$help_line" | tr ',' ' ' )"
            valid_args+=" $(printf "%s" "$help_line" | tr '\n' ' ')"
        fi
    done <<< "$help_text"

    echo "$valid_args"
}

# parse command line args and check for invalid arguments.
# args:
#   arg1: string of command line args and options
#   arg2: space separated list of valid command line arguments.
# echo return
#   invalid argument if found else empty string
function validate_cmdline_args()
{
    local cmd_line="$1"
    local valid_args="$2"

    local invalid_arg=""

    local cmd_args="$(printf "%s" "$cmd_line" | grep -oE '(^|[\ ])[-]{1,2}[^=^.]+' | tr '\n' ' ')"
    local cmd_arg_array=( $cmd_args )

    if [[ "$cmd_line" != "" && "$cmd_args" == "" ]]; then
        cmd_arg_array=( $cmd_line )
        printf "%s" "${cmd_arg_array[0]}"
        return
    fi

    local arg=""
    local grepable_arg=""
    local matching_arg=""
    for arg in "${cmd_arg_array[@]}"; do
        grepable_arg="$(printf "%s" "$arg" |  sed "s@\-@\\\\-@g")"
        matching_arg="$(printf "%s" "$valid_args" | grep -oE "$grepable_arg(\ |\$)" | head -n1)"
        if [[ "$matching_arg" == "" ]]; then
            invalid_arg="$arg"
            break
        fi
    done

    printf "%s" "$invalid_arg"
}

function install_apt_package ()
{
    local package="$1"
    local reinstall="$2"
    local result_code=0
    dpkg -s $package &> /dev/null
    result_code=$?
    if [[ $result_code -eq 0 && $reinstall != "reinstall" ]]; then
        echo "   *** Skipping  : $package is already installed"
    else
        echo "   *** Installing: $package"
        local reinstall_flag=""
        if [[ "$reinstall" == "reinstall" ]]; then
            reinstall_flag="--reinstall"
        fi
        sudo apt install $reinstall_flag $package -y
    fi
}

function install_apt_package_list ()
{
    local package_list=("$1")
    local reinstall="$2"

    for pkg in ${package_list[@]}; do
        install_apt_package $pkg $reinstall
    done
}

#-------------------------------------------------------
#-------------------------------------------------------
#-------------------------------------------------------
#-------------------------------------------------------
#-------------------------------------------------------
# Script entry point
#-------------------------------------------------------
#-------------------------------------------------------
#-------------------------------------------------------
#-------------------------------------------------------
#-------------------------------------------------------


if [[ "$(has_option_novalue "--help,-h,-help,help" "$*")" == true ]]; then
    show_help
    exit 0
fi

#-------------------------------------------------------------
#-------------------------------------------------------------
# validate arguments and options
# ------------------------------------------------------------
valid_args="$(valid_args_from_help "$(show_help)")"
invalid_arg="$(validate_cmdline_args "$*" "$valid_args")"
if [[ "$invalid_arg" != "" ]]; then
    show_help
    echo " "
    echo "Error: invalid command line option: $invalid_arg"
    echo " "
    exit 1
fi
#-------------------------------------------------------------

#-------------------------------------------------------------
#-------------------------------------------------------------
# start logging
# ------------------------------------------------------------
date_format="%Y_%m_%d-%H_%M_%S"
LOG_FILE+="_"$(date +"$date_format")".log"
echo " "
echo "~~~~~~~~~~~~~~"
echo "logging to file: $LOG_FILE"
echo "~~~~~~~~~~~~~~"
exec > >(tee -ia $LOG_FILE) 2>&1

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Setting up command line options"
echo "-------------------------------------------------------------"
REINSTALL=""
if [[ "$(has_option_novalue "--reinstall" "$*")" == true ]]; then
    echo "~~~~~~~~~~~~~~"
    echo "reinstall option enabled. all installed packages will be reinstalled"
    echo "~~~~~~~~~~~~~~"
    REINSTALL="reinstall"
fi

cd $HOME

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Checking for root privileges"
echo "-------------------------------------------------------------"
if [[ "$(whoami)" != "root" ]]; then
    echo " "
    echo "Error: Script must be run as super user or with sudo."
    exit 1
else
    echo " "
    echo "Installing for user $SUDO_USER with root priviliges"
    echo " "
fi

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Determining ROS version to install"
echo "-------------------------------------------------------------"
UBUNTU_RELEASE="$(lsb_release -c | cut -f 2)"
ROS_RELEASE=""
PYTHON_EXEC=""
if [[ "$UBUNTU_RELEASE" == "xenial" ]]; then
    ROS_RELEASE="kinetic"
    PYTHON_EXEC="python"
elif [[ "$UBUNTU_RELEASE" == "bionic" ]]; then
    ROS_RELEASE="melodic"
    PYTHON_EXEC="python"
elif [[ "$UBUNTU_RELEASE" == "focal" ]]; then
    ROS_RELEASE="noetic"
    PYTHON_EXEC="python3"
elif [[ "$UBUNTU_RELEASE" == "" ]]; then
    echo "Error: Could not determine the required ROS release version to install."
    echo "       For Ubuntu release: $UBUNTU_RELEASE"
    exit 1
fi

echo " "
echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "ROS installer"
echo "  Installer version: $INSTALLER_VERSION"
echo "  Detected Ubuntu release: $UBUNTU_RELEASE"
echo "  Installing ROS release : $ROS_RELEASE"
echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo " "

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Installing non-ROS support packages"
echo "-------------------------------------------------------------"
echo "------- Installing ubuntu base packages"
UBUNTUBASE_PACKAGES="git vim meld build-essential libfontconfig1 mesa-common-dev libglu1-mesa-dev"
install_apt_package_list "$UBUNTUBASE_PACKAGES"

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Adding ROS repository keys"
echo "-------------------------------------------------------------"
sh -c 'echo "deb http://packages.ros.org/ros/ubuntu '"$UBUNTU_RELEASE"' main" > /etc/apt/sources.list.d/ros-latest.list'
install_apt_package curl
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Updating Ubuntu packages to include latest ROS packages"
echo "-------------------------------------------------------------"
apt update -y

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Installing ROS $ROS_RELEASE base packages"
echo "-------------------------------------------------------------"
ROS_PACKAGES="ros-$ROS_RELEASE-desktop-full"
install_apt_package_list "$ROS_PACKAGES" "$REINSTALL"

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Installing ROS $ROS_RELEASE support packages"
echo "-------------------------------------------------------------"
ROS_SUPPORT_PACKAGES="$PYTHON_EXEC-rosdep $PYTHON_EXEC-rosinstall $PYTHON_EXEC-rosinstall-generator $PYTHON_EXEC-wstool $PYTHON_EXEC-catkin-tools"
install_apt_package_list "$ROS_SUPPORT_PACKAGES" "$REINSTALL"

echo "-------------------------------------------------------------"
echo "-------------------------------------------------------------"
echo "Configuring ROS environment"
echo "-------------------------------------------------------------"
ROS_ENV_COMMAND="source /opt/ros/$ROS_RELEASE/setup.bash"
if [[ "$(cat $HOME/.bashrc | grep -oE "^$ROS_ENV_COMMAND")" == "" ]]; then
    echo "$ROS_ENV_COMMAND" >> $HOME/.bashrc
else
    echo "Skipping: ROS environment already in .bashrc"
fi

SOURCE_WS_COMMAND="alias sws='source ./devel/setup.bash'"
if [[ "$(cat $HOME/.bashrc | grep -oE "^$SOURCE_WS_COMMAND")" == "" ]]; then
    echo "$SOURCE_WS_COMMAND" >> $HOME/.bashrc
else
    echo "Skipping: Source Workspace alias, already in .bashrc"
fi
source $HOME/.bashrc

rosdep init
rosdep update --rosdistro $ROS_RELEASE
