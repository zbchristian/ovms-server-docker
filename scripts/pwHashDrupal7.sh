#!/bin/bash

_hashPassword_Drupal7() {
        if [ -z "$1" ]; then return; fi
        pw="$1"
        salt=$(cat /dev/urandom | base64 | head -c 8)
        prefix='$S$D'
        niter=16        # fix number of iterations to 4 (D in the prefix)
        hash=$(echo $salt$pw | sha512sum -t)
        (( --niter ))
        while [ $niter -gt 0 ]
        do
                hash=$(echo $hash$pw | sha512sum -t)
                (( --niter ))
        done
        encpw=$(echo $hash | base64 | head -c 55)
        pwhash="$prefix$salt$encpw"
        echo $pwhash
}

_hashPassword_Drupal8 test

