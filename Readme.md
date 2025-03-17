Run a OVMS Server V2 as a Docker Container
==========================================

This setup is running a minimal setup of the Open Vehicle Monitoring System Server API V2 in a docker container.
The docker-compose file instantiates two containers: 
- ovms-server - OVMS server V2
- ovms-db - MariaDB to store the received messages

There is NO web frontend and only the API V2 is per default enabled. This allows for the communication with the OVMS module and the OVMS App.
A simple setup for cars and owners is available via the script `manage-db.sh`.


Configuration
-------------
- Clone this repository to your server and change to the top level directory.
- Modify the file `.env`
  - edit the path to the folder of this repo on your Linux system `OVMS_PATH`
  - edit the path to the folder for the persistent data base `OVMS_DB`
  - edit the password for the database `OVMS_DB_ROOT_PW` and `OVMS_DB_USER_PW`
  - set the correct timezone `OVMS_TIMEZONE`
  - `DOMAIN` and `LE_PATH` are only needed for the version utilizing a certificate (`docker-compose-tls.yml`)
- Modify the file `conf/ovms_server.conf`
  - Edit the password for the database (same as above)
  - Add plugins, BUT this has not been tested
- Build the container: `sudo docker-compose build` 
  - The build process extracts the OVMS server from github and adds the required Perl modules and programs required by the service scripts
  - check the log for errors

Run the Server
--------------
- Run the setup: `sudo docker-compose up -d` 
- Check the log of the server: `sudo docker logs -f ovms-server`
  - After about 10s the initialization of the database should be stated
  - The startup script adds a DEMO car and a default owner called Joe-the-Owner to the DB
  - Once initialized, the server should display a line containing `OVMS::Server::ApiV2: - - - starting V2 server listener on port tcp/6867`
  - Any error messages should be carefully checked (e.g. missing perl modules etc.)
- Add your car and owner name: `sudo docker exec ovms-server ./manage-db.sh addcar <CAR-ID> <CAR-PW> <YOUR-NAME>`
  - The `CAR-ID` and `CAR-PW` have to match the vehicle settings in the OVMS module
  - The owner name can be omitted. In this case the default owner is assigned to this car
  - Repeat for as many cars as you like

Configure the OVMS Module in your car
-------------------------------------
### Configure the Server V2
Use either the Web frontend or the console.
- Set the server name to your server
- disable TLS encryption
- the port should be set automatically to 6867.

### Configure the Vehicle
Again use the Web frontend or the console
- Set the same vehicle ID as above (`CAR-ID`) 
- Set the same password as above (`CAR-PW`)  

Service Script
--------------
The script `manage-db.sh` allows to modfy the database by running: `sudo docker exec ovms-server ./manage-db.sh <PARAMETERS ..... >`

### Parameters
check [DB-ROOT-Password]                     
: check if the DB is available and initialze if not done yet (automatically called at startup)
: Root acces to the DB required. Can be passed as parameter, or environment variable `MYSQL_ROOT_PASSWORD`

addcar ID pass [owner-name] 
: add the car with name=ID and password=pass (as defined in the OVMS module). 
: owner-name is optional. Owner will be created if not existing

delcar ID                   
: delete the car with name=ID from the DB

adduser name [password]     
: add a user to the DB
: Usually not needed: use addcar and provide the user name.

deluser name                
: remove a user from the DB

list
: list the cars and owners stored in the DB  


Passwords
---------
The password for the cars are stored as clear text in the database. 
This is the pre-shared key for the RC4 encryption of the communication between car, server and App. 

Owner passwords are stored as a Bcrypt hash in the DB, but never used in this setup. They might get important, if 
the HTTP API is needed (enable modules `ApiHttp.pm` and `ApiHttpd.pm`) on port 6868 and 6869. In this case the
password is required for authentification. Since the utilized hashing is not compatible with the included `AuthDrupal.pm` module,
a corresponding password encoding has to be provided.

Using TLS Transport Encryption on Port 6870
-------------------------------------------
The configuration in `docker-compose-tls.yml` assumes Traefik as a reverse proxy.
Traefik obtains a Lets Encrypt certificate for `ovms.my-server-domain.tld` for the TLS based transport encryption. 
The corresponding domain name and path to the Lets Encrypt store has to be specified to `.env` (`DOMAIN`, `LE_PATH`). 

The additional container `ovms-cert` dumps the private key and the certificate into `conf/ovms_server.pem`, which is used by the OVMS server.

Be aware, that the TLS connection to the OVMS module requires, that the corresponding root certificate for Lets Encrypt is present. Otherwise the connection will fail.
