# AXErunner

DASH wallet/daemon management utilities - version 0.1.26

* This script installs, updates, and manages single-user dash daemons and wallets
* It is currently only compatible with 32/64 bit linux.
* Multi-user (system directory) installs are not supported

# Install/Usage

To install axerunner do:

    sudo apt-get install python git unzip pv
    cd ~ && git clone https://github.com/AXErunners/axerunner

To update your existing version 12 32/64bit linux dash wallet to the latest
dashd, do:

    axerunner/axerunner update

To perform a new install of dash, do:

    axerunner/axerunner install

To overwrite an existing dash install, do:

    axerunner/axerunner reinstall

To update axerunner to the latest version, do:

    axerunner/axerunner sync

To restart (or start) dashd, do:

    axerunner/axerunner restart

To get the current status of dashd, do:

    axerunner/axerunner status


# Commands

## sync

"axerunner sync" updates axerunner to the latest version from github

## install

"axerunner install" downloads and initializes a fresh dash install into ~/.dashcore
unless already present

## reinstall

"axerunner reinstall" downloads and overwrites existing dash executables, even if
already present

## update

where it all began, "axerunner update" searches for your dashd/dash-cli
executibles in the current directory, ~/.dashcore, and $PATH.  It will prompt
to install in the first directory found containing both dashd and dash-cli.
Multiple wallet directories are not supported. The script assumes the host runs
a single instance of dashd.

## restart

"axerunner restart [now]" restarts (or starts) dashd. Searches for dash-cli/dashd
the current directory, ~/.dashcore, and $PATH. It will prompt to restart if not
given the optional 'now' argument.

<a href="#restart-1">screencap</a>

## status

"axerunner status" interrogates the locally running dashd and displays its status

<a href="#status-1">screencap</a>

# Dependencies

* bash version 4
* nc (netcat)
* curl
* perl
* pv
* python
* unzip
* dashd, dash-cli - version 12 or greater to update

Based on Dashman https://github.com/moocowmoo/dashman
