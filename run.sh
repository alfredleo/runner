#!/bin/bash
## run 1.1 - run application [2022-05-27]
## This script can be run on Windows, MAC and Linux.
## Windows: Just install git bash and run bash terminal in PHPStorm or VScode
## Usage: ./run.sh [COMMAND] [COMMAND] ...
## Commands:
##   test          run application tests
##   init          init application
##   start         start/restart application
##   stop          stop application without removing volumes/db
##   log-sql       log all sql queries application
##   remove-db     remove database files
##   clear         remove all images, volumes, and containers from the system
##   load-env      load one env variable from .env file on host system
## Examples:
##   $./run.sh test
##   $./run.sh init
##   $./run.sh start
##   $./run.sh clear init test

## debug mode
# set -o xtrace

fallback_message=$"Usage: $0 { start | stop | init | test | log-sql | remove-db | clear | load-env }, one or more commands separated by space"
if [[ $# -eq 0 ]]; then
    echo "$fallback_message"
    exit 0
fi

## Find machine type
unameOut="$(uname -s)"
case "${unameOut}" in
Linux*) machine=Linux ;;
Darwin*) machine=Mac ;;
CYGWIN*) machine=Cygwin ;;
MINGW*) machine=MinGw ;;
MSYS_NT*) machine=Windows ;;
*) machine="UNKNOWN:${unameOut}" ;;
esac
# echo "This is a ${machine} machine"

runTest() {
    echo "---------> runTest"
    # Run tests
    # cp -n .env-dev.testing .env.testing
#    docker-compose down -v
#    docker-compose up -d
    echo "Wait for mysql up"
    while [ $(docker inspect --format "{{json .State.Health.Status }}" mysql) != "\"healthy\"" ]; do printf "."; sleep 1; done
#    docker-compose exec php php artisan config:clear
    docker-compose exec php php artisan migrate --force
    # run all tests
    docker-compose exec php ./vendor/bin/phpunit --configuration phpunit.xml --dont-report-useless-tests
    # run each test group
    # docker-compose exec php ./vendor/bin/phpunit --configuration phpunit.xml --testsuite Unit
    # docker-compose exec php ./vendor/bin/phpunit --configuration phpunit.xml --testsuite Feature
}

runInit() {
    echo "---------> runInit"
    cp -n .env-dev .env
    docker-compose down -v
    docker-compose up -d --build
    # docker-compose exec php sh -c "chmod -R 777 /var/www/html/storage"
    docker-compose exec php composer install --no-interaction
    docker-compose exec php php artisan config:clear
    docker-compose exec php sh -c "php artisan route:clear"
    echo "Wait for mysql up"
    while [ $(docker inspect --format "{{json .State.Health.Status }}" mysql) != "\"healthy\"" ]; do printf "."; sleep 1; done
    docker-compose exec php php artisan migrate --force
    #  docker-compose exec php sh -c "php artisan passport:install"
    #  docker-compose exec php sh -c "php artisan ide-helper:generate"
    #  docker-compose exec php sh -c "php artisan ide-helper:models --dir='app/Models'"
    #  docker-compose exec php sh -c "php artisan ide-helper:meta"
    docker-compose exec php php artisan db:seed
}

runStart() {
    echo "---------> runStart"
    cp -n .env-dev .env
    docker-compose down
    docker-compose up -d
    # docker-compose exec php sh -c "chmod -R 777 /var/www/html/storage"
    docker-compose exec php php artisan config:clear
    docker-compose exec php php artisan migrate --force
}

runStop() {
    echo "---------> runStop"
    cp -n .env-dev .env
    docker-compose down
}

runLogSql() {
    envFile=".env"
    #  if [[ "$second_argument" == "test" ]]
    #  then
    #    envFile=".env.testing"
    #  fi
    runLoadEnv
    docker-compose --env-file ${envFile} exec mysql sh -c "mysql -uroot -p${DB_PASSWORD} -e 'SET global general_log_file=\"/var/lib/mysql/general.log\"'"
    docker-compose --env-file ${envFile} exec mysql sh -c "mysql -uroot -p${DB_PASSWORD} -e 'SET global general_log = 1;'"
    docker-compose --env-file ${envFile} exec mysql sh -c "tail -f /var/lib/mysql/general.log"
}

runRemoveDb() {
    cp -n .env-dev .env
    docker-compose down -v
}

runClearSystem() {
    echo "---------> runClearSystem"
    cp -n .env-dev .env
    docker-compose down --remove-orphans -v
    docker system prune -a --force
}

runLoadEnv() {
    # load just DB_PASSWORD env variable
    if [ -f .env ]; then
        export "$(cat .env | grep -v '#' | grep 'DB_PASSWORD' | awk '/=/ {print $1}')"
    fi
}

# run OS specific commands
if [ $machine == Windows ]; then
    # this is required for mysql on windows to set file as readonly or mysql will ignore it
    attrib +R docker/local/mysql/my.cnf
fi

# main application login
for arg in "$@"; do
    case $arg in
    test)
        runTest
        ;;
    init)
        runInit
        ;;
    start)
        runStart
        ;;
    stop)
        runStop
        ;;
    log-sql)
        runLogSql
        ;;
    remove-db)
        runRemoveDb
        ;;
    clear)
        runClearSystem
        ;;
    load-env)
        runLoadEnv
        ;;
    *)
        echo "$fallback_message"
        ;;
    esac
done
