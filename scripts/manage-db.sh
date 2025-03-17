#!/bin/bash 
#
# Control the database of the OVMS server API V2
# ==============================================
# Script has to run in the directory above the server/ path
# Configuration in server/conf/ovms_server.conf
# SQL config in server/ovms_server.sql
#
# w/o a parameter, the usage message is displayed
#
# Parameter:
#       check [DB-ROOT-PW]          : check if DB is existing and initialize if not (requires a ROOT PW for the DB
#       addcar ID pass [owner-name] : add vehicle for owner with given name
#       delcar ID                   : delete vehicle
#       adduser name [password] 
#       deluser name
#       list                        : list all cars
#
#
# Requires: mysql-client, htpasswd (apache2-utils), sed, base64, netcat
#
# Owner passwords are stored as bcrypt hash, like in Drupal 8-10
# This is NOT consistent with the AuthDrupal.pm module, which expects a Drupal 7 hash
#
# zbchristian@github  2025
#

fconf=server/conf/ovms_server.conf
fsql=server/ovms_server.sql

if [ ! -f $fconf ]; then
    echo "Configuration file $fconf not found ... exit"
    exit 1
fi

dbhost=$(cat $fconf | sed -rn 's/^path=.*host\=([^;\w]*).*$/\1/p')
dbport=$(cat $fconf | sed -rn 's/^path=.*port\=([^;\w]*).*$/\1/p')
if [ -z "$dbport" ]; then 
    dbport=3306
fi

db=openvehicles


user=$(cat $fconf | sed -rn 's/^user\=(.*?)\w*$/\1/p')
pw=$(cat $fconf | sed -rn 's/^pass\=(.*?)\w*$/\1/p')

if [ -z "$user" ] || [ -z "$pw" ]; then
    echo "No database user and/or password found in environment/configuration file"
    exit 1
fi 

if [[ $# -eq 0 ]]; then
    echo "Manage DB Script for the OVMS API V2 Server"
    echo "==========================================="
    echo "Parameters: "
    echo "  check [DB-ROOT-PW]          : check if the DB is available and initialze if not done yet (requires DB ROOT access)"
    echo "  addcar ID pass [owner-name] : add the car with name=ID and password=pass (as defined in OVMS module)." 
    echo "                                owner-name is optional. Owner will be created if not existing"
    echo "  delcar ID                   : delete the car with name=ID from the DB"
    echo "  adduser name [password]     : add a user to the DB. Usually not needed. Use addcar and provide the user name."
    echo "  deluser name                : remove a user from the DB"
    echo "  list                        : list the cars and owners stored in the DB"
    exit 0
fi

if [[ "$1" == "check" ]] && [ ! -z "$2" ]; then
    rootpw="$2"
else 
    rootpw=$(echo $MYSQL_ROOT_PASSWORD)
fi

dbcmd="mariadb"

mysqlcmd="$dbcmd -h $dbhost -P $dbport -u $user -p$pw  $db"

_get_ownerid() {
    # get the ID of the owner - empty if not existing
    $mysqlcmd -e "SELECT owner FROM ovms_owners WHERE name='$1'" | grep -o "[0-9]*"
}

_get_car() {
    # get the car entry - empty if not existing
    $mysqlcmd -e "SELECT * FROM ovms_cars WHERE vehicleid='$1'" | grep $carID
}

_pw_hash() {
    # get Bcrypt hash of password
    htpasswd -bnBC 10 "" $1 | tr -d ':\n'
}

_gen_pw() {
    # generate base64 random password
    base64 -w 0 /dev/urandom |head -c 12
}

_init_DB() {
    $mysqlcmd << EOF
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$pw';
CREATE DATABASE IF NOT EXISTS $db;
GRANT ALL ON $db.* TO '$user'@'%';
FLUSH PRIVILEGES;
EOF
    $mysqlcmd  < $fsql
    echo "DB initialized and tables imported from $fsql..."
}


# decode the command
case "$1" in
    addcar)
        if [[ $# -lt 3 ]]; then
            echo "Usage: addcar ID password [owner-name]..."
            exit 1
        fi
        carID="$2"
        carpass="$3"
        if [[ $# -eq 4 ]]; then
            name="$4"
            ownerid=$(_get_ownerid $name)
            if [ -z "$ownerid" ]; then
                usrpass=$(_gen_pw)
                $0 adduser $name $usrpass
                ownerid=$(_get_ownerid $name)
            fi
        else
            ownerid=1
        fi
        cexists=$(_get_car $carID)
        if [ -z "$cexists" ]; then
            $mysqlcmd -e "INSERT INTO ovms_cars (vehicleid, owner, carpass) VALUES('$carID', '$ownerid', '$carpass')"
            echo "Vehicle $carID added to DB with password $carpass"
        else
            echo "Vehicle $carID already exists ... exit"
        fi
        ;;
    delcar)
        if [[ $# -ne 2 ]]; then
            echo "Usage: delcar ID ..."
            exit 1
        fi
        carID="$2"
        cexists=$(_get_car $carID)
        if [ -z "$cexists" ]; then 
            echo "Vehicle $carID does not exist ... exit"
        else
            $mysqlcmd -e "DELETE FROM ovms_cars WHERE vehicleid='$carID'"
            echo "Vehicle $carID removed from DB "
        fi
        ;;
    adduser)
        if [[ $# -lt 2 ]]; then
            echo "Usage: adduser name [password] ..."
            exit 1
        fi
        name="$2"
        [ $# -eq 3 ] && pass="$3"  || pass=$(_gen_pw)
        pwhash=$(_pw_hash "$pass")
        uexists=$(_get_ownerid $name)
        if [ -z "$uexists" ]; then
            id=$($mysqlcmd -e "SELECT max(owner) FROM ovms_owners" | grep -o "[0-9]*")
            [ -z $id ] && id=1 || ((++id))
            $mysqlcmd -e "INSERT INTO ovms_owners (owner, name, pass, status) VALUES('$id', '$name', '$pwhash', 1)"
            echo "User $name added to DB with password $pass and ownerID $id"
        else
            echo "User $name already exists ... exit"
        fi
        ;;
    deluser)
        if [[ $# -ne 2 ]]; then
            echo "Usage: deluser name ..."
            exit 1
        fi
        name="$2"
        uexists=$(_get_ownerid $name)
        if [ -z "$uexists" ]; then
            echo "User $name does not exist ... exit"
        else
            $mysqlcmd -e "DELETE FROM ovms_owners WHERE name='$name'"
            echo "User $name removed from DB "
        fi
        ;;
    list)
        $mysqlcmd -e "SELECT vehicleid,vehiclename,carpass,owner FROM ovms_cars" 
        $mysqlcmd -e "SELECT name,owner FROM ovms_owners" 
        ;;
    check)
        # wait for the DB server to start
        sleep 10

        # check access to DB
        if nc -v -z -w 3 $dbhost $dbport &> /dev/null; then
            echo "Active DB server $dbhost found"
        else
            echo "DB server $dbhost not reachable ... exit"
            exit 1
        fi
        if [ -z "$rootpw" ]; then
            echo "NO Root password available - exit"
            exit 1          
        fi
        mysqlcmd="$dbcmd -h $dbhost -P $dbport -u root -p$rootpw $db"
        # check DATABASE and initialize
        if $mysqlcmd -e exit > /dev/null 2>&1; then
            echo "DB $db found"
        else
            echo "Initialize DB $db"
            echo "Create Database $db and user $user ..."
        fi
        ret=$($mysqlcmd -e "SHOW TABLES FROM $db" | grep ovms_cars)
        if [ -z "$ret" ]; then
            _init_DB
            echo "Create DEMO vehicle and the owner Joe-the-Owner"
            carpass=$(_gen_pw)
            $0 addcar DEMO $carpass  
            usrpass=$(_gen_pw)
            $0 adduser Joe-the-Owner $usrpass
            echo "Initialization of DB done"
        else
            echo " and tables exist"
        fi
        ;;
    *)
        # show usage
        echo "Unknown option "
        $0
        ;;
esac

