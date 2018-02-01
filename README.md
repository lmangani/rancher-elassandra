# rancher-elassandra
Docker Elassandra with Rancher Support

# Image
```
qxip/rancher-elassandra
```

## Example
```
version: '2'
services:      
  CassandraSeed:
    environment:
      RANCHER_ENABLE: 'true'
      RANCHER_SEED_SERVICE: CassandraSeed
      CASSANDRA_RACK: 'rack1'
      CASSANDRA_DC: aws-us-east
      CASSANDRA_ENDPOINT_SNITCH: GossipingPropertyFileSnitch
    labels:
      io.rancher.container.pull_image: always
    tty: true
    image: qxip/rancher-elassandra:latest
    stdin_open: true
    volumes:
      - /var/lib/cassandra
  Cassandra2:
    environment:
      RANCHER_ENABLE: 'true'
      RANCHER_SEED_SERVICE: CassandraSeed
      CASSANDRA_RACK: 'rack2'
      CASSANDRA_DC: aws-us-east
      CASSANDRA_ENDPOINT_SNITCH: GossipingPropertyFileSnitch
    labels:
      io.rancher.container.pull_image: always
    tty: true
    image: qxip/rancher-elassandra:latest
    stdin_open: true
    volumes:
      - /var/lib/cassandra
  Cassandra3:
    environment:
      RANCHER_ENABLE: 'true'
      RANCHER_SEED_SERVICE: CassandraSeed
      CASSANDRA_RACK: 'rack3'
      CASSANDRA_DC: aws-us-east
      CASSANDRA_ENDPOINT_SNITCH: GossipingPropertyFileSnitch
    labels:
      io.rancher.container.pull_image: always
    tty: true
    image: qxip/rancher-elassandra:latest
    stdin_open: true
    volumes:
      - /var/lib/cassandra
```

### Test
```
# nodetool status
Datacenter: aws-us-east
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address       Load       Tokens       Owns (effective)  Host ID                  Rack
UN  10.42.246.43  92.79 KiB  8            36.0%             9b5600de-7382-49ce-9684-18631f9288ef  rack1
UN  10.42.127.17  106 KiB    8            34.3%             14b872e7-81f5-4adb-9930-336eb244b200  rack2
UN  10.42.139.21  128.99 KiB  8            29.7%             8d8702be-6ec8-4a0f-a328-44e4fed222cf  rack3
```
