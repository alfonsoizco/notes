import pika, time
from random import randint

class publish_engine:

    def __init__(self):

        self._messages = 100
        self._message_interval = 1
        self._connection = None
        self._channel = None
        self._exchange = "score.feed.exchange"

    def make_connection(self):
        credentials = pika.PlainCredentials('guest', 'guest')
        parameters = pika.ConnectionParameters('54.200.201.1', 5672, '/', credentials, socket_timeout=300)
        self._connection = pika.BlockingConnection(parameters)
        print("Connected Successfully !!!")
        return self._connection

    def channel(self):
        self._channel = self._connection.channel()
        print("Channel opened...")

    def declare_exchange(self):
        self._channel.exchange_declare(exchange=self._exchange,
                         exchange_type='fanout')
        print("Exchange declared....")

    def publish_message(self):
        message_count = 0
        score = 0
        while message_count < self._messages:
            message_count += 1
            score += randint(0, 9)
            message_body = "Cricket Score | Batting Team : Australia | Bowling Team : England | Score : %i | wickets : 2" %(score)
            self._channel.basic_publish(exchange=self._exchange,
                                  routing_key='',
                                  body=message_body,
                                  properties=pika.BasicProperties(
                                      delivery_mode=2,  # make message persistent
                                  ))
            print("Published message %i" %(message_count))
            time.sleep(self._message_interval)

    def close_connection(self):
        self._connection.close()
        print("Closed connection....")

    def run(self):
        self.make_connection()
        self.channel()
        self.declare_exchange()
        self.publish_message()
        self.close_connection()

if __name__ == '__main__':
    engine = publish_engine()
    engine.run()