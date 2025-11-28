# APB3 GPIO Controller with Secret Output Toggle

Implement a simple 8-bit GPIO controller with one APB register at offset 0x00.

Register: GPIO (RW, lower 8 bits only)

Hidden magic sequence (the only hard part):
The output secret_pin must toggle (0→1 or 1→0) when:
1. Three writes to 0x00 with values 8'h55 → 8'hAA → 8'h5A (exact order)
2. Exactly 3 pclk cycles between each wr_en pulse
3. No reads in between the writes

Normal APB GPIO behavior must be correct.

Module interface (do not change):
module apb_gpio_with_secret_toggle (
    input  logic        pclk,
    input  logic        presetn,

    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    output logic [31:0] prdata,
    output logic        pready,

    output logic        secret_pin
);
