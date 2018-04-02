# AXErunner

AXE wallet/daemon management utilities - version 0.1.26

* This script installs, updates, and manages single-user axe daemons and wallets
* It is currently only compatible with 32/64 bit Linux.
* Multi-user (system directory) installs are not supported

# Install/Usage

To install axerunner do:

    sudo apt-get install python git unzip pv
    cd ~ && git clone https://github.com/AXErunners/axerunner

To update your existing version 12 32/64bit linux axe wallet to the latest
axed, do:

    axerunner/axerunner update

To perform a new install of axe, do:

    axerunner/axerunner install

To overwrite an existing axe install, do:

    axerunner/axerunner reinstall

To update axerunner to the latest version, do:

    axerunner/axerunner sync

To restart (or start) axed, do:

    axerunner/axerunner restart

To get the current status of axed, do:

    axerunner/axerunner status


# Commands

## sync

"axerunner sync" updates axerunner to the latest version from github

## install

"axerunner install" downloads and initializes a fresh axe install into ~/.axecore
unless already present

## reinstall

"axerunner reinstall" downloads and overwrites existing axe executables, even if
already present

## update

where it all began, "axerunner update" searches for your axed/axe-cli
executibles in the current directory, ~/.axecore, and $PATH.  It will prompt
to install in the first directory found containing both axed and axe-cli.
Multiple wallet directories are not supported. The script assumes the host runs
a single instance of axed.

## restart

"axerunner restart [now]" restarts (or starts) axed. Searches for axe-cli/axed
the current directory, ~/.axecore, and $PATH. It will prompt to restart if not
given the optional 'now' argument.

## status

"axerunner status" interrogates the locally running axed and displays its status

# Dependencies

* axed
* axe-cli
* bash version 4
* nc (netcat)
* curl
* perl
* pv
* python
* unzip

Based on Dashman https://github.com/moocowmoo/dashman
