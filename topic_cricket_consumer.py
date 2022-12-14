#!/usr/bin/env python
import pika
import time

class consume_engine:

    def __init__(self):
        self._messages = 10
        self._message_interval = 5
        self._queue_name = None
        self._connection = None
        self._channel = None
        self._exchange = "sports.feed.topic"

    def connection(self):
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
                         exchange_type='topic')
        print("Exchange declared....")

    def declare_queue(self):
        result = self._channel.queue_declare(exclusive=True)
        self._queue_name = result.method.queue
        print("Queue declared....")
        print(' [*] Waiting for messages. To exit press CTRL+C')

    def make_binding(self):
        self._channel.queue_bind(exchange=self._exchange,
                                 routing_key="scores.cricket",
                                 queue=self._queue_name)
        print("Made binding between exchange: %s and queue: %s" %(self._exchange, self._queue_name))

    def on_message(self, channel, method, properties, body):
        print(" [x] Feed Received - %s \n" % str(body))
        time.sleep(2)

    def consume_messages(self):
        self._channel.basic_consume(self.on_message,
                          queue=self._queue_name, no_ack=True)
        self._channel.start_consuming()

    def run(self):
        self.connection()
        self.channel()
        self.declare_exchange()
        self.declare_queue()
        self.make_binding()
        self.consume_messages()

if __name__ == '__main__':
    engine = consume_engine()
    engine.run()