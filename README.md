remote-task-workstation
=======================

Installation
============

### Requirements

- Python environment and virtualenv

        $ [sudo] apt-get install python-pip python-dev
        $ [sudo] pip install virtualenv

- Necessary tools

        $ [sudo] apt-get install expect graphicsmagick

- Oracle Java 6

        $ [sudo] apt-get install software-properties-common
        $ [sudo] add-apt-repository ppa:webupd8team/java
        $ [sudo] apt-get update
        $ [sudo] apt-get install oracle-java6-installer

- Android SDK

    Follow [Get the Android SDK](http://developer.android.com/sdk/index.html) to install android sdk.

    Note: Don't forget to add `adb` in your path environment.


### Nodejs Runtime

Install it from [Nodejs Official site](http://nodejs.org/), or via [nvm](https://github.com/creationix/nvm).

Note: Nodejs version should >= v0.10.*


### Clone and Install nodejs packages

        $ git clone https://github.com/xiaocong/remote-task-workstation && cd remote-task-workstation
        $ npm install

Run
===

### Run the workstation as a private one

        $ REG_USER=user@email.com npm start

### Run the workstation as a public one

        $ npm start
