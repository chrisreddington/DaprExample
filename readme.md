# Dapr and KEDA examples

This project contains examples for Dapr and KEDA. They are not to be considered production ready, but examples to support a user's understanding of the concepts.

## Components
* A frontend application that returns the hostname of the current machine. In the case of container apps, it would be the instance of the container.
* A producer applications that puts messages onto a queue
* A consumer application that takes messages from the queue
* Several Bicep files to deploy these to Azure. These Bicep files depend on several existing resources to be created.
  * TODO: Add a separate ARM template to deploy the pre-requisites.

# Run the demo locally

Firstly, you need to make sure that you have dapr configured on your local environment.

```bash
dapr init
```

Configure the components in a ``.components`` subfolder of your project or the ``~/.dapr/components`` directory.

> **Note:** If you use the subfolder approach, you will need to add a ``--components-path`` flag to the below ``dapr run`` commands (as [per the documentation](https://docs.dapr.io/reference/cli/dapr-run/)).

Examples of the components can be found in the ``DaprExample.Manifests`` folder of this repository. Further documentation on the YAML schema for components is available on each of the component's respective documentation pages.

* [Binding Component: Azure Service Bus Queues](https://docs.dapr.io/reference/components-reference/supported-bindings/servicebusqueues/)
* [Binding Component: Azure Storage Queues](https://docs.dapr.io/reference/components-reference/supported-bindings/storagequeues/)

## Producer

To run the producer, run the following command:

```bash
dapr run --app-id producer dotnet run
```

## Consumer

To run the consumer, run the following command:

```bash
dapr run --app-id consumer --app-port 5002 dotnet run
```
# Run the demo on Azure

There are several Bicep files available in the ``InfrastructureSetup/ContainerApps`` folder, and can be used to deploy the example as a Container App to Azure.

Before hand, you will need to push each of the applications (e.g. ``frontend``, ``producer`` and ``consumer``) as a Docker Image to Azure.

You will also need to create the pre-requisite resources (e.g. Azure Container Registry, Azure Service Bus, Azure Storage Queue, etc.).

This is a to-do item for this sample, and welcomes any contributions.

# License

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./License)