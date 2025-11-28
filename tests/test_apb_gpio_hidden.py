# harness/test_apb_gpio_with_secret_toggle.py
import random
import cocotb  # type: ignore
from cocotb.triggers import RisingEdge, Timer  # type: ignore
from cocotb.clock import Clock  # type: ignore


async def apb_write(dut, data):
    """Perform a single APB write transaction."""
    dut.psel.value    = 1
    dut.penable.value = 0
    dut.pwrite.value  = 1
    dut.pwdata.value  = data

    # Setup phase
    await RisingEdge(dut.pclk)

    # Access phase
    dut.penable.value = 1
    await RisingEdge(dut.pclk)

    # Wait for ready
    while dut.pready.value == 0:
        await RisingEdge(dut.pclk)

    # Idle state
    dut.psel.value    = 0
    dut.penable.value = 0
    dut.pwrite.value  = 0


@cocotb.test()
async def test_secret_toggle(dut):
    """Random APB noise + magic sequence → secret_pin should toggle."""
    cocotb.start_soon(Clock(dut.pclk, 10, 'ns').start())

    # Reset
    dut.presetn.value = 0
    await Timer(20, 'ns')
    dut.presetn.value = 1
    await RisingEdge(dut.pclk)

    initial_pin = dut.secret_pin.value.integer

    # Thousands of random writes
    for _ in range(2000):
        if random.random() < 0.1:
            await apb_write(dut, random.randint(0, 255))
        await RisingEdge(dut.pclk)

    # Hidden directed sequence
    await apb_write(dut, 0x55)
    for _ in range(3):
        await RisingEdge(dut.pclk)

    await apb_write(dut, 0xAA)
    for _ in range(3):
        await RisingEdge(dut.pclk)

    await apb_write(dut, 0x5A)

    # Wait a few cycles and check for toggle
    for _ in range(10):
        await RisingEdge(dut.pclk)
        if dut.secret_pin.value.integer != initial_pin:
            return  # PASS

    # FAIL if it never toggled
    raise cocotb.result.TestFailure(
        "secret_pin never toggled — magic sequence not detected"
    )


# ✅ CRITICAL: Pytest wrapper function
def test_apb_gpio_hidden_runner():
    import os
    from pathlib import Path
    from cocotb_tools.runner import get_runner
    
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    
    sources = [proj_path / "sources/apb_gpio_with_secret_toggle.sv"]
    
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="apb_gpio_with_secret_toggle",
        always=True,
    )
    runner.test(
        hdl_toplevel="apb_gpio_with_secret_toggle",
        test_module="test_apb_gpio_hidden"
    )

