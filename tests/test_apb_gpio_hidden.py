import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock


async def apb_write(dut, addr: int, data: int):
    """Perform a single APB write transaction."""
    dut.psel.value = 1
    dut.pwrite.value = 1
    dut.penable.value = 0
    dut.paddr.value = addr
    dut.pwdata.value = data

    # Setup phase
    await RisingEdge(dut.pclk)

    # Enable phase
    dut.penable.value = 1
    await RisingEdge(dut.pclk)

    # Idle phase
    dut.psel.value = 0
    dut.penable.value = 0
    await RisingEdge(dut.pclk)


@cocotb.test()
async def test_secret_toggle(dut):
    """Test secret pin toggle with magic sequence."""
    
    # ----- Clock generator -----
    cocotb.start_soon(Clock(dut.pclk, 10, unit="ns").start())  # Fixed: units -> unit

    # ----- Reset -----
    dut.psel.value = 0
    dut.penable.value = 0
    dut.pwrite.value = 0
    dut.paddr.value = 0
    dut.pwdata.value = 0

    dut.presetn.value = 0
    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)
    dut.presetn.value = 1
    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)  # Extra clock to let signal stabilize

    # Capture initial secret_pin value (should be 0 after reset)
    # Handle 'X' case if signal not yet initialized
    try:
        initial_pin = int(dut.secret_pin.value)
    except ValueError:
        # If signal is 'X', assume it's 0 (default after reset)
        initial_pin = 0
        dut._log.info("Secret pin was 'X', assuming 0")
    
    dut._log.info(f"Initial secret pin: {initial_pin}")

    # -------- Magic sequence (0x55 -> 0xAA -> 0x5A) --------
    await apb_write(dut, 0x0, 0x55)
    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)

    await apb_write(dut, 0x0, 0xAA)
    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)

    await apb_write(dut, 0x0, 0x5A)

    await RisingEdge(dut.pclk)
    await RisingEdge(dut.pclk)

    # -------- Check secret_pin (STRICT) --------
    final_pin = int(dut.secret_pin.value)
    dut._log.info(f"Secret pin after sequence: {final_pin}")

    # STRICT assertion: secret pin MUST toggle
    assert final_pin != initial_pin, f"Secret pin must toggle! Initial: {initial_pin}, Final: {final_pin}"
    
    dut._log.info(f"✓ PASS: Secret pin toggled from {initial_pin} to {final_pin}")


# ⚠ CRITICAL: Pytest wrapper function
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
