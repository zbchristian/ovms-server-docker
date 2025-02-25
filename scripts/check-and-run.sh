#!/bin/bash

# Check and initialize database and run OVMS server
#

./ctrl-DB.sh check


# start the server
cd server
perl ./ovms_server.pl
