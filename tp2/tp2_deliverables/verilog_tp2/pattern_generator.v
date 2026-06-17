module pattern_generator (
    input  wire [9:0] pixel_x,
    input  wire [9:0] pixel_y,
    input  wire       video_on,
    input  wire       mode,
    output reg  [3:0] red,
    output reg  [3:0] green,
    output reg  [3:0] blue
);

    wire chess_bit;
    assign chess_bit = pixel_x[5] ^ pixel_y[5];

    wire [3:0] region;
    assign region = pixel_x[9:3] / 10;

    always @(*) begin
        if (!video_on) begin
            red   = 4'h0;
            green = 4'h0;
            blue  = 4'h0;
        end else if (mode == 1'b0) begin
            if (chess_bit) begin
                red   = 4'hF;
                green = 4'hF;
                blue  = 4'hF;
            end else begin
                red   = 4'h3;
                green = 4'h3;
                blue  = 4'h3;
            end
        end else begin
            case (region)
                4'd0: begin
                    red   = 4'hF;
                    green = 4'hF;
                    blue  = 4'hF;
                end
                4'd1: begin
                    red   = 4'hF;
                    green = 4'hF;
                    blue  = 4'h0;
                end
                4'd2: begin
                    red   = 4'h0;
                    green = 4'hF;
                    blue  = 4'hF;
                end
                4'd3: begin
                    red   = 4'h0;
                    green = 4'hF;
                    blue  = 4'h0;
                end
                4'd4: begin
                    red   = 4'hF;
                    green = 4'h0;
                    blue  = 4'hF;
                end
                4'd5: begin
                    red   = 4'hF;
                    green = 4'h0;
                    blue  = 4'h0;
                end
                4'd6: begin
                    red   = 4'h0;
                    green = 4'h0;
                    blue  = 4'hF;
                end
                default: begin
                    red   = 4'h0;
                    green = 4'h0;
                    blue  = 4'h0;
                end
            endcase
        end
    end

endmodule