# Uitsmijter

![image](Graphics/Logo/uitsmijter-horizontal-color.svg)

**A versatile authorisation middleware for Traefik2 with an A complete oauth2 SSO solution without an own user-database.**

## Description

Pluggable SSO implementation for your existing projects and the best starting point for new projects.

[Providers](https://docs.uitsmijter.io/providers/) connect Uitsmijter with an existing user database.

Uitsmijter is a standalone OAuth2 authorization server with embedded middleware that provides login mechanisms to your 
project without changing the existing user database.

The goal of this project is to bring trustworthy and easy-to-integrate security to your project, within a few hours from 
installation, configuration and implementation to go-live.

Main goals of the project:

- Easy migration
- Move from a single application login to a distributed OAuth 2 flow for many kinds of applications in just one day
- Fast implementation
- Reliability
- OAuth 2 compatibility
- Fast response times
- Low Memory and CPU consumption

[Read more about Uitsmijter](https://docs.uitsmijter.io/general/about/)

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

## Documentation
The documentation can be found at [docs.uitsmijter.io](https://docs.uitsmijter.io)

## Installation
Uitsmijter comes with helm packages. The installation is described in detail on 
the [documentation page](https://docs.uitsmijter.io/configuration/helm/)

## Quickstart for developers
Checkout the project and get familiar with the [tooling](https://docs.uitsmijter.io/contribution/tooling/).

To run Uitsmijter locally in a test environment just build and run it: 
```shell
$ ./tooling.sh run-cluster --dirty
```
Follow the instructions in the terminal to access the test cluster.

To run the current source in docker as a standalone application without kubernetes: 
```shell
$ ./tooling.sh run
```
Go to the standard login page at http://localhost:8080


## Community
Coming soon. 

## Contribution
To contribute a feature or idea to Uitsmijter, [create an issue](https://github.com/uitsmijter/Uitsmijter/issues/new) 
explaining your idea.

If you find a bug, please [create an issue](https://github.com/uitsmijter/Uitsmijter/issues/new).

If you find a security vulnerability, please contact [security@uitsmijter.io](mailto:security@uitsmijter.io) as soon as 
possible.

In the interest of fostering an open and welcoming environment, we as contributors and maintainers pledge to making participation in our project and our community a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

**A contribution is greatly appreciated.**


