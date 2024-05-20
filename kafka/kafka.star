def run(plan):
    zookeeper = plan.add_service(
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
    zookeeper_uri = "{0}:{1}".format(zookeeper.ip_address, zookeeper.ports["zookeeper"].number)

    broker = plan.add_service(
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
                "KAFKA_ZOOKEEPER_CONNECT": zookeeper_uri,
                "KAFKA_MESSAGE_MAX_BYTES": "2000000",
                "KAFKA_CREATE_TOPICS": "tweet:1:1,weather:1:1,twittersink:1:1",
            },
        ),
    )
    broker_uri = "{0}:{1}".format(broker.ip_address, broker.ports["broker"].number)

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
                "ZK_HOSTS": zookeeper_uri,
                "APPLICATION_SECRET": "random-secret",
                "KAFKA_MANAGER_AUTH_ENABLED": "true",
                "KAFKA_MANAGER_USERNAME": "admin",
                "KAFKA_MANAGER_PASSWORD": "smellycat",
            },
        ),
    )

    # add kafka connect
    connector_setup_cmds = [
        "curl -s -O -L https://downloads.datastax.com/kafka/kafka-connect-cassandra-sink.tar.gz",
        "mkdir datastax-connector",
        "tar xzf kafka-connect-cassandra-sink.tar.gz -C datastax-connector --strip-components=1",
        "mv datastax-connector/kafka-connect* datastax-connector/kafka-connect-cassandra.jar",
    ]
    result = plan.run_sh(
        run=" &&".join(connector_setup_cmds),
        store=[StoreSpec(
            src="datastax-connector/kafka-connect-cassandra.jar",
            name="kafka-connect-cassandra-artifact",
        )],
    )
    plan.print(result)

    plan.add_service(
        name="kafka-connect",
        config=ServiceConfig(
            image="confluentinc/cp-kafka-connect-base:latest",
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
                "CONNECT_BOOTSTRAP_SERVERS": "broker:9092",    #broker_uri
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
                "CONNECT_ZOOKEEPER_CONNECT": "zookeeper:2181", #zookeeper_uri
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
    twitter_response = plan.request(
        service_name = "kafka-connect",
        recipe = PostHttpRequestRecipe(
            port_id="connect",
            endpoint="/connectors",
            body=json.encode(twitter_body),
        ),
    )
    plan.print(twitter_response)
    
    # Start Weather sink
    weather_response = plan.request(
        service_name = "kafka-connect",
        recipe = PostHttpRequestRecipe(
            port_id="connect",
            endpoint="/connectors",
            body=json.encode(weather_body),
        ),
    )
    plan.print(weather_response)

    return broker_uri

twitter_body = {
    "name": "twittersink",
    "config":{
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
      "topic.twittersink.kafkapipeline.twitterdata.consistencyLevel": "LOCAL_QUORUM"
    }
}

weather_body = {
  "name": "weathersink",
  "config": {
    "connector.class": "com.datastax.oss.kafka.sink.CassandraSinkConnector",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",  
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable":"false",
    "tasks.max": "10",
    "topics": "weather",
    "contactPoints": "cassandradb",
    "loadBalancing.localDc": "datacenter1",
    "topic.weather.kafkapipeline.weatherreport.mapping": "location=value.location, forecastdate=value.report_time, description=value.description, temp=value.temp, feels_like=value.feels_like, temp_min=value.temp_min, temp_max=value.temp_max, pressure=value.pressure, humidity=value.humidity, wind=value.wind, sunrise=value.sunrise, sunset=value.sunset",
    "topic.weather.kafkapipeline.weatherreport.consistencyLevel": "LOCAL_QUORUM"
  }
}