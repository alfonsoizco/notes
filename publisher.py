import pika,time

message_count = 15
count = 1

def connect_machine():
    credentials = pika.PlainCredentials('guest', 'guest')
    connection = pika.BlockingConnection(pika.ConnectionParameters('34.217.176.249', 5672, '/', credentials, socket_timeout=300))
    channel = connection.channel()
    channel.queue_declare(queue='sample_test', durable=True)
    return connection, channel

def disconnect_machine(connection):
    connection.close()

while count <= message_count:
    body_content = "Message number " + str(count)
    count = count + 1
    connection, channel = connect_machine()
    channel.basic_publish(exchange='',
                        routing_key='sample_test',
                        body=body_content)
    disconnect_machine(connection)
    print(" [x] Sent '{}'".format(body_content))
    time.sleep(1)


