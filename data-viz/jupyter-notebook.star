

def run(plan, cassandra_info):
    plan.add_service(
        name="dataviz",
        config=ServiceConfig(
            image=ImageBuildSpec(
                image_name="dataviz:latest",
                build_context_dir=".",
            ),
            ports = {
                "notebook": PortSpec(
                    number=8888,
                    transport_protocol="TCP",
                    application_protocol="http",
                )
            },
            env_vars={
                "CASSANDRA_HOST": cassandra_info.uri,
                "CASSANDRA_KEYSPACE": cassandra_info.keyspace_name,
                "WEATHER_TABLE": cassandra_info.weather_table,
                "TWITTER_TABLE": cassandra_info.twitter_table,
            },
            files={
                "/usr/app/": Directory(persistent_key="data-vis"), # persist data vis data
            }
        )
    )