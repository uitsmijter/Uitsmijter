# Uitsmijter

![image](Graphics/Logo/uitsmijter-horizontal-color.svg)

**A versatile authorization middleware for Traefik2 with a complete OAuth2 SSO solution without an own user database.**

## Description

Pluggable SSO implementation for your existing projects and the best starting point for new projects.

[Providers](https://docs.uitsmijter.io/providers/) connect Uitsmijter with an existing user database.

Uitsmijter is a standalone OAuth2 authorization server with embedded middleware that provides login mechanisms to your
project without changing the existing user database.

The goal of this project is to bring trustworthy and easy-to-integrate security to your project, within a few hours from
installation, configuration and implementation to go-live.

## Features

- **OAuth2/OIDC Compliant** - Full OAuth2 authorization server with OpenID Connect support
- **Pluggable Authentication** - JavaScript-based providers connect to any existing user database
- **Multi-Tenant Architecture** - Support multiple organizations with custom login templates
- **Traefik2 Integration** - Drop-in forward auth middleware
- **Kubernetes-Native** - Custom Resource Definitions (CRDs) for configuration
- **Redis-Backed Sessions** - Scalable session management with Redis support
- **Prometheus Metrics** - Built-in monitoring and observability
- **Zero Database Migration** - Works with your existing user storage

## Goals

- Easy migration from monolithic to microservice architecture
- Move from single application login to distributed OAuth2 flow in one day
- Fast implementation and go-live within hours
- High reliability and OAuth2 compatibility
- Fast response times with low memory and CPU consumption

[Read more about Uitsmijter](https://docs.uitsmijter.io/general/about/) and visit our
[articles page](https://articles.uitsmijter.io) to stay up to date.

## About the name
Uitsmijter is a popular breakfast, brunch and lunch dish in the Netherlands. The ingredients are put on top of each 
other, finishing with a fried egg on top that covers the ham and the cheese.

Legend goes that this dish used to be served late at night, just before the guests are kicked out at closing time, 
which may explain why the Dutch name for this dish, “uitsmijter,” means “bouncer” or “doorman” in english.

We found this is an excellent name for the product, because it is put on top of your existing products 
(the ham and the cheese) and makes everything more delicious. The english translation bouncer makes perfect sense, 
because the applications inside no longer have to worry about their security. The bouncer will keep uninvited guests 
outside.

## Motivation
We have treated it as normal that migration projects take a long time and involve a lot of risk. Uitsmijter hits a 
pretty crowded market of authorisation servers, but fills the need that migrations from a monolith into a microservice 
architecture should be nice and comfortable.

With Uitsmijter it is no longer a hurdle to implement secure and modern authentication methods. The product supports 
the developers in every project phase. It is such a pleasure to work with Uitsmijter that it makes sense to build new 
projects upon it, because the flexibility that is needed for smooth migrations are the successors of new ideas.

You may want to read the full [motivation page](https://docs.uitsmijter.io/general/motivation/) to get a deeper 
understanding of why we are building Uitsmijter from the ground up.

## Technology Stack

- **Language**: Swift 6.2
- **Web Framework**: Vapor 4
- **Session Storage**: Redis (production) / In-Memory (development)
- **Template Engine**: Leaf
- **JavaScript Runtime**: JXKit for pluggable providers
- **Deployment**: Docker, Kubernetes with Helm charts
- **Metrics**: Prometheus with SwiftPrometheus

## Requirements

- **Swift**: 6.2 or later
- **Platform**: macOS 13+ or Linux
- **Docker**: For containerized development and deployment
- **Redis**: For production session storage (optional for development)
- **Kubernetes**: For production deployment (optional)

## Installation

### Production Deployment

Uitsmijter comes with Helm packages for Kubernetes deployment:

```bash
# Add Helm repository
helm repo add uitsmijter https://charts.uitsmijter.io
helm repo update

# Install Uitsmijter
helm install uitsmijter uitsmijter/uitsmijter
```

See the [installation documentation](https://docs.uitsmijter.io/configuration/helm/) for detailed configuration options.

### Development Setup

```bash
# Clone the repository
git clone git@github.com:uitsmijter/Uitsmijter.git
cd Uitsmijter

# Build the project
./tooling.sh build

# Run tests
./tooling.sh test

# Run locally in Docker (standalone)
./tooling.sh run
# Access at http://localhost:8080

# Run in local Kubernetes cluster (full environment)
./tooling.sh run-cluster --dirty
```

## Development

### Available Commands

The `./tooling.sh` script provides all development commands:

```bash
# Building
./tooling.sh build              # Build the project
./tooling.sh release            # Build release version

# Testing
./tooling.sh test               # Run all tests
./tooling.sh test <filter>      # Run specific test
./tooling.sh list-tests         # List all available tests
./tooling.sh e2e                # Run end-to-end tests
./tooling.sh e2e --fast         # Run E2E tests on Chromium only

# Code Quality
./tooling.sh lint               # Run SwiftLint checks

# Deployment
./tooling.sh run                # Run in Docker (standalone)
./tooling.sh run-cluster        # Run in local Kubernetes cluster
./tooling.sh helm               # Build Helm package

# Cleanup
./tooling.sh remove             # Remove build artifacts and Docker resources
```

### Direct Swift Commands

```bash
# Build with Swift Package Manager
swift build

# Run all tests
swift test

# Run specific tests
swift test --filter <TestName>
```

### Project Structure

```
Sources/
├── Uitsmijter/              # Application entry point
├── Uitsmijter-AuthServer/   # Core authorization server
│   ├── Controllers/         # HTTP request handlers
│   ├── Entities/            # Tenant and Client configuration
│   ├── ScriptingProvider/   # JavaScript provider system
│   ├── OAuth/               # OAuth2 flow implementation
│   └── JWT/                 # JWT token handling
├── Logger/                  # Structured logging system
└── FoundationExtensions/    # Swift Foundation utilities

Tests/
└── Uitsmijter-AuthServerTests/  # Unit tests

Deployment/
├── e2e/                     # End-to-end tests
├── helm/                    # Helm charts
├── Uitsmijter.Dockerfile    # Main application image
└── Runtime.Dockerfile       # Runtime base image
```

### Environment Configuration

Create a `.env` file in the project root for local development:

```bash
LOG_LEVEL=debug              # trace, debug, info, warning, error
LOG_FORMAT=console           # console or json
ENVIRONMENT=development      # development or production
REDIS_HOST=localhost         # Redis server hostname
REDIS_PASSWORD=              # Redis password (if required)
```

## Documentation

- **Main Documentation**: [docs.uitsmijter.io](https://docs.uitsmijter.io)
- **Articles & Updates**: [articles.uitsmijter.io](https://articles.uitsmijter.io)
- **Tooling Guide**: [docs.uitsmijter.io/contribution/tooling/](https://docs.uitsmijter.io/contribution/tooling/)
- **API Documentation**: Generated with Swift-DocC


## Community

- **Mastodon**: Follow us at [social.uitsmijter.io](https://social.uitsmijter.io/public/local)
- **Discourse**: Join discussions at [discourse.uitsmijter.io](http://discourse.uitsmijter.io)
- **GitHub**: [github.com/uitsmijter/Uitsmijter](https://github.com/uitsmijter/Uitsmijter)

## Contributing

We welcome contributions! Here's how you can help:

### Reporting Issues

- **Feature Requests**: [Create an issue](https://github.com/uitsmijter/Uitsmijter/issues/new) explaining your idea
- **Bug Reports**: [Create an issue](https://github.com/uitsmijter/Uitsmijter/issues/new) with reproduction steps
- **Security Vulnerabilities**: Email [security@uitsmijter.io](mailto:security@uitsmijter.io) immediately

### Development Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following our code quality standards
4. Run tests and linting: `./tooling.sh test && ./tooling.sh lint`
5. Commit your changes
6. Push to your branch
7. Open a Pull Request

### Code of Conduct

We are committed to fostering an open and welcoming environment. We pledge to make participation in our project and community a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

Copyright 2023-2025, aus der Technik Simon & Sinon GbR
