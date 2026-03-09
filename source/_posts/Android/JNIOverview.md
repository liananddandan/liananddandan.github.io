---
title: JNI Overview
date: 2023-04-08 00:00:00
categories: Android
description: A brief overview of Java Native Interface (JNI) and how Java interacts with native code
tags:
- Java
- JNI
---

## What is JNI

JNI stands for **Java Native Interface**.

It is a programming interface that allows Java code running in a JVM to interact with applications and libraries written in other languages such as **C or C++**.

With JNI:

- Java code can call functions implemented in native languages (usually C/C++).
- Native code can also call Java methods.

This mechanism is widely used in **Android framework development**, where Java APIs interact with native system components.

---

## MediaPlayer Example (Java Layer)

In Android, the Java layer loads native libraries using `System.loadLibrary`.

Example from the Android framework:

```java
static {
    System.loadLibrary("media_jni");
    native_init();
}

private static native final void native_init();
```

Two things happen here:

1. Load the JNI library.
2. Declare a native method in Java.

The `System.loadLibrary` method dynamically expands the library name.

On Linux:

```
lib + name + .so
```

For example:

```
media_jni → libmedia_jni.so
```

On Windows:

```
name.dll
```

---

## MediaPlayer Example (JNI Layer)

Corresponding native implementation:

```
/frameworks/base/media/jni/android_media_MediaPlayer.cpp
```

Example:

```cpp
static void android_media_MediaPlayer_native_init(JNIEnv *env)
{
    jclass clazz;

    clazz = env->FindClass("android/media/MediaPlayer");
    if (clazz == NULL) {
        return;
    }

    fields.context = env->GetFieldID(clazz, "mNativeContext", "J");
    if (fields.context == NULL) {
        return;
    }
}
```

---

## Why Does `native_init` Map to `android_media_MediaPlayer_native_init`?

Java method:

```
android.media.MediaPlayer.native_init
```

In JNI naming rules, dots (`.`) are replaced with underscores (`_`).

Therefore the native function becomes:

```
android_media_MediaPlayer_native_init
```

---

## JNI Function Registration

There are two ways to register JNI methods.

### 1 Static Registration

Steps:

1. Write Java code.
2. Compile to `.class`.
3. Use `javah` to generate JNI headers.

Example:

```
javah -o output.h packagename.classname
```

Generated header example:

```cpp
JNIEXPORT jboolean JNICALL
Java_android_filterfw_core_GLFrame_nativeAllocate(JNIEnv* env,
                                                   jobject thiz,
                                                   jobject gl_env,
                                                   jint width,
                                                   jint height);
```

When Java calls `nativeAllocate`, the JVM searches for:

```
Java_android_filterfw_core_GLFrame_nativeAllocate
```

If found, it links the two functions.

---

### 2 Dynamic Registration

Dynamic registration uses the `JNINativeMethod` structure:

```cpp
typedef struct {
    const char* name;
    const char* signature;
    void* fnPtr;
} JNINativeMethod;
```

Fields:

- **name** – Java native method name
- **signature** – method signature
- **fnPtr** – pointer to the native function

Example:

```cpp
static const JNINativeMethod gMethods[] = {
    {"native_init", "()V", (void *)android_media_MediaPlayer_native_init},
    {"_seekTo", "(JI)V", (void *)android_media_MediaPlayer_seekTo},
};
```

These mappings are registered using:

```cpp
AndroidRuntime::registerNativeMethods(env,
    "android/media/MediaPlayer", gMethods, NELEM(gMethods));
```

---

## When Does JNI Registration Happen?

When Java loads a native library using:

```java
System.loadLibrary(...)
```

The JVM searches for a special function:

```
JNI_OnLoad
```

Example:

```cpp
jint JNI_OnLoad(JavaVM* vm, void* reserved)
{
    JNIEnv* env = NULL;

    if (register_android_media_MediaPlayer(env) < 0) {
        return -1;
    }

    return JNI_VERSION_1_6;
}
```

This is where **dynamic registration occurs**.

---

## Data Type Mapping

In JNI:

- Primitive Java types have direct equivalents.
- Most Java objects are represented as `jobject`.

Example Java method:

```java
private static native final void native_init();
```

Native implementation:

```cpp
static void android_media_MediaPlayer_native_init(JNIEnv *env)
```

Because the Java method is **static**, JNI uses `jclass` instead of `jobject`.

---

## Understanding JNIEnv

`JNIEnv` represents the **JNI environment**.

It provides functions for:

- Calling Java methods
- Accessing fields
- Creating Java objects

Important points:

- `JNIEnv` is **thread-specific**.
- Each thread has its own `JNIEnv`.

However, **JavaVM is global** within the process.

Example:

```cpp
jint JNI_OnLoad(JavaVM* vm, void* reserved)
```

To obtain `JNIEnv` in a thread:

```cpp
vm->AttachCurrentThread(...)
```

Before the thread exits:

```
DetachCurrentThread()
```

must be called to release resources.

---

## Accessing Fields and Methods

Retrieve field or method IDs:

```cpp
jfieldID GetFieldID(jclass clazz, const char* name, const char* sig);

jmethodID GetMethodID(jclass clazz, const char* name, const char* sig);
```

Calling a Java method from JNI:

```cpp
env->CallVoidMethod(thiz, methodID, args);
```

Accessing fields:

```
Get<Type>Field
Set<Type>Field
```

---

## Working with Strings

Convert Java strings to native strings:

```cpp
const char *tmp = env->GetStringUTFChars(name, nullptr);
```

Release memory afterward:

```cpp
env->ReleaseStringUTFChars(name, tmp);
```

Failing to release them can cause **memory leaks**.

---

## JNI Method Signatures

Method signatures uniquely identify Java methods.

Format:

```
(ArgumentTypes)ReturnType
```

Example:

```
(Landroid/media/MediaDataSource;)V
```

Because Java supports **method overloading**, JNI must use both:

- method name
- method signature

to locate the correct function.

---

## JNI Reference Types

JNI provides three types of references.

### Local Reference

Valid only during the native method call.

Automatically released after the function returns.

### Global Reference

Created using:

```
NewGlobalRef
```

Remains valid until explicitly deleted.

### Weak Global Reference

May be garbage collected.

Before use, check with:

```
IsSameObject
```

Example:

```cpp
mClass = (jclass)env->NewGlobalRef(clazz);
mObject = env->NewGlobalRef(weak_thiz);
```

Release them later:

```cpp
env->DeleteGlobalRef(mObject);
env->DeleteGlobalRef(mClass);
```

---

## References

- https://www.kancloud.cn/alex_wsc/android_depp/412877  
- https://docs.oracle.com/en/java/javase/17/docs/specs/jni/