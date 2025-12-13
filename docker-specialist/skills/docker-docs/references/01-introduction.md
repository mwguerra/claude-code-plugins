# Introduction to Docker & Docker Compose

Docker is a containerization platform that packages applications and their dependencies into isolated units called containers. Docker Compose extends this by orchestrating multi-container applications through declarative YAML configuration.

## Key Concepts

| Concept | Description |
|---------|-------------|
| **Image** | Read-only template containing instructions for creating a container |
| **Container** | Running instance of an image with its own filesystem and network |
| **Dockerfile** | Text file with instructions to build a Docker image |
| **Docker Compose** | Tool for defining and running multi-container applications |
| **Volume** | Persistent storage mechanism that survives container restarts |
| **Network** | Communication layer enabling container-to-container communication |

## When to Use Docker

- **Development Environments**: Consistent environments across team members
- **Microservices**: Isolate services with their dependencies
- **CI/CD**: Reproducible builds and deployments
- **Legacy Apps**: Containerize older applications
- **Testing**: Isolated testing environments

## Docker vs Docker Compose

| Aspect | Docker | Docker Compose |
|--------|--------|----------------|
| **Scope** | Single container | Multi-container applications |
| **Configuration** | Command-line flags | YAML file |
| **Use Case** | Simple apps, debugging | Complex applications |
| **Networking** | Manual setup | Automatic service discovery |
| **Volumes** | Manual management | Declarative configuration |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                     Docker Host                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Docker Engine                       │    │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐   │    │
│  │  │ Container │  │ Container │  │ Container │   │    │
│  │  │   App 1   │  │   App 2   │  │    DB     │   │    │
│  │  └───────────┘  └───────────┘  └───────────┘   │    │
│  │        │              │              │          │    │
│  │  ┌─────┴──────────────┴──────────────┴─────┐   │    │
│  │  │              Docker Network             │   │    │
│  │  └───────────────────────────────────────┘    │    │
│  │  ┌───────────┐  ┌───────────┐                 │    │
│  │  │  Volume   │  │  Volume   │                 │    │
│  │  │   Data    │  │   Logs    │                 │    │
│  │  └───────────┘  └───────────┘                 │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Version Information

- **Docker Compose Version:** v2.x (Compose Specification)
- The `version` field is deprecated since Docker Compose v1.27.0 (2020)
- Modern compose files start directly with `services`
