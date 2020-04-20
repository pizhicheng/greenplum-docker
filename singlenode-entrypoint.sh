#!/bin/bash


# check to see if this file is being run or sourced from another script
_is_sourced() {
    # https://unix.stackexchange.com/a/215279
    [ "${#FUNCNAME[@]}" -ge 2 ] \
        && [ "${FUNCNAME[0]}" = '_is_sourced' ] \
        && [ "${FUNCNAME[1]}" = 'source' ]
}

docker_setup_env() {
    declare -g DATA_DIR=${DATA_DIR=/data/greenplum/gpmaster}
    declare -g MIRROR_DIR=${MIRROR_DIR=/data/greenplum/gpdata}
    declare -g MASTER_DIR=${MASTER_DIR=/data/greenplum/gpmirror}
    declare -g USER_NAME=${USER_NAME=gpadmin}
    declare -g USER_PASSWORD=${USER_PASSWORD=gpadmin}

    declare -g DATABASE_ALREADY_EXISTS
    if [[ -f ${MASTER_DATA_DIRECTORY}/pg_hba.conf ]]; then
        echo "File already exists:"
        echo "$PGDATA/PG_VERSION"
        DATABASE_ALREADY_EXISTS='true'
    fi

    sysctl -p
    hostname mdw

}

docker_process_init_files() {
    echo "install udf and extension"
    . /opt/greenplum-db-6.0.1/greenplum_path.sh
    export PGPASSWORD=${USER_PASSWORD}
    local f
    for f in `ls ${INIT_DIR}`; do
        case "$f" in
            *.sh)
                if [ -x "$f" ]; then
                    echo "$0: running $f"
                    "$f"
                else
                    echo "$0: sourcing $f"
                    . "$f"
                fi
                ;;
            *.sql)    echo "$0: running $f"; psql postgres -h 127.0.0.1 -U ${USER_NAME} -f "${INIT_DIR}/$f"; echo ;;
            *)        echo "$0: ignoring $f" ;;
        esac
        echo
    done
}

docker_generate_init_file() {
    local segment_number=${SEGMENT_NUMBER}
    local enable_mirror=${ENABLE_MIRROR}
    
    mkdir -p ${DATA_DIR}
    mkdir -p ${MIRROR_DIR}
    mkdir -p ${MASTER_DIR}
    chown -R ${USER_NAME} ${DATA_DIR}
    chown -R ${USER_NAME} ${MIRROR_DIR}
    chown -R ${USER_NAME} ${MASTER_DIR}
    
    host_name=mdw
    p_data=""
    m_data=""
    id=2
    content=0
    #This is master segment. save slave name and address
    #Generate input file and hosts file
    echo "Generating input file"
    for((j=0;j<segment_number;j++)); do
      p_data="${p_data}\n${host_name}~$[6000 + ${j}]~${DATA_DIR}/gpseg${content}~${id}~${content}"
      let content++
      let id++
    done
    input_file="ARRAY_NAME=\"Greenplum Data Platform\"\nTRUSTED_SHELL=ssh\nCHECK_POINT_SEGMENTS=8\nENCODING=unicode\nSEG_PREFIX=gpseg\nHEAP_CHECKSUM=on\nHBA_HOSTNAMES=0\nQD_PRIMARY_ARRAY=${host_name}~5432~${MASTER_DIR}/gpseg-1~1~-1~0\ndeclare -a PRIMARY_ARRAY=(${p_data}\n)\n"
    if [[ ${enable_mirror} = true ]]; then
      content=0
      for((j=0;j<segment_number;j++)); do
        m_data="${m_data}\n${host_name}~$[7000 + ${j}]~${MIRROR_DIR}/gpseg${content}~${id}~${content}"
        let content++
        let id++
      done
      input_file="${input_file}declare -a MIRROR_ARRAY=(${m_data}\n)\n"
    fi
    echo -e ${input_file} > /home/${USER_NAME}/input_file
    chown ${USER_NAME} /home/${USER_NAME}/input_file
}

docker_enable_ssh_auto() {
    service ssh start
    echo "127.0.0.1 mdw" >> /etc/hosts
    su - ${USER_NAME} -s /bin/bash -c "bash /home/${USER_NAME}/ssh_auto.sh -h mdw -u ${USER_NAME} -p ${USER_PASSWORD}"
    su - ${USER_NAME} -s /bin/bash -c ". /opt/greenplum-db-6.0.1/greenplum_path.sh;
export MASTER_DATA_DIRECTORY=${MASTER_DATA_DIRECTORY}
gpssh-exkeys -h mdw;"
}

docker_start_up() {
      su - ${USER_NAME} -c ". /opt/greenplum-db-6.0.1/greenplum_path.sh;
export MASTER_DATA_DIRECTORY=${MASTER_DATA_DIRECTORY}
gpstart -a"
}

docker_stop_database() {
    su - ${USER_NAME} -c ". /opt/greenplum-db-6.0.1/greenplum_path.sh;
export MASTER_DATA_DIRECTORY=${MASTER_DATA_DIRECTORY}
gpstop -af"
}

docker_init_database() {
      su - ${USER_NAME} -s /bin/bash -c ". /opt/greenplum-db-6.0.1/greenplum_path.sh;
export MASTER_DATA_DIRECTORY=${MASTER_DATA_DIRECTORY}
gpinitsystem -I /home/${USER_NAME}/input_file -B 4 -a;
gpconfig -c enable_hashjoin -v off;
gpconfig -c enable_nestloop -v on;
gpconfig -c enable_seqscan -v off;
gpconfig -c optimizer -v off;
gpconfig -c statement_mem -v 1024MB;
gpconfig -c log_statement -v none -m none;
psql postgres -c \"ALTER ROLE ${USER_NAME} PASSWORD '${USER_PASSWORD}'\";
gpstop -u;"
}

docker_enable_hosts() {
    local host_list=(${*})
    for host in ${host_list[*]}; do
      temp_var=`cat ${MASTER_DATA_DIRECTORY}/pg_hba.conf | grep "${host}"`
      if [[ -z ${temp_var} ]]; then
        echo "add host: ${hosts[i]}"
        echo "host all ${USER_NAME} ${host} md5" >> ${MASTER_DATA_DIRECTORY}/pg_hba.conf
      else
        echo "host ${host} already added"
      fi
    done
}


_main() {
    while getopts "n:h:m" opt; do
      case ${opt} in
      n)
        segment_number=${OPTARG}
        ;;
      h)
        hosts=(${hosts[*]} ${OPTARG})
        ;;
      m)
        enable_mirror=true
        ;;
      esac
    done
    declare -g SEGMENT_NUMBER=${segment_number=4}
    declare -g VISIBLE_HOSTS=(${hosts[*]})
    declare -g ENABLE_MIRROR=${enable_mirror=false}
    
    docker_setup_env
    
    docker_enable_ssh_auto
    
    docker_generate_init_file
    
    if [[ ${DATABASE_ALREADY_EXISTS} = 'true' ]]; then
      echo "database is already exists"
      docker_start_up
    else
      echo "init greenplum"
      docker_init_database
    fi

    docker_enable_hosts ${VISIBLE_HOSTS[*]}

    docker_process_init_files
    docker_stop_database
    docker_start_up

}


if ! _is_sourced; then
    _main "$@"

    while true
    do
      sleep 1000;
    done

fi

