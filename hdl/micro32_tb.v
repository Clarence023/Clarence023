`timescale 1ns/1ps

module micro32_tb;

    localparam GPIO_ADDR      = 32'h1000_0000;
    localparam UART_DATA      = 32'h1000_0004;
    localparam TIMER_COMPARE  = 32'h1000_0010;
    localparam TIMER_CTRL     = 32'h1000_0014;
    localparam PWM_DUTY       = 32'h1000_0018;
    localparam SPI_DATA       = 32'h1000_001C;
    localparam I2C_CTRL       = 32'h1000_0024;
    localparam ADC_VALUE      = 32'h1000_0028;
    localparam IRQ_ENABLE     = 32'h1000_0058;
    localparam GPIO_SET       = 32'h1000_005C;
    localparam GPIO_TOGGLE    = 32'h1000_0064;
    localparam GPIO_IN_ADDR   = 32'h1000_0044;
    localparam TIMER2_COMPARE = 32'h1000_0050;
    localparam TIMER2_CTRL    = 32'h1000_0054;
    localparam SW_IRQ         = 32'h1000_0070;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [11:0] adc_in = 12'd1234;
    reg uart_rx = 1'b1;
    reg [31:0] gpio_in = 32'hA5A5_5A5A;

    wire [31:0] gpio_out;
    wire [31:0] gpio_dir;
    wire halted;
    wire [31:0] debug_pc;
    wire uart_tx, uart_irq, pwm_out;
    wire spi_sclk, spi_mosi, spi_cs;
    wire i2c_scl, i2c_sda, irq;

    integer errors;
    integer pwm_high_count;
    reg saw_spi_clock;
    reg saw_uart_start;
    reg saw_irq;

    micro32 #(
        .UART_DIV(2),
        .WDT_LIMIT(32'h0000_00FF)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .adc_in(adc_in),
        .uart_rx(uart_rx),
        .gpio_in(gpio_in),
        .gpio_out(gpio_out),
        .gpio_dir(gpio_dir),
        .halted(halted),
        .debug_pc(debug_pc),
        .uart_tx(uart_tx),
        .uart_irq(uart_irq),
        .pwm_out(pwm_out),
        .spi_sclk(spi_sclk),
        .spi_mosi(spi_mosi),
        .spi_cs(spi_cs),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda),
        .irq(irq)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (pwm_out) pwm_high_count = pwm_high_count + 1;
        if (spi_sclk) saw_spi_clock = 1'b1;
        if (!uart_tx) saw_uart_start = 1'b1;
        if (irq) saw_irq = 1'b1;
    end

    function [31:0] enc_i;
        input [3:0] op;
        input [4:0] d;
        input [4:0] s;
        input integer value;
        begin
            enc_i = {op, d, s, 5'd0, value[12:0]};
        end
    endfunction

    function [31:0] enc_r;
        input [3:0] op;
        input [4:0] d;
        input [4:0] a;
        input [4:0] b;
        begin
            enc_r = {op, d, a, b, 13'd0};
        end
    endfunction

    function [31:0] enc_store;
        input [4:0] base;
        input [4:0] data;
        begin
            enc_store = {4'h4, 5'd0, base, data, 13'd0};
        end
    endfunction

    function [31:0] enc_load;
        input [4:0] d;
        input [4:0] base;
        begin
            enc_load = {4'h3, d, base, 5'd0, 13'd0};
        end
    endfunction

    task cpu_write;
        input [4:0] regno;
        input [31:0] value;
        input [31:0] address;
        begin
            @(negedge clk);
            uut.regs[regno] = value;
            uut.regs[30] = address;
            uut.imem[0] = enc_store(5'd30, regno);
            uut.imem[1] = {4'hF, 28'd0};
            uut.pc = 32'd0;
            uut.halted = 1'b0;

            @(posedge clk);
            @(posedge clk);
            wait (halted === 1'b1);
        end
    endtask

    task cpu_read;
        input [4:0] regno;
        input [31:0] address;
        begin
            @(negedge clk);
            uut.regs[30] = address;
            uut.imem[0] = enc_load(regno, 5'd30);
            uut.imem[1] = {4'hF, 28'd0};
            uut.pc = 32'd0;
            uut.halted = 1'b0;

            @(posedge clk);
            @(posedge clk);
            wait (halted === 1'b1);
        end
    endtask

    task send_uart_byte;
        input [7:0] value;
        integer k;
        begin
            @(negedge clk);
            uart_rx = 1'b0;
            repeat (2) @(posedge clk);

            for (k = 0; k < 8; k = k + 1) begin
                @(negedge clk);
                uart_rx = value[k];
                repeat (2) @(posedge clk);
            end

            @(negedge clk);
            uart_rx = 1'b1;
            repeat (4) @(posedge clk);
        end
    endtask

    initial begin
        errors = 0;
        pwm_high_count = 0;
        saw_spi_clock = 0;
        saw_uart_start = 0;
        saw_irq = 0;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        uut.imem[0] = enc_i(4'h2, 5'd1, 5'd0, 5);
        uut.imem[1] = enc_i(4'h2, 5'd2, 5'd0, 7);
        uut.imem[2] = enc_r(4'h1, 5'd3, 5'd1, 5'd2);
        uut.imem[3] = enc_r(4'h6, 5'd3, 5'd0, 5'd0);
        uut.imem[4] = {4'hF, 28'd0};
        uut.pc = 32'd0;
        uut.halted = 1'b0;

        wait (halted === 1'b1);

        if (gpio_out !== 32'd12) begin
            $display("FAIL GPIO arithmetic: got %0d", gpio_out);
            errors = errors + 1;
        end else begin
            $display("PASS GPIO arithmetic");
        end

        cpu_write(5'd1, 32'hA5, GPIO_SET);

        if (gpio_out !== 32'h0000_00BD) begin
            $display("FAIL GPIO SET: got 0x%08h", gpio_out);
            errors = errors + 1;
        end else begin
            $display("PASS GPIO SET");
        end

        cpu_write(5'd1, 32'h0F, GPIO_TOGGLE);

        if (gpio_out !== 32'h0000_00B2) begin
            $display("FAIL GPIO TOGGLE: got 0x%08h", gpio_out);
            errors = errors + 1;
        end else begin
            $display("PASS GPIO TOGGLE");
        end

        cpu_write(5'd1, 32'h1, TIMER_CTRL);
        cpu_write(5'd1, 32'd3, TIMER_COMPARE);
        cpu_write(5'd1, 32'h1, TIMER2_CTRL);
        cpu_write(5'd1, 32'd5, TIMER2_COMPARE);
        cpu_write(5'd1, 32'h9, IRQ_ENABLE);

        repeat (20) @(posedge clk);

        if (!saw_irq) begin
            $display("FAIL timer interrupt");
            errors = errors + 1;
        end else begin
            $display("PASS timer interrupt");
        end

        cpu_write(5'd1, 32'h0000_0180, PWM_DUTY);
        repeat (20) @(posedge clk);

        if (pwm_high_count == 0) begin
            $display("FAIL PWM");
            errors = errors + 1;
        end else begin
            $display("PASS PWM");
        end

        cpu_write(5'd1, 32'hA6, SPI_DATA);
        repeat (30) @(posedge clk);

        if (!saw_spi_clock) begin
            $display("FAIL SPI");
            errors = errors + 1;
        end else begin
            $display("PASS SPI");
        end

        cpu_write(5'd1, 32'b111, I2C_CTRL);

        if (i2c_scl !== 1'b1 || i2c_sda !== 1'b1) begin
            $display("FAIL I2C");
            errors = errors + 1;
        end else begin
            $display("PASS I2C");
        end

        cpu_write(5'd1, 32'h5A, UART_DATA);
        repeat (30) @(posedge clk);

        if (!saw_uart_start || !uart_irq) begin
            $display("FAIL UART TX");
            errors = errors + 1;
        end else begin
            $display("PASS UART TX");
        end

        send_uart_byte(8'h3C);

        if (!uut.uart_rx_valid || uut.uart_rx_data !== 8'h3C) begin
            $display("FAIL UART RX: received 0x%02h", uut.uart_rx_data);
            errors = errors + 1;
        end else begin
            $display("PASS UART RX");
        end

        cpu_write(5'd1, 32'h1, SW_IRQ);
        cpu_write(5'd1, 32'h10, IRQ_ENABLE);
        repeat (2) @(posedge clk);

        if (!irq) begin
            $display("FAIL software interrupt");
            errors = errors + 1;
        end else begin
            $display("PASS software interrupt");
        end

        cpu_read(5'd4, ADC_VALUE);

        if (uut.regs[4] !== 32'd1234) begin
            $display("FAIL ADC: got %0d", uut.regs[4]);
            errors = errors + 1;
        end else begin
            $display("PASS ADC");
        end

        cpu_read(5'd5, GPIO_IN_ADDR);

        if (uut.regs[5] !== gpio_in) begin
            $display("FAIL GPIO input: got 0x%08h", uut.regs[5]);
            errors = errors + 1;
        end else begin
            $display("PASS GPIO input");
        end

        if (uut.rng_state === 32'h1ACE_B00C) begin
            $display("FAIL RNG");
            errors = errors + 1;
        end else begin
            $display("PASS RNG");
        end

        $display("----------------------------------------");
        $display("Real-time simulation completed.");
        $display("Errors = %0d", errors);
        $display("GPIO   = 0x%08h", gpio_out);
        $display("Cycles = %0d", uut.cycle_count);
        $display("PC     = 0x%08h", debug_pc);

        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end else begin
            $display("TESTS FAILED");
        end

        #20 $finish;
    end

endmodule
