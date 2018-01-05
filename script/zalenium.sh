#!/usr/bin/env bash

# One-liner Zalenium & Docker-selenium (dosel) installer
#-- With love by team-tip

# set -e: exit asap if a command exits with a non-zero status
set -e

# In OSX install gtimeout through
#   brew install coreutils
function mtimeout() {
    if [ "$(uname -s)" = 'Darwin' ]; then
        gtimeout "$@"
    else
        timeout "$@"
    fi
}

function please_install_gnu_grep() {
    echo "GNU grep is not installed, please install with:"
    echo "  brew tap homebrew/dupes"
    echo "  brew install grep --with-default-names"
    echo ""
    exit 16
}

# In OSX install GNU grep through
#   brew tap homebrew/dupes
#   brew install grep --with-default-names
#   /usr/local/Cellar/grep/*/bin/grep --version
function set_mgrep() {
    if [ "$(uname -s)" != 'Darwin' ]; then
        M_GREP="grep"
    else
        if grep --version >/dev/null; then
            if grep --version | grep GNU >/dev/null; then
                # All good here, we can use this default grep.
                M_GREP="grep"
            else
                # Looks like BSD grep is installed so try GNU
                if /usr/local/Cellar/grep/*/bin/grep --version >/dev/null; then
                    # Found GNU grep installed
                    M_GREP="/usr/local/Cellar/grep/*/bin/grep"
                else
                    # Will need to install GNU grep
                    please_install_gnu_grep
                fi
            fi
        else
            # No grep found in the path, try Cellar
            if /usr/local/Cellar/grep/*/bin/grep --version >/dev/null; then
                # Found GNU grep installed
                M_GREP="/usr/local/Cellar/grep/*/bin/grep"
            else
                # Will need to install GNU grep
                please_install_gnu_grep
            fi
        fi
    fi
}
export -f set_mgrep
set_mgrep

# In OSX install GNU gsort through
#   brew install coreutils
function set_msort() {
    if [ "$(uname -s)" = 'Darwin' ]; then
        M_SORT="gsort"
    else
        M_SORT="sort"
    fi
}
export -f set_msort
set_msort

# Actively waits for Zalenium to fully starts
# you can copy paste this in your Jenkins scripts
WaitZaleniumStarted()
{
    set_mgrep

    DONE_MSG="Zalenium is now ready!"
    while ! docker logs zalenium | ${M_GREP} "${DONE_MSG}" >/dev/null; do
        echo -n '.'
        sleep 0.2
    done

    if [ "$(uname -s)" != 'Darwin' ]; then
        # This doesn't work properly on OSX
        # Below export is useless if this is run in a separate shell
        if [ "${USE_NET_HOST}" == "true" ]; then
            local __sel_host="localhost"
        else
            local __sel_host=$(docker inspect -f='{{.NetworkSettings.IPAddress}}' zalenium)
        fi
        local __selenium_grid_console="http://${__sel_host}:4444/grid/console"

        # Also wait for the Proxy to be registered into the hub
        while ! curl -sSL "${__selenium_grid_console}" 2>&1 \
                | grep "DockerSeleniumStarterRemoteProxy" 2>&1 >/dev/null; do
            echo -n '.'
            sleep 0.2
        done
    fi
}
export -f WaitZaleniumStarted

EnsureCleanEnv()
{
    local __containers=$(docker ps -a -f name=zalenium_ -q | wc -l)

    if [ ${__containers} -gt 0 ]; then
        echo "Removing exited docker-selenium containers..."
        docker rm -f $(docker ps -a -f name=zalenium_ -q)
    fi
}

toolchainStop() {
    # This works differently in certain peculiar environment
    if [ "${TOOLCHAIN_LOOKUP_REGISTRY}" != "" ]; then
        local __video=${VIDEO:-"true"}
        if [ "${__video}" == "true" ]; then
            rm -rf ./videos || true

            /tools/run :stups -v /tmp:/tmp -- \
                cp --recursive --copy-contents /tmp/videos/${BUILD_NUMBER} ./videos || true

            ls -la ./videos || true
        fi
    fi
}

getDockerOpts(){

    # Supported: 1.11, 1.12, 1.13
    local __docker_ver=$(docker --version | ${M_GREP} -Po '(?<=version )([a-z0-9]+\.[a-z0-9]+)')

    local __z_default_docker_opts="--name zalenium"

    if [ "${USE_NET_HOST}" == "true" ]; then
        local __z_docker_opts="${__z_default_docker_opts} --net=host"
    else
        local __z_docker_opts="${__z_default_docker_opts} -p 4444:4444 -p 5555:5555 ${ADDITIONAL_DOCKER_OPTS}"
    fi

    local __z_startup_opts=""
    local __interactive="${1}"


    if [ "${__interactive}" == "true" ]; then
        __z_docker_opts="${__z_docker_opts} -t --rm"
    else
        __z_docker_opts="${__z_docker_opts} -t -d"
    fi


    if [ -n "${FORCED_DOCKER_OPTS}" ]; then
        __z_docker_opts="${FORCED_DOCKER_OPTS}"
    else
        __z_docker_opts="${__z_docker_opts} ${CUSTOM_DOCKER_OPTS}"
    fi


    if docker-machine active >/dev/null 2>&1; then
        # With docker-machine the file might not be here
        # but will be available during docker run.
        # Also on some installations executable is in /usr/local/bin
        if [ -f /usr/local/bin/docker ]; then
            __z_docker_opts="${__z_docker_opts} -v /usr/local/bin/docker:/usr/bin/docker"
        else
            __z_docker_opts="${__z_docker_opts} -v /usr/bin/docker:/usr/bin/docker"
        fi
    else
        if [ -f /usr/bin/docker ]; then
            __z_docker_opts="${__z_docker_opts} -v /usr/bin/docker:/usr/bin/docker"
        else
            # This should only be necessary in docker native for OSX
            __z_docker_opts="${__z_docker_opts} -e DOCKER=${__docker_ver}"
        fi
    fi


    if [ -f /etc/timezone ]; then
        __z_startup_opts="${__z_startup_opts} --timeZone $(cat /etc/timezone)"
        # TODO: else: Figure out how to get timezone in OSX
    fi


    # Docker in docker in docker related fixes
    if ls /lib/x86_64-linux-gnu/libsystemd-journal.so.0 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /lib/x86_64-linux-gnu/libsystemd-journal.so.0:/lib/x86_64-linux-gnu/libsystemd-journal.so.0:ro"
    fi

    if ls /lib/x86_64-linux-gnu/libcgmanager.so.0 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /lib/x86_64-linux-gnu/libcgmanager.so.0:/lib/x86_64-linux-gnu/libcgmanager.so.0:ro"
    fi

    if ls /lib/x86_64-linux-gnu/libnih.so.1 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /lib/x86_64-linux-gnu/libnih.so.1:/lib/x86_64-linux-gnu/libnih.so.1:ro"
    fi

    if ls /lib/x86_64-linux-gnu/libnih-dbus.so.1 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /lib/x86_64-linux-gnu/libnih-dbus.so.1:/lib/x86_64-linux-gnu/libnih-dbus.so.1:ro"
    fi

    if ls /lib/x86_64-linux-gnu/libdbus-1.so.3 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /lib/x86_64-linux-gnu/libdbus-1.so.3:/lib/x86_64-linux-gnu/libdbus-1.so.3:ro"
    fi

    if ls /lib/x86_64-linux-gnu/libgcrypt.so.11 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /lib/x86_64-linux-gnu/libgcrypt.so.11:/lib/x86_64-linux-gnu/libgcrypt.so.11:ro"
    fi

    if ls /usr/lib/x86_64-linux-gnu/libapparmor.so.1 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /usr/lib/x86_64-linux-gnu/libapparmor.so.1:/usr/lib/x86_64-linux-gnu/libapparmor.so.1:ro"
    fi

    if ls /usr/lib/x86_64-linux-gnu/libltdl.so.7 >/dev/null 2>&1; then
        __z_docker_opts="${__z_docker_opts} -v /usr/lib/x86_64-linux-gnu/libltdl.so.7:/usr/lib/x86_64-linux-gnu/libltdl.so.7:ro"
    fi


    local __start_tunnel=false
    local __video=${VIDEO:-"true"}
    local __screen_width=${SCREEN_WIDTH:-"1920"}
    local __screen_height=${SCREEN_HEIGHT:-"1080"}
    local __desired_containers_count=${DESIRED_CONTAINERS_START_COUNT:-"2"}
    local __chrome_count=${CHROME_START_COUNT:-"1"}
    local __firefox_count=${FIREFOX_START_COUNT:-"1"}
    local __max_containers=${MAX_CONTAINERS_COUNT:-"60"}
    local __time_zone=${TIME_ZONE:-"Europe/Berlin"}
    local __debug_enabled=${DEBUG_ENABLED:-"false"}
    local __selenium_image_name=${SELENIUM_IMAGE_NAME:-"elgalu/selenium"}
    local __max_test_sessions=${MAX_TEST_SESSIONS:-"1"}
    local __keep_only_failed_tests=${KEEP_ONLY_FAILED_TESTS:-"false"}
    local __send_anonymous_usage_info=${SEND_ANONYMOUS_USAGE_INFO:-"true"}

    if [ "${deprecated_parameters}" == "true" ]; then
        __desired_containers_count=$((__chrome_count + __firefox_count))
    fi

    # Map video folder if videos are enabled
    if [ "${__video}" == "true" ]; then
        local __videos_dir=""
        # This works differently in certain peculiar environment
        if [ "${TOOLCHAIN_LOOKUP_REGISTRY}" != "" ]; then
            __videos_dir="/tmp/videos/${BUILD_NUMBER}"
            export HOST_UID="$(id -u)"
            export HOST_GID="$(id -g)"
            docker run --rm -v /tmp:/tmp alpine mkdir -p ${__videos_dir} >&2
            docker run --rm -v /tmp:/tmp alpine chown -R ${HOST_UID}:${HOST_GID} ${__videos_dir} >&2
        else
            __videos_dir=${VIDEOS_DIR:-"/tmp/videos"}
            mkdir -p "${__videos_dir}"
        fi

        __z_docker_opts="${__z_docker_opts} -v ${__videos_dir}:/home/seluser/videos"
    fi

    # Pre-alpha Android emulation in Appium - appium port (4723)
    if [ "${APPIUM_PORT}" != "" ]; then
        # Only export ports when not using --net=host
        if [ "${USE_NET_HOST}" != "true" ]; then
            __z_docker_opts="${__z_docker_opts} -p ${APPIUM_PORT}:${APPIUM_PORT}"
        fi
    fi

    # Pre-alpha Android emulation in Appium - vnc port (6080)
    if [ "${APPIUM_VNC}" != "" ]; then
        # Only export ports when not using --net=host
        if [ "${USE_NET_HOST}" != "true" ]; then
            __z_docker_opts="${__z_docker_opts} -p ${APPIUM_VNC}:${APPIUM_VNC}"
        fi
    fi

    # Sauce Labs
    if [ "${SAUCE_USERNAME}" == "" ]; then
        echo "WARN: Sauce Labs will not be enabled because the var \$SAUCE_USERNAME is NOT present" >&2
        SAUCE_LABS_ENABLED=false
    else
        echo "INFO: Sauce Labs will be enabled because the var \$SAUCE_USERNAME is present" >&2
        if [ "${SAUCE_ACCESS_KEY}" == "" ]; then
            echo "\$SAUCE_USERNAME is set but \$SAUCE_ACCESS_KEY is not so failing..." >&2
            exit 17
        fi
        SAUCE_LABS_ENABLED=true
        export SAUCE_TUNNEL_ID="zalenium${BUILD_NUMBER}"
        __start_tunnel=true
    fi

    # BrowserStack
    if [ "${BROWSER_STACK_USER}" == "" ]; then
        echo "WARN: BrowserStack will not be enabled because the var \$BROWSER_STACK_USER is NOT present" >&2
        BROWSER_STACK_ENABLED=false
    else
        echo "INFO: BrowserStack will be enabled because the var \$BROWSER_STACK_USER is present" >&2
        if [ "${BROWSER_STACK_KEY}" == "" ]; then
            echo "\$BROWSER_STACK_USER is set but \$BROWSER_STACK_KEY is not so failing..." >&2
            exit 18
        fi
        BROWSER_STACK_ENABLED=true
        export BROWSER_STACK_TUNNEL_ID="zalenium${BUILD_NUMBER}"
        __start_tunnel=true
    fi

    # Testing Bot
    if [ "${TESTINGBOT_SECRET}" == "" ]; then
        echo "WARN: Testing Bot will not be enabled because the var \$TESTINGBOT_SECRET is NOT present" >&2
        TESTINGBOT_ENABLED=false
    else
        echo "INFO: Testing Bot will be enabled because the var \$TESTINGBOT_SECRET is present" >&2
        if [ "${TESTINGBOT_KEY}" == "" ]; then
            echo "\$TESTINGBOT_SECRET is set but \$TESTINGBOT_KEY is not so failing..." >&2
            exit 19
        fi
        TESTINGBOT_ENABLED=true
        __start_tunnel=true
    fi

    mkdir -p /tmp/mounted

    echo ${__z_docker_opts} \
      -e BUILD_URL="${BUILD_URL}" \
      -e CDP_TARGET_REPOSITORY="${CDP_TARGET_REPOSITORY}" \
      -e KUBERNETES_ENABLED="${KUBERNETES_ENABLED}" \
      -e SAUCE_USERNAME="${SAUCE_USERNAME}" \
      -e SAUCE_ACCESS_KEY="${SAUCE_ACCESS_KEY}" \
      -e SAUCE_TUNNEL_ID="${SAUCE_TUNNEL_ID}" \
      -e BROWSER_STACK_USER="${BROWSER_STACK_USER}" \
      -e BROWSER_STACK_KEY="${BROWSER_STACK_KEY}" \
      -e BROWSER_STACK_TUNNEL_ID="${BROWSER_STACK_TUNNEL_ID}" \
      -e TESTINGBOT_SECRET="${TESTINGBOT_SECRET}" \
      -e TESTINGBOT_KEY="${TESTINGBOT_KEY}" \
      -e HOST_UID="$(id -u)" \
      -e HOST_GID="$(id -g)" \
      -v /var/run/docker.sock:/var/run/docker.sock \
      --privileged \
      -v /tmp/mounted:/tmp/mounted \
      -v /dev/shm:/dev/shm \
      --label zalenium_main \
      dosel/zalenium:${zalenium_tag} \
      start ${__z_startup_opts} \
            --desiredContainers "${__desired_containers_count}" \
            --maxDockerSeleniumContainers "${__max_containers}" \
            --screenWidth "${__screen_width}" --screenHeight "${__screen_height}" \
            --videoRecordingEnabled "${__video}" \
            --sauceLabsEnabled ${SAUCE_LABS_ENABLED} \
            --browserStackEnabled ${BROWSER_STACK_ENABLED} \
            --testingBotEnabled ${TESTINGBOT_ENABLED} \
            --startTunnel "${__start_tunnel}" \
            --timeZone "${__time_zone}" \
            --debugEnabled "${__debug_enabled}" \
            --seleniumImageName "${__selenium_image_name}" \
            --maxTestSessions "${__max_test_sessions}" \
            --keepOnlyFailedTests "${__keep_only_failed_tests}" \
            --sendAnonymousUsageInfo "${__send_anonymous_usage_info}"
}

ShutDownZalenium(){
    echo "Terminating Zalenium properly..."

    local __containers=$(docker ps -q --filter "label=zalenium_main" | wc -l)
    if [ ${__containers} -gt 0 ]; then
        if [ -z "${INTERACTIVE}" ]; then
            docker logs zalenium
        fi
        docker attach --no-stdin zalenium &
        if [ "${TOOLCHAIN_LOOKUP_REGISTRY}" != "" ]; then
            echo "Waiting for video processing..."
            sleep 60
        fi
        docker stop --time 90 zalenium
    fi

    __containers=$(docker ps -a -q --filter "label=zalenium_main" | wc -l)
    if [ ${__containers} -gt 0 ]; then
        docker rm zalenium
    fi

    __containers=$(docker ps -a -q --filter "label=zalenium_main" | wc -l)
    if [ ${__containers} -gt 0 ]; then
        docker rm -f zalenium
    fi

    toolchainStop
    EnsureCleanEnv
    echo "Zalenium stopped!"
    exit 0
}

StartZalenium(){

    echo "Starting Zalenium in docker..."

    local opts="$(getDockerOpts ${INTERACTIVE})"
    docker run ${opts}

    if [ -z "${INTERACTIVE}" ]; then
        # When running in daemon mode we want to wait for Zalenium to start
        # before returning the prompt to the user
        if ! mtimeout --foreground "2m" bash -c WaitZaleniumStarted; then
            echo "Zalenium failed to start after 2 minutes, failing..."
            docker logs zalenium
            exit 4
        fi

        echo "Zalenium in docker started!"
    fi
}

function InstallDockerCompose() {
    DOCKER_COMPOSE_VERSION="1.9.0"
    PLATFORM=`uname -s`-`uname -m`
    url="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${PLATFORM}"
    curl -ssL "${url}" >docker-compose
    chmod +x docker-compose

    if [ "${we_have_sudo}" == "true" ]; then
        sudo rm -f /usr/bin/docker-compose
        sudo rm -f /usr/local/bin/docker-compose
        sudo mv docker-compose /usr/local/bin
        docker-compose --version
    else
        ./docker-compose --version
    fi
}

# VersionGt tell if the 1st argument version is greater than the 2nd
#   VersionGt "1.12.3" "1.11"   #=> exit 0
#   VersionGt "1.12.3" "1.12"   #=> exit 0
#   VersionGt "1.12.3" "1.13"   #=> exit 1
#   VersionGt "1.12.3" "1.12.3" #=> exit 1
function VersionGt() {
    test "$(printf '%s\n' "$@" | ${M_SORT} -V | head -n 1)" != "$1";
}

function CheckDependencies() {
    # TODO: Only check upon new Zalenium versions
    echo -n "${checking_and_or_updating} dependencies... "

    if ! which test >/dev/null; then
        echo "Please install test"
        echo "  brew install coreutils"
        exit 1
    fi

    if ! which printf >/dev/null; then
        echo "Please install printf"
        echo "  brew install coreutils"
        exit 2
    fi

    if ! ${M_SORT} --version >/dev/null; then
        echo "Please install ${M_SORT} (GNU sort)"
        echo "  brew install coreutils"
        exit 3
    fi

    if ! ${M_GREP} --version >/dev/null; then
        please_install_gnu_grep
    fi

    if ! which wc >/dev/null; then
        echo "Please install wc"
        echo "  brew install coreutils"
        exit 5
    fi

    if ! which head >/dev/null; then
        echo "Please install head"
        echo "  brew install coreutils"
        exit 6
    fi

    if ! perl --version >/dev/null; then
        echo "Please install perl, e.g. brew install perl"
        exit 7
    fi

    if ! wget --version >/dev/null; then
        echo "Please install wget, e.g. brew install wget"
        exit 8
    fi

    if ! jq --version >/dev/null; then
        echo "Please install jq, e.g. brew install jq"
        exit 20
    fi

    if ! mtimeout --version >/dev/null; then
        echo "Please install GNU timeout"
        echo "  brew install coreutils"
        exit 10
    fi

    if ! docker --version >/dev/null; then
        echo "Please install docker, e.g. brew install docker"
        exit 11
    fi

    # Grab docker version, e.g. "1.12.3"
    DOCKER_VERSION=$(docker --version | ${M_GREP} -Po '(?<=version )([a-z0-9\.]+)')
    # Check supported docker range of versions, e.g. > 1.11.0
    if ! VersionGt "${DOCKER_VERSION}" "1.11.0"; then
        echo "Current docker version '${DOCKER_VERSION}' is not supported by Zalenium"
        echo "Docker version >= 1.11.1 is required"
        exit 12
    fi

    # Note it doesn't matter if the container named `grid` exists
    # `docker ps` will only fail if docker is not running
    if ! docker ps -q --filter=name=grid >/dev/null; then
        echo "Docker is installed but doesn't seem to be running properly."
        echo "Make sure docker commands like 'docker ps' work."
        exit 13
    fi

    if ! docker ps -a -q --filter "label=zalenium_main" >/dev/null; then
        echo "Docker is installed but the current version doesn't support --filter."
        echo "Make sure you have a recent or latest version of Docker."
        exit 21
    fi

    if ! docker-compose --version >/dev/null 2>&1; then
        echo "--INFO: docker-compose is not installed"
    else
        # Grab docker-compose version, e.g. "1.9.0"
        DOCKER_COMPOSE_VERSION=$(docker-compose --version | ${M_GREP} -Po '(?<=version )([a-z0-9\.]+)')
        # Check supported docker-compose range of versions, e.g. > 1.7.0
        if ! VersionGt "${DOCKER_COMPOSE_VERSION}" "1.7.0"; then
            echo "Current docker-compose version '${DOCKER_COMPOSE_VERSION}' is not supported by Zalenium"
            if [ "${upgrade_if_needed}" == "true" ]; then
                echo "Will upgrade docker-compose because you passed the 'upd' argument"
                #InstallDockerCompose
            else
                echo "Docker-compose version >= 1.7.1 is required"
                exit 14
            fi
        fi
    fi

    # If we have docker-machine then docker.sock is not in the current host
    if ! docker-machine active >/dev/null 2>&1; then
        if ! ls /var/run/docker.sock >/dev/null; then
            echo "ERROR: Zalenium needs /var/run/docker.sock but couldn't find it!"
            exit 15
        fi
    fi

    echo "Done ${checking_and_or_updating} dependencies."
}

function PullDependencies() {
    # Retry pulls up to 3 times as networks are known to be unreliable

    # https://github.com/zalando/zalenium
    docker pull dosel/zalenium:${zalenium_tag} || \
    docker pull dosel/zalenium:${zalenium_tag} || \
    docker pull dosel/zalenium:${zalenium_tag}

    [ -z "${dosel_tag}" ] && dosel_tag="${zalenium_tag}"
    # https://github.com/elgalu/docker-selenium
    docker pull elgalu/selenium:${dosel_tag} || \
    docker pull elgalu/selenium:${dosel_tag} || \
    docker pull elgalu/selenium:${dosel_tag}
}

function usage() {
    echo "Usage:"
    echo ""
    echo "$0"
    echo -e "\t -h, --help\t\t\tPrint usage"
    echo ""
    echo -e "\t Start/stop:"
    echo ""
    echo -e "\t start, -s, --start\t\tStart Zalenium"
    echo -e "\t stop, --stop\t\t\tStop Zalenium"
    echo -e "\t -i, --interactive\t\t\tAttach to current process (default detached)"
    echo -e "\t --docker-opt\t\t\tCustom Zalenium docker startup options"
    echo -e "\t --force-docker-opts\t\tOverwrite the default Zalenium docker startup options"
    #echo -e "\t -u ." //TODO: define upgrade mechanism
    echo ""
    echo -e "\t Tests:"
    echo ""
    echo -e "\t --desiredContainers\t\tNumber of nodes/containers created on startup. Default is 2."
    echo -e "\t --maxDockerSeleniumContainers\tMax number of docker-selenium containers running at the same time (default 10)"
    echo -e "\t --sauceLabsEnabled\t\tDetermines if the Sauce Labs node is started (default true)"
    echo -e "\t --videoRecordingEnabled\tRecord video of tests (default true)"
    echo -e "\t --videos-dir\tDirectory where to store videos (default /tmp/videos)"
    echo -e "\t --screenWidth\t\t\tSets the screen width (default 1900)"
    echo -e "\t --screenHeight\t\t\tSets the screen height (default 1800)"
    echo -e "\t --timeZone\t\t\tSets the time zone in the containers (default \"Europe/Berlin\")"
    echo -e "\t --sendAnonymousUsageInfo\t\t\tCollects anonymous usage of the tool. Defaults to 'true'"
    echo -e "\t --debugEnabled\t\t\tenables LogLevel.FINE. Defaults to 'false'"
    echo -e "\t --seleniumImageName\t\t\tenables overriding of the Docker selenium image to use. Defaults to \"elgalu/selenium\""
    echo -e "\t --maxTestSessions\t\t\max amount of tests executed per container, defaults to '1'."
    echo -e "\t --keepOnlyFailedTests\t\t\Keeps only videos of failed tests (you need to send a cookie). Defaults to 'false'"
    echo ""

    echo ""
    echo -e "\t Examples:"
    echo ""
    echo -e "\t - Starting Zalenium with 2 nodes/containers and without Sauce Labs"
    echo -e "\t start --desiredContainers 2 --sauceLabsEnabled false"
    echo -e "\t - Starting Zalenium screen width 1440 and height 810, time zone \"America/Montreal\""
    echo -e "\t start --screenWidth 1440 --screenHeight 810 --timeZone \"America/Montreal\""
}

#----------
# Defaults
#----------
upgrade_if_needed="false"
we_have_sudo="true"
start_it="false"
stop_it="false"
zalenium_tag="latest"
deprecated_parameters="false"

# Overwrite defaults in certain peculiar environments
if [ "${TOOLCHAIN_LOOKUP_REGISTRY}" != "" ]; then
    upgrade_if_needed="true"
    we_have_sudo="false"
fi

#---------------------
# Parse CLI arguments
#---------------------
while [ "$1" != "" ]; do
    # PARAM="$(echo $1)"
    PARAM="$1"
    case ${PARAM} in
        -h | --help)
            usage
            exit 0
            ;;
        --upgrade_if_needed)
            upgrade_if_needed="true"
            ;;
        --upd)
            upgrade_if_needed="true"
            ;;
        upd)
            upgrade_if_needed="true"
            ;;
        -u)
            upgrade_if_needed="true"
            ;;
        u)
            upgrade_if_needed="true"
            ;;
        no-sudo)
            we_have_sudo="false"
            ;;
        --no-sudo)
            we_have_sudo="false"
            ;;
         -i | --interactive)
            INTERACTIVE="true"
            ;;
        --docker-opt)
            CUSTOM_DOCKER_OPTS="${CUSTOM_DOCKER_OPTS} ${2}"
            shift
            ;;
        --force-docker-opts)
            FORCED_DOCKER_OPTS="${FORCED_DOCKER_OPTS} ${2}"
            shift
            ;;
        --start)
            start_it="true"
            ;;
        start)
            start_it="true"
            ;;
        -s)
            start_it="true"
            ;;
        s)
            start_it="true"
            ;;
        --stop)
            stop_it="true"
            ;;
        stop)
            stop_it="true"
            ;;
        --desiredContainers)
            deprecated_parameters="false"
            DESIRED_CONTAINERS_START_COUNT="${2}"
            shift
            ;;
        --chromeContainers)
            echo "Using DEPRECATED --chromeContainers parameter, will fallback to --desiredContainers with the sum of Chrome and Firefox."
            deprecated_parameters="true"
            CHROME_START_COUNT="${2}"
            shift
            ;;
        --firefoxContainers)
            echo "Using DEPRECATED --firefoxContainers parameter, will fallback to --desiredContainers with the sum of Chrome and Firefox."
            deprecated_parameters="true"
            FIREFOX_START_COUNT="${2}"
            shift
            ;;
        --maxDockerSeleniumContainers)
            MAX_CONTAINERS_COUNT="${2}"
            shift
            ;;
        --screenWidth)
            SCREEN_WIDTH="${2}"
            shift
            ;;
        --screenHeight)
            SCREEN_HEIGHT="${2}"
            shift
            ;;
        --videoRecordingEnabled)
            VIDEO="${2}"
            shift
            ;;
        --videos-dir)
            VIDEOS_DIR="${2}"
            shift
            ;;
        --timeZone)
            TIME_ZONE="${2}"
            shift
            ;;
        --debugEnabled)
            DEBUG_ENABLED="${2}"
            shift
            ;;
        --debugEnabled)
            DEBUG_ENABLED="${2}"
            shift
            ;;
        --seleniumImageName)
            SELENIUM_IMAGE_NAME="${2}"
            shift
            ;;
        --maxTestSessions)
            MAX_TEST_SESSIONS="${2}"
            shift
            ;;
        --keepOnlyFailedTests)
            KEEP_ONLY_FAILED_TESTS="${2}"
            shift
            ;;
        --sendAnonymousUsageInfo)
            SEND_ANONYMOUS_USAGE_INFO="${2}"
            shift
            ;;
        3)
            zalenium_tag="3"
            ;;
        2)
            echo "Unsupported version 2 so falling back to Selenium 3"
            zalenium_tag="3"
            ;;
        3*)
            echo "Will use zalenium:${PARAM} and docker-selenium:3"
            zalenium_tag="${PARAM}"
            dosel_tag="3"
            ;;
        2*)
            zalenium_tag="$1"
            echo "Will use zalenium:${zalenium_tag}"
            ;;
        *)
            echo "ERROR: unknown parameter \"${PARAM}\""
            usage
            exit 10
            ;;
    esac
    shift 1
done

trap ShutDownZalenium SIGTERM SIGINT

if [ "${stop_it}" == "true" ]; then
    ShutDownZalenium
fi

if [ "${upgrade_if_needed}" == "true" ]; then
    checking_and_or_updating="Checking and updating"
else
    checking_and_or_updating="Checking"
fi

CheckDependencies
if [ "${PULL_DEPENDENCIES}" != "false" ]; then
    PullDependencies
fi

if [ "${start_it}" == "true" ]; then
    EnsureCleanEnv
    StartZalenium
fi
