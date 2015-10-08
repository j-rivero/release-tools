# TODO: run inside docker as a normal user and replace the sudo calls
# This are usually for debbuilders
sudo rm -fr ${WORKSPACE}/pkgs
sudo mkdir -p ${WORKSPACE}/pkgs
# This are usually for continous integration jobs
sudo rm -fr ${WORKSPACE}/build
sudo mkdir -p ${WORKSPACE}/build

# Need to map timing dir into the docker container
timing_mapping_str=""
if $ENABLE_TIMING; then
  timing_mapping_str="-v ${TIMING_DIR}:${TIMING_DIR}"
fi

sudo docker build -t ${DOCKER_TAG} .
stop_stopwatch CREATE_TESTING_ENVIROMENT

echo '# BEGIN SECTION: see build.sh script'
cat build.sh
echo '# END SECTION'

if $USE_GPU_DOCKER; then
  GPU_PARAMS_STR="--privileged \
                  -e DISPLAY=unix$DISPLAY \
		          -v /sys:/sys:ro         \
                  -v /tmp/.X11-unix:/tmp/.X11-unix:rw"
fi

sudo docker run $GPU_PARAMS_STR  \
            --cidfile=${CIDFILE} \
            -v ${WORKSPACE}/pkgs:${WORKSPACE}/pkgs \
            -v ${WORKSPACE}/build:${WORKSPACE}/build \
	        $timing_mapping_str \
            -t ${DOCKER_TAG} \
            /bin/bash build.sh

CID=$(cat ${CIDFILE})

sudo docker stop ${CID} || true
sudo docker rm ${CID} || true

# Export results out of build directory, to WORKSPACE
for d in $(find ${WORKSPACE}/build -name '*_results' -type d); do
    sudo mv ${d} ${WORKSPACE}/
    sudo chown -R jenkins ${WORKSPACE}/*_results
done

if [[ -z ${KEEP_WORKSPACE} ]]; then
    # Clean the whole build directory
    sudo rm -fr ${WORKSPACE}/build
    # Mimic old layout of exported test results
    mkdir ${WORKSPACE}/build
    for d in $(find ${WORKSPACE} -name '*_results' -type d); do
       sudo mv ${d} ${WORKSPACE}/build/
    done
    
    chown jenkins -R ${WORKSPACE}/build/
fi
