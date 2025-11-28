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

    // Gate transfers with PRE-READY so each APB write is seen exactly once.
    logic apb_transfer;
    logic apb_write;
    logic apb_read;
    logic gpio_sel;

    assign apb_transfer = psel & penable & pready;
    assign apb_write    = apb_transfer & pwrite;
    assign apb_read     = apb_transfer & ~pwrite;
    assign gpio_sel     = (paddr[3:0] == ADDR_GPIO);

    // Simple APB slave: drive ready high after reset.
    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            pready <= 1'b0;
        end else begin
            pready <= 1'b1;
        end
    end

    // GPIO register and secret pin flop.
    logic [7:0] gpio_reg;
    logic       secret_pin_r;
    assign secret_pin = secret_pin_r;

    // Track elapsed cycles since the most recent GPIO write.
    logic [3:0] cycles_since_write;  // allows “>= 3 clocks between writes”

    typedef enum logic [1:0] {
        S_IDLE,
        S_WAIT_AA,
        S_WAIT_5A
    } seq_state_e;

    seq_state_e seq_state;

    always_ff @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_reg            <= 8'd0;
            prdata              <= 32'd0;
            secret_pin_r        <= 1'b0;
            seq_state           <= S_IDLE;
            cycles_since_write  <= 4'd0;
        end else begin
            // Default: increment cycle counter while sequence is active.
            if (seq_state != S_IDLE && cycles_since_write != 4'hF) begin
                cycles_since_write <= cycles_since_write + 1'b1;
            end

            // Handle APB reads.
            if (apb_read && gpio_sel) begin
                prdata             <= {24'd0, gpio_reg};
                seq_state          <= S_IDLE;          // any read aborts sequence
                cycles_since_write <= 4'd0;
            end

            // Handle APB writes.
            if (apb_write && gpio_sel) begin
                gpio_reg            <= pwdata[7:0];
                cycles_since_write  <= 4'd0;           // reset counter on every write

                unique case (seq_state)
                    S_IDLE: begin
                        if (pwdata[7:0] == 8'h55) begin
                            seq_state <= S_WAIT_AA;
                        end
                    end

                    S_WAIT_AA: begin
                        if (pwdata[7:0] == 8'hAA && cycles_since_write >= 4'd3) begin
                            seq_state <= S_WAIT_5A;
                        end else if (pwdata[7:0] != 8'hAA) begin
                            seq_state <= S_IDLE;
                        end
                    end

                    S_WAIT_5A: begin
                        if (pwdata[7:0] == 8'h5A && cycles_since_write >= 4'd3) begin
                            secret_pin_r <= ~secret_pin_r;  // success!
                            seq_state    <= S_IDLE;
                        end else if (pwdata[7:0] != 8'h5A) begin
                            seq_state <= S_IDLE;
                        end
                    end
                endcase
            end
        end
    end

endmodule
