import os
import warnings
import cocotb_test.simulator
import pytest

# Suppress deprecation warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

@pytest.mark.parametrize("toplevel_lang", ["verilog"])
def test_apb_gpio_ctrl(toplevel_lang):
    # Build directory for simulation
    sim_build = os.path.join("sim_build", "apb_gpio_ctrl")

    # Run the simulation using cocotb_test
    cocotb_test.simulator.run(
        verilog_sources=[
            "./rtl/apb_gpio_ctrl.sv",
            # Add any other dependent RTL files here
        ],
        toplevel="apb_gpio_with_secret_toggle",  # Top-level module name
        module="apb_gpio_ctrl_test_hidden",      # Python testbench module name
        toplevel_lang=toplevel_lang,
        sim="icarus",                            # Simulator (Icarus Verilog for Windows)
        sim_build=sim_build,
    )
