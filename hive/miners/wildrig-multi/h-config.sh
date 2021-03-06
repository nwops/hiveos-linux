#!/usr/bin/env bash

function miner_ver() {
        echo $MINER_LATEST_VER
}

function miner_config_echo() {
        local MINER_VER=`miner_ver`
        miner_echo_config_file "$MINER_DIR/$MINER_VER/$MINER_NAME.conf"
}

function miner_config_gen() {
	local MINER_CONFIG="$MINER_DIR/$MINER_VER/$MINER_NAME.conf"
	mkfile_from_symlink $MINER_CONFIG

	[[ -z $WILDRIG_MULTI_TEMPLATE ]] && echo -e "${YELLOW}WILDRIG_MULTI_TEMPLATE is empty${NOCOLOR}" && return 1
	[[ -z $WILDRIG_MULTI_URL ]] && echo -e "${YELLOW}WILDRIG_MULTI_URL is empty${NOCOLOR}" && return 2
	[[ -z $WILDRIG_MULTI_PASS ]] && WILDRIG_MULTI_PASS=x

	# Add wallet template and password
	conf="--user ${WILDRIG_MULTI_TEMPLATE} --pass ${WILDRIG_MULTI_PASS}\n"

	# Add algorithm
	if [ ! -z $WILDRIG_MULTI_ALGO ]; then 
		case $WILDRIG_MULTI_ALGO in
			skunk) wild_algo=skunkhash
			;;
			*)
			wild_algo=$WILDRIG_MULTI_ALGO
		esac
		conf+="--algo=${wild_algo}\n"
	fi

	# Add pool or pools
	pools=""
	for pool_url in $WILDRIG_MULTI_URL; do
		pools+="--url $pool_url "
	done
	conf+="$pools\n"

	# Add general options
	conf+="--api-port ${MINER_API_PORT} --print-full --print-time=60 --print-level=2 --donate-level=1\n"

	# Add user config options
	[[ ! -z $WILDRIG_MULTI_USER_CONFIG ]] && conf+="${WILDRIG_MULTI_USER_CONFIG}"

	#replace tpl values in whole file
	[[ -z $EWAL && -z $ZWAL && -z $DWAL ]] && echo -e "${RED}No WAL address is set${NOCOLOR}"
	[[ ! -z $EWAL ]] && conf=$(sed "s/%EWAL%/$EWAL/g" <<< "$conf")
	[[ ! -z $DWAL ]] && conf=$(sed "s/%DWAL%/$DWAL/g" <<< "$conf")
	[[ ! -z $ZWAL ]] && conf=$(sed "s/%ZWAL%/$ZWAL/g" <<< "$conf")
	[[ ! -z $EMAIL ]] && conf=$(sed "s/%EMAIL%/$EMAIL/g" <<< "$conf")
	[[ ! -z $WORKER_NAME ]] && conf=$(sed "s/%WORKER_NAME%/$WORKER_NAME/g" <<< "$conf") #|| echo "${RED}WORKER_NAME not set${NOCOLOR}"

	echo -e "$conf" > $MINER_CONFIG
}
