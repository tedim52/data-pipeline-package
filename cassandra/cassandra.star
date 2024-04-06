def run(plan):
    keyspace_script = read_file(src="./keyspace.cql")
    keyspace_artifact = plan.render_templates(
        config={"keyspace.cql": struct(template=keyspace_script, data={})},
        name="keyspace-artifact",
    )

    schema_script = read_file(src="./schema.cql")
    schema_script = plan.render_templates(
        config={
            "schema.cql": struct(template=schema_script, data={}),
        },
        name="schema-artifact",
    )

    cassandra = plan.add_service(
        name="cassandra",
        config=ServiceConfig(
            image="cassandra:4.0",
            ports={
                "cluster": PortSpec(number=7000, transport_protocol="TCP"),
                "client": PortSpec(number=9042, transport_protocol="TCP"),
            },
            env_vars={
                "CASSANDRA_SEEDS": "cassandra,",
                # without this set Cassandra tries to take 8G and OOMs
                "MAX_HEAP_SIZE": "512M",
                "HEAP_NEWSIZE": "1M",
            },
            files={
                "/var/lib/cassandra": Directory(persistent_key="db"),
                "/opt/scripts/": Directory(
                    artifact_names=[keyspace_artifact, schema_script]
                ),
            },
        ),
    )

    # setup keyspace and database schema
    keyspace_setup_result = plan.exec(
        service_name="cassandra",
        recipe=ExecRecipe(command=["cqlsh", "-f", "/opt/scripts/keyspace.cql"]),
    )
    # TODO: verify success
    plan.print(keyspace_setup_result)
    schema_setup_result = plan.exec(
        service_name="cassandra",
        recipe=ExecRecipe(command=["cqlsh", "-f", "/opt/scripts/schema.cql"]),
    )
    # TODO: verify success
    plan.print(schema_setup_result)

    # TODO: return information useful downstream
    return cassandra
