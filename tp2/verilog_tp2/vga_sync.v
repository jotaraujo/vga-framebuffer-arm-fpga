module vga_sync (
    input  wire        clk,
    input  wire        rst_n,
    output reg         hsync,
    output reg         vsync,
    output wire        video_on,
    output wire [9:0]  pixel_x,
    output wire [9:0]  pixel_y
);

    localparam H_VISIBLE    = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_PULSE  = 96;
    localparam H_BACK_PORCH  = 48;
    localparam H_TOTAL       = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;

    localparam H_SYNC_START = H_VISIBLE + H_FRONT_PORCH;
    localparam H_SYNC_END   = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE;

    localparam V_VISIBLE    = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_PULSE  =  2;
    localparam V_BACK_PORCH  = 33;
    localparam V_TOTAL       = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;

    localparam V_SYNC_START = V_VISIBLE + V_FRONT_PORCH;
    localparam V_SYNC_END   = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE;

    reg [9:0] h_count;
    reg [9:0] v_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1)
                h_count <= 10'd0;
            else
                h_count <= h_count + 10'd1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            v_count <= 10'd0;
        end else begin
            if (h_count == H_TOTAL - 1) begin
                if (v_count == V_TOTAL - 1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            hsync <= 1'b1;
        else
            hsync <= ~((h_count >= H_SYNC_START) && (h_count < H_SYNC_END));
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            vsync <= 1'b1;
        else
            vsync <= ~((v_count >= V_SYNC_START) && (v_count < V_SYNC_END));
    end

    assign video_on = (h_count < H_VISIBLE) && (v_count < V_VISIBLE);

    assign pixel_x = h_count;
    assign pixel_y = v_count;

endmodule