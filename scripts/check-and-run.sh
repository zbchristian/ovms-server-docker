#!/bin/bash
#
# Check and initialize database and run OVMS server
#
# zbchristian@github 2025

./manage-db.sh check


# start the server
cd server
perl ./ovms_server.pl
