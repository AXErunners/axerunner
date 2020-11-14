# vim: set filetype=sh ts=4 sw=4 et

# axerunner_functions.sh - common functions and variables

# Copyright (c) 2015-2019 moocowmoo - moocowmoo@masternode.me

# variables are for putting things in ----------------------------------------

C_RED=''
C_YELLOW=''
C_GREEN=''
C_PURPLE=''
C_CYAN=''
C_NORM=''
TPUT_EL=''

if [ -t 1 ] || [ ! -z "$FORCE_COLOR" ] ; then
    C_RED="\e[31m"
    C_YELLOW="\e[33m"
    C_GREEN="\e[32m"
    C_PURPLE="\e[35m"
    C_CYAN="\e[36m"
    C_NORM="\e[0m"
    TPUT_EL=$(tput el)
fi


GITHUB_API_AXE="https://api.github.com/repos/axerunners/axe"

AXED_RUNNING=0
AXED_RESPONDING=0
AXERUNNER_VERSION=$(cat $AXERUNNER_GITDIR/VERSION)
AXERUNNER_CHECKOUT=$(GIT_DIR=$AXERUNNER_GITDIR/.git GIT_WORK_TREE=$AXERUNNER_GITDIR git describe --dirty | sed -e "s/^.*-\([0-9]\+-g\)/\1/" )
if [ "$AXERUNNER_CHECKOUT" == "v"$AXERUNNER_VERSION ]; then
    AXERUNNER_CHECKOUT=""
else
    AXERUNNER_CHECKOUT=" ("$AXERUNNER_CHECKOUT")"
fi

[ -z "$CACHE_EXPIRE" ] && CACHE_EXPIRE=5
[ -z "$ENABLE_CACHE" ] && ENABLE_CACHE=0

CACHE_CMD=''
[ $ENABLE_CACHE -gt 0 ] && CACHE_CMD='cached_cmd'

CACHE_DIR=/tmp/axerunner_cache
mkdir -p $CACHE_DIR
chmod 700 $CACHE_DIR

curl_cmd="timeout 7 curl -k -s -L -A axerunner/$AXERUNNER_VERSION"
function cached_cmd() {
    cmd=""
    whitespace="[[:space:]]"
    punctuation="&"
    for i in "$@"; do
        if [[ $i =~ $whitespace ]];then
            i=\'$i\'
        fi
        if [[ $i =~ $punctuation ]];then
            i=\'$i\'
        fi
        cmd="$cmd $i"
    done

    FILE_HASH=$(echo $cmd| md5sum | awk '{print $1}')
    CACHE_FILE=$CACHE_DIR/$FILE_HASH
    find $CACHE_DIR -type f \( -name '*.cached' -o -name '*.err' -o -name '*.cmd' \) -cmin +$CACHE_EXPIRE -exec rm {} \; >/dev/null 2>&1
    if [ -e $CACHE_FILE.cached ];then
        cat $CACHE_FILE.cached
        return
    fi
    echo $cmd > $CACHE_FILE.cmd
    eval $cmd > $CACHE_FILE.cached 2> $CACHE_FILE.err
    if [ $? -gt 0 ];then
        exit $?
    fi
    if [ -e $CACHE_FILE.cached ];then
        cat $CACHE_FILE.cached
        return
    fi
}
curl_cmd="$CACHE_CMD $curl_cmd"
wget_cmd='wget --no-check-certificate -q'


# (mostly) functioning functions -- lots of refactoring to do ----------------

pending(){ [[ $QUIET ]] || ( echo -en "$C_YELLOW$1$C_NORM$TPUT_EL" ); }

ok(){ [[ $QUIET ]] || echo -e "$C_GREEN$1$C_NORM" ; }

warn() { [[ $QUIET ]] || echo -e "$C_YELLOW$1$C_NORM" ; }
highlight() { [[ $QUIET ]] || echo -e "$C_PURPLE$1$C_NORM" ; }

err() { [[ $QUIET ]] || echo -e "$C_RED$1$C_NORM" ; }
die() { [[ $QUIET ]] || echo -e "$C_RED$1$C_NORM" ; exit 1 ; }

quit(){ [[ $QUIET ]] || echo -e "$C_GREEN${1:-${messages["exiting"]}}$C_NORM" ; echo ; exit 0 ; }

confirm() { read -r -p "$(echo -e "${1:-${messages["prompt_are_you_sure"]} [y/N]}")" ; [[ ${REPLY:0:1} = [Yy] ]]; }


up()     { echo -e "\e[${1:-1}A"; }
clear_n_lines(){ for n in $(seq ${1:-1}) ; do tput cuu 1; tput el; done ; }


usage(){
    cat<<EOF



    ${messages["usage"]}: ${0##*/} [command]

        ${messages["usage_title"]}

    ${messages["commands"]}

        install

            ${messages["usage_install_description"]}

        update

            ${messages["usage_update_description"]}

        reinstall

            ${messages["usage_reinstall_description"]}

        restart [now]

            ${messages["usage_restart_description"]}
                debug.log
                banlist.dat
                fee_estimates.dat
                governance.dat
                instantsend.dat
                mempool.dat
                mncache.dat
                mnpayments.dat
                netfulfilled.dat
                peers.dat
                sporks.dat

            ${messages["usage_restart_description_now"]}

        status

            ${messages["usage_status_description"]}

        vote

            ${messages["usage_vote_description"]}

        sync

            ${messages["usage_sync_description"]}

        branch

            ${messages["usage_branch_description"]}

        version

            ${messages["usage_version_description"]}

EOF
}

function cache_output(){
    # cached output
    FILE=$1
    # command to cache
    CMD=$2
    OLD=0
    CONTENTS=""
    # is cache older than 1 minute?
    if [ -e $FILE ]; then
        OLD=$(find $FILE -mmin +1 -ls | wc -l)
        CONTENTS=$(cat $FILE);
    fi
    # is cache empty or older than 1 minute? rebuild
    if [ -z "$CONTENTS" ] || [ "$OLD" -gt 0 ]; then
        CONTENTS=$(eval $CMD)
        echo "$CONTENTS" > $FILE
    fi
    echo "$CONTENTS"
}

_check_dependencies() {

    (which python 2>&1) >/dev/null || die "${messages["err_missing_dependency"]} python - sudo apt-get install python"

    DISTRO=$(/usr/bin/env python -mplatform | sed -e 's/.*with-//g')
    if [[ $DISTRO == *"Ubuntu"* ]] || [[ $DISTRO == *"debian"* ]]; then
        PKG_MANAGER=apt-get
    elif [[ $DISTRO == *"centos"* ]]; then
        PKG_MANAGER=yum
    fi

    if [ -z "$PKG_MANAGER" ]; then
        (which apt-get 2>&1) >/dev/null || \
            (which yum 2>&1) >/dev/null || \
            die ${messages["err_no_pkg_mgr"]}

    fi

    (which curl 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}curl "
    (which perl 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}perl "
    (which git  2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}git "

    MN_CONF_ENABLED=$( egrep -s '^[^#]*\s*masternodeblsprivkey\s*=' $HOME/.axe{,core}/axe.conf | wc -l 2>/dev/null)
    if [ $MN_CONF_ENABLED -gt 0 ] ; then
        (which unzip 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}unzip "
        (which virtualenv 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}python-virtualenv "
    fi

    if [ "$1" == "install" ]; then
        # only require unzip for install
        (which unzip 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}unzip "
        (which pv   2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}pv "

        # only require python-virtualenv for sentinel
        if [ "$2" == "sentinel" ]; then
            (which virtualenv 2>&1) >/dev/null || MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}python-virtualenv "
        fi
    fi

    # make sure we have the right netcat version (-4,-6 flags)
    if [ ! -z "$(which nc)" ]; then
        (nc -z -4 8.8.8.8 53 2>&1) >/dev/null
        if [ $? -gt 0 ]; then
            MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}netcat6 "
        fi
    else
        MISSING_DEPENDENCIES="${MISSING_DEPENDENCIES}netcat "
    fi

    if [ ! -z "$MISSING_DEPENDENCIES" ]; then
        err "${messages["err_missing_dependency"]} $MISSING_DEPENDENCIES\n"
        sudo $PKG_MANAGER install $MISSING_DEPENDENCIES
    fi


}

# attempt to locate axe-cli executable.
# search current dir, ~/.axe, `which axe-cli` ($PATH), finally recursive
_find_axe_directory() {

    INSTALL_DIR=''

    # axe-cli in PATH

    if [ ! -z $(which axe-cli 2>/dev/null) ] ; then
        INSTALL_DIR=$(readlink -f `which axe-cli`)
        INSTALL_DIR=${INSTALL_DIR%%/axe-cli*};


        #TODO prompt for single-user or multi-user install


        # if copied to /usr/*
        if [[ $INSTALL_DIR =~ \/usr.* ]]; then
            LINK_TO_SYSTEM_DIR=$INSTALL_DIR

            # if not run as root
            if [ $EUID -ne 0 ] ; then
                die "\n${messages["exec_found_in_system_dir"]} $INSTALL_DIR${messages["run_axerunner_as_root"]} ${messages["exiting"]}"
            fi
        fi

    # axe-cli not in PATH

        # check current directory
    elif [ -e ./axe-cli ] ; then
        INSTALL_DIR='.' ;

        # check ~/.axe directory
    elif [ -e $HOME/.axe/axe-cli ] ; then
        INSTALL_DIR="$HOME/.axe" ;

    elif [ -e $HOME/.axecore/axe-cli ] ; then
        INSTALL_DIR="$HOME/.axecore" ;

        # TODO try to find axe-cli with find
#    else
#        CANDIDATES=`find $HOME -name axe-cli`
    fi

    if [ ! -z "$INSTALL_DIR" ]; then
        INSTALL_DIR=$(readlink -f $INSTALL_DIR) 2>/dev/null
        if [ ! -e $INSTALL_DIR ]; then
            echo -e "${C_RED}${messages["axecli_not_found_in_cwd"]}, ~/.axecore, or \$PATH. -- ${messages["exiting"]}$C_NORM"
            exit 1
        fi
    else
        echo -e "${C_RED}${messages["axecli_not_found_in_cwd"]}, ~/.axecore, or \$PATH. -- ${messages["exiting"]}$C_NORM"
        exit 1
    fi

    AXE_CLI="$INSTALL_DIR/axe-cli"

    # check INSTALL_DIR has axed and axe-cli
    if [ ! -e $INSTALL_DIR/axed ]; then
        echo -e "${C_RED}${messages["axed_not_found"]} $INSTALL_DIR -- ${messages["exiting"]}$C_NORM"
        exit 1
    fi

    if [ ! -e $AXE_CLI ]; then
        echo -e "${C_RED}${messages["axecli_not_found"]} $INSTALL_DIR -- ${messages["exiting"]}$C_NORM"
        exit 1
    fi

    AXE_CLI="$CACHE_CMD $INSTALL_DIR/axe-cli"

}


_check_axerunner_updates() {
    GITHUB_AXERUNNER_VERSION=$( $curl_cmd https://raw.githubusercontent.com/axerunners/axerunner/master/VERSION )
    if [ ! -z "$GITHUB_AXERUNNER_VERSION" ] && [ "$AXERUNNER_VERSION" != "$GITHUB_AXERUNNER_VERSION" ]; then
        echo -e "\n"
        echo -e "${C_RED}${0##*/} ${messages["requires_updating"]} $C_GREEN$GITHUB_AXERUNNER_VERSION$C_RED\n${messages["requires_sync"]}$C_NORM\n"

        pending "${messages["sync_to_github"]} "

        if confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo $AXERUNNER_VERSION > $AXERUNNER_GITDIR/PREVIOUS_VERSION
            exec $AXERUNNER_GITDIR/${0##*/} sync $COMMAND
        fi
        die "${messages["exiting"]}"
    fi
}

_get_platform_info() {
    PLATFORM=$(uname -m)
    case "$PLATFORM" in
        i[3-6]86)
            PLAT=i686-pc
            ;;
        x86_64)
            PLAT=x86_64
            ;;
        armv7l)
            PLAT=arm
            ARM=1
            BIGARM=$(grep -E "(BCM2709|Freescale i\\.MX6)" /proc/cpuinfo | wc -l)
            ;;
        aarch64)
            PLAT=aarch64
            ARM=1
            BIGARM=$(grep -E "(BCM2709|Freescale i\\.MX6)" /proc/cpuinfo | wc -l)
            ;;
        *)
            err "${messages["err_unknown_platform"]} $PLATFORM"
            err "${messages["err_axerunner_supports"]}"
            die "${messages["exiting"]}"
            ;;
    esac
}

_get_versions() {
    _get_platform_info


    local IFS=' '
    DOWNLOAD_FOR='linux'
    if [ ! -z "$BIGARM" ]; then
        DOWNLOAD_FOR='RPi2'
    fi

    GITHUB_RELEASE_JSON="$($curl_cmd $GITHUB_API_AXE/releases/latest | python -mjson.tool)"
    CHECKSUM_URL=$(echo "$GITHUB_RELEASE_JSON" | grep browser_download | grep SUMS.asc | cut -d'"' -f4)
    CHECKSUM_FILE=$( $curl_cmd $CHECKSUM_URL )

    read -a DOWNLOAD_URLS <<< $( echo "$GITHUB_RELEASE_JSON" | grep browser_download | grep -v 'debug' | grep -v '.asc' | grep $DOWNLOAD_FOR | cut -d'"' -f4 | tr "\n" " ")
    #$(( <-- vim syntax highlighting fix

    LATEST_VERSION=$(echo "$GITHUB_RELEASE_JSON" | grep tag_name | cut -d'"' -f4 | tr -d 'v')
    TARDIR="axecore-${LATEST_VERSION::+5}"
    if [ -z "$LATEST_VERSION" ]; then
        die "\n${messages["err_could_not_get_version"]} -- ${messages["exiting"]}"
    fi

    if [ -z "$AXE_CLI" ]; then AXE_CLI='echo'; fi
    CURRENT_VERSION=$( $AXE_CLI --version | perl -ne '/v([0-9.]+)/; print $1;' 2>/dev/null ) 2>/dev/null
    for url in "${DOWNLOAD_URLS[@]}"
    do
        if [[ $url =~ .*${PLAT}-linux.* ]] ; then
            DOWNLOAD_URL=$url
            DOWNLOAD_FILE=${DOWNLOAD_URL##*/}
        fi
    done
}


_check_axed_state() {
    _get_axed_proc_status
    AXED_RUNNING=0
    AXED_RESPONDING=0
    if [ $AXED_HASPID -gt 0 ] && [ $AXED_PID -gt 0 ]; then
        AXED_RUNNING=1
    fi
    $AXE_CLI getblockchaininfo >/dev/null 2>&1
    if [ $? -eq 0 ] || [ $? -eq 28 ]; then
        AXED_RESPONDING=1
    fi
}

restart_axed(){

    if [ $AXED_RUNNING == 1 ]; then
        pending " --> ${messages["stopping"]} axed. ${messages["please_wait"]}"
        $AXE_CLI stop 2>&1 >/dev/null
        sleep 10
        killall -9 axed axe-shutoff 2>/dev/null
        ok "${messages["done"]}"
        AXED_RUNNING=0
    fi

    pending " --> ${messages["deleting_cache_files"]}"

    cd $INSTALL_DIR

    rm -f \
        debug.log \
        banlist.dat \
        fee_estimates.dat \
        governance.dat \
        instantsend.dat \
        mempool.dat \
        mncache.dat \
        mnpayments.dat \
        netfulfilled.dat \
        peers.dat \
        sporks.dat

    ok "${messages["done"]}"

    pending " --> ${messages["starting_axed"]}"
    $INSTALL_DIR/axed 2>&1 >/dev/null
    AXED_RUNNING=1
    ok "${messages["done"]}"

    pending " --> ${messages["waiting_for_axed_to_respond"]}"
    echo -en "${C_YELLOW}"
    AXED_RESPONDING=0
    while [ $AXED_RUNNING == 1 ] && [ $AXED_RESPONDING == 0 ]; do
        echo -n "."
        _check_axed_state
        sleep 2
    done
    if [ $AXED_RUNNING == 0 ]; then
        die "\n - axed unexpectedly quit. ${messages["exiting"]}"
    fi
    ok "${messages["done"]}"
    pending " --> axe-cli getblockchaininfo"
    echo
    $AXE_CLI getblockchaininfo
    echo

}


update_axed(){

    if [ $LATEST_VERSION != $CURRENT_VERSION ] || [ ! -z "$REINSTALL" ] ; then


        if [ ! -z "$REINSTALL" ];then
            echo -e ""
            echo -e "$C_GREEN*** ${messages["axe_version"]} $CURRENT_VERSION is up-to-date. ***$C_NORM"
            echo -e ""
            echo -en

            pending "${messages["reinstall_to"]} $INSTALL_DIR$C_NORM?"
        else
            echo -e ""
            echo -e "$C_RED*** ${messages["newer_axe_available"]} ***$C_NORM"
            echo -e ""
            echo -e "${messages["currnt_version"]} $C_RED$CURRENT_VERSION$C_NORM"
            echo -e "${messages["latest_version"]} $C_GREEN$LATEST_VERSION$C_NORM"
            echo -e ""
            if [ -z "$UNATTENDED" ] ; then
                pending "${messages["download"]} $DOWNLOAD_URL\n${messages["and_install_to"]} $INSTALL_DIR?"
            else
                echo -e "$C_GREEN*** UNATTENDED MODE ***$C_NORM"
            fi
        fi


        if [ -z "$UNATTENDED" ] ; then
            if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
                echo -e "${C_RED}${messages["exiting"]}$C_NORM"
                echo ""
                exit 0
            fi
        fi

        # push it ----------------------------------------------------------------

        cd $INSTALL_DIR

        # pull it ----------------------------------------------------------------

        pending " --> ${messages["downloading"]} ${DOWNLOAD_URL}... "
        wget --no-check-certificate -q -r $DOWNLOAD_URL -O $DOWNLOAD_FILE
        wget --no-check-certificate -q -r https://github.com/axerunners/axe/releases/download/v$LATEST_VERSION/SHA256SUMS.asc -O ${DOWNLOAD_FILE}.DIGESTS.txt
        if [ ! -e $DOWNLOAD_FILE ] ; then
            echo -e "${C_RED}${messages["err_downloading_file"]}"
            echo -e "${messages["err_tried_to_get"]} $DOWNLOAD_URL$C_NORM"

            exit 1
        else
            ok "${messages["done"]}"
        fi

        # prove it ---------------------------------------------------------------

        pending " --> ${messages["checksumming"]} ${DOWNLOAD_FILE}... "
        SHA256SUM=$( sha256sum $DOWNLOAD_FILE )
        SHA256PASS=$( grep $SHA256SUM ${DOWNLOAD_FILE}.DIGESTS.txt | wc -l )
        if [ $SHA256PASS -lt 1 ] ; then
            echo -e " ${C_RED} SHA256 ${messages["checksum"]} ${messages["FAILED"]} ${messages["try_again_later"]} ${messages["exiting"]}$C_NORM"
            exit 1
        fi
        ok "${messages["done"]}"

        # produce it -------------------------------------------------------------

        pending " --> ${messages["unpacking"]} ${DOWNLOAD_FILE}... " && \
        tar zxf $DOWNLOAD_FILE && \
        ok "${messages["done"]}"

        # pummel it --------------------------------------------------------------

        if [ $AXED_RUNNING == 1 ]; then
            pending " --> ${messages["stopping"]} axed. ${messages["please_wait"]}"
            $AXE_CLI stop >/dev/null 2>&1
            sleep 15
            killall -9 axed axe-shutoff >/dev/null 2>&1
            ok "${messages["done"]}"
        fi

        # prune it ---------------------------------------------------------------

        pending " --> ${messages["removing_old_version"]}"
        rm -rf \
            debug.log \
            banlist.dat \
            fee_estimates.dat \
            governance.dat \
            instantsend.dat \
            mempool.dat \
            mncache.dat \
            mnpayments.dat \
            netfulfilled.dat \
            peers.dat \
            sporks.dat \
            axed \
            axed-$CURRENT_VERSION \
            axe-qt \
            axe-qt-$CURRENT_VERSION \
            axe-cli \
            axe-cli-$CURRENT_VERSION \
            axecore-${CURRENT_VERSION}*.gz*
        ok "${messages["done"]}"

        # place it ---------------------------------------------------------------

        mv $TARDIR/bin/axed axed-$LATEST_VERSION
        mv $TARDIR/bin/axe-cli axe-cli-$LATEST_VERSION
        if [ $PLATFORM != 'armv7l' ];then
            mv $TARDIR/bin/axe-qt axe-qt-$LATEST_VERSION
        fi
        ln -s axed-$LATEST_VERSION axed
        ln -s axe-cli-$LATEST_VERSION axe-cli
        if [ $PLATFORM != 'armv7l' ];then
            ln -s axe-qt-$LATEST_VERSION axe-qt
        fi

        # permission it ----------------------------------------------------------

        if [ ! -z "$SUDO_USER" ]; then
            chown -h $SUDO_USER:$SUDO_USER {$DOWNLOAD_FILE,${DOWNLOAD_FILE}.DIGESTS.txt,axe-cli,axed,axe-qt,axe*$LATEST_VERSION}
        fi

        # purge it ---------------------------------------------------------------

        rm -rf axecore-1.2.3*
        rm -rf axecore-1.2.2*
        rm -rf axecore-1.2.1*
        rm -rf axecore-1.2.0*
        rm -rf axecore-1.1.8*
        rm -rf axecore-1.1.8*
        rm -rf axecore-1.1.7*
        rm -rf $TARDIR

        # punch it ---------------------------------------------------------------

        pending " --> ${messages["launching"]} axed... "
        touch $INSTALL_DIR/axed.pid
        $INSTALL_DIR/axed > /dev/null
        ok "${messages["done"]}"

        # probe it ---------------------------------------------------------------

        pending " --> ${messages["waiting_for_axed_to_respond"]}"
        echo -en "${C_YELLOW}"
        AXED_RUNNING=1
        while [ $AXED_RUNNING == 1 ] && [ $AXED_RESPONDING == 0 ]; do
            echo -n "."
            _check_axed_state
            sleep 1
        done
        if [ $AXED_RUNNING == 0 ]; then
            die "\n - axed unexpectedly quit. ${messages["exiting"]}"
        fi
        ok "${messages["done"]}"

        # poll it ----------------------------------------------------------------

        MN_CONF_ENABLED=$( egrep -s '^[^#]*\s*masternodeblsprivkey\s*=' $INSTALL_DIR/axe.conf | wc -l 2>/dev/null)
        if [ $MN_CONF_ENABLED -gt 0 ] ; then

            # populate it --------------------------------------------------------

            pending " --> updating sentinel... "
            cd sentinel
            git remote update >/dev/null 2>&1
            git reset -q --hard origin/master
            cd ..
            ok "${messages["done"]}"

            # patch it -----------------------------------------------------------

            pending "  --> updating crontab... "
            (crontab -l 2>/dev/null | grep -v sentinel.py ; echo "* * * * * cd $INSTALL_DIR/sentinel && venv/bin/python bin/sentinel.py  2>&1 >> sentinel-cron.log") | crontab -
            ok "${messages["done"]}"

        fi

        # poll it ----------------------------------------------------------------

        LAST_VERSION=$CURRENT_VERSION

        _get_versions

        # pass or punt -----------------------------------------------------------

        if [ $LATEST_VERSION == $CURRENT_VERSION ]; then
            echo -e ""
            echo -e "${C_GREEN}${messages["successfully_upgraded"]} ${LATEST_VERSION}$C_NORM"
            echo -e ""
            echo -e "${C_GREEN}${messages["installed_in"]} ${INSTALL_DIR}$C_NORM"
            echo -e ""
            ls -l --color {$DOWNLOAD_FILE,${DOWNLOAD_FILE}.DIGESTS.txt,axe-cli,axed,axe-qt,axe*$LATEST_VERSION}
            echo -e ""

            quit
        else
            echo -e "${C_RED}${messages["axe_version"]} $CURRENT_VERSION ${messages["is_not_uptodate"]} ($LATEST_VERSION) ${messages["exiting"]}$C_NORM"
        fi

    else
        echo -e ""
        echo -e "${C_GREEN}${messages["axe_version"]} $CURRENT_VERSION ${messages["is_uptodate"]} ${messages["exiting"]}$C_NORM"
    fi

    exit 0
}

install_axed(){

    INSTALL_DIR=$HOME/.axecore
    AXE_CLI="$INSTALL_DIR/axe-cli"

    if [ -e $INSTALL_DIR ] ; then
        die "\n - ${messages["preexisting_dir"]} $INSTALL_DIR ${messages["found"]} ${messages["run_reinstall"]} ${messages["exiting"]}"
    fi

    if [ -z "$UNATTENDED" ] ; then
        pending "${messages["download"]} $DOWNLOAD_URL\n${messages["and_install_to"]} $INSTALL_DIR?"
    else
        echo -e "$C_GREEN*** UNATTENDED MODE ***$C_NORM"
    fi

    if [ -z "$UNATTENDED" ] ; then
        if ! confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
            echo -e "${C_RED}${messages["exiting"]}$C_NORM"
            echo ""
            exit 0
        fi
    fi

    get_public_ips
    # prompt for ipv4 or ipv6 install
#    if [ ! -z "$PUBLIC_IPV6" ] && [ ! -z "$PUBLIC_IPV4" ]; then
#        pending " --- " ; echo
#        pending " - ${messages["prompt_ipv4_ipv6"]}"
#        if confirm " [${C_GREEN}y${C_NORM}/${C_RED}N${C_NORM}] $C_CYAN"; then
#            USE_IPV6=1
#        fi
#    fi

    echo ""

    # prep it ----------------------------------------------------------------

    mkdir -p $INSTALL_DIR

    if [ ! -e $INSTALL_DIR/axe.conf ] ; then
        pending " --> ${messages["creating"]} axe.conf... "

        IPADDR=$PUBLIC_IPV4
#        if [ ! -z "$USE_IPV6" ]; then
#            IPADDR='['$PUBLIC_IPV6']'
#        fi
        RPCUSER=`echo $(dd if=/dev/urandom bs=32 count=1 2>/dev/null) | sha256sum | awk '{print $1}'`
        RPCPASS=`echo $(dd if=/dev/urandom bs=32 count=1 2>/dev/null) | sha256sum | awk '{print $1}'`
        while read; do
            eval echo "$REPLY"
        done < $AXERUNNER_GITDIR/.axe.conf.template > $INSTALL_DIR/axe.conf
        ok "${messages["done"]}"
    fi

    # push it ----------------------------------------------------------------

    cd $INSTALL_DIR

    # pull it ----------------------------------------------------------------

    pending " --> ${messages["downloading"]} ${DOWNLOAD_URL}... "
    tput sc
    echo -e "$C_CYAN"
    $wget_cmd -O - $DOWNLOAD_URL | pv -trep -s28787607 -w80 -N wallet > $DOWNLOAD_FILE
    $wget_cmd -O - https://github.com/axerunners/axe/releases/download/v$LATEST_VERSION/SHA256SUMS.asc | pv -trep -w80 -N checksums > ${DOWNLOAD_FILE}.DIGESTS.txt
    echo -ne "$C_NORM"
    clear_n_lines 2
    tput rc
    clear_n_lines 3
    if [ ! -e $DOWNLOAD_FILE ] ; then
        echo -e "${C_RED}error ${messages["downloading"]} file"
        echo -e "tried to get $DOWNLOAD_URL$C_NORM"
        exit 1
    else
        ok ${messages["done"]}
    fi

    # prove it ---------------------------------------------------------------

    pending " --> ${messages["checksumming"]} ${DOWNLOAD_FILE}... "
    SHA256SUM=$( sha256sum $DOWNLOAD_FILE )
    #MD5SUM=$( md5sum $DOWNLOAD_FILE )
    SHA256PASS=$( grep $SHA256SUM ${DOWNLOAD_FILE}.DIGESTS.txt | wc -l )
    #MD5SUMPASS=$( grep $MD5SUM ${DOWNLOAD_FILE}.DIGESTS.txt | wc -l )
    if [ $SHA256PASS -lt 1 ] ; then
        echo -e " ${C_RED} SHA256 ${messages["checksum"]} ${messages["FAILED"]} ${messages["try_again_later"]} ${messages["exiting"]}$C_NORM"

        exit 1
    fi
    #if [ $MD5SUMPASS -lt 1 ] ; then
    #    echo -e " ${C_RED} MD5 ${messages["checksum"]} ${messages["FAILED"]} ${messages["try_again_later"]} ${messages["exiting"]}$C_NORM"
    #    exit 1
    #fi
    ok "${messages["done"]}"

    # produce it -------------------------------------------------------------

    pending " --> ${messages["unpacking"]} ${DOWNLOAD_FILE}... " && \
    tar zxf $DOWNLOAD_FILE && \
    ok "${messages["done"]}"

    # pummel it --------------------------------------------------------------

#    if [ $AXED_RUNNING == 1 ]; then
#        pending " --> ${messages["stopping"]} axed. ${messages["please_wait"]}"
#        $AXE_CLI stop >/dev/null 2>&1
#        sleep 15
#        killall -9 axed axe-shutoff >/dev/null 2>&1
#        ok "${messages["done"]}"
#    fi

    # prune it ---------------------------------------------------------------

#    pending " --> ${messages["removing_old_version"]}"
#    rm -f \
#        banlist.dat \
#        budget.dat \
#        debug.log \
#        fee_estimates.dat \
#        governance.dat \
#        mncache.dat \
#        mnpayments.dat \
#        netfulfilled.dat \
#        peers.dat \
#        axed \
#        axed-$CURRENT_VERSION \
#        axe-qt \
#        axe-qt-$CURRENT_VERSION \
#        axe-cli \
#        axe-cli-$CURRENT_VERSION
#    ok "${messages["done"]}"

    # place it ---------------------------------------------------------------

    mv $TARDIR/bin/axed axed-$LATEST_VERSION
    mv $TARDIR/bin/axe-cli axe-cli-$LATEST_VERSION
    if [ $PLATFORM != 'armv7l' ];then
        mv $TARDIR/bin/axe-qt axe-qt-$LATEST_VERSION
    fi
    ln -s axed-$LATEST_VERSION axed
    ln -s axe-cli-$LATEST_VERSION axe-cli
    if [ $PLATFORM != 'armv7l' ];then
        ln -s axe-qt-$LATEST_VERSION axe-qt
    fi

    # permission it ----------------------------------------------------------

    if [ ! -z "$SUDO_USER" ]; then
        chown -h $SUDO_USER:$SUDO_USER {$DOWNLOAD_FILE,${DOWNLOAD_FILE}.DIGESTS.txt,axe-cli,axed,axe-qt,axe*$LATEST_VERSION}
    fi

    # purge it ---------------------------------------------------------------

    rm -rf axecore-1.5*
    rm -rf axecore-1.4*
    rm -rf axecore-1.3*
    rm -rf axecore-1.2*
    rm -rf axecore-1.1*
    rm -rf axecore-1.0*
    rm -rf $TARDIR

    # punch it ---------------------------------------------------------------

    pending " --> ${messages["launching"]} axed... "
    $INSTALL_DIR/axed > /dev/null
    AXED_RUNNING=1
    ok "${messages["done"]}"

    # probe it ---------------------------------------------------------------

    pending " --> ${messages["waiting_for_axed_to_respond"]}"
    echo -en "${C_YELLOW}"
    while [ $AXED_RUNNING == 1 ] && [ $AXED_RESPONDING == 0 ]; do
        echo -n "."
        _check_axed_state
        sleep 2
    done
    if [ $AXED_RUNNING == 0 ]; then
        die "\n - axed unexpectedly quit. ${messages["exiting"]}"
    fi
    ok "${messages["done"]}"

    # path it ----------------------------------------------------------------

    pending " --> adding $INSTALL_DIR PATH to ~/.bash_aliases ... "
    if [ ! -f ~/.bash_aliases ]; then touch ~/.bash_aliases ; fi
    sed -i.bak -e '/axerunner_env/d' ~/.bash_aliases
    echo "export PATH=$INSTALL_DIR:\$PATH ; # axerunner_env" >> ~/.bash_aliases
    ok "${messages["done"]}"


    # poll it ----------------------------------------------------------------

    _get_versions

    # pass or punt -----------------------------------------------------------

    if [ $LATEST_VERSION == $CURRENT_VERSION ]; then
        echo -e ""
        echo -e "${C_GREEN}axe ${LATEST_VERSION} ${messages["successfully_installed"]}$C_NORM"

        echo -e ""
        echo -e "${C_GREEN}${messages["installed_in"]} ${INSTALL_DIR}$C_NORM"
        echo -e ""
        ls -l --color {$DOWNLOAD_FILE,${DOWNLOAD_FILE}.DIGESTS.txt,axe-cli,axed,axe-qt,axe*$LATEST_VERSION}
        echo -e ""

        if [ ! -z "$SUDO_USER" ]; then
            echo -e "${C_GREEN}Symlinked to: ${LINK_TO_SYSTEM_DIR}$C_NORM"
            echo -e ""
            ls -l --color $LINK_TO_SYSTEM_DIR/{axed,axe-cli}
            echo -e ""
        fi

    else
        echo -e "${C_RED}${messages["axe_version"]} $CURRENT_VERSION ${messages["is_not_uptodate"]} ($LATEST_VERSION) ${messages["exiting"]}$C_NORM"
        exit 1
    fi

}

_get_axed_proc_status(){
    AXED_HASPID=0
    if [ -e $INSTALL_DIR/axed.pid ] ; then
        AXED_HASPID=`ps --no-header \`cat $INSTALL_DIR/axed.pid 2>/dev/null\` | wc -l`;
    else
        AXED_HASPID=$(pidof axed)
        if [ $? -gt 0 ]; then
            AXED_HASPID=0
        fi
    fi
    AXED_PID=$(pidof axed)
}

get_axed_status(){

    _get_axed_proc_status

    AXED_UPTIME=$(ps -p $AXED_PID -o etime= 2>/dev/null | sed -e 's/ //g')
    AXED_UPTIME_TIMES=$(echo "$AXED_UPTIME" | perl -ne 'chomp ; s/-/:/ ; print join ":", reverse split /:/' 2>/dev/null )
    AXED_UPTIME_SECS=$( echo "$AXED_UPTIME_TIMES" | cut -d: -f1 )
    AXED_UPTIME_MINS=$( echo "$AXED_UPTIME_TIMES" | cut -d: -f2 )
    AXED_UPTIME_HOURS=$( echo "$AXED_UPTIME_TIMES" | cut -d: -f3 )
    AXED_UPTIME_DAYS=$( echo "$AXED_UPTIME_TIMES" | cut -d: -f4 )
    if [ -z "$AXED_UPTIME_DAYS" ]; then AXED_UPTIME_DAYS=0 ; fi
    if [ -z "$AXED_UPTIME_HOURS" ]; then AXED_UPTIME_HOURS=0 ; fi
    if [ -z "$AXED_UPTIME_MINS" ]; then AXED_UPTIME_MINS=0 ; fi
    if [ -z "$AXED_UPTIME_SECS" ]; then AXED_UPTIME_SECS=0 ; fi

    AXED_LISTENING=`netstat -nat | grep LIST | grep 9937 | wc -l`;
    AXED_CONNECTIONS=`netstat -nat | grep ESTA | grep 9937 | wc -l`;
    AXED_CURRENT_BLOCK=`$AXE_CLI getblockcount 2>/dev/null`
    if [ -z "$AXED_CURRENT_BLOCK" ] ; then AXED_CURRENT_BLOCK=0 ; fi
    AXED_GETBLOCKCHAININFO=`$AXE_CLI getblockchaininfo 2>/dev/null`;
    AXED_DIFFICULTY=$(echo "$AXED_GETBLOCKCHAININFO" | grep difficulty | awk '{print $2}' | sed -e 's/[",]//g')

    WEB_BLOCK_COUNT_DQA=`$curl_cmd http://axe-explorer.arcpool.com/api/getblockcount`;
    if [ -z "$WEB_BLOCK_COUNT_DQA" ]; then
        WEB_BLOCK_COUNT_DQA=0
    fi

    CHECK_SYNC_AGAINST_HEIGHT=$(echo "$WEB_BLOCK_COUNT_DQA" | tr " " "\n" | sort -rn | head -1)

    AXED_SYNCED=0
    if [ $CHECK_SYNC_AGAINST_HEIGHT -ge $AXED_CURRENT_BLOCK ] && [ $(($CHECK_SYNC_AGAINST_HEIGHT - 5)) -lt $AXED_CURRENT_BLOCK ];then
        AXED_SYNCED=1
    fi

    AXED_CONNECTED=0
    if [ $AXED_CONNECTIONS -gt 0 ]; then AXED_CONNECTED=1 ; fi

    AXED_UP_TO_DATE=0
    if [ $LATEST_VERSION == $CURRENT_VERSION ]; then
        AXED_UP_TO_DATE=1
    fi

    get_public_ips

    MASTERNODE_BIND_IP=$PUBLIC_IPV4
    PUBLIC_PORT_CLOSED=$( timeout 2 nc -4 -z $PUBLIC_IPV4 9937 2>&1 >/dev/null; echo $? )
#    if [ $PUBLIC_PORT_CLOSED -ne 0 ] && [ ! -z "$PUBLIC_IPV6" ]; then
#        PUBLIC_PORT_CLOSED=$( timeout 2 nc -6 -z $PUBLIC_IPV6 9937 2>&1 >/dev/null; echo $? )
#        if [ $PUBLIC_PORT_CLOSED -eq 0 ]; then
#            MASTERNODE_BIND_IP=$PUBLIC_IPV6
#        fi
#    else
#        MASTERNODE_BIND_IP=$PUBLIC_IPV4
#    fi

    # masternode (remote!) specific

    MN_PROTX_RAW="$($AXE_CLI protx list valid 1 2>&1)"
    MN_PROTX_RECORD=`echo "$MN_PROTX_RAW" | grep -w -B6 -A19 $MASTERNODE_BIND_IP:9937 | sed -e 's/:9937/~9937/' -e 's/[":,{}]//g' -e 's/^ \+//' -e 's/ \+$//' -e 's/~9937/:9937/' -e '/^$/d' -e '/^[^ ]\+$/d'`
    MN_PROTX_QUEUE=`echo "$MN_PROTX_RAW" | egrep '(proTxHash|lastPaidHeight|PoSeRevivedHeight|registeredHeight)' | sed -e 's/[":,{}]//g' -e 's/^ \+//' -e 's/ \+$//' -e '/^$/d' -e '/^[^ ]\+$/d' | sed -e 'N;s/\n/ /' | sed -e 'N;s/\n/ /' | awk ' \
{
    if ($8 > $6) {
        print $8 " " $_
    }
    else if ($6 == 0) {
        print $4 " " $_
    }
    else {
        print $6 " " $_
    }
}' | sort -k1,1nr`
    MN_PROTX_QUEUE_LENGTH=$(echo "$MN_PROTX_QUEUE" | wc -l)

    MN_PROTX_HASH=''
    MN_PROTX_CONFIRMATIONS=''
    MN_PROTX_REGD_HEIGHT=''
    MN_PROTX_LAST_PAID_HEIGHT=''
    MN_PROTX_COLL_HASH=''
    MN_PROTX_COLL_IDX=''
    MN_PROTX_COLL_ADDY=''
    MN_PROTX_OPER_REWARD=''
    MN_PROTX_POSE_PENALTY=''
    MN_PROTX_POSE_REVIVED_HEIGHT=''
    MN_PROTX_POSE_BAN_HEIGHT=''
    MN_PROTX_SERVICE=''
    MN_PROTX_OWNER_ADDRESS=''
    MN_PROTX_VOTER_ADDRESS=''
    MN_PROTX_PAYOUT_ADDRESS=''
    MN_PROTX_OPER_PUBKEY=''
    MN_PROTX_QUEUE_POSITION=0
    MN_PROTX_SERVICE_VALID=0

    MN_CONF_ENABLED=$( egrep -s '^[^#]*\s*masternodeblsprivkey\s*=' $HOME/.axe{,core}/axe.conf | wc -l 2>/dev/null)
    #MN_STARTED=`$AXE_CLI masternode status 2>&1 | grep 'successfully started' | wc -l`
    MN_REGISTERED=0
    [[ -z "$MN_PROTX_RECORD" ]] || MN_REGISTERED=1

    if [ $MN_REGISTERED -gt 0 ]; then
        MN_PROTX_HASH=$(echo "$MN_PROTX_RECORD" | grep proTxHash | awk '{print $2}')
        MN_PROTX_CONFIRMATIONS=$(echo "$MN_PROTX_RECORD" | grep confirmations | awk '{print $2}')
        MN_PROTX_REGD_HEIGHT=$(echo "$MN_PROTX_RECORD" | grep registeredHeight | awk '{print $2}')
        MN_PROTX_LAST_PAID_HEIGHT=$(echo "$MN_PROTX_RECORD" | grep lastPaidHeight | awk '{print $2}')
        MN_PROTX_COLL_HASH=$(echo "$MN_PROTX_RECORD" | grep collateralHash | awk '{print $2}')
        MN_PROTX_COLL_IDX=$(echo "$MN_PROTX_RECORD" | grep collateralIndex | awk '{print $2}')
        MN_PROTX_COLL_ADDY=$(echo "$MN_PROTX_RECORD" | grep collateralAddress | awk '{print $2}')
        MN_PROTX_OPER_REWARD=$(echo "$MN_PROTX_RECORD" | grep operatorReward | awk '{print $2}')
        MN_PROTX_POSE_PENALTY=$(echo "$MN_PROTX_RECORD" | grep PoSePenalty | awk '{print $2}')
        MN_PROTX_POSE_REVIVED_HEIGHT=$(echo "$MN_PROTX_RECORD" | grep PoSeRevivedHeight | awk '{print $2}')
        MN_PROTX_POSE_BAN_HEIGHT=$(echo "$MN_PROTX_RECORD" | grep PoSeBanHeight | awk '{print $2}')
        MN_PROTX_SERVICE=$(echo "$MN_PROTX_RECORD" | grep service | awk '{print $2}')
        MN_PROTX_OWNER_ADDRESS=$(echo "$MN_PROTX_RECORD" | grep ownerAddress | awk '{print $2}')
        MN_PROTX_VOTER_ADDRESS=$(echo "$MN_PROTX_RECORD" | grep votingAddress | awk '{print $2}')
        MN_PROTX_PAYOUT_ADDRESS=$(echo "$MN_PROTX_RECORD" | grep payoutAddress | awk '{print $2}')
        MN_PROTX_OPER_PUBKEY=$(echo "$MN_PROTX_RECORD" | grep pubKeyOperator | awk '{print $2}')

        MN_PROTX_SERVICE_IP=$(echo "$MN_PROTX_SERVICE" | sed -e 's/:.*//' )

        if [ "$MASTERNODE_BIND_IP" == "$MN_PROTX_SERVICE_IP" ]; then
            MN_PROTX_SERVICE_VALID=1
        fi
        MN_PROTX_QUEUE_POSITION=$(echo "$MN_PROTX_QUEUE" | grep -A9999999 $MN_PROTX_HASH | wc -l)
    fi

    MN_QUEUE_IN_SELECTION=0
    MN_QUEUE_LENGTH=0
    MN_QUEUE_POSITION=0


    NOW=`date +%s`
    MN_LIST="$(cache_output /tmp/mnlist_cache '$AXE_CLI masternodelist full 2>/dev/null')"

    MN_STATUS=$( grep $MASTERNODE_BIND_IP /tmp/mnlist_cache | sed -e 's/"//g' | awk '{print $2}' )
    MN_VISIBLE=$( test "$MN_STATUS" && echo 1 || echo 0 )
    MN_ENABLED=$( cat /tmp/mnlist_cache | grep -c ENABLED )
    MN_UNHEALTHY=$( cat /tmp/mnlist_cache | grep -c EXPIRED )
    MN_TOTAL=$(( $MN_ENABLED + $MN_UNHEALTHY ))

    MN_SYNC_STATUS=$( $AXE_CLI mnsync status )
    MN_SYNC_ASSET=$(echo "$MN_SYNC_STATUS" | grep 'AssetName' | awk '{print $2}' | sed -e 's/[",]//g' )
    MN_SYNC_COMPLETE=$(echo "$MN_SYNC_STATUS" | grep 'IsSynced' | grep 'true' | wc -l)

    if [ $MN_VISIBLE -gt 0 ]; then
        MN_QUEUE_LENGTH=$MN_ENABLED
        MN_QUEUE_POSITION=$(echo "$SORTED_MN_LIST" | grep ENABLED | grep -A9999999 $MASTERNODE_BIND_IP | wc -l)
        if [ $MN_QUEUE_POSITION -gt 0 ]; then
            MN_QUEUE_IN_SELECTION=$(( $MN_QUEUE_POSITION <= $(( $MN_QUEUE_LENGTH / 10 )) ))
        fi
    fi

    # sentinel checks
    if [ -e $INSTALL_DIR/sentinel ]; then

        SENTINEL_INSTALLED=0
        SENTINEL_PYTEST=0
        SENTINEL_CRONTAB=0
        SENTINEL_LAUNCH_OUTPUT=""
        SENTINEL_LAUNCH_OK=-1

        cd $INSTALL_DIR/sentinel
        SENTINEL_INSTALLED=$( ls -l bin/sentinel.py | wc -l )
        SENTINEL_PYTEST=$( venv/bin/py.test test 2>&1 > /dev/null ; echo $? )
        SENTINEL_CRONTAB=$( crontab -l | grep sentinel | grep -v '^#' | wc -l )
        SENTINEL_LAUNCH_OUTPUT=$( venv/bin/python bin/sentinel.py 2>&1 )
        if [ -z "$SENTINEL_LAUNCH_OUTPUT" ] ; then
            SENTINEL_LAUNCH_OK=$?
        fi
        cd - > /dev/null
    fi

    if [ $MN_CONF_ENABLED -gt 0 ] ; then
        WEB_NINJA_API=$($curl_cmd "https://www.axeninja.pl/api/masternodes?ips=\[\"${MASTERNODE_BIND_IP}:9937\"\]&portcheck=1&balance=1")
        if [ -z "$WEB_NINJA_API" ]; then
            sleep 2
            # downgrade connection to support distros with stale nss libraries
            WEB_NINJA_API=$($curl_cmd --ciphers rsa_3des_sha "https://www.axeninja.pl/api/masternodes?ips=\[\"${MASTERNODE_BIND_IP}:9937\"\]&portcheck=1&balance=1")
        fi

    fi

}

date2stamp () {
    date --utc --date "$1" +%s
}

stamp2date (){
    date --utc --date "1970-01-01 $1 sec" "+%Y-%m-%d %T"
}

dateDiff (){
    case $1 in
        -s)   sec=1;      shift;;
        -m)   sec=60;     shift;;
        -h)   sec=3600;   shift;;
        -d)   sec=86400;  shift;;
        *)    sec=86400;;
    esac
    dte1=$(date2stamp $1)
    dte2=$(date2stamp "$2")
    diffSec=$((dte2-dte1))
    if ((diffSec < 0)); then abs=-1; else abs=1; fi
    echo $((diffSec/sec*abs))
}

get_host_status(){
    HOST_LOAD_AVERAGE=$(cat /proc/loadavg | awk '{print $1" "$2" "$3}')
    uptime=$(</proc/uptime)
    uptime=${uptime%%.*}
    HOST_UPTIME_DAYS=$(( uptime/60/60/24 ))
    HOSTNAME=$(hostname -f)
}


print_status() {

    AXED_UPTIME_STRING="$AXED_UPTIME_DAYS ${messages["days"]}, $AXED_UPTIME_HOURS ${messages["hours"]}, $AXED_UPTIME_MINS ${messages["mins"]}, $AXED_UPTIME_SECS ${messages["secs"]}"

    pending "${messages["status_hostnam"]}" ; ok "$HOSTNAME"
    pending "${messages["status_uptimeh"]}" ; ok "$HOST_UPTIME_DAYS ${messages["days"]}, $HOST_LOAD_AVERAGE"
    pending "${messages["status_axedip"]}" ; [ $MASTERNODE_BIND_IP != 'none' ] && ok "$MASTERNODE_BIND_IP" || err "$MASTERNODE_BIND_IP"
    pending "${messages["status_axedve"]}" ; ok "$CURRENT_VERSION"
    pending "${messages["status_uptodat"]}" ; [ $AXED_UP_TO_DATE -gt 0 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_running"]}" ; [ $AXED_HASPID     -gt 0 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_uptimed"]}" ; [ $AXED_RUNNING    -gt 0 ] && ok "$AXED_UPTIME_STRING" || err "$AXED_UPTIME_STRING"
    pending "${messages["status_drespon"]}" ; [ $AXED_RUNNING    -gt 0 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_dlisten"]}" ; [ $AXED_LISTENING  -gt 0 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_dconnec"]}" ; [ $AXED_CONNECTED  -gt 0 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_dportop"]}" ; [ $PUBLIC_PORT_CLOSED  -lt 1 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_dconcnt"]}" ; [ $AXED_CONNECTIONS   -gt 0 ] && ok "$AXED_CONNECTIONS" || err "$AXED_CONNECTIONS"
    pending "${messages["status_dblsync"]}" ; [ $AXED_SYNCED     -gt 0 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_dbllast"]}" ; [ $AXED_SYNCED     -gt 0 ] && ok "$AXED_CURRENT_BLOCK" || err "$AXED_CURRENT_BLOCK"
    pending "${messages["status_dcurdif"]}" ; ok "$AXED_DIFFICULTY"
    if [ $AXED_RUNNING -gt 0 ] && [ $MN_CONF_ENABLED -gt 0 ] ; then
    #pending "${messages["status_mnstart"]}" ; [ $MN_STARTED -gt 0  ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_mnregis"]}" ; [ $MN_REGISTERED -gt 0 ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_mnvislo"]}" ; [ $MN_VISIBLE -gt 0  ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "${messages["status_mnqueue"]}" ; ok "$MN_PROTX_QUEUE_POSITION/$MN_PROTX_QUEUE_LENGTH"
    pending "  masternode mnsync state    : " ; [ ! -z "$MN_SYNC_ASSET" ] && ok "$MN_SYNC_ASSET" || ""
    pending "  masternode network state   : " ; [ "$MN_STATUS" == "ENABLED" ] && ok "$MN_STATUS" || highlight "$MN_STATUS"

    pending "    sentinel installed       : " ; [ $SENTINEL_INSTALLED -gt 0  ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "    sentinel tests passed    : " ; [ $SENTINEL_PYTEST    -eq 0  ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "    sentinel crontab enabled : " ; [ $SENTINEL_CRONTAB   -gt 0  ] && ok "${messages["YES"]}" || err "${messages["NO"]}"
    pending "    sentinel online          : " ; [ $SENTINEL_LAUNCH_OK -eq 0  ] && ok "${messages["YES"]}" || ([ $MN_SYNC_COMPLETE -eq 0 ] && warn "${messages["NO"]} - sync incomplete") || err "${messages["NO"]}"

        else
    err     "  external api offline         " ;
        fi
    if [ $MN_REGISTERED -gt 0 ] ; then
        pending " protx registration hash     : " ; ok "$MN_PROTX_HASH"
        pending " protx registered service    : " ; [ $MN_PROTX_SERVICE_VALID  -eq 1 ] && ok "$MN_PROTX_SERVICE" || err "$MN_PROTX_SERVICE"
        pending " protx registered address    : " ; ok "$MN_PROTX_COLL_ADDY"
        pending " protx registered collateral : " ; ok "$MN_PROTX_COLL_HASH-$MN_PROTX_COLL_IDX"
        pending " protx registered at block   : " ; ok "$MN_PROTX_REGD_HEIGHT"
        pending " protx confirmations         : " ; ok "$MN_PROTX_CONFIRMATIONS"
        pending " protx last paid block       : " ; ok "$MN_PROTX_LAST_PAID_HEIGHT"
        pending " protx owner address         : " ; ok "$MN_PROTX_OWNER_ADDRESS"
        pending " protx voter address         : " ; ok "$MN_PROTX_VOTER_ADDRESS"
        pending " protx payout address        : " ; ok "$MN_PROTX_PAYOUT_ADDRESS"
        pending " protx operator reward       : " ; ok "$MN_PROTX_OPER_REWARD"
        pending " protx operator pubkey       : " ; ok "$MN_PROTX_OPER_PUBKEY"
        pending " protx pose score            : " ; [ $MN_PROTX_POSE_PENALTY  -gt 0 ] && err "$MN_PROTX_POSE_PENALTY" || ok "$MN_PROTX_POSE_PENALTY"
        #    MN_PROTX_POSE_REVIVED_HEIGHT=$(echo "$MN_PROTX_RECORD" | grep PoSeRevivedHeight | awk '{print $2}')
        #    MN_PROTX_POSE_BAN_HEIGHT=$(echo "$MN_PROTX_RECORD" | grep PoSeBanHeight | awk '{print $2}')
    fi

    pending "${messages["status_mncount"]}" ; [ $MN_TOTAL            -gt 0 ] && ok "$MN_TOTAL" || err "$MN_TOTAL"
}

show_message_configure() {
    echo
    ok "${messages["to_enable_masternode"]}"
    ok "${messages["uncomment_conf_lines"]}"
    echo
         pending "    $HOME/.axecore/axe.conf" ; echo
    echo
    echo -e "$C_GREEN install sentinel$C_NORM"
    echo
    echo -e "    ${C_YELLOW}axerunner install sentinel$C_NORM"
    echo
    echo -e "$C_GREEN ${messages["then_run"]}$C_NORM"
    echo
    echo -e "    ${C_YELLOW}axerunner restart now$C_NORM"
    echo
}

get_public_ips() {
    PUBLIC_IPV4=$($curl_cmd -4 https://icanhazip.com/)
#    PUBLIC_IPV6=$($curl_cmd -6 https://icanhazip.com/)
#    if [ -z "$PUBLIC_IPV4" ] && [ -z "$PUBLIC_IPV6" ]; then
    if [ -z "$PUBLIC_IPV4" ]; then

        # try http
        PUBLIC_IPV4=$($curl_cmd -4 http://icanhazip.com/)
#        PUBLIC_IPV6=$($curl_cmd -6 http://icanhazip.com/)

#        if [ -z "$PUBLIC_IPV4" ] && [ -z "$PUBLIC_IPV6" ]; then
        if [ -z "$PUBLIC_IPV4" ]; then
            sleep 3
            err "  --> ${messages["err_failed_ip_resolve"]}"
            # try again
            get_public_ips
        fi

    fi
}

cat_until() {
    PATTERN=$1
    FILE=$2
    while read; do
        if [[ "$REPLY" =~ $PATTERN ]]; then
            return
        else
            echo "$REPLY"
        fi
    done < $FILE
}

install_sentinel() {



    # push it ----------------------------------------------------------------

    cd $INSTALL_DIR

    # pummel it --------------------------------------------------------------

    rm -rf sentinel

    # pull it ----------------------------------------------------------------

    pending "  --> ${messages["downloading"]} sentinel... "

    git clone -q https://github.com/axerunners/sentinel.git

    ok "${messages["done"]}"

    # prep it ----------------------------------------------------------------

    pending "  --> installing dependencies... "
    echo

    cd sentinel

    pending "   --> virtualenv init... "
    virtualenv venv 2>&1 > /dev/null;
    if [[ $? -gt 0 ]];then
        err "  --> virtualenv initialization failed"
        pending "  when running: " ; echo
        echo -e "    ${C_YELLOW}virtualvenv venv$C_NORM"
        quit
    fi
    ok "${messages["done"]}"

    pending "   --> pip modules... "
    venv/bin/pip install -r requirements.txt 2>&1 > /dev/null;
    if [[ $? -gt 0 ]];then
        err "  --> pip install failed"
        pending "  when running: " ; echo
        echo -e "    ${C_YELLOW}venv/bin/pip install -r requirements.txt$C_NORM"
        quit
    fi
    ok "${messages["done"]}"

    pending "  --> testing installation... "
    venv/bin/py.test ./test/ 2>&1>/dev/null;
    if [[ $? -gt 0 ]];then
        err "  --> sentinel tests failed"
        pending "  when running: " ; echo
        echo -e "    ${C_YELLOW}venv/bin/py.test ./test/$C_NORM"
        quit
    fi
    ok "${messages["done"]}"

    pending "  --> installing crontab... "
    (crontab -l 2>/dev/null | grep -v sentinel.py ; echo "* * * * * cd $INSTALL_DIR/sentinel && venv/bin/python bin/sentinel.py  2>&1 >> sentinel-cron.log") | crontab -
    ok "${messages["done"]}"

    cd ..

}
