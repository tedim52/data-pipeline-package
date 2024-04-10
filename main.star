cassandra = import_module("./cassandra/cassandra.star")
kafka = import_module("./kafka/kafka.star")
producers = import_module("./producers/producers.star")
data_viz = import_module("./data-viz/jupyter-notebook.star")

def run(plan, args):
    # start cassandra database
    # topics from kafka are stored in cassandra
    cassandra_info = cassandra.run(plan)

    # setup kafka
    # manages event stream, publishes topics for consumption
    # setups up a kafka connector db sink that retrieves topics from kafka broker and puts in cassandra
    # how does the kafka connect to the cassandra db?
    kafka_broker_uri = kafka.run(plan)
    
    # produces data that's sent to kafka topics
    producers.run(plan, kafka_broker_uri)

    # start data visualization service
    # reads published data from cassandra DB and visualizes it
    data_viz.run(plan, cassandra_info)