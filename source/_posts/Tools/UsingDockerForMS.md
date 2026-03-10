---
title: Docker Notes from My Project
date: 2026-03-10 14:17:00
categories: Tools
description: Some practical notes on using Docker and Docker Compose to manage services in a development environment
tags:
- Docker
---

## Project Background

The project discussed in this article is available here: [FinTrack](https://github.com/liananddandan/FinTrack-Microservices)

FinTrack is a microservices-based backend system. The services are separated into multiple independent components and communicate through APIs and message queues.

During early development, everything was started manually. Each service needed to run in its own terminal, and several external services were also required, such as databases and message brokers.

This quickly became inconvenient.

For example, starting the system locally often required opening multiple terminals and running different commands for each service. In addition, the project depended on several infrastructure components. Managing and starting all of them manually was tedious and error-prone.

Another problem appeared when demonstrating the project. Launching each service one by one was not an ideal workflow.

This is where Docker becomes useful.

By containerizing the services and their dependencies, the entire system can be started in a consistent way. With tools such as Docker Compose, multiple services can be launched together with a single command.

For a microservices project, this greatly simplifies both local development and project demonstration.

## Common Docker Compose Commands

In daily development, only a few Docker Compose commands are used frequently. Most of the time, managing containers revolves around starting, stopping, and rebuilding services.

- ### docker compose up
The most common command is:
```
docker compose up
```
This starts the services defined in the `docker-compose.yml` file.
Two options are commonly used:
```
docker compose up -d --build
```

- `-d` runs the containers in detached mode (in the background).
- `--build` forces Docker to rebuild images before starting the containers.

This is useful when the source code or Dockerfile has changed.

- ### docker compose down

docker compose down

This stops and removes the containers, networks, and default resources created by the Compose project.

Sometimes volumes are also removed:

docker compose down -v

The `-v` option removes the volumes associated with the containers.

- ### docker compose start

docker compose start

This command starts containers that already exist but are currently stopped.

It does not rebuild images or recreate containers.

- ### docker compose stop

docker compose stop

This stops the running containers but does not remove them. The containers can later be restarted using `docker compose start`.

- ### docker compose -f

Sometimes multiple compose files are used. In that case, the `-f` option allows specifying the compose file manually.

Example:

docker compose -f docker-compose.dev.yml up -d

This tells Docker Compose to use a specific configuration file instead of the default `docker-compose.yml`.

## Dockerfile Example

Below is the Dockerfile used to build the IdentityService.

```dockerfile
# ---------- build stage ----------
# Use the .NET SDK image as the build environment
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Set the working directory inside the container to /src
# After this line, all following commands (COPY, RUN, etc.)
# will use /src as their base directory
WORKDIR /src

# Copy the solution file into the container build environment
# The destination "./" means the current WORKDIR, which is /src
COPY FinTrack.sln ./

# Copy project files (csproj) into the container
# These paths are relative to the current WORKDIR (/src)
COPY src/Services/IdentityService/IdentityService.csproj src/Services/IdentityService/
COPY src/Shared/SharedKernel/SharedKernel.csproj src/Shared/SharedKernel/

# Restore NuGet dependencies for the project
RUN dotnet restore src/Services/IdentityService/IdentityService.csproj

# Copy the full source code into the container
# "." means the build context root on the host
# "." as the destination means the current WORKDIR (/src)
COPY . .

# Publish the application
# The compiled output will be placed in /app/publish inside the container
RUN dotnet publish src/Services/IdentityService/IdentityService.csproj \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false


# ---------- runtime stage ----------
# Use a lighter ASP.NET runtime image for running the application
FROM mcr.microsoft.com/dotnet/aspnet:9.0

# Set the runtime working directory inside the container
# The application will run from /app
WORKDIR /app

# Copy the published output from the build stage
# "/app/publish" refers to the path inside the build stage container
# "." means the current WORKDIR (/app) in this runtime stage
COPY --from=build /app/publish .

# Configure ASP.NET Core to listen on port 8080 inside the container
ENV ASPNETCORE_URLS=http://+:8080

# Document that the container exposes port 8080
EXPOSE 8080

# When the container starts, run the service
ENTRYPOINT ["dotnet", "IdentityService.dll"]
```

## Docker Compose File example
```yaml
version: '3.9'
services:

  # ========================
  # Infrastructure services
  # These are shared components used by backend services
  # ========================

  mysql:
    image: mysql:8.0
    container_name: fintrack-mysql
    environment:
      MYSQL_ROOT_PASSWORD: 123456
      MYSQL_DATABASE: fintrack_identity
    ports:
      - "3307:3306" # host:container
    volumes:
      - mysql_data:/var/lib/mysql # persist database data outside container
    healthcheck:
      # wait until MySQL is ready before dependent services start
      test: ["CMD","mysqladmin","ping","-h","localhost","-p123456"]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: redis:latest
    container_name: fintrack-redis
    ports:
      - "6379:6379"

  rabbitmq:
    image: rabbitmq:3-management
    container_name: fintrack-rabbitmq
    ports:
      - "5672:5672"     # message broker port
      - "15672:15672"   # management UI
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    healthcheck:
      # ensure RabbitMQ is ready before services depending on it start
      test: ["CMD","rabbitmq-diagnostics","ping"]
      interval: 10s
      timeout: 5s
      retries: 10

  mailhog:
    image: mailhog/mailhog
    container_name: fintrack-mailhog
    ports:
      - "1025:1025"  # SMTP port
      - "8025:8025"  # MailHog web UI


  # ========================
  # Backend microservices
  # Each service is built from its own Dockerfile
  # ========================

  identity-service:
    build:
      context: .
      dockerfile: src/Services/IdentityService/Dockerfile
    container_name: fintrack-identity
    depends_on:
      mysql:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
      redis:
        condition: service_started
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      ASPNETCORE_URLS: http://+:8080

      # Docker Compose automatically creates a network
      # Services can reach each other using service names as hostnames

      ConnectionStrings__DefaultConnection: server=mysql;port=3306;database=fintrack_identity;user=root;password=123456
      ConnectionStrings__Redis: redis:6379
      RabbitMQ__Host: rabbitmq
    ports:
      - "5100:8080"

  transaction-service:
    build:
      context: .
      dockerfile: src/Services/TransactionService/Dockerfile
    container_name: fintrack-transaction
    depends_on:
      mysql:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      ASPNETCORE_URLS: http://+:8080
      ConnectionStrings__DefaultConnection: server=mysql;port=3306;database=fintrack_transaction;user=root;password=123456
      RabbitMQ__Host: rabbitmq
    ports:
      - "5101:8080"

  auditlog-service:
    build:
      context: .
      dockerfile: src/Services/AuditLogService/Dockerfile
    container_name: fintrack-auditlog
    depends_on:
      mysql:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      ASPNETCORE_URLS: http://+:8080
      ConnectionStrings__DefaultConnection: server=mysql;port=3306;database=fintrack_auditlog;user=root;password=123456
      RabbitMQ__Host: rabbitmq
    ports:
      - "5102:8080"

  notification-service:
    build:
      context: .
      dockerfile: src/Services/NotificationService/Dockerfile
    container_name: fintrack-notification
    depends_on:
      rabbitmq:
        condition: service_healthy
      mailhog:
        condition: service_started
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      ASPNETCORE_URLS: http://+:8080
      RabbitMQ__Host: rabbitmq
      SMTP__Host: mailhog
      SMTP__Port: 1025
    ports:
      - "5103:8080"


  # ========================
  # API Gateway
  # Acts as the entry point for backend APIs
  # ========================

  gateway:
    build:
      context: .
      dockerfile: src/Services/GatewayService/Dockerfile
    container_name: fintrack-gateway
    depends_on:
      identity-service:
        condition: service_started
      transaction-service:
        condition: service_started
      auditlog-service:
        condition: service_started
      notification-service:
        condition: service_started
      redis:
        condition: service_started
    environment:
      ASPNETCORE_ENVIRONMENT: Development
      ASPNETCORE_URLS: http://+:8080

      # Redis used for caching
      ConnectionStrings__Redis: redis:6379

      # Reverse proxy routing configuration
      ReverseProxy__Clusters__identityCluster__Destinations__identity__Address: http://identity-service:8080/
      ReverseProxy__Clusters__transactionCluster__Destinations__transaction__Address: http://transaction-service:8080/
      ReverseProxy__Clusters__auditlogCluster__Destinations__destination1__Address: http://auditlog-service:8080/
    ports:
      - "5193:8080"


  # ========================
  # Frontend applications
  # ========================

  web-portal:
    build:
      context: ./apps/web-portal
      dockerfile: Dockerfile
    container_name: fintrack-web-portal
    depends_on:
      gateway:
        condition: service_started
    ports:
      - "3000:80"

  web-admin:
    build:
      context: ./apps/web-admin
      dockerfile: Dockerfile
    container_name: fintrack-web-admin
    depends_on:
      gateway:
        condition: service_started
    ports:
      - "3001:80"


# ========================
# Named volumes
# Used to persist database data
# ========================

volumes:
  mysql_data:
```

## Some Practical Notes

These concepts are simple, but understanding their boundaries helps avoid many common Docker misunderstandings.

When using Docker in a microservice project, it is helpful to clearly understand the scope of several concepts: images, containers, and networks.

### Image vs Container

An **image** is a packaged environment that contains the application and everything it needs to run.

A **container** is a running instance of that image.

In other words:

image → blueprint  
container → running process

Multiple containers can be created from the same image.

### Container Network

When using Docker Compose, all services are placed on the same internal Docker network.

Inside this network, containers can communicate using **service names as hostnames**.

For example:

identity-service can reach MySQL using:

mysql:3306

This works because Docker Compose automatically creates an internal network and provides DNS resolution between services.

### Container vs Host

Containers run in an isolated environment.

Services inside containers are **not automatically accessible from the host machine** unless a port is exposed.

For example:

ports:
  - "5100:8080"

This means:

host:5100 → container:8080

After this mapping, the service can be accessed from the host machine using:

http://localhost:5100

### Container vs Server

In development, containers run on the local machine.

In production, the same images can run on a remote server or cloud environment.

Since the application and its dependencies are packaged inside the image, the runtime environment remains consistent.