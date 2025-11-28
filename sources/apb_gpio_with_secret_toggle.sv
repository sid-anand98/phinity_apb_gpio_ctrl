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

    // APB handshaking
    logic apb_write;
    logic apb_read;
    logic gpio_sel;

    assign gpio_sel = (paddr[3:0] == ADDR_GPIO);

    // Simple APB slave: ready after reset
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn)
            pready <= 1'b0;
        else
            pready <= 1'b1;
    end

    // Detect valid APB transactions (only when ready is high)
    assign apb_write = psel & penable & pready & pwrite & gpio_sel;
    assign apb_read  = psel & penable & pready & ~pwrite & gpio_sel;

    // GPIO register
    logic [7:0] gpio_reg;

    // Secret pin and sequence detection
    logic secret_pin_r;
    assign secret_pin = secret_pin_r;

    typedef enum logic [1:0] {
        S_IDLE,
        S_WAIT_AA,
        S_WAIT_5A
    } state_t;

    state_t state;
    logic [3:0] idle_count;  // Count idle cycles between writes

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_reg     <= 8'd0;
            prdata       <= 32'd0;
            secret_pin_r <= 1'b0;
            state        <= S_IDLE;
            idle_count   <= 4'd0;
        end else begin
            // Default: increment idle counter
            if (state != S_IDLE && idle_count != 4'hF)
                idle_count <= idle_count + 1'b1;

            // Handle reads
            if (apb_read) begin
                prdata     <= {24'd0, gpio_reg};
                state      <= S_IDLE;  // Read aborts sequence
                idle_count <= 4'd0;
            end

            // Handle writes
            if (apb_write) begin
                gpio_reg <= pwdata[7:0];

                case (state)
                    S_IDLE: begin
                        if (pwdata[7:0] == 8'h55) begin
                            state      <= S_WAIT_AA;
                            idle_count <= 4'd0;
                        end
                    end

                    S_WAIT_AA: begin
                        // Check if enough time passed (idle_count incremented this cycle, so it's already +1)
                        if (pwdata[7:0] == 8'hAA && idle_count >= 4'd3) begin
                            state      <= S_WAIT_5A;
                            idle_count <= 4'd0;
                        end else begin
                            // Wrong value or wrong timing
                            state      <= S_IDLE;
                            idle_count <= 4'd0;
                        end
                    end

                    S_WAIT_5A: begin
                        if (pwdata[7:0] == 8'h5A && idle_count >= 4'd3) begin
                            secret_pin_r <= ~secret_pin_r;  // Toggle!
                            state        <= S_IDLE;
                            idle_count   <= 4'd0;
                        end else begin
                            state      <= S_IDLE;
                            idle_count <= 4'd0;
                        end
                    end

                    default: begin
                        state      <= S_IDLE;
                        idle_count <= 4'd0;
                    end
                endcase
            end
        end
    end

endmodule
