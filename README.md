# APB3 GPIO Controller with Secret Output Toggle

A SystemVerilog implementation of an 8-bit GPIO controller with APB3 interface, featuring a hidden secret pin toggle mechanism.

## Overview

This project implements a simple 8-bit GPIO controller with one APB register. The controller follows the standard APB3 protocol and includes a special hidden behavior that toggles a secret output pin when a specific write sequence is detected.

## Features

- **APB3 Interface**: Standard 2-cycle APB protocol support
- **8-bit GPIO Register**: Read/write access to GPIO data register
- **Secret Pin Toggle**: Hidden behavior triggered by a specific write sequence
- **Synthesizable RTL**: SystemVerilog implementation ready for synthesis

## Project Structure

```
apb_gpio_ctrl/
├── rtl/                          # RTL source files
│   └── apb_gpio_ctrl.sv         # Main module implementation
├── harness/                      # Test harness
│   ├── sources/                  # Reference implementations
│   └── tests/                    # Test files
│       ├── apb_gpio_ctrl_test_hidden.py  # Cocotb testbench
│       └── pytest_apb_gpio_ctrl.py        # Pytest runner
├── docs/                         # Documentation
│   └── Specification.md          # Detailed specification
└── pyproject.toml                # Python project configuration
```

## Module Interface

```systemverilog
module apb_gpio_with_secret_toggle (
    input  logic        pclk,        // APB clock
    input  logic        presetn,      // Active-low async reset
    input  logic        psel,         // APB select
    input  logic        penable,      // APB enable
    input  logic        pwrite,       // APB write/read
    input  logic [31:0] paddr,        // APB address
    input  logic [31:0] pwdata,       // APB write data
    output logic [31:0] prdata,       // APB read data
    output logic        pready,       // APB ready
    output logic        secret_pin    // Secret pin (toggles on magic sequence)
);
```

## Register Map

| Offset | Name | Access | Bits | Description | Reset |
|--------|------|--------|------|-------------|-------|
| 0x00   | GPIO | RW     | [7:0]| GPIO data register | 0x00 |

**Note**: Only the lower 8 bits of the 32-bit APB interface are used.

## Normal Functionality

- **Writes**: Write operations to the GPIO register instantly update the internal value
- **Reads**: Read operations return the current GPIO register value
- **APB Protocol**: Standard 2-cycle APB protocol - `pready` is asserted one cycle after `penable`

## Special Hidden Behavior

The `secret_pin` output toggles (0→1 or 1→0) when the following exact sequence occurs:

1. **Three consecutive writes** to offset 0x00
2. **Write values**: `0x55` → `0xAA` → `0x5A` (in this exact order)
3. **Timing**: Exactly 3 `pclk` cycles between each write
4. **No reads**: No read operations between the three writes

When the sequence is correctly detected, `secret_pin` flips its current value.

## Installation

### Prerequisites

- Python >= 3.10
- Icarus Verilog (for simulation)
- pip (Python package manager)

### Setup

1. Clone or navigate to the project directory:
```bash
cd apb_gpio_ctrl
```

2. Install dependencies:
```bash
pip install -e .
```

This will install:
- `cocotb>=1.8.0` - Coroutine-based testbench framework
- `pytest>=7.0.0` - Testing framework
- `cocotb-test>=0.2.4` - Cocotb test integration

## Running Tests

Run the test suite using pytest:

```bash
pytest harness/tests/pytest_apb_gpio_ctrl.py -v
```

The test suite includes:
- Random write operations to verify normal functionality
- Directed test sequence to verify the secret pin toggle behavior

## Simulation

The project uses Icarus Verilog as the simulator. The test framework automatically handles:
- Compilation of RTL files
- Running the cocotb testbench
- Generating simulation results

## License

This project is part of a Verilog/SystemVerilog RTL problems collection for evaluation purposes.
