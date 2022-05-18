# Run locally

```bash
dapr init
```

Configure the components in your .components folder of the dapr directory.

# Producer

```bash
dapr run --app-id producer dotnet run
```

# Consumer

```bash
dapr run --app-id consumer --app-port 5002 dotnet run
```
