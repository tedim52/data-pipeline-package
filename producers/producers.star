
def run(plan, kafka_broker_uri):
    plan.add_service(
        name="twitter-producer",
        config=ServiceConfig(
            image=ImageBuildSpec(
                build_context_dir="./twitter/",
                image_name="twitter-producer:latestagain",
            ),
            env_vars={
                "KAFKA_BROKER_URL": kafka_broker_uri,
                "TOPIC_NAME": "twitter",
            },
        ),
   )

    plan.add_service(
        name="weather-producer",
        config=ServiceConfig(
            image=ImageBuildSpec(
                build_context_dir="./weather/",
                image_name="weather-producer:latestagain",
            ),
            env_vars={
                "KAFKA_BROKER_URL": kafka_broker_uri,
                "TOPIC_NAME": "weather",
            }
        )
    )