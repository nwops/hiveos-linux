#!/usr/bin/env bash

function miner_fork() {
	local MINER_FORK=$XMR_STAK_FORK
	[[ -z $MINER_FORK ]] && MINER_FORK=$MINER_DEFAULT_FORK

	echo $MINER_FORK
}


function miner_ver() {
	if [[ $MINER_FORK == "fireice-uk" ]]; then
		echo $MINER_LATEST_VER_FIREICE_UK
	elif [[ $MINER_FORK == "indeedminers" ]]; then
		echo $MINER_LATEST_VER_INDEEDMINERS
	fi
}


function miner_config_echo() {
	export MINER_FORK=`miner_fork`
	local MINER_VER=`miner_ver`
	miner_echo_config_file "$MINER_DIR/$MINER_FORK/$MINER_VER/config.txt"
	miner_echo_config_file "$MINER_DIR/$MINER_FORK/$MINER_VER/pools.txt"
	miner_echo_config_file "$MINER_DIR/$MINER_FORK/$MINER_VER/amd.txt"
	miner_echo_config_file "$MINER_DIR/$MINER_FORK/$MINER_VER/nvidia.txt"
	miner_echo_config_file "$MINER_DIR/$MINER_FORK/$MINER_VER/cpu.txt"
}


function miner_config_gen() {
	[[ -z $XMR_STAK_PASS ]] && XMR_STAK_PASS="x"

	local MINER_CONFIG="$MINER_DIR/$MINER_FORK/$MINER_VER/config.txt"
	mkfile_from_symlink $MINER_CONFIG

	local POOLS_CONFIG="$MINER_DIR/$MINER_FORK/$MINER_VER/pools.txt"
	mkfile_from_symlink $POOLS_CONFIG

	local AMD_CONFIG="$MINER_DIR/$MINER_FORK/$MINER_VER/amd.txt"
	mkfile_from_symlink $AMD_CONFIG

	local NVIDIA_CONFIG="$MINER_DIR/$MINER_FORK/$MINER_VER/nvidia.txt"
	mkfile_from_symlink $NVIDIA_CONFIG

	local CPU_CONFIG="$MINER_DIR/$MINER_FORK/$MINER_VER/cpu.txt"
	mkfile_from_symlink $CPU_CONFIG

	conf=`cat $MINER_DIR/$MINER_FORK/$MINER_VER/config_global.json`

	currency=""
	case `jq -r '."xmr-stak".coin' <<< $META` in
		AEON )
			currency='"currency" : "aeon7"'
		;;
		BBS )
			currency='"currency" : "bbscoin"'
		;;
		CROAT )
			currency='"currency" : "croat"'
		;;
		EDL )
			currency='"currency" : "edollar"'
		;;
		ETN )
			currency='"currency" : "electroneum"'
		;;
		GRFT )
			currency='"currency" : "graft"'
		;;
		XHV )
			currency='"currency" : "haven"'
		;;
		ITNS )
			currency='"currency" : "intense"'
		;;
		KRB )
			currency='"currency" : "karbo"'
		;;
		XMR )
			currency='"currency" : "monero7"'
		;;
		XTL )
			currency='"currency" : "stellite"'
		;;
		SUMO )
			currency='"currency" : "sumokoin"'
		;;
		TRTL )
			currency='"currency" : "turtlecoin"'
		;;
		# * )
		# 	currency='"currency" : "'$XMR_STAK_ALGO'"'
		# ;;
	esac
	[[ ! -z $currency ]] && conf=$(jq -s '.[0] * .[1]' <<< "$conf {$currency}")

	#merge user config options into main config
	if [[ ! -z $XMR_STAK_USER_CONFIG ]]; then
		while read -r line; do
			[[ -z $line ]] && continue
			conf=$(jq -s '.[0] * .[1]' <<< "$conf {$line}")
		done <<< "$XMR_STAK_USER_CONFIG"
	fi

	pools='[]'
	#this is undocumented, but we will use this own feature
	use_tls=$(jq -r .use_tls <<< "$conf")
	[[ -z $use_tls || $use_tls == "null" ]] && use_tls="false"

	for url in $XMR_STAK_URL
	do
		grep -q "nicehash.com" <<< $XMR_STAK_URL
		[[ $? -eq 0 ]] && nicehash="true" || nicehash="false"
		pool=$(cat <<EOF
				{"pool_address": "$url", "wallet_address": "$XMR_STAK_TEMPLATE", "pool_password": "$XMR_STAK_PASS", "use_nicehash": $nicehash, "use_tls": $use_tls, "tls_fingerprint": "", "pool_weight": 1, "rig_id": "$WORKER_NAME" }
EOF
	)
		pools=`jq --null-input --argjson pools "$pools" --argjson pool "$pool" '$pools + [$pool]'`
	done

	if [[ -z $pools || $pools == '[]' || $pools == 'null' ]]; then
		echo -e "${RED}No pools configured, using default${NOCOLOR}"
	else
		#Don't remove until Hive 1 is gone
		#pass can also contain %var%
		[[ ! -z $EWAL ]] && pools=${pools/\%EWAL\%/$EWAL}
		[[ ! -z $ZWAL ]] && pools=${pools/\%ZWAL\%/$ZWAL}
		[[ ! -z $DWAL ]] && pools=${pools/\%DWAL\%/$DWAL}
		[[ ! -z $EMAIL ]] && pools=${pools/\%EMAIL\%/$EMAIL}
		[[ ! -z $WORKER_NAME ]] && pools=${pools/\%WORKER_NAME\%/$WORKER_NAME} || echo -e "${YELLOW}WORKER_NAME not set${NOCOLOR}";
		[[ ! -z $XMR_STAK_ALGO ]] && pools=${pools/\%XMR_STAK_ALGO\%/$XMR_STAK_ALGO}
		[[ ! -z $MINER_API_PORT ]] && pools=${pools/\%MINER_API_PORT\%/$MINER_API_PORT}

		pools=`jq --null-input --argjson pool_list "$pools" '{$pool_list}'`
		conf=$(jq -s '.[0] * .[1]' <<< "$conf $pools")
	fi


	#amd nvidia cpu overrides or default
	#[[ ! -z $XMR_STAK__AMD ]] &&
	echo "$XMR_STAK_AMD" > $AMD_CONFIG
	#[[ ! -z $XMR_STAK__NVIDIA ]] &&
	echo "$XMR_STAK_NVIDIA" > $NVIDIA_CONFIG
	#[[ ! -z $XMR_STAK__CPU ]] &&
	echo "$XMR_STAK_CPU" > $CPU_CONFIG

	#delete { and } lines
	echo $conf | jq . | sed 1d | sed '$d' > $MINER_CONFIG
	echo $conf | jq . | sed 1d | sed '$d' > $POOLS_CONFIG
}
