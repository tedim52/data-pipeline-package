import json
import os
from datetime import datetime
import tweepy
from kafka import KafkaProducer
import configparser
import random 

TWIITER_API_GEOBOX_FILTER = [-123.371556, 49.009125, -122.264683, 49.375294]
TWITTER_API_LANGS_FILTER = ['en']

# Twitter API Keys
config = configparser.ConfigParser()
config.read('twitter_service.cfg')
api_credential = config['twitter_api_credential']
# access_token = api_credential['access_token']
# access_token_secret = api_credential['access_token_secret']
# consumer_key = api_credential['consumer_key']
# consumer_secret = api_credential['consumer_secret']
bearer_token = api_credential['bearer_token']

# Kafka settings
KAFKA_BROKER_URL = os.environ.get("KAFKA_BROKER_URL") if os.environ.get(
    "KAFKA_BROKER_URL") else 'localhost:9092'
TOPIC_NAME = os.environ.get("TOPIC_NAME") if os.environ.get(
    "TOPIC_NAME") else 'from_twitter'

# a static location is used for now as a
# geolocation filter is imposed on twitter API
TWEET_LOCATION = 'MetroVancouver'


class stream_listener(tweepy.StreamingClient):

    def __init__(self, bearer_tokens):
        super(stream_listener, self).__init__(bearer_token)
        self.producer = KafkaProducer(
            bootstrap_servers=KAFKA_BROKER_URL,
            value_serializer=lambda x: json.dumps(x).encode('utf8'),
            api_version=(0, 10, 1)
        )


    def _generate_funny_tweet(self):
        funny_phrases = [
        "I told my computer I needed a break. It replied, 'Fine, I'll go calculate pi for a while.'",
        "Why don't scientists trust atoms? Because they make up everything!",
        "I used to be a baker, but I couldn't make enough dough.",
        "Parallel lines have so much in common... it’s a shame they’ll never meet.",
        "I told a chemistry joke, but there was no reaction.",
        "I'm reading a book on anti-gravity. It's impossible to put down!",
        "Why did the scarecrow win an award? Because he was outstanding in his field!",
        "I'm on a seafood diet. I see food and I eat it!"
        ]
    
        return random.choice(funny_phrases)

    def on_tweet(self, tweet):
        twitter_df = {
            'tweet':  self._generate_funny_tweet(),
            'datetime': datetime.utcnow().timestamp(),
            'location': TWEET_LOCATION
        }
        print(twitter_df)

        self.producer.send(TOPIC_NAME, value=twitter_df)
        self.producer.flush()
        return True

    def on_errors(self, errors):
        twitter_df = {
            'tweet':  self._generate_funny_tweet(),
            'datetime': datetime.utcnow().timestamp(),
            'location': TWEET_LOCATION
        }
        print(twitter_df)
        self.producer.send(TOPIC_NAME, value=twitter_df)
        self.producer.flush()
        # print('Errors: ' + errors)
        return True

    def on_request_error(self, status_code):
        twitter_df = {
            'tweet':  self._generate_funny_tweet(),
            'datetime': datetime.utcnow().timestamp(),
            'location': TWEET_LOCATION
        }
        print(twitter_df)
        self.producer.send(TOPIC_NAME, value=twitter_df)
        self.producer.flush()
        # if status_code == 420:

        #     return False
        # print('Streaming Error: ' + str(status_code))
        return True



class twitter_stream():

    def __init__(self):
        self.stream_listener = stream_listener(bearer_token)

    def twitter_listener(self):
        self.stream_listener.filter()

if __name__ == '__main__':
    ts = twitter_stream()
    ts.twitter_listener()
