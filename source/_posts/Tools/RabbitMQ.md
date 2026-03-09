---
title: RabbitMQ Basics
date: 2023-12-27 00:00:00
categories: Tools
description: A simple introduction to RabbitMQ, message queues, exchanges, and routing
tags:
- RabbitMQ
---

## Installing RabbitMQ

RabbitMQ can be installed easily using Homebrew on macOS.

```bash
brew install rabbitmq
```

Start RabbitMQ service:

```bash
brew services start rabbitmq
```

Stop the service:

```bash
brew services stop rabbitmq
```

RabbitMQ also provides a **management web UI**:

```
http://localhost:15672
```

Default login:

```
username: guest
password: guest
```

---

## Introduction

RabbitMQ is a **message broker**.  
It accepts messages from producers and forwards them to consumers.

Some basic concepts:

| Concept | Description |
|------|------|
| Producer | A program that sends messages |
| Queue | A buffer that stores messages |
| Consumer | A program that receives messages |
| Exchange | A component that routes messages to queues |

The typical message flow is:

```
Producer → Exchange → Queue → Consumer
```

---

## Default Dispatch Strategy

By default, RabbitMQ uses **Round-Robin dispatching**.

Messages are delivered sequentially to consumers.

Example:

```
consumer1 → message1
consumer2 → message2
consumer1 → message3
consumer2 → message4
```

This means every consumer receives roughly the same number of messages.

---

## Fair Dispatch

Sometimes tasks take different amounts of time.

If one worker receives heavy tasks while another receives light ones, the round-robin strategy can be inefficient.

RabbitMQ provides **Fair Dispatch**.

This can be enabled by setting:

```csharp
BasicQos(prefetchCount: 1)
```

This tells RabbitMQ:

> Do not give a worker a new message until it has processed and acknowledged the previous one.

This ensures workloads are distributed more fairly.

---

## Sending a Message

Steps:

1. Create a connection
2. Create a channel
3. Declare a queue
4. Send a message

Example:

```csharp
using RabbitMQ.Client;
using System.Text;

var factory = new ConnectionFactory { HostName = "localhost" };

using var connection = await factory.CreateConnectionAsync();
using var channel = await connection.CreateChannelAsync();

await channel.QueueDeclareAsync(
    queue: "hello",
    durable: false,
    exclusive: false,
    autoDelete: false,
    arguments: null
);

var message = "Hello World!";
var body = Encoding.UTF8.GetBytes(message);

await channel.BasicPublishAsync(
    exchange: "",
    routingKey: "hello",
    body: body
);

Console.WriteLine($"[x] Sent {message}");
```

---

## Receiving a Message

Consumers wait for messages from the queue.

Example:

```csharp
using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;

var factory = new ConnectionFactory { HostName = "localhost" };

using var connection = await factory.CreateConnectionAsync();
using var channel = await connection.CreateChannelAsync();

await channel.QueueDeclareAsync(
    queue: "hello",
    durable: false,
    exclusive: false,
    autoDelete: false,
    arguments: null
);

Console.WriteLine("Waiting for messages...");

var consumer = new AsyncEventingBasicConsumer(channel);

consumer.ReceivedAsync += (model, ea) =>
{
    var body = ea.Body.ToArray();
    var message = Encoding.UTF8.GetString(body);

    Console.WriteLine($"Received {message}");

    return Task.CompletedTask;
};

await channel.BasicConsumeAsync(
    queue: "hello",
    autoAck: true,
    consumer: consumer
);
```

---

## Exchanges

In RabbitMQ, producers do **not send messages directly to queues**.

Instead, they send messages to an **exchange**.

The exchange decides how messages are routed to queues.

Different exchange types define different routing strategies.

---

## Exchange Types

### Fanout Exchange

A **fanout exchange** broadcasts messages to all bound queues.

```
Producer → Fanout Exchange → Queue1
                           → Queue2
                           → Queue3
```

The routing key is ignored.

This is useful for **broadcast scenarios**, such as logging or notifications.

---

### Direct Exchange

A **direct exchange** routes messages based on an exact match between:

```
routingKey == bindingKey
```

Example:

```
routingKey: error
queue binding: error
```

The message will be delivered to that queue.

---

### Topic Exchange

A **topic exchange** routes messages based on pattern matching.

Special symbols:

| Symbol | Meaning |
|------|------|
| `*` | matches exactly one word |
| `#` | matches zero or more words |

Example binding keys:

```
*.critical
logs.#
```

Example routing key:

```
kern.critical
```

This message would match:

```
*.critical
kern.#
#
```

Topic exchanges are very flexible and commonly used in event-driven systems.

---

## Topic Exchange Example

Sender:

```csharp
await channel.ExchangeDeclareAsync(
    exchange: "topic_logs",
    type: ExchangeType.Topic
);

await channel.BasicPublishAsync(
    exchange: "topic_logs",
    routingKey: "kern.critical",
    body: body
);
```

Receiver:

```csharp
await channel.QueueBindAsync(
    queue: queueName,
    exchange: "topic_logs",
    routingKey: "*.critical"
);
```

Testing example:

```
receiver args: "*.critical"
sender routing key: "kern.critical"
```

The message will be delivered.

---

## Summary

RabbitMQ is a powerful message broker widely used in distributed systems.

Important concepts include:

- producer
- queue
- consumer
- exchange
- routing key

Common exchange types:

| Exchange | Description |
|------|------|
| fanout | broadcast to all queues |
| direct | exact routing key match |
| topic | pattern-based routing |

These mechanisms make RabbitMQ a flexible solution for building **asynchronous and event-driven systems**.