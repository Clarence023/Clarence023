`timescale 1ns/1ps

module micro32 #(
    parameter integer UART_DIV  = 4,
    parameter [31:0] WDT_LIMIT = 32'h0000_00FF
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] adc_in,
    input  wire        uart_rx,
    input  wire [31:0] gpio_in,

    output reg  [31:0] gpio_out,
    output reg  [31:0] gpio_dir,
    output reg         halted,
    output wire [31:0] debug_pc,

    output reg         uart_tx,
    output reg         uart_irq,
    output reg         pwm_out,

    output reg         spi_sclk,
    output reg         spi_mosi,
    output reg         spi_cs,

    output reg         i2c_scl,
    output reg         i2c_sda,

    output wire        irq
);

    localparam OP_NOP   = 4'h0;
    localparam OP_ADD   = 4'h1;
    localparam OP_ADDI  = 4'h2;
    localparam OP_LOAD  = 4'h3;
    localparam OP_STORE = 4'h4;
    localparam OP_BNE   = 4'h5;
    localparam OP_OUT   = 4'h6;
    localparam OP_SUB   = 4'h7;
    localparam OP_AND   = 4'h8;
    localparam OP_OR    = 4'h9;
    localparam OP_XOR   = 4'hA;
    localparam OP_SLT   = 4'hB;
    localparam OP_JAL   = 4'hC;
    localparam OP_JR    = 4'hD;
    localparam OP_MUL   = 4'hE;
    localparam OP_HALT  = 4'hF;

    localparam GPIO_ADDR      = 32'h1000_0000;
    localparam UART_DATA      = 32'h1000_0004;
    localparam UART_STATUS    = 32'h1000_0008;
    localparam TIMER_COUNT    = 32'h1000_000C;
    localparam TIMER_COMPARE  = 32'h1000_0010;
    localparam TIMER_CTRL     = 32'h1000_0014;
    localparam PWM_DUTY       = 32'h1000_0018;
    localparam SPI_DATA       = 32'h1000_001C;
    localparam SPI_CTRL       = 32'h1000_0020;
    localparam I2C_CTRL       = 32'h1000_0024;
    localparam ADC_VALUE      = 32'h1000_0028;
    localparam RNG_VALUE      = 32'h1000_002C;
    localparam IRQ_STATUS     = 32'h1000_0030;
    localparam IRQ_CLEAR      = 32'h1000_0034;
    localparam WDT_CTRL       = 32'h1000_0038;
    localparam SLEEP_CTRL     = 32'h1000_003C;
    localparam UART_RX_DATA   = 32'h1000_0040;
    localparam GPIO_IN_ADDR   = 32'h1000_0044;
    localparam GPIO_DIR_ADDR  = 32'h1000_0048;
    localparam TIMER2_COUNT   = 32'h1000_004C;
    localparam TIMER2_COMPARE = 32'h1000_0050;
    localparam TIMER2_CTRL    = 32'h1000_0054;
    localparam IRQ_ENABLE     = 32'h1000_0058;
    localparam GPIO_SET       = 32'h1000_005C;
    localparam GPIO_CLEAR     = 32'h1000_0060;
    localparam GPIO_TOGGLE    = 32'h1000_0064;
    localparam CYCLE_COUNT    = 32'h1000_0068;
    localparam CHIP_ID        = 32'h1000_006C;
    localparam SW_IRQ         = 32'h1000_0070;
    localparam RESET_CTRL     = 32'h1000_0074;

    localparam CHIP_ID_VALUE  = 32'hA032_0001;

    reg [31:0] regs [0:31];
    reg [31:0] imem [0:255];
    reg [31:0] dmem [0:255];

    reg [31:0] pc;
    reg [31:0] cycle_count;
    reg [31:0] read_data;

    reg [31:0] timer_count;
    reg [31:0] timer_compare;
    reg        timer_enable;
    reg        timer_irq;

    reg [31:0] timer2_count;
    reg [31:0] timer2_compare;
    reg        timer2_enable;
    reg        timer2_irq;

    reg [7:0] pwm_duty;
    reg [7:0] pwm_counter;
    reg       pwm_enable;

    reg [7:0] spi_shift;
    reg [3:0] spi_bits;
    reg       spi_active;

    reg       i2c_enable;
    reg [31:0] rng_state;

    reg       wdt_enable;
    reg [31:0] wdt_counter;
    reg        sleep_mode;

    reg [9:0]  uart_shift;
    reg [3:0]  uart_bits;
    reg [15:0] uart_divider;
    reg        uart_busy;

    reg [7:0]  uart_rx_data;
    reg        uart_rx_valid;
    reg        uart_rx_busy;
    reg [3:0]  uart_rx_bits;
    reg [15:0] uart_rx_divider;

    reg [31:0] irq_enable;
    reg        software_irq;

    wire [31:0] instr = imem[pc[9:2]];

    wire [3:0] opcode = instr[31:28];
    wire [4:0] rd     = instr[27:23];
    wire [4:0] rs1    = instr[22:18];
    wire [4:0] rs2    = instr[17:13];
    wire [12:0] imm13 = instr[12:0];

    wire signed [31:0] signed_imm = {{19{imm13[12]}}, imm13};

    wire [31:0] alu_address = regs[rs1] + signed_imm;
    wire data_access = (alu_address[31:10] == 22'd0);

    wire [31:0] irq_pending =
        {27'd0, software_irq, timer2_irq,
         uart_rx_valid, uart_irq, timer_irq};

    assign debug_pc = pc;
    assign irq = |(irq_pending & irq_enable);

    integer i;

    always @* begin
        read_data = 32'd0;

        if (data_access) begin
            read_data = dmem[alu_address[9:2]];
        end else begin
            case (alu_address)
                GPIO_ADDR:      read_data = gpio_out & gpio_dir;
                GPIO_IN_ADDR:   read_data = gpio_in;
                GPIO_DIR_ADDR:  read_data = gpio_dir;

                UART_STATUS:
                    read_data = {27'd0, uart_rx_valid,
                                 uart_busy, uart_tx, uart_irq};

                UART_RX_DATA:   read_data = {24'd0, uart_rx_data};

                TIMER_COUNT:    read_data = timer_count;
                TIMER_COMPARE:  read_data = timer_compare;
                TIMER_CTRL:     read_data = {31'd0, timer_enable};

                TIMER2_COUNT:   read_data = timer2_count;
                TIMER2_COMPARE: read_data = timer2_compare;
                TIMER2_CTRL:    read_data = {31'd0, timer2_enable};

                PWM_DUTY:       read_data = {23'd0, pwm_enable, pwm_duty};
                SPI_DATA:       read_data = {24'd0, spi_shift};
                SPI_CTRL:       read_data = {31'd0, spi_active};

                I2C_CTRL:
                    read_data = {29'd0, i2c_enable,
                                 i2c_sda, i2c_scl};

                ADC_VALUE:      read_data = {20'd0, adc_in};
                RNG_VALUE:      read_data = rng_state;
                IRQ_STATUS:     read_data = irq_pending;
                IRQ_ENABLE:     read_data = irq_enable;
                WDT_CTRL:       read_data = {31'd0, wdt_enable};
                SLEEP_CTRL:     read_data = {31'd0, sleep_mode};
                CYCLE_COUNT:    read_data = cycle_count;
                CHIP_ID:        read_data = CHIP_ID_VALUE;
                SW_IRQ:         read_data = {31'd0, software_irq};

                default:        read_data = 32'd0;
            endcase
        end
    end

    initial begin
        for (i = 0; i < 256; i = i + 1) begin
            imem[i] = 32'd0;
            dmem[i] = 32'd0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'd0;
            cycle_count <= 32'd0;
            gpio_out <= 32'd0;
            gpio_dir <= 32'hFFFF_FFFF;
            halted <= 1'b0;

            timer_count <= 32'd0;
            timer_compare <= 32'd100;
            timer_enable <= 1'b0;
            timer_irq <= 1'b0;

            timer2_count <= 32'd0;
            timer2_compare <= 32'd200;
            timer2_enable <= 1'b0;
            timer2_irq <= 1'b0;

            pwm_duty <= 8'd0;
            pwm_counter <= 8'd0;
            pwm_enable <= 1'b0;
            pwm_out <= 1'b0;

            spi_shift <= 8'd0;
            spi_bits <= 4'd0;
            spi_active <= 1'b0;
            spi_sclk <= 1'b0;
            spi_mosi <= 1'b0;
            spi_cs <= 1'b1;

            i2c_enable <= 1'b0;
            i2c_scl <= 1'b1;
            i2c_sda <= 1'b1;

            rng_state <= 32'h1ACE_B00C;

            wdt_enable <= 1'b0;
            wdt_counter <= 32'd0;
            sleep_mode <= 1'b0;

            uart_tx <= 1'b1;
            uart_irq <= 1'b0;
            uart_shift <= 10'h3FF;
            uart_bits <= 4'd0;
            uart_divider <= 16'd0;
            uart_busy <= 1'b0;

            uart_rx_data <= 8'd0;
            uart_rx_valid <= 1'b0;
            uart_rx_busy <= 1'b0;
            uart_rx_bits <= 4'd0;
            uart_rx_divider <= 16'd0;

            irq_enable <= 32'd0;
            software_irq <= 1'b0;

            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'd0;
            end
        end else begin
            cycle_count <= cycle_count + 1'b1;
            regs[0] <= 32'd0;

            if (timer_enable) begin
                if (timer_count >= timer_compare) begin
                    timer_count <= 32'd0;
                    timer_irq <= 1'b1;
                end else begin
                    timer_count <= timer_count + 1'b1;
                end
            end

            if (timer2_enable) begin
                if (timer2_count >= timer2_compare) begin
                    timer2_count <= 32'd0;
                    timer2_irq <= 1'b1;
                end else begin
                    timer2_count <= timer2_count + 1'b1;
                end
            end

            if (pwm_enable) begin
                pwm_counter <= pwm_counter + 1'b1;
                pwm_out <= (pwm_counter < pwm_duty);
            end else begin
                pwm_counter <= 8'd0;
                pwm_out <= 1'b0;
            end

            rng_state <= {
                rng_state[30:0],
                rng_state[31] ^ rng_state[21] ^
                rng_state[1] ^ rng_state[0]
            };

            if (wdt_enable) begin
                if (wdt_counter >= WDT_LIMIT) begin
                    pc <= 32'd0;
                    halted <= 1'b0;
                    sleep_mode <= 1'b0;
                    wdt_counter <= 32'd0;
                end else begin
                    wdt_counter <= wdt_counter + 1'b1;
                end
            end

            if (uart_busy) begin
                if (uart_divider >= UART_DIV - 1) begin
                    uart_divider <= 16'd0;
                    uart_tx <= uart_shift[0];
                    uart_shift <= {1'b1, uart_shift[9:1]};

                    if (uart_bits == 9) begin
                        uart_busy <= 1'b0;
                        uart_irq <= 1'b1;
                        uart_tx <= 1'b1;
                    end else begin
                        uart_bits <= uart_bits + 1'b1;
                    end
                end else begin
                    uart_divider <= uart_divider + 1'b1;
                end
            end

            if (!uart_rx_busy) begin
                if (!uart_rx) begin
                    uart_rx_busy <= 1'b1;
                    uart_rx_bits <= 4'd0;
                    uart_rx_divider <= UART_DIV + (UART_DIV / 2) - 1;
                end
            end else if (uart_rx_divider != 0) begin
                uart_rx_divider <= uart_rx_divider - 1'b1;
            end else begin
                uart_rx_divider <= UART_DIV - 1;

                if (uart_rx_bits < 8) begin
                    uart_rx_data <= {uart_rx, uart_rx_data[7:1]};
                    uart_rx_bits <= uart_rx_bits + 1'b1;
                end else begin
                    uart_rx_busy <= 1'b0;
                    uart_rx_valid <= 1'b1;
                end
            end

            if (spi_active) begin
                spi_sclk <= ~spi_sclk;

                if (!spi_sclk) begin
                    spi_mosi <= spi_shift[7];
                    spi_shift <= {spi_shift[6:0], 1'b0};

                    if (spi_bits == 7) begin
                        spi_active <= 1'b0;
                        spi_cs <= 1'b1;
                        spi_sclk <= 1'b0;
                    end else begin
                        spi_bits <= spi_bits + 1'b1;
                    end
                end
            end

            if (!halted && !sleep_mode) begin
                case (opcode)
                    OP_NOP: pc <= pc + 4;

                    OP_ADD: begin
                        if (rd != 0) regs[rd] <= regs[rs1] + regs[rs2];
                        pc <= pc + 4;
                    end

                    OP_ADDI: begin
                        if (rd != 0) regs[rd] <= regs[rs1] + signed_imm;
                        pc <= pc + 4;
                    end

                    OP_SUB: begin
                        if (rd != 0) regs[rd] <= regs[rs1] - regs[rs2];
                        pc <= pc + 4;
                    end

                    OP_AND: begin
                        if (rd != 0) regs[rd] <= regs[rs1] & regs[rs2];
                        pc <= pc + 4;
                    end

                    OP_OR: begin
                        if (rd != 0) regs[rd] <= regs[rs1] | regs[rs2];
                        pc <= pc + 4;
                    end

                    OP_XOR: begin
                        if (rd != 0) regs[rd] <= regs[rs1] ^ regs[rs2];
                        pc <= pc + 4;
                    end

                    OP_SLT: begin
                        if (rd != 0) begin
                            regs[rd] <= ($signed(regs[rs1]) <
                                         $signed(regs[rs2])) ? 1 : 0;
                        end
                        pc <= pc + 4;
                    end

                    OP_MUL: begin
                        if (rd != 0) regs[rd] <= regs[rs1] * regs[rs2];
                        pc <= pc + 4;
                    end

                    OP_LOAD: begin
                        if (rd != 0) regs[rd] <= read_data;
                        pc <= pc + 4;
                    end

                    OP_STORE: begin
                        if (data_access) begin
                            dmem[alu_address[9:2]] <= regs[rs2];
                        end else begin
                            case (alu_address)
                                GPIO_ADDR: gpio_out <= regs[rs2];
                                GPIO_SET: gpio_out <= gpio_out | regs[rs2];
                                GPIO_CLEAR: gpio_out <= gpio_out & ~regs[rs2];
                                GPIO_TOGGLE: gpio_out <= gpio_out ^ regs[rs2];
                                GPIO_DIR_ADDR: gpio_dir <= regs[rs2];

                                UART_DATA: begin
                                    if (!uart_busy) begin
                                        uart_shift <= {
                                            1'b1, regs[rs2][7:0], 1'b0
                                        };
                                        uart_bits <= 0;
                                        uart_divider <= 0;
                                        uart_busy <= 1'b1;
                                        uart_irq <= 1'b0;
                                    end
                                end

                                TIMER_COMPARE: timer_compare <= regs[rs2];

                                TIMER_CTRL: begin
                                    timer_enable <= regs[rs2][0];
                                    if (!regs[rs2][0]) timer_irq <= 1'b0;
                                end

                                TIMER2_COMPARE: timer2_compare <= regs[rs2];

                                TIMER2_CTRL: begin
                                    timer2_enable <= regs[rs2][0];
                                    if (!regs[rs2][0]) timer2_irq <= 1'b0;
                                end

                                PWM_DUTY: begin
                                    pwm_duty <= regs[rs2][7:0];
                                    pwm_enable <= regs[rs2][8];
                                    pwm_counter <= 0;
                                end

                                SPI_DATA: begin
                                    spi_shift <= regs[rs2][7:0];
                                    spi_bits <= 0;
                                    spi_active <= 1'b1;
                                    spi_cs <= 1'b0;
                                    spi_sclk <= 1'b0;
                                end

                                SPI_CTRL: begin
                                    spi_active <= regs[rs2][0];
                                    spi_cs <= ~regs[rs2][0];
                                end

                                I2C_CTRL: begin
                                    i2c_scl <= regs[rs2][0];
                                    i2c_sda <= regs[rs2][1];
                                    i2c_enable <= regs[rs2][2];
                                end

                                IRQ_ENABLE: irq_enable <= regs[rs2];

                                IRQ_CLEAR: begin
                                    if (regs[rs2][0]) timer_irq <= 0;
                                    if (regs[rs2][1]) uart_irq <= 0;
                                    if (regs[rs2][2]) uart_rx_valid <= 0;
                                    if (regs[rs2][3]) timer2_irq <= 0;
                                    if (regs[rs2][4]) software_irq <= 0;
                                end

                                SW_IRQ: software_irq <= regs[rs2][0];

                                WDT_CTRL: begin
                                    wdt_enable <= regs[rs2][0];
                                    wdt_counter <= 0;
                                end

                                SLEEP_CTRL: sleep_mode <= regs[rs2][0];

                                RESET_CTRL: begin
                                    if (regs[rs2][0]) begin
                                        pc <= 0;
                                        halted <= 0;
                                        sleep_mode <= 0;
                                    end
                                end

                                default: ;
                            endcase
                        end
                        pc <= pc + 4;
                    end

                    OP_BNE: begin
                        if (regs[rs1] != regs[rs2]) begin
                            pc <= pc + signed_imm;
                        end else begin
                            pc <= pc + 4;
                        end
                    end

                    OP_OUT: begin
                        gpio_out <= regs[rd];
                        pc <= pc + 4;
                    end

                    OP_JAL: begin
                        if (rd != 0) regs[rd] <= pc + 4;
                        pc <= pc + signed_imm;
                    end

                    OP_JR: pc <= regs[rs1];

                    OP_HALT: halted <= 1'b1;

                    default: pc <= pc + 4;
                endcase
            end
        end
    end
endmodule
