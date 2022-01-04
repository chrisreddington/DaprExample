using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using DaprExample.Consumer.Models;
using Dapr;
using Dapr.Client;

namespace DaprExample.Consumer.Controllers;

[ApiController]
public class ReceiverController : Controller
{
    [HttpPost("/azurebusbinding")]
    public ActionResult<string> getCheckout([FromBody] int orderId)
    {
        Console.WriteLine("Received Message: " + orderId);
        return Ok("CID" + orderId);
    }
}
