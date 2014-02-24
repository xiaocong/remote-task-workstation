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

- Java 7

        $ [sudo] apt-get install openjdk-7-jdk

- Android SDK

    Follow [Get the Android SDK][http://developer.android.com/sdk/index.html] to install android sdk.

    Note: Don't forget to add `adb` in your path environment.


### Nodejs Runtime

Install it from [Nodejs Official site][http://nodejs.org/], or via [nvm][https://github.com/creationix/nvm].

Note: Nodejs version should >= v0.10.*


### Clone and Install nodejs packages

        $ git clone https://github.com/xiaocong/remote-task-workstation && cd remote-task-workstation
        $ npm install

Run
===

### Run the workstation as a private one

        $ REG_USER=user@email.com ./node_modules/.bin/coffee app.coffee

### Run the workstation as a public one

        $ ./node_modules/.bin/coffee app.coffee
