def run(plan):
    plan.add_service(
        name="zookeeper",
        config=ServiceConfig(
            image="zookeeper",
            ports={
                "zookeeper": PortSpec(
                    number=2181,
                    transport_protocol="TCP",
                )
            },
            env_vars={"ZOO_MY_ID": "1"},
        ),
    )

    plan.add_service(
        name="broker",
        config=ServiceConfig(
            image="wurstmeister/kafka",
            ports={
                "broker": PortSpec(
                    number=9092,
                    transport_protocol="TCP",
                )
            },
            env_vars={
                "KAFKA_ADVERTISED_HOST_NAME": "broker",
                "KAFKA_ZOOKEEPER_CONNECT": "zookeeper:2181",  # TODO: refactor to be uri taken off zookeeper service
                "KAFKA_MESSAGE_MAX_BYTES": "2000000",
                "KAFKA_CREATE_TOPICS": "tweet:1:1,weather:1:1,twittersink:1:1",
            },
        ),
    )

    # add kafka manager
    plan.add_service(
        name="kafka-manager",
        config=ServiceConfig(
            image="hlebalbau/kafka-manager:stable",
            cmd=["bash", "-c", "-Dpidfile.path=/dev/null"],
            ports={
                "dashboard": PortSpec(
                    number=9000,
                    transport_protocol="TCP",
                    application_protocol="http",
                )
            },
            env_vars={
                "ZK_HOSTS": "zookeeper:2181",  # TODO: refactor to be uri taken off zookeeper service
                "APPLICATION_SECRET": "random-secret",
                "KAFKA_MANAGER_AUTH_ENABLED": "true",
                "KAFKA_MANAGER_USERNAME": "admin",
                "KAFKA_MANAGER_PASSWORD": "smellycat",
            },
        ),
    )

    # add kafka connect
    connector_setup_cmds = [
        "curl -O -L https://downloads.datastax.com/kafka/kafka-connect-cassandra-sink.tar.gz",
        "mkdir datastax-connector",
        "tar xzf kafka-connect-cassandra-sink.tar.gz -C datastax-connector --strip-components=1",
        "mv datastax-connector/kafka-connect* datastax-connector/kafka-connect-cassandra.jar",
    ]
    plan.run_sh(
        run=connector_setup_cmds.join(" &&"),
        store=StoreSpec(
            src="datastax-connector/kafka-connect-cassandra.jar",
            name="kafka-connect-cassandra-artifact",
        ),
    )
    plan.add_service(
        name="kafka-connect",
        config=ServiceConfig(
            image="confluentinc/cp-kafka-connect-base:5.3.0",
            ports={
                "connect": PortSpec(
                    number=8083,
                    transport_protocol="TCP",
                    application_protocol="http",
                ),
            },
            files={
                "/datastax-connector/kafka-connect-cassandra.jar": "kafka-connect-cassandra-artifact",
            },
            env_vars={
                "CONNECT_PLUGIN_PATH": "/usr/share/java,/datastax-connector/kafka-connect-cassandra.jar",
                "CONNECT_BOOTSTRAP_SERVERS": "broker:9092",
                "CONENCT_OFFSET_STORAGE_REPLICATION_FACTOR": "1",
                "CONNECT_KEY_CONVERTER": "org",
                "CONNECT_BOOTSTRAP_SERVERS": "broker:9092",
                "CONNECT_REST_ADVERTISED_HOST_NAME": "kafka-connect",
                "CONNECT_REST_PORT": "8083",
                "CONNECT_GROUP_ID": "kafka-connect-group",
                "CONNECT_CONFIG_STORAGE_TOPIC": "docker-connect-configs",
                "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR": "1",
                "CONNECT_OFFSET_FLUSH_INTERVAL_MS": "10000",
                "CONNECT_OFFSET_STORAGE_TOPIC": "docker-connect-offsets",
                "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR": "1",
                "CONNECT_STATUS_STORAGE_TOPIC": "docker-connect-status",
                "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR": "1",
                "CONNECT_KEY_CONVERTER": "org.apache.kafka.connect.storage.StringConverter",
                "CONNECT_VALUE_CONVERTER": "org.apache.kafka.connect.json.JsonConverter",
                "CONNECT_VALUE_CONVERTER_SCHEMAS_ENABLE": "false",
                "CONNECT_INTERNAL_KEY_CONVERTER": "org.apache.kafka.connect.json.JsonConverter",
                "CONNECT_INTERNAL_VALUE_CONVERTER": "org.apache.kafka.connect.json.JsonConverter",
                "CONNECT_ZOOKEEPER_CONNECT": "zookeeper:2181",
            },
            ready_conditions=ReadyCondition(
                recipe=GetHttpRequestRecipe(
                    port_id="connect",
                    endpoint="/connectors",
                ),
                field="code",
                assertion="==",
                target_value=200,
            ),
        ),
    )

    # Start Twitter sink
    plan.request()
    http_response = plan.request(
    service_name = "kafka-connect",
    # The recipe that will determine the request to be performed.
    # Valid values are of the following types: (GetHttpRequestRecipe, PostHttpRequestRecipe)
    # MANDATORY
    recipe = PostHttpRequestRecipe(
        port_id="connect",
        body="{
  "name": "twittersink",
  "config":{{
    "connector.class": "com.datastax.oss.kafka.sink.CassandraSinkConnector",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",  
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable":"false",
    "tasks.max": "10",
    "topics": "twittersink",
    "contactPoints": "cassandradb",
    "loadBalancing.localDc": "datacenter1",
    "topic.twittersink.kafkapipeline.twitterdata.mapping": "location=value.location, tweet_date=value.datetime, tweet=value.tweet, classification=value.classification",
    "topic.twittersink.kafkapipeline.twitterdata.consistencyLevel": "LOCAL_QUORUM"}}
  }"
  ),
    
    # If the recipe returns a code that does not belong on this list, this instruction will fail.
    # OPTIONAL (Defaults to [200, 201, ...])
    acceptable_codes = [200, 500], # Here both 200 and 500 are valid codes that we want to accept and not fail the instruction
    
    # If False, instruction will never fail based on code (acceptable_codes will be ignored).
    # You can chain this call with assert to check codes after request is done.
    # OPTIONAL (defaults to False)
    skip_code_check = false,

    # A human friendly description for the end user of the package
    # OPTIONAL (Default: Running 'REQUEST_TYPE' request on service 'SERVICE_NAME')
    description = "making a request"
)
plan.print(get_response["body"]) # Prints the body of the request
plan.print(get_response["code"]) # Prints the result code of the request (e.g. 200, 500)
plan.print(get_response["extract.extracted-field"]) # Prints the result of running ".name.id" query, that is saved with key "extracted-field"
    # Start Weather sink 
