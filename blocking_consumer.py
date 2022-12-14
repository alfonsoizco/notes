#!/usr/bin/env python
import pika
import time

class consume_engine:

    def __init__(self):
        self._messages = 100
        self._message_interval = 1
        self._queue_name = "task_queue"
        self._connection = None
        self._channel = None

    def connection(self):
        credentials = pika.PlainCredentials('guest', 'guest')
        parameters = pika.ConnectionParameters('54.218.29.52', 5672, '/', credentials, socket_timeout=300)
        self._connection = pika.BlockingConnection(parameters)
        print("Connected Successfully !!!")
        return self._connection

    def channel(self):
        self._channel = self._connection.channel()
        print("Channel opened...")

    def declare_queue(self):
        self._channel.queue_declare(queue=self._queue_name, durable=True)
        print("Queue declared....")
        print(' [*] Waiting for messages. To exit press CTRL+C')

    def on_message(self, channel, method, properties, body):
        print(" [x] working on %r" % body)
        time.sleep(3)
        print(" [x] Done")
        self._channel.basic_ack(delivery_tag = method.delivery_tag)

    def consume_messages(self):
        self._channel.basic_qos(prefetch_count=1)
        self._channel.basic_consume(self.on_message,
                          queue='task_queue')
        self._channel.start_consuming()

    def run(self):
        self.connection()
        self.channel()
        self.declare_queue()
        self.consume_messages()

if __name__ == '__main__':
    engine = consume_engine()
    engine.run()