#!/bin/bash
set -e

# first arg is `-f` or `--some-option`
if [ "${1:0:1}" = '-' ]; then
	set -- bin/cassandra -f "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'bin/cassandra' -a "$(id -u)" = '0' ]; then
	chown -R cassandra /var/lib/cassandra /var/log/cassandra "$CASSANDRA_CONF"
	exec gosu cassandra "$BASH_SOURCE" "$@"
fi


if [ "$1" = 'bin/cassandra' ]; then
	: ${CASSANDRA_RPC_ADDRESS='0.0.0.0'}

	if [ "$RANCHER_ENABLE" = 'true' ]; then
        echo "-- RANCHER ENABLED"
    
        RANCHER_META=http://rancher-metadata/2015-07-25
        
        if [ "$RANCHER_SEED_SERVICE" = '' ]; then
            echo "RANCHER_SEED_SERVICE envrionment variable does not seem to exist"
            exit 0
        fi
    
        PRIMARY_IP_CHECK=$(curl -s -o /dev/null -w "%{http_code}" $RANCHER_META/self/container/primary_ip)
        NET=managed
        if [ $PRIMARY_IP_CHECK -eq 404 ]; then
            NET=host
        elif [ $PRIMARY_IP_CHECK -eq 200 ]; then
            NET=managed
        else 
            echo "Unable to use http://rancher-metadata/2015-07-25"
            echo "If you are running your docker container in NET=host mode, be sure to enable 'Enable Rancher DNS service discovery'"
            exit 0
        fi

        if [ "$NET" = 'managed' ]; then
            PRIMARY_IP=$(curl --retry 3 --fail --silent $RANCHER_META/self/container/primary_ip)

            : ${RANCHER_SEED_SERVICE:=$(curl --retry 3 --fail --silent $RANCHER_META/self/service/name)}

        else 
            CHECK_CONTAINER_EXISTS=$(curl -s -o /dev/null -w "%{http_code}" $RANCHER_META/services/${RANCHER_SEED_SERVICE}/containers)
            if [ $CHECK_CONTAINER_EXISTS -eq 404 ]; then
                echo "Container ($RANCHER_SEED_SERVICE) specified via env RANCHER_SEED_SERVICE, does not exist"
                exit 0
            fi
        
            PRIMARY_IP=$(curl --retry 3 --fail --silent $RANCHER_META/self/host/agent_ip)
        fi
        
        echo "-- NETWORK ($NET) WITH SEED SERVICE: $RANCHER_SEED_SERVICE"
        
        CASSANDRA_LISTEN_ADDRESS=$PRIMARY_IP
        CASSANDRA_BROADCAST_ADDRESS=$CASSANDRA_LISTEN_ADDRESS
        CASSANDRA_BROADCAST_RPC_ADDRESS=$CASSANDRA_BROADCAST_ADDRESS
        
        containers="$(curl --retry 3 --fail --silent $RANCHER_META/services/${RANCHER_SEED_SERVICE}/containers)"
        readarray -t containers_array <<<"$containers"

        for i in "${containers_array[@]}"
        do
            container_name="$(curl --retry 3 --fail --silent $RANCHER_META/services/${RANCHER_SEED_SERVICE}/containers/$i)"
            container_ip="$(curl --retry 3 --fail --silent $RANCHER_META/containers/$container_name/primary_ip)"

            if [ -z "$CASSANDRA_SEEDS" ]; then
                CASSANDRA_SEEDS="$container_ip"
            else
                CASSANDRA_SEEDS="$CASSANDRA_SEEDS,$container_ip"
            fi
        done
        
        echo "-- PRIMARY IP: $PRIMARY_IP"
        
	else
		: ${CASSANDRA_LISTEN_ADDRESS='auto'}
		if [ "$CASSANDRA_LISTEN_ADDRESS" = 'auto' ]; then
			CASSANDRA_LISTEN_ADDRESS="$(hostname --ip-address)"
		fi

		: ${CASSANDRA_BROADCAST_ADDRESS="$CASSANDRA_LISTEN_ADDRESS"}

		if [ "$CASSANDRA_BROADCAST_ADDRESS" = 'auto' ]; then
			CASSANDRA_BROADCAST_ADDRESS="$(hostname --ip-address)"
		fi
		: ${CASSANDRA_BROADCAST_RPC_ADDRESS:=$CASSANDRA_BROADCAST_ADDRESS}

		if [ -n "${CASSANDRA_NAME:+1}" ]; then
			: ${CASSANDRA_SEEDS:="cassandra"}
		fi
	fi

	: ${CASSANDRA_SEEDS:="$CASSANDRA_BROADCAST_ADDRESS"}

    echo "-- SEEDS FOUND: $CASSANDRA_SEEDS"
	sed -ri 's/(- seeds:) "[0-9\.,]+"/\1 "'"$CASSANDRA_SEEDS"'"/' "$CASSANDRA_CONF/cassandra.yaml"

	for yaml in \
		broadcast_address \
		broadcast_rpc_address \
		cluster_name \
		endpoint_snitch \
		listen_address \
		num_tokens \
		rpc_address \
		start_rpc \
	; do
		var="CASSANDRA_${yaml^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^(# )?('"$yaml"':).*/\2 '"$val"'/' "$CASSANDRA_CONF/cassandra.yaml"
		fi
	done

	echo "-- REPLACING SNITCH"
	sed -ri 's/^endpoint_snitch.*/endpoint_snitch: GossipingPropertyFileSnitch/' "$CASSANDRA_CONF/cassandra-rackdc.properties"

	for rackdc in dc rack; do
		var="CASSANDRA_${rackdc^^}"
		val="${!var}"
		if [ "$val" ]; then
			sed -ri 's/^('"$rackdc"'=).*/\1 '"$val"'/' "$CASSANDRA_CONF/cassandra-rackdc.properties"
		fi
	done
fi

exec "$@"
