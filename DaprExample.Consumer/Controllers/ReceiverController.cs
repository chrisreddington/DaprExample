using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using DaprExample.Consumer.Models;
using Dapr;
using Dapr.Client;

namespace DaprExample.Consumer.Controllers;

[ApiController]
public class ReceiverController : Controller
{
    private readonly ILogger<ReceiverController> _logger;


    public ReceiverController(ILogger<ReceiverController> logger)
    {
        _logger = logger;
    }


    [HttpPost("/azurebusnosecrets")]
    public ActionResult<string> getCheckout([FromBody] int orderId)
    {
        _logger.LogInformation("Received Message: " + orderId);
        return Ok("CID" + orderId);
    }
}
