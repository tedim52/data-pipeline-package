cassandra = import_module("./cassandra/cassandra.star")
kafka = import_module("./kafka/kafka.star")


def run(plan, args):
    # start cassandra database
    result = cassandra.run(plan)

    # starting kafka
    kafka.run(plan)

    # start zookeeper application

    # start message broker
    # connects to zookeeper

    # start kafka manager
    # - connects to broker
    # - provides a frontend

    # start kafka manager
