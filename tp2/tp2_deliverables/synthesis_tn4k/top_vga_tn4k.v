module top_vga_tn4k (
    input  wire clk_27mhz,
    input  wire rst_n_btn,
    output wire led_r
);
    wire hsync_w, vsync_w, video_on_w;
    wire [9:0] pixel_x_w, pixel_y_w;

    reg [7:0] frame_count;

    vga_sync u_vga_sync (
        .clk(clk_27mhz), .rst_n(rst_n_btn),
        .hsync(hsync_w), .vsync(vsync_w),
        .video_on(video_on_w),
        .pixel_x(pixel_x_w), .pixel_y(pixel_y_w)
    );

    reg vsync_prev;
    always @(posedge clk_27mhz or negedge rst_n_btn) begin
        if (!rst_n_btn) begin
            vsync_prev  <= 1'b1;
            frame_count <= 8'd0;
        end else begin
            vsync_prev <= vsync_w;
            if (vsync_w == 1'b1 && vsync_prev == 1'b0)
                frame_count <= frame_count + 8'd1;
        end
    end

    assign led_r = frame_count[5];

endmodule