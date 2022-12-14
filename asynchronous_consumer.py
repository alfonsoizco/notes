import pika, time
import logging
from pika.frame import *

LOG_FORMAT = ('%(levelname) -10s %(asctime)s %(name) -30s %(funcName) '
                '-35s %(lineno) -5d: %(message)s')
LOGGER = logging.getLogger(__name__)

class consume_engine:

    def __init__(self):
        self._channel = None
        self._connection = None
        self.QUEUE = "orders_q"
        self.EXCHANGE = ""

    def on_open(self, connection):
        # Invoked when the connection is open
        print("Reached connection open \n")
        self._channel = self._connection.channel(self.on_channel_open)

    def on_declare(self, channel):
        print("Now in on declare")
        self._channel.add_on_cancel_callback(self.on_consumer_cancelled)
        self._consumer_tag = self._channel.basic_consume(self.on_message,
                                                         self.QUEUE)

    def on_consumer_cancelled(self, method_frame):
        print(method_frame)
        if self._channel:
            self._channel.close()

    def on_message(self, channel, basic_deliver, properties, body):
        self._channel.basic_ack(basic_deliver.delivery_tag)
        print(basic_deliver)
        print("Delivery tag is: " + str(basic_deliver.delivery_tag))
        print(properties)
        print("Recevied Content: " + str(body))

    def on_channel_open(self, channel):
        print("Reached channel open \n")
        argument_list = {'x-queue-master-locator': 'random'}
        self._channel.queue_declare(self.on_declare, queue='orders_q', durable=True, arguments=argument_list)

    def on_close(self, connection, reply_code, reply_message):
        # This will be called on connection close
        print(reply_code)
        print(reply_message)
        print("connection is being closed \n")

    def stop_consuming(self):

        print("Keyboard Interupt recevied !!!")
        if self._channel:
            self._channel.basic_cancel(self.on_cancelok, self._consumer_tag)

    def on_cancelok(self, unused_frame):
        self._channel.close()
        self.close_connection()

    def stop(self):
        self._closing = True
        self.stop_consuming()
        self._connection.ioloop.start()

    def close_connection(self):
        self._connection.close()


    def run(self):
    # Create our connection object, passing in the on_open method
        logging.basicConfig(level=logging.ERROR, format=LOG_FORMAT)
        credentials = pika.PlainCredentials('guest', 'guest')
        parameters = pika.ConnectionParameters('34.217.176.249', 5672, '/', credentials, socket_timeout=300)
        self._connection = pika.SelectConnection(parameters, on_open_callback=self.on_open)
        self._connection.add_on_close_callback(self.on_close)
        print("Script execution is done!! will start IO Loop")

        try:
            # Loop so we can communicate with RabbitMQ
            self._connection.ioloop.start()
        except KeyboardInterrupt:
            # Gracefully close the connection
            self.stop_consuming()


if __name__ == '__main__':

    engine = consume_engine()
    engine.run()
