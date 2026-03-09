---
title: Init Process in Android
date: 2023-05-01 00:00:00
categories: Android
description: An overview of the Android init process, including first stage init, SELinux setup, property service, init.rc parsing, and Zygote startup
tags:
- Linux
---

## What Is the Init Process

`init` is the first process in user space in Linux, and it is also the first process in user space in Android.

During boot, the Android `init` process performs a number of critical tasks. The three most important ones are:

- creating and mounting the file systems and directories required during boot
- initializing and starting the property service
- parsing `init.rc` and starting the Zygote process

After the Linux kernel finishes loading, it looks for the system init program and starts the `init` process.

---

## Entry Function

In Android 10, the entry point of the `init` process was refactored. The logic was moved from `init.cpp` to `main.cpp`, and different stages of initialization were separated more clearly.

```cpp
int main(int argc, char** argv) {
    setpriority(PRIO_PROCESS, 0, -20);

    if (!strcmp(basename(argv[0]), "ueventd")) {
        return ueventd_main(argc, argv);
    }

    if (argc > 1) {
        if (!strcmp(argv[1], "subcontext")) {
            android::base::InitLogging(argv, &android::base::KernelLogger);
            const BuiltinFunctionMap& function_map = GetBuiltinFunctionMap();
            return SubcontextMain(argc, argv, &function_map);
        }

        if (!strcmp(argv[1], "selinux_setup")) {
            return SetupSelinux(argv);
        }

        if (!strcmp(argv[1], "second_stage")) {
            return SecondStageMain(argc, argv);
        }
    }

    return FirstStageMain(argc, argv);
}
```

By default, the system enters `FirstStageMain`, which starts the first stage of init.

---

## FirstStageMain

The first stage of init mainly handles:

- mounting partitions
- creating device nodes and important directories
- initializing kernel logging
- enabling SELinux

Example:

```cpp
int FirstStageMain(int argc, char** argv) {
    CHECKCALL(mount("tmpfs", "/dev", "tmpfs", MS_NOSUID, "mode=0755"));
    CHECKCALL(mount("devpts", "/dev/pts", "devpts", 0, NULL));
    CHECKCALL(mount("sysfs", "/sys", "sysfs", 0, NULL));
    CHECKCALL(mount("selinuxfs", "/sys/fs/selinux", "selinuxfs", 0, NULL));
    CHECKCALL(mount("tmpfs", "/mnt", "tmpfs", MS_NOEXEC | MS_NOSUID | MS_NODEV,
                "mode=0755,uid=0,gid=1000"));

    CHECKCALL(mkdir("/mnt/vendor", 0755));
    CHECKCALL(mkdir("/mnt/product", 0755));

    InitKernelLogging(argv);

    const char* path = "/system/bin/init";
    const char* args[] = {path, "selinux_setup", nullptr};
    auto fd = open("/dev/kmsg", O_WRONLY | O_CLOEXEC);
    dup2(fd, STDOUT_FILENO);
    dup2(fd, STDERR_FILENO);
    close(fd);
    execv(path, const_cast<char**>(args));

    return 1;
}
```

At this stage, Android mounts several runtime file systems such as:

- `tmpfs`
- `devpts`
- `sysfs`
- `selinuxfs`

These file systems exist only while the system is running.

It also creates directories such as:

- `/mnt/vendor`
- `/mnt/product`

Finally, it switches to the SELinux setup stage.

---

## SetupSelinux

After the first stage, init re-enters through `main.cpp` with the `selinux_setup` argument, which leads to `SetupSelinux`.

Its main responsibilities are:

- loading SELinux policy
- enabling SELinux enforcement
- switching to the second stage of init

```cpp
int SetupSelinux(char** argv) {
    if (IsMicrodroid()) {
        LoadSelinuxPolicyMicrodroid();
    } else {
        LoadSelinuxPolicyAndroid();
    }

    SelinuxSetEnforcement();

    const char* path = "/system/bin/init";
    const char* args[] = {path, "second_stage", nullptr};
    execv(path, const_cast<char**>(args));

    PLOG(FATAL) << "execv(\"" << path << "\") failed";
    return 1;
}
```

This passes the `second_stage` argument and enters `SecondStageMain`.

---

## SecondStageMain

The second stage handles the core system initialization logic, including:

- property system initialization
- SELinux-related path handling
- child process signal handling
- property service startup
- `init.rc` parsing

```cpp
int SecondStageMain(int argc, char** argv) {
    PropertyInit();
    InstallSignalFdHandler(&epoll);
    InstallInitNotifier(&epoll);
    StartPropertyService(&property_fd);
    LoadBootScripts(am, sm);
}
```

One important step here is `InstallSignalFdHandler`, which prevents child processes from becoming zombie processes. For example, if Zygote exits unexpectedly, init can detect that and restart the service.

---

## Property Service

The Android property service is a persistent key-value mechanism used to store system and runtime state.

It is used for:

- system configuration
- device information
- boot parameters
- service control

Even after a reboot, properties can still influence system behavior.

### PropertyInit

`PropertyInit` creates the property area and loads default property information.

```cpp
void PropertyInit() {
    mkdir("/dev/__properties__", S_IRWXU | S_IXGRP | S_IXOTH);
    CreateSerializedPropertyInfo();

    if (__system_property_area_init()) {
        LOG(FATAL) << "Failed to initialize property area";
    }

    if (!property_info_area.LoadDefaultPath()) {
        LOG(FATAL) << "Failed to load serialized property info file";
    }

    ProcessKernelDt();
    ProcessKernelCmdline();
    ProcessBootconfig();
    ExportKernelBootProps();
    PropertyLoadBootDefaults();
}
```

The property area is created under:

```cpp
#define PROP_FILENAME "/dev/__properties__"
```

---

## Starting the Property Service

The property service creates a socket and listens for property set requests.

```cpp
void StartPropertyService(int* epoll_socket) {
    InitPropertySet("ro.property_service.version", "2");

    int sockets[2];
    if (socketpair(AF_UNIX, SOCK_SEQPACKET | SOCK_CLOEXEC, 0, sockets) != 0) {
        PLOG(FATAL) << "Failed to socketpair() between property_service and init";
    }

    *epoll_socket = from_init_socket = sockets[0];
    init_socket = sockets[1];
    StartSendingMessages();

    if (auto result = CreateSocket(PROP_SERVICE_NAME, SOCK_STREAM | SOCK_CLOEXEC | SOCK_NONBLOCK,
                                   false, false, 0666, 0, 0, {});
        result.ok()) {
        property_set_fd = *result;
    } else {
        LOG(FATAL) << "start_property_service socket creation failed: " << result.error();
    }

    listen(property_set_fd, 8);

    auto new_thread = std::thread{PropertyServiceThread};
    property_service_thread.swap(new_thread);
}
```

The socket name is:

```cpp
#define PROP_SERVICE_NAME "property_service"
```

Requests are monitored with `epoll`.

---

## Handling Property Data

When a property request arrives, init processes it through `handle_property_set_fd`.

There are two major types of Android properties:

- **normal properties**: used to describe device or system information, such as vendor or model
- **control properties**: used to trigger actions such as starting or stopping a service, usually prefixed with `ctl.`

Example flow:

```cpp
static void handle_property_set_fd() {
    switch (cmd) {
    case PROP_MSG_SETPROP:
    case PROP_MSG_SETPROP2: {
        std::string name;
        std::string value;

        const auto& cr = socket.cred();
        std::string error;
        auto result = HandlePropertySet(name, value, source_context, cr, &socket, &error);
        if (!result) {
            return;
        }

        if (*result != PROP_SUCCESS) {
            LOG(ERROR) << "Unable to set property '" << name << "'";
        }
    }
    }
}
```

The actual property setting logic is handled in `HandlePropertySet` and `PropertySet`.

Key steps include:

- checking permissions
- detecting special control properties
- validating property names and values
- updating or adding properties in the property area
- notifying listeners of property changes

Example:

```cpp
static std::optional<uint32_t> PropertySet(const std::string& name, const std::string& value,
                                           SocketConnection* socket, std::string* error) {
    if (!IsLegalPropertyName(name)) {
        *error = "Illegal property name";
        return {PROP_ERROR_INVALID_NAME};
    }

    if (auto result = IsLegalPropertyValue(name, value); !result.ok()) {
        *error = result.error().message();
        return {PROP_ERROR_INVALID_VALUE};
    }

    prop_info* pi = (prop_info*)__system_property_find(name.c_str());
    if (pi != nullptr) {
        if (StartsWith(name, "ro.")) {
            *error = "Read-only property was already set";
            return {PROP_ERROR_READ_ONLY_PROPERTY};
        }

        __system_property_update(pi, value.c_str(), value.size());
    } else {
        int rc = __system_property_add(name.c_str(), name.size(), value.c_str(), value.size());
        if (rc < 0) {
            *error = "__system_property_add failed";
            return {PROP_ERROR_SET_FAILED};
        }
    }

    NotifyPropertyChange(name, value);
    return {PROP_SUCCESS};
}
```

A special rule applies to properties starting with `ro.`: they are write-once and cannot be modified after being set.

Common tools include:

- `adb shell getprop`
- `adb shell setprop`

Important property files include:

- `/default.prop`
- `/system/build.prop`

---

## Parsing init.rc and Starting Zygote

During the second stage, init parses the boot scripts, especially `init.rc`.

An `init.rc` file typically contains several kinds of sections:

- **Action**
- **Command**
- **Service**
- **Option**
- **Import**

### Action

Actions are triggered by conditions and begin with `on`, for example:

- `on early-init`
- `on init`
- `on late-init`
- `on boot`
- `on charger`
- `on property`

### Service

A service is started by the init process, usually through `fork`.

### Command

Examples include:

- `class_start <service_class_name>`
- `start <service_name>`
- `stop <service_name>`
- `setprop`
- `mkdir`
- `exec`

### Option

Options are used together with a service, for example:

- `disabled`
- `oneshot`
- `user`
- `group`
- `class`

---

## Loading Boot Scripts

Boot scripts are loaded through `LoadBootScripts`.

```cpp
static void LoadBootScripts(ActionManager& action_manager, ServiceList& service_list) {
    Parser parser = CreateParser(action_manager, service_list);

    std::string bootscript = GetProperty("ro.boot.init_rc", "");
    if (bootscript.empty()) {
        parser.ParseConfig("/system/etc/init/hw/init.rc");
        parser.ParseConfig("/system/etc/init");
        parser.ParseConfig("/system_ext/etc/init");
        parser.ParseConfig("/vendor/etc/init");
        parser.ParseConfig("/odm/etc/init");
        parser.ParseConfig("/product/etc/init");
    } else {
        parser.ParseConfig(bootscript);
    }
}
```

The parser is configured to handle different section types:

```cpp
Parser CreateParser(ActionManager& action_manager, ServiceList& service_list) {
    Parser parser;

    parser.AddSectionParser("service", std::make_unique<ServiceParser>(
                                               &service_list, GetSubcontext(), std::nullopt));
    parser.AddSectionParser("on", std::make_unique<ActionParser>(&action_manager, GetSubcontext()));
    parser.AddSectionParser("import", std::make_unique<ImportParser>(&parser));

    return parser;
}
```

---

## Starting Zygote

In `init.rc`, the command `class_start main` starts all services whose class is `main`.

Example:

```rc
on nonencrypted
    class_start main
    class_start late_start
```

This corresponds to the `do_class_start` implementation:

```cpp
static Result<void> do_class_start(const BuiltinArguments& args) {
    for (const auto& service : ServiceList::GetInstance()) {
        if (service->classnames().count(args[1])) {
            if (auto result = service->StartIfNotDisabled(); !result.ok()) {
                LOG(ERROR) << "Could not start service '" << service->name() << "'";
            }
        }
    }
    return {};
}
```

If a service is not disabled, init starts it:

```cpp
Result<void> Service::StartIfNotDisabled() {
    if (!(flags_ & SVC_DISABLED)) {
        return Start();
    } else {
        flags_ |= SVC_DISABLED_START;
    }
    return {};
}
```

---

## Zygote Service Definition

A typical Zygote configuration can be found in `init.zygote64.rc`:

```rc
service zygote /system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote
    class main
    priority -20
    user root
    group root readproc reserved_disk
    socket zygote stream 660 root system
    socket usap_pool_primary stream 660 root system
    onrestart restart audioserver
    onrestart restart cameraserver
    onrestart restart media
    onrestart restart netd
    onrestart restart wificond
    task_profiles ProcessCapacityHigh MaxPerformance
    critical window=${zygote.critical_window.minute:-off} target=zygote-fatal
```

Since the service belongs to `class main`, it will be started during `class_start main`.

The process launched is:

```bash
/system/bin/app_process64 -Xzygote /system/bin --zygote --start-system-server --socket-name=zygote
```

---

## Zygote Entry Point

The Zygote entry point is in `app_main.cpp`.

```cpp
int main(int argc, char* const argv[])
{
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

Because the process is started with `--zygote --start-system-server`, it launches:

```java
com.android.internal.os.ZygoteInit
```

with `startSystemServer = true`.

---

## Summary

At this point, the main responsibilities of the Android init process have been completed:

- mounting partitions, creating device nodes and key directories, initializing logging, and enabling SELinux
- initializing the property service
- parsing `init.rc` and starting the Zygote process

These steps form the foundation of the Android boot process and prepare the system for launching higher-level framework services.

---

## References

- https://www.kancloud.cn/alex_wsc/android_depp/412880
- https://blog.csdn.net/xingyu19911016/article/details/127451545
- https://blog.csdn.net/yang_study_first/article/details/134229794
- https://blog.csdn.net/Jacinth40/article/details/136294510