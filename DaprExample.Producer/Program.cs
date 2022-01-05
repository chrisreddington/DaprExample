// Use the Dapr Client .NET SDK
using Dapr.Client;

// Set up the appropriate binding information
string BINDING_NAME = "azurebusbinding";
string BINDING_OPERATION = "create";

// Initialise the counter to 0 and init the Dapr Client
var daprClient = new DaprClientBuilder().Build();
var counter = 0;

// Keep looping every second, create a message by invoking the binding.
while (true)
{
    await daprClient.InvokeBindingAsync(BINDING_NAME, BINDING_OPERATION, counter);
    await Task.Delay(200);
}