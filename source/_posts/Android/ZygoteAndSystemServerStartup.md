---
title: Zygote and SystemServer Startup
date: 2023-05-25 00:00:00
categories: Android
description: An overview of how Zygote starts, enters the Java world, preloads resources, starts SystemServer, and waits for app process requests
tags:
- Zygote
- SystemServer
---

## From Init to Zygote

When the `init` process parses `init.rc`, it starts all services whose class is `main`. One of these services is `app_process`, which becomes the Zygote process.

Android can be understood as having two worlds:

- the **native world**
- the **Java world**

Starting Zygote means that the Java world of Android is about to begin.

---

## What Does Zygote Do

Zygote has several important responsibilities:

- create the ART virtual machine, load JNI functions, and preload classes and resources
- fork and start `system_server`, the most important system process
- open a socket and wait for process creation requests
- fork application processes when needed

Because app processes are forked from Zygote, they can reuse the work already done by Zygote, such as VM creation and class preloading.

---

## Zygote Startup

The startup flow continues from `init`, which launches `app_process`. Its entry point is in `app_main.cpp`.

```cpp
int main(int argc, char* const argv[])
{
    AppRuntime runtime(argv[0], computeArgBlockSize(argc, argv));

    bool zygote = false;
    bool startSystemServer = false;
    bool application = false;
    String8 niceName;
    String8 className;

    ++i;
    while (i < argc) {
        const char* arg = argv[i++];

        if (strcmp(arg, "--zygote") == 0) {
            zygote = true;
            niceName = ZYGOTE_NICE_NAME;
        } else if (strcmp(arg, "--start-system-server") == 0) {
            startSystemServer = true;
        } else if (strcmp(arg, "--application") == 0) {
            application = true;
        } else if (strncmp(arg, "--nice-name=", 12) == 0) {
            niceName.setTo(arg + 12);
        } else if (strncmp(arg, "--", 2) != 0) {
            className.setTo(arg);
            break;
        } else {
            --i;
            break;
        }
    }

    if (!niceName.isEmpty()) {
        runtime.setArgv0(niceName.string(), true);
    }

    if (zygote) {
        runtime.start("com.android.internal.os.ZygoteInit", args, zygote);
    } else if (!className.isEmpty()) {
        runtime.start("com.android.internal.os.RuntimeInit", args, zygote);
    } else {
        fprintf(stderr, "Error: no class name or --zygote supplied.\n");
        app_usage();
        LOG_ALWAYS_FATAL("app_process: no class name or --zygote supplied.");
    }
}
```

The corresponding `init.rc` entry looks like this:

```rc
service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote
```

The important parameters here are:

- `--zygote`
- `--start-system-server`
- `--socket-name=zygote`

So the process starts in Zygote mode, and `startSystemServer` is set to `true`.

There are two main modes here:

- **zygote mode**: start Zygote and call `ZygoteInit`
- **application mode**: start a normal application process and call `RuntimeInit`

---

## AndroidRuntime.start

`AppRuntime` extends `AndroidRuntime`, and it does not override `start`, so `AndroidRuntime::start` is used.

This method does several key things:

- create the VM and obtain `JNIEnv`
- register JNI methods
- convert the class name from dot form to slash form
- find and call the Java `main` method

```cpp
void AndroidRuntime::start(const char* className, const Vector<String8>& options, bool zygote)
{
    JNIEnv* env;
    if (startVm(&mJavaVM, &env, zygote, primary_zygote) != 0) {
        return;
    }

    if (startReg(env) < 0) {
        ALOGE("Unable to register all android natives\n");
        return;
    }

    char* slashClassName = toSlashClassName(className != NULL ? className : "");
    jclass startClass = env->FindClass(slashClassName);
    if (startClass == NULL) {
        ALOGE("JavaVM unable to locate class '%s'\n", slashClassName);
    } else {
        jmethodID startMeth = env->GetStaticMethodID(startClass, "main",
            "([Ljava/lang/String;)V");
        if (startMeth == NULL) {
            ALOGE("JavaVM unable to find main() in '%s'\n", className);
        } else {
            env->CallStaticVoidMethod(startClass, startMeth, strArray);
        }
    }
}
```

This is an important transition point. Up to now, everything has been happening in native code:

- `init`
- `app_process`
- `AndroidRuntime`

To call `ZygoteInit.main`, Android must first create a VM and register JNI functions. Only then can execution cross from the native world into the Java world.

---

## Creating the VM

The VM is created in `startVm`.

```cpp
int AndroidRuntime::startVm(JavaVM** pJavaVM, JNIEnv** pEnv, bool zygote, bool primary_zygote)
{
    if (JNI_CreateJavaVM(pJavaVM, pEnv, &initArgs) < 0) {
        ALOGE("JNI_CreateJavaVM failed\n");
        return -1;
    }

    return 0;
}
```

If this succeeds:

- the process has its Java VM
- `JNIEnv` is ready for JNI calls

---

## Registering JNI Methods

After the VM is created, Android registers a large set of JNI methods through `startReg`.

```cpp
int AndroidRuntime::startReg(JNIEnv* env)
{
    if (register_jni_procs(gRegJNI, NELEM(gRegJNI), env) < 0) {
        env->PopLocalFrame(NULL);
        return -1;
    }
}
```

Registration works by iterating over the `gRegJNI` array:

```cpp
static int register_jni_procs(const RegJNIRec array[], size_t count, JNIEnv* env)
{
    for (size_t i = 0; i < count; i++) {
        if (array[i].mProc(env) < 0) {
            return -1;
        }
    }
    return 0;
}
```

Example:

```cpp
int register_com_android_internal_os_RuntimeInit(JNIEnv* env)
{
    const JNINativeMethod methods[] = {
        {"nativeFinishInit", "()V",
         (void*)com_android_internal_os_RuntimeInit_nativeFinishInit},
        {"nativeSetExitWithoutCleanup", "(Z)V",
         (void*)com_android_internal_os_RuntimeInit_nativeSetExitWithoutCleanup},
    };
    return jniRegisterNativeMethods(env, "com/android/internal/os/RuntimeInit",
        methods, NELEM(methods));
}
```

At this point, the VM exists and JNI methods have been registered. The Java world is ready.

---

## Entering the Java World: ZygoteInit.main

The Java entry point is `ZygoteInit.main`.

```java
public static void main(String[] argv) {
    Runnable caller;

    boolean startSystemServer = false;
    String zygoteSocketName = "zygote";
    String abiList = null;
    boolean enableLazyPreload = false;

    for (int i = 1; i < argv.length; i++) {
        if ("start-system-server".equals(argv[i])) {
            startSystemServer = true;
        } else if ("--enable-lazy-preload".equals(argv[i])) {
            enableLazyPreload = true;
        } else if (argv[i].startsWith(ABI_LIST_ARG)) {
            abiList = argv[i].substring(ABI_LIST_ARG.length());
        } else if (argv[i].startsWith(SOCKET_NAME_ARG)) {
            zygoteSocketName = argv[i].substring(SOCKET_NAME_ARG.length());
        } else {
            throw new RuntimeException("Unknown command line argument: " + argv[i]);
        }
    }

    if (!enableLazyPreload) {
        preload(bootTimingsTraceLog);
    }

    zygoteServer = new ZygoteServer(isPrimaryZygote);

    if (startSystemServer) {
        Runnable r = forkSystemServer(abiList, zygoteSocketName, zygoteServer);
        if (r != null) {
            r.run();
            return;
        }
    }

    caller = zygoteServer.runSelectLoop(abiList);

    if (caller != null) {
        caller.run();
    }
}
```

The major steps here are:

1. parse arguments
2. preload classes and resources
3. create the Zygote socket server
4. fork `system_server`
5. enter the select loop and wait for future process requests

---

## Preloading Classes and Resources

Zygote preloads many commonly used classes and resources to improve process startup efficiency.

```java
static void preload(TimingsTraceLog bootTimingsTraceLog) {
    beginPreload();
    preloadClasses();
    cacheNonBootClasspathClassLoaders();
    Resources.preloadResources();
    nativePreloadAppProcessHALs();
    maybePreloadGraphicsDriver();
    preloadSharedLibraries();
    preloadTextResources();
    WebViewFactory.prepareWebViewInZygote();
    endPreload();
    warmUpJcaProviders();
    sPreloadComplete = true;
}
```

Class preloading uses:

```java
private static final String PRELOADED_CLASSES = "/system/etc/preloaded-classes";
```

Example:

```java
private static void preloadClasses() {
    final VMRuntime runtime = VMRuntime.getRuntime();

    InputStream is;
    try {
        is = new FileInputStream(PRELOADED_CLASSES);
    } catch (FileNotFoundException e) {
        Log.e(TAG, "Couldn't find " + PRELOADED_CLASSES + ".");
        return;
    }
}
```

The idea is simple: if Zygote preloads these classes once, every app forked from Zygote can reuse them instead of repeating the same work.

Zygote also preloads framework resources, such as those from `framework-res.apk`.

---

## Creating the IPC Server: ZygoteServer

Zygote creates a local socket server so that other components can request new processes.

```java
ZygoteServer(boolean isPrimaryZygote) {
    mUsapPoolEventFD = Zygote.getUsapPoolEventFD();

    if (isPrimaryZygote) {
        mZygoteSocket = Zygote.createManagedSocketFromInitSocket(Zygote.PRIMARY_SOCKET_NAME);
        mUsapPoolSocket =
                Zygote.createManagedSocketFromInitSocket(
                        Zygote.USAP_POOL_PRIMARY_SOCKET_NAME);
    } else {
        mZygoteSocket = Zygote.createManagedSocketFromInitSocket(Zygote.SECONDARY_SOCKET_NAME);
        mUsapPoolSocket =
                Zygote.createManagedSocketFromInitSocket(
                        Zygote.USAP_POOL_SECONDARY_SOCKET_NAME);
    }

    mUsapPoolSupported = true;
    fetchUsapPoolPolicyProps();
}
```

The socket is created from an init-provided file descriptor:

```java
private static final String ANDROID_SOCKET_PREFIX = "ANDROID_SOCKET_";
```

```java
static LocalServerSocket createManagedSocketFromInitSocket(String socketName) {
    final String fullSocketName = ANDROID_SOCKET_PREFIX + socketName;
    String env = System.getenv(fullSocketName);
    int fileDesc = Integer.parseInt(env);

    FileDescriptor fd = new FileDescriptor();
    fd.setInt$(fileDesc);
    return new LocalServerSocket(fd);
}
```

This produces a server socket such as:

```text
ANDROID_SOCKET_zygote
```

Zygote then waits for incoming process creation requests.

---

## Forking SystemServer

Since `--start-system-server` was passed, Zygote forks `system_server`.

```java
private static Runnable forkSystemServer(String abiList, String socketName,
        ZygoteServer zygoteServer) {
    String[] args = {
        "--setuid=1000",
        "--setgid=1000",
        "--setgroups=1001,1002,1003,1004,1005,1006,1007,1008,1009,1010,1018,1021,1023,"
                + "1024,1032,1065,3001,3002,3003,3005,3006,3007,3009,3010,3011,3012",
        "--capabilities=" + capabilities + "," + capabilities,
        "--nice-name=system_server",
        "--runtime-args",
        "--target-sdk-version=" + VMRuntime.SDK_VERSION_CUR_DEVELOPMENT,
        "com.android.server.SystemServer",
    };

    int pid;

    ZygoteCommandBuffer commandBuffer = new ZygoteCommandBuffer(args);
    parsedArgs = ZygoteArguments.getInstance(commandBuffer);

    pid = Zygote.forkSystemServer(
            parsedArgs.mUid, parsedArgs.mGid,
            parsedArgs.mGids,
            parsedArgs.mRuntimeFlags,
            null,
            parsedArgs.mPermittedCapabilities,
            parsedArgs.mEffectiveCapabilities);

    if (pid == 0) {
        if (hasSecondZygote(abiList)) {
            waitForSecondaryZygote(socketName);
        }

        zygoteServer.closeServerSocket();
        return handleSystemServerProcess(parsedArgs);
    }

    return null;
}
```

In the child process (`pid == 0`), execution continues as `system_server`.

---

## Why Is SystemServer So Important

Zygote treats `system_server` specially. If `system_server` dies, Zygote kills itself.

This logic is implemented in native code.

```cpp
static void SetSignalHandlers() {
    struct sigaction sig_chld = {.sa_flags = SA_SIGINFO, .sa_sigaction = SigChldHandler};

    if (sigaction(SIGCHLD, &sig_chld, nullptr) < 0) {
        ALOGW("Error setting SIGCHLD handler: %s", strerror(errno));
    }

    struct sigaction sig_hup = {};
    sig_hup.sa_handler = SIG_IGN;
    if (sigaction(SIGHUP, &sig_hup, nullptr) < 0) {
        ALOGW("Error setting SIGHUP handler: %s", strerror(errno));
    }
}
```

```cpp
static void SigChldHandler(int, siginfo_t* info, void*) {
    if (pid == gSystemServerPid) {
        async_safe_format_log(ANDROID_LOG_ERROR, LOG_TAG,
                              "Exit zygote because system server (pid %d) has terminated", pid);
        kill(getpid(), SIGKILL);
    }
}
```

This shows that `system_server` is not just another child process. It is so central that if it terminates, Zygote also exits.

---

## Preparing the Child as SystemServer

After the fork, the child process runs `handleSystemServerProcess`.

```java
private static Runnable handleSystemServerProcess(ZygoteArguments parsedArgs) {
    ClassLoader cl = getOrCreateSystemServerClassLoader();
    if (cl != null) {
        Thread.currentThread().setContextClassLoader(cl);
    }

    return ZygoteInit.zygoteInit(parsedArgs.mTargetSdkVersion,
            parsedArgs.mDisabledCompatChanges,
            parsedArgs.mRemainingArgs, cl);
}
```

This prepares the process to become `system_server`.

The remaining args contain:

```text
com.android.server.SystemServer
```

So the next step is to enter `ZygoteInit.zygoteInit`.

---

## ZygoteInit.zygoteInit

This method performs two key steps:

1. native zygote initialization
2. application initialization

```java
public static Runnable zygoteInit(int targetSdkVersion, long[] disabledCompatChanges,
        String[] argv, ClassLoader classLoader) {
    RuntimeInit.redirectLogStreams();
    RuntimeInit.commonInit();
    ZygoteInit.nativeZygoteInit();
    return RuntimeInit.applicationInit(targetSdkVersion, disabledCompatChanges, argv,
            classLoader);
}
```

---

## nativeZygoteInit and Binder Thread Pool

`nativeZygoteInit` eventually calls into `AndroidRuntime`.

```cpp
static void com_android_internal_os_ZygoteInit_nativeZygoteInit(JNIEnv* env, jobject clazz)
{
    gCurRuntime->onZygoteInit();
}
```

`gCurRuntime` is initialized in the `AndroidRuntime` constructor:

```cpp
AndroidRuntime::AndroidRuntime(char* argBlockStart, const size_t argBlockLength) :
        mExitWithoutCleanup(false),
        mArgBlockStart(argBlockStart),
        mArgBlockLength(argBlockLength)
{
    init_android_graphics();
    mOptions.setCapacity(20);
    assert(gCurRuntime == NULL);
    gCurRuntime = this;
}
```

When Zygote starts, `AppRuntime` is constructed, and because `AppRuntime` extends `AndroidRuntime`, `gCurRuntime` points to that `AppRuntime` instance.

Then `onZygoteInit` is called:

```cpp
virtual void onZygoteInit()
{
    sp<ProcessState> proc = ProcessState::self();
    ALOGV("App process: starting thread pool.\n");
    proc->startThreadPool();
}
```

This starts the Binder thread pool, which is essential for system IPC.

---

## Starting SystemServer.main

After native initialization, `applicationInit` resolves the target Java class and returns a runnable that will invoke its `main` method.

```java
protected static Runnable applicationInit(int targetSdkVersion, long[] disabledCompatChanges,
        String[] argv, ClassLoader classLoader) {
    final Arguments args = new Arguments(argv);
    return findStaticMain(args.startClass, args.startArgs, classLoader);
}
```

```java
protected static Runnable findStaticMain(String className, String[] argv,
        ClassLoader classLoader) {
    Method m;
    m = cl.getMethod("main", new Class[] { String[].class });
    return new MethodAndArgsCaller(m, argv);
}
```

```java
public void run() {
    try {
        mMethod.invoke(null, new Object[] { mArgs });
    } catch (IllegalAccessException ex) {
        throw new RuntimeException(ex);
    } catch (InvocationTargetException ex) {
        Throwable cause = ex.getCause();
        if (cause instanceof RuntimeException) {
            throw (RuntimeException) cause;
        } else if (cause instanceof Error) {
            throw (Error) cause;
        }
        throw new RuntimeException(ex);
    }
}
```

Back in `ZygoteInit.main`, this runnable is executed:

```java
if (r != null) {
    r.run();
    return;
}
```

At that moment, `SystemServer.main` begins.

---

## What SystemServer Does

`SystemServer.main` eventually creates a `SystemServer` instance and calls `run`.

```java
public static void main(String[] args) {
    new SystemServer().run();
}
```

Its main tasks include:

- loading the `android_servers` native library
- creating the system context
- creating the `SystemServiceManager`
- starting bootstrap, core, other, and APEX services
- entering the main loop

```java
private void run() {
    System.loadLibrary("android_servers");

    createSystemContext();

    mSystemServiceManager = new SystemServiceManager(mSystemContext);

    try {
        startBootstrapServices(t);
        startCoreServices(t);
        startOtherServices(t);
        startApexServices(t);
    } catch (Throwable ex) {
        Slog.e("System", "************ Failure starting system services", ex);
        throw ex;
    }

    Looper.loop();
    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

This is the point where `system_server` truly becomes the core host of Android system services.

It inherits the VM from Zygote, starts the Binder thread pool, and then launches and manages the system services that drive the Android framework.

---

## Waiting for App Process Requests

After starting `system_server`, Zygote does not stop. It enters a loop and waits for future requests to create app processes.

```java
Runnable runSelectLoop(String abiList) {
    socketFDs.add(mZygoteSocket.getFileDescriptor());

    if (pollIndex == 0) {
        ZygoteConnection newPeer = acceptCommandPeer(abiList);
        peers.add(newPeer);
        socketFDs.add(newPeer.getFileDescriptor());
    } else if (pollIndex < usapPoolEventFDIndex) {
        ZygoteConnection connection = peers.get(pollIndex);
        final Runnable command =
                connection.processCommand(this, multipleForksOK);
    }
}
```

The server socket accepts incoming connections. Once a client connects, Zygote reads the request and processes the command.

A natural question is: who is the client?

One important example is ActivityManager through the process startup path.

---

## How App Processes Are Started

A typical flow begins in `ProcessList.startProcessLocked`.

```java
boolean startProcessLocked(HostingRecord hostingRecord, String entryPoint, ProcessRecord app,
        int uid, int[] gids, int runtimeFlags, int zygotePolicyFlags, int mountExternal,
        String seInfo, String requiredAbi, String instructionSet, String invokeWith,
        long startUptime, long startElapsedTime) {

    final Process.ProcessStartResult startResult = startProcess(hostingRecord,
        entryPoint, app,
        uid, gids, runtimeFlags, zygotePolicyFlags, mountExternal, seInfo,
        requiredAbi, instructionSet, invokeWith, startUptime);
}
```

Eventually this reaches:

```java
startResult = Process.start(entryPoint,
    app.processName, uid, uid, gids, runtimeFlags, mountExternal,
    app.info.targetSdkVersion, seInfo, requiredAbi, instructionSet,
    app.info.dataDir, invokeWith, app.info.packageName, zygotePolicyFlags,
    isTopApp, app.getDisabledCompatChanges(), pkgDataInfoMap,
    allowlistedAppDataInfoMap, bindMountAppsData, bindMountAppStorageDirs,
    new String[]{PROC_START_SEQ_IDENT + app.getStartSeq()});
```

Then `Process.start` delegates to `ZYGOTE_PROCESS.start`, and ultimately to `startViaZygote`.

```java
private Process.ProcessStartResult startViaZygote(@NonNull final String processClass, .. .. ..)
{
    return zygoteSendArgsAndGetResult(openZygoteSocketIfNeeded(abi),
                                  zygotePolicyFlags,
                                  argsForZygote);
}
```

Here the client opens the Zygote socket and sends the process creation arguments to Zygote.

---

## How Zygote Creates an App Process

Zygote receives the request and handles it in `ZygoteConnection.processCommand`.

```java
Runnable processCommand(ZygoteServer zygoteServer, boolean multipleOK) {
    pid = Zygote.forkAndSpecialize(parsedArgs.mUid, parsedArgs.mGid,
        parsedArgs.mGids, parsedArgs.mRuntimeFlags, rlimits,
        parsedArgs.mMountExternal, parsedArgs.mSeInfo, parsedArgs.mNiceName,
        fdsToClose, fdsToIgnore, parsedArgs.mStartChildZygote,
        parsedArgs.mInstructionSet, parsedArgs.mAppDataDir,
        parsedArgs.mIsTopApp, parsedArgs.mPkgDataInfoList,
        parsedArgs.mAllowlistedDataInfoList, parsedArgs.mBindMountAppDataDirs,
        parsedArgs.mBindMountAppStorageDirs);

    try {
        if (pid == 0) {
            zygoteServer.setForkChild();
            zygoteServer.closeServerSocket();
            IoUtils.closeQuietly(serverPipeFd);
            serverPipeFd = null;

            return handleChildProc(parsedArgs, childPipeFd,
                    parsedArgs.mStartChildZygote);
        } else {
            IoUtils.closeQuietly(childPipeFd);
            childPipeFd = null;
            handleParentProc(pid, serverPipeFd);
            return null;
        }
    }
}
```

In the child process, `handleChildProc` is called:

```java
private Runnable handleChildProc(ZygoteArguments parsedArgs,
                FileDescriptor pipeFd, boolean isZygote) {
    closeSocket();
    if (!isZygote) {
        return ZygoteInit.zygoteInit(parsedArgs.mTargetSdkVersion,
                parsedArgs.mDisabledCompatChanges,
                parsedArgs.mRemainingArgs, null);
    } else {
        return ZygoteInit.childZygoteInit(
                parsedArgs.mRemainingArgs);
    }
}
```

For a normal application process, `parsedArgs.mRemainingArgs` contains the app entry point, typically:

```text
android.app.ActivityThread
```

So, just like in the `system_server` case, Zygote forks the process and then calls into the Java entry point, ultimately reaching `ActivityThread.main`.

At that point, the new process becomes the actual host process of the application.

---

## Summary

By this point, the major work of Zygote is clear:

- create the `AppRuntime` VM and register JNI functions
- call `ZygoteInit.main` and enter the Java world
- preload classes and resources
- create the Zygote socket server
- fork and prepare `system_server`
- start the Binder thread pool for `system_server`
- invoke `SystemServer.main` to start system services
- enter `runSelectLoop` and wait for app process creation requests
- fork app processes and invoke their Java entry points

Zygote is therefore not just a process launcher. It is the bridge from Android’s native boot world into the Java framework world, and it is also the common ancestor of both `system_server` and ordinary app processes.

---

## References

- https://www.kancloud.cn/alex_wsc/android_depp/412890
- https://blog.csdn.net/xingyu19911016/article/details/127686947