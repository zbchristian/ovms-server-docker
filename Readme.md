Run a barebone OVMS Server V2 in Docker Container
=================================================

This setup is running a barebone Open Vehicle Monitoring System Server API V2 in a docker container.
The docker-compose file instantiates three containers: 
- ovms-server - OVMS server V2
- ovms-db - MariaDB

There is NO web frontend and only the API V2 is per default enabled. This allows for the communication with the OVMS module and the OVMS APP.

Configuration
-------------
- Clone this repository to your server and change to the to level directory.
- Modify the file `.env`
  - add the path to the folder for the persistent data base files
  - edit the password for the database in both files
  - `DOMAIN` and `LE_PATH` are only needed for the version utilizing a certificate (`docker-compose-tls.yml`)
- Modify the file `conf/ovms_server.conf`
  -Edit the password for the database (same as above)
- Build the container: `sudo docker-compose build` - check for errors
  - The build process extracts the OVMS server from github and adds the required Perl modules and programs required by the service scripts

Run the Server
--------------
- Run the containers: `sudo docker-compose up -d` 
- Check the log file: `sudo docker logs -f ovms-server`
  - After about 10s the initialization of the database should be stated. The startup script adds a DEMO car and a default owner to the DB.
  - Once initialized, the server should display a line containing `OVMS::Server::ApiV2: - - - starting V2 server listener on port tcp/6867`
  - Any error messages should be carefully checked (e.g. missing perl modules etc.)
- Add your car and owner name: `sudo docker exec ovms-server ./ctrl_DB.sh addcar <CAR-ID> <CAR-PW> <YOUR-NAME>`
  - The `CAR-ID` and `CAR-PW` have to match the vehicle settings in the OVMS module
  - Repeat for as many cars as you like

Configure the OVMS Module in your car
-------------------------------------
Configure the Server V2 in the module by using either the Web frontend, or the console.
Set the server name to your server and disable TLS encryption. The port should be set automatically to 6867.

Service Script
--------------
The script `ctrl_DB.sh` allows to modfy the database by running: `sudo docker exec ovms-server ./ctrl_db.sh <PARAMETERS ..... >`

Parameters
 -  check                       : check if the DB is available and initialze if not done yet"
 -  addcar ID pass [owner-name] : add the car with name=ID and password=pass (as defined in OVMS module)." 
 -                                owner-name is optional. Owner will be created if not existing"
 -  delcar ID                   : delete the car with name=ID from the DB"
 -  adduser name [password]     : add a user to the DB. Usually not needed. Use addcar and provide the user name."
 -  deluser name                : remove a user from the DB"
 -  list                        : list the cars and owners stored in the DB"  

Be aware, that the user/owner passwords have no function and by default a hashed random value is placed into the DB. 


Using TLS Transport Encryption on Port 6870
-------------------------------------------
In `docker-compose-tls.yml`, Traefik as  a reverse proxy is assumed, in order to obtain a Lets Encrypt certificate for the TLS based transport encryption. 
The corresponding domain name and path to the Lets Encrypt store has to be added to `.env`. 

The container `ovms-cert` dumps the private key and the certificate into `conf/ovms_server.pem`, which is used by the server.

Be aware, that the TLS connection to the OVMS module requires, that the corresponding root certificate for Lets Encrypt is present. Otherwise the connection will fail.
