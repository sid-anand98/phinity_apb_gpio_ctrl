`timescale 1ns/1ps
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

    localparam ADDR_GPIO = 4'h0;

    // APB transfer signals
    wire apb_transfer = psel & penable;
    wire apb_write    = apb_transfer & pwrite;
    wire apb_read     = apb_transfer & ~pwrite;
    wire gpio_sel     = (paddr[3:0] == ADDR_GPIO);

    // GPIO register
    reg [7:0] gpio_reg;

    // Secret pin
    reg secret_pin_r;
    assign secret_pin = secret_pin_r;

    // Sequence logic
    typedef enum logic [1:0] {S_IDLE, S_WAIT_AA, S_WAIT_5A} seq_t;
    seq_t seq;
    reg [1:0] idle_cycles;  // counts cycles between writes (0..3)

    // APB ready and read data
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_reg     <= 8'd0;
            prdata       <= 32'd0;
            pready       <= 1'b0;
            secret_pin_r <= 1'b0;
            seq          <= S_IDLE;
            idle_cycles  <= 2'd0;
        end else begin
            pready <= penable; // standard APB ready

            // Default: hold read data
            prdata <= prdata;

            // Handle reads
            if (apb_read && gpio_sel) begin
                prdata <= {24'd0, gpio_reg};
                seq <= S_IDLE;  // any read aborts sequence
                idle_cycles <= 2'd0;
            end

            // Handle writes
            if (apb_write && gpio_sel) begin
                gpio_reg <= pwdata[7:0];

                case (seq)
                    S_IDLE: begin
                        if (pwdata[7:0] == 8'h55) begin
                            seq <= S_WAIT_AA;
                            idle_cycles <= 2'd0;
                        end
                    end

                    S_WAIT_AA: begin
                        if (idle_cycles == 2'd3 && pwdata[7:0] == 8'hAA) begin
                            seq <= S_WAIT_5A;
                            idle_cycles <= 2'd0;
                        end else if (pwdata[7:0] != 8'hAA) begin
                            seq <= S_IDLE;
                            idle_cycles <= 2'd0;
                        end
                    end

                    S_WAIT_5A: begin
                        if (idle_cycles == 2'd3 && pwdata[7:0] == 8'h5A) begin
                            secret_pin_r <= ~secret_pin_r;
                            seq <= S_IDLE;
                            idle_cycles <= 2'd0;
                        end else if (pwdata[7:0] != 8'h5A) begin
                            seq <= S_IDLE;
                            idle_cycles <= 2'd0;
                        end
                    end
                endcase
            end else begin
                // No write: increment idle_cycles if sequence active
                if (seq != S_IDLE && idle_cycles < 2'd3)
                    idle_cycles <= idle_cycles + 1;
            end
        end
    end

endmodule

