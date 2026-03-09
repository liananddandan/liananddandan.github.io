---
title: The Role of Handler in Android
date: 2023-06-19 00:00:00
categories: Android
description: An overview of how Handler, Looper, MessageQueue, and HandlerThread work together in Android's message-driven model
tags:
- Handler
- Looper
---

## Message-Driven Model in Android

Android uses a message-driven mechanism to coordinate work across threads.

The basic idea is simple:

- there is a message queue that stores messages
- there is a message loop that continuously takes messages from the queue
- once a message is taken out, it is processed

In Android, this mechanism is mainly implemented by **Looper** and **Handler**:

- `Looper` encapsulates the message loop and owns a `MessageQueue`
- `Handler` encapsulates message sending and message handling

---

## The Role of Looper

A typical custom Looper thread looks like this:

```java
class LooperThread extends Thread {
    public Handler mHandler;

    public void run() {
        Looper.prepare();
        // ...
        Looper.loop();
    }
}
```

Usage:

```java
new LooperThread().start();
```

This already shows the basic pattern:

1. call `Looper.prepare()`
2. create or bind handlers
3. call `Looper.loop()`

---

## What Does `Looper.prepare()` Do

In `Looper.java`:

```java
public static void prepare() {
    prepare(true);
}

private static void prepare(boolean quitAllowed) {
    if (sThreadLocal.get() != null) {
        throw new RuntimeException("Only one Looper may be created per thread");
    }
    sThreadLocal.set(new Looper(quitAllowed));
}
```

A `Looper` can only be created once per thread.

The important part is this line:

```java
sThreadLocal.set(new Looper(quitAllowed));
```

This stores the `Looper` inside a `ThreadLocal`, meaning the `Looper` becomes associated with the current thread.

Now look at the constructor:

```java
private Looper(boolean quitAllowed) {
    mQueue = new MessageQueue(quitAllowed);
    mThread = Thread.currentThread();
}
```

So `Looper.prepare()` mainly does two things:

- create a `Looper` for the current thread
- create a `MessageQueue` inside that `Looper`

In other words, `prepare()` binds the current thread to a `Looper`, and that `Looper` owns a message queue.

---

## What Does `Looper.loop()` Do

The main work of the Looper happens in `loop()`.

```java
public static @Nullable Looper myLooper() {
    return sThreadLocal.get();
}

public static void loop() {
    final Looper me = myLooper();
    if (me == null) {
        throw new RuntimeException("No Looper; Looper.prepare() wasn't called on this thread.");
    }

    if (me.mInLoop) {
        Slog.w(TAG, "Loop again would have the queued messages be executed"
                + " before this one completed.");
    }

    me.mInLoop = true;

    for (;;) {
        if (!loopOnce(me, ident, thresholdOverride)) {
            return;
        }
    }
}
```

This function:

- retrieves the current thread’s `Looper`
- marks it as running
- enters an infinite loop
- repeatedly fetches and dispatches messages

The actual work happens in `loopOnce()`:

```java
private static boolean loopOnce(final Looper me,
        final long ident, final int thresholdOverride) {
    Message msg = me.mQueue.next(); // might block
    if (msg == null) {
        return false;
    }

    try {
        msg.target.dispatchMessage(msg);
    } finally {
        ThreadLocalWorkSource.restore(origWorkSource);
    }

    msg.recycleUnchecked();
    return true;
}
```

This shows the core logic very clearly:

- get the next message from the queue
- if there is no message, the loop may stop
- otherwise, send the message to its target `Handler`
- let the handler process it

So the role of `Looper` is:

- run a loop forever
- wait for messages
- dispatch each message to the correct `Handler`

---

## How Does the Queue Return the Next Message

The next message is retrieved from `MessageQueue.next()`.

```java
Message next() {
    int pendingIdleHandlerCount = -1;
    int nextPollTimeoutMillis = 0;

    for (;;) {
        nativePollOnce(ptr, nextPollTimeoutMillis);

        synchronized (this) {
            final long now = SystemClock.uptimeMillis();
            Message prevMsg = null;
            Message msg = mMessages;

            if (msg != null) {
                if (now < msg.when) {
                    nextPollTimeoutMillis = (int) Math.min(msg.when - now, Integer.MAX_VALUE);
                } else {
                    mBlocked = false;
                    if (prevMsg != null) {
                        prevMsg.next = msg.next;
                    } else {
                        mMessages = msg.next;
                    }
                    msg.next = null;
                    msg.markInUse();
                    return msg;
                }
            } else {
                nextPollTimeoutMillis = -1;
            }
        }

        nextPollTimeoutMillis = 0;
    }
}
```

This means:

- if the next message is not yet ready, the queue waits
- when the scheduled time arrives, the message is returned
- the Looper then dispatches it to the handler

So the queue is not simply a container. It is also responsible for time-based scheduling.

---

## Summary of Looper

At this point, the role of `Looper` is already clear:

- it creates and owns a `MessageQueue`
- it is bound to a specific thread through `ThreadLocal`
- it runs an infinite loop
- it waits for messages to arrive
- it dispatches each message to the appropriate `Handler`

This leads to the next question: how are messages actually sent into the queue?

---

## The Role of Handler

To understand `Handler`, it is best to start from its constructor.

```java
final Looper mLooper;
final MessageQueue mQueue;
final Callback mCallback;
final boolean mAsynchronous;
```

These are the core fields.

Now look at the constructors:

```java
public Handler(@Nullable Callback callback, boolean async) {
    mLooper = Looper.myLooper();
    if (mLooper == null) {
        throw new RuntimeException(
            "Can't create handler inside thread " + Thread.currentThread()
                    + " that has not called Looper.prepare()");
    }
    mQueue = mLooper.mQueue;
    mCallback = callback;
    mAsynchronous = async;
}

public Handler(@NonNull Looper looper, @Nullable Callback callback, boolean async) {
    mLooper = looper;
    mQueue = looper.mQueue;
    mCallback = callback;
    mAsynchronous = async;
}
```

From this we can see:

- every `Handler` is bound to a `Looper`
- every `Handler` ultimately holds a reference to a `MessageQueue`
- that queue comes from the bound `Looper`

So a `Handler` is not just a callback container. It is also the interface through which messages are inserted into a thread’s message queue.

---

## What If There Were No Handler

Without `Handler`, sending a message would be much more complicated.

You would have to:

- get the `Looper`
- get the `MessageQueue`
- manually create a `Message`
- fill in its fields
- call `enqueueMessage()` directly

`Handler` exists to hide this complexity and provide a much easier API for message posting and handling.

---

## Sending a Message

Take `sendMessage()` as an example:

```java
public final boolean sendMessage(@NonNull Message msg) {
    return sendMessageDelayed(msg, 0);
}

public final boolean sendMessageDelayed(@NonNull Message msg, long delayMillis) {
    if (delayMillis < 0) {
        delayMillis = 0;
    }
    return sendMessageAtTime(msg, SystemClock.uptimeMillis() + delayMillis);
}

public boolean sendMessageAtTime(@NonNull Message msg, long uptimeMillis) {
    MessageQueue queue = mQueue;
    if (queue == null) {
        RuntimeException e = new RuntimeException(
                this + " sendMessageAtTime() called with no mQueue");
        Log.w("Looper", e.getMessage(), e);
        return false;
    }
    return enqueueMessage(queue, msg, uptimeMillis);
}
```

This shows that sending a message really means:

- getting the handler’s queue
- calculating the trigger time
- inserting the message into the queue

---

## Enqueuing a Message

In `Handler.java`:

```java
private boolean enqueueMessage(@NonNull MessageQueue queue, @NonNull Message msg,
        long uptimeMillis) {
    msg.target = this;
    msg.workSourceUid = ThreadLocalWorkSource.getUid();

    if (mAsynchronous) {
        msg.setAsynchronous(true);
    }

    return queue.enqueueMessage(msg, uptimeMillis);
}
```

A very important detail is:

```java
msg.target = this;
```

This means the `Handler` itself becomes the message’s target. Later, when the Looper takes the message out of the queue, it will call:

```java
msg.target.dispatchMessage(msg);
```

So the message knows which handler should process it.

Now look at `MessageQueue.enqueueMessage()`:

```java
boolean enqueueMessage(Message msg, long when) {
    if (msg.target == null) {
        throw new IllegalArgumentException("Message must have a target.");
    }

    synchronized (this) {
        if (msg.isInUse()) {
            throw new IllegalStateException(msg + " This message is already in use.");
        }

        if (mQuitting) {
            IllegalStateException e = new IllegalStateException(
                    msg.target + " sending message to a Handler on a dead thread");
            Log.w(TAG, e.getMessage(), e);
            msg.recycle();
            return false;
        }

        msg.markInUse();
        msg.when = when;
        Message p = mMessages;
        boolean needWake;

        if (p == null || when == 0 || when < p.when) {
            msg.next = p;
            mMessages = msg;
            needWake = mBlocked;
        } else {
            needWake = mBlocked && p.target == null && msg.isAsynchronous();
            Message prev;
            for (;;) {
                prev = p;
                p = p.next;
                if (p == null || when < p.when) {
                    break;
                }
                if (needWake && p.isAsynchronous()) {
                    needWake = false;
                }
            }
            msg.next = p;
            prev.next = msg;
        }

        if (needWake) {
            nativeWake(mPtr);
        }
    }
    return true;
}
```

This shows that the message queue is a **singly linked list** ordered by trigger time.

Messages are inserted:

- at the head if they should run earlier
- in the middle if their time falls between existing messages
- at the tail if they are the latest

So `Handler` does not directly execute the message. It inserts the message into the queue associated with the target thread.

---

## How a Handler Processes a Message

When the Looper dispatches a message, it eventually calls `dispatchMessage()`:

```java
public void dispatchMessage(@NonNull Message msg) {
    if (msg.callback != null) {
        handleCallback(msg);
    } else {
        if (mCallback != null) {
            if (mCallback.handleMessage(msg)) {
                return;
            }
        }
        handleMessage(msg);
    }
}
```

This reveals the message handling priority:

1. if the `Message` itself has a callback, execute that first
2. otherwise, if the `Handler` has a `Callback`, use it
3. otherwise, call `handleMessage(msg)`

This is why subclassing `Handler` and overriding `handleMessage()` is a common pattern.

---

## Summary of Handler

The role of `Handler` can now be summarized as follows:

- bind to a specific `Looper`
- send messages into that Looper’s `MessageQueue`
- when the message is dispatched, handle it through callback logic

So `Looper` is responsible for the loop and dispatching, while `Handler` is responsible for sending and receiving messages.

---

## The Problem Solved by HandlerThread

Consider the following custom thread:

```java
class LooperThread extends Thread {
    public Looper myLooper = null;

    public void run() {
        Looper.prepare();
        myLooper = Looper.myLooper();
        Looper.loop();
    }
}
```

Usage:

```java
LooperThread lpThread = new LooperThread;
lpThread.start();
Looper looper = lpThread.myLooper;   // problem here
Handler thread2Handler = new Handler(looper);
thread2Handler.sendMessage(...);
```

The problem is obvious: after `lpThread.start()`, the new thread may not yet have completed `Looper.prepare()`. At that moment, `myLooper` may still be `null`.

So there is a race condition.

Android solves this with `HandlerThread`.

Usage:

```java
HandlerThread handlerThread = new HandlerThread("MyHandlerThread");
handlerThread.start();
Handler handler = new Handler(handlerThread.getLooper());
```

Now look at its implementation:

```java
public void run() {
    mTid = Process.myTid();
    Looper.prepare();
    synchronized (this) {
        mLooper = Looper.myLooper();
        notifyAll();
    }
    Process.setThreadPriority(mPriority);
    onLooperPrepared();
    Looper.loop();
    mTid = -1;
}
```

And `getLooper()`:

```java
public Looper getLooper() {
    if (!isAlive()) {
        return null;
    }

    boolean wasInterrupted = false;

    synchronized (this) {
        while (isAlive() && mLooper == null) {
            try {
                wait();
            } catch (InterruptedException e) {
                wasInterrupted = true;
            }
        }
    }

    if (wasInterrupted) {
        Thread.currentThread().interrupt();
    }

    return mLooper;
}
```

This uses `wait()` and `notifyAll()` to make sure that `getLooper()` does not return until the `Looper` has really been created.

So the role of `HandlerThread` is to safely provide a ready-to-use thread with a Looper.

---

## Final Summary

The message mechanism in Android can be understood as a clear division of labor:

### Looper

- created per thread
- stored in `ThreadLocal`
- owns a `MessageQueue`
- runs an infinite loop
- fetches and dispatches messages

### MessageQueue

- stores messages in time order
- blocks when necessary
- returns the next ready message

### Handler

- binds to a specific `Looper`
- sends messages into the queue
- receives and handles dispatched messages

### HandlerThread

- creates a thread with its own `Looper`
- solves the synchronization problem of getting the Looper safely

So, in one sentence, the role of `Handler` in Android is:

**to provide a simple way to post work into a specific thread’s message queue and handle that work when the Looper dispatches it.**

---

## References

- https://www.jianshu.com/p/6e58200a4def
- https://blog.csdn.net/u010445301/article/details/124935802
- https://blog.csdn.net/cpcpcp123/article/details/122000274
- https://www.kancloud.cn/alex_wsc/android_depp/412913