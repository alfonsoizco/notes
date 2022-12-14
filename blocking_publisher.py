#!/usr/bin/env python
import pika, time
import sys

class publish_engine:

    def __init__(self):

        self._messages = 100
        self._message_interval = 1
        self._queue_name = "task_queue"
        self._connection = None
        self._channel = None

    def make_connection(self):
        credentials = pika.PlainCredentials('guest', 'guest')
        parameters = pika.ConnectionParameters('54.191.35.214', 5672, '/', credentials, socket_timeout=300)
        self._connection = pika.BlockingConnection(parameters)
        print("Connected Successfully !!!")
        return self._connection

    def channel(self):
        self._channel = self._connection.channel()
        print("Channel opened...")

    def declare_queue(self):
        self._channel.queue_declare(queue=self._queue_name, durable=True)
        print("Queue declared....")

    def publish_message(self):
        message_count = 0
        while message_count < self._messages:
            message_count += 1
            message_body = "task number %i" %(message_count)
            self._channel.basic_publish(exchange='',
                                  routing_key=self._queue_name,
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
        self.declare_queue()
        self.publish_message()
        self.close_connection()

if __name__ == '__main__':
    engine = publish_engine()
    engine.run()