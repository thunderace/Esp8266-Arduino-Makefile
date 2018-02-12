
#!/usr/bin/env bash

function build_sketches()
{
    #set +e
    local srcpath=$1
    local build_arg=$2
    
    local makefiles=$(find $srcpath -name Makefile*)
    echo $makefiles
    for makefile in $makefiles; do
        local dir=`dirname "$makefile"`;
        local file=`basename "$makefile"`;
        
        local build_cmd="cd `dirname \"$makefile\"` && make -f `basename \"$makefile\"` ESP8266_VERSION=$build_arg"
        echo $build_cmd
        $build_cmd clean
        time ($build_cmd >build.log)
        local result=$?
        if [ $result -ne 0 ]; then
            echo "Build failed ($1)"
            echo "Build log:"
            cat build.log
            set -e
            return $result
        fi
        rm build.log
    done
    #set -e
}

function install_cores()
{
    wget -O https://github.com/esp8266/Arduino/releases/download/2.3.0/esp8266-2.3.0.zip
    unzip esp8266-2.3.0.zip
    cp -R bin/package esp8266
    cd esp8266-2.3.0/tools
    python get.py
    #export PATH="$ide_path:$core_path/tools/xtensa-lx106-elf/bin:$PATH"
    git clone https://github.com/esp8266/Arduino.git esp8266.git
    cd esp8266;GIT/tools
    python get.py
}

set -e

build_sketches ../example/esp8266 -2.3.0
build_sketches ../example/esp8266 .git
