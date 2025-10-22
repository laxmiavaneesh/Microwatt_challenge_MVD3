`timescale 1ns/1ps
module cache_2hack #(parameter COUNTER_WIDTH=64,parameter ADDR_WIDTH=5,parameter DATA_WIDTH=32)(
input wire clk,
input wire rst_n,
input wire read_access,
input wire write_access,
input wire access_hit,
input wire [ADDR_WIDTH-1:0] reg_addr,
input wire reg_rd_en,
output reg [DATA_WIDTH-1:0] reg_rd_data,
output reg reg_rd_valid,
input wire reg_wr_en,
input wire [DATA_WIDTH-1:0] reg_wr_data,
output reg int_out
);
localparam integer HIGH_LSB=DATA_WIDTH;
localparam integer HIGH_MSB=DATA_WIDTH+DATA_WIDTH-1;
reg [COUNTER_WIDTH-1:0] read_hit_cnt,read_miss_cnt,write_hit_cnt,write_miss_cnt;
reg [COUNTER_WIDTH-1:0] snap_read_hit,snap_read_miss,snap_write_hit,snap_write_miss;
reg snap_valid_read_hit,snap_valid_read_miss,snap_valid_write_hit,snap_valid_write_miss;
reg [31:0] thresh_read_hit_low,thresh_read_miss_low,thresh_write_hit_low,thresh_write_miss_low;
reg clear_request;
reg clear_ack_sticky;
reg overflow_read_hit,overflow_read_miss,overflow_write_hit,overflow_write_miss;
reg int_pending;
reg [DATA_WIDTH-1:0] rdata_next;
wire control_write=(reg_wr_en&&(reg_addr==5'd4));
wire read_low_0=(reg_rd_en&&(reg_addr==5'd0));
wire read_low_1=(reg_rd_en&&(reg_addr==5'd1));
wire read_low_2=(reg_rd_en&&(reg_addr==5'd2));
wire read_low_3=(reg_rd_en&&(reg_addr==5'd3));
wire write_thresh_0=(reg_wr_en&&(reg_addr==5'd10));
wire write_thresh_1=(reg_wr_en&&(reg_addr==5'd11));
wire write_thresh_2=(reg_wr_en&&(reg_addr==5'd12));
wire write_thresh_3=(reg_wr_en&&(reg_addr==5'd13));

always@(posedge clk or negedge rst_n)begin
if(!rst_n)
clear_request<=1'b0;
else
clear_request<=(control_write&&reg_wr_data[0])?1'b1:1'b0;
end

always@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
read_hit_cnt<=0;
read_miss_cnt<=0;
write_hit_cnt<=0;
write_miss_cnt<=0;
overflow_read_hit<=0;
overflow_read_miss<=0;
overflow_write_hit<=0;
overflow_write_miss<=0;
int_out<=0;
int_pending<=0;
clear_ack_sticky<=0;
end
else begin
int_out<=0;
if(clear_request)begin
read_hit_cnt<=0;
read_miss_cnt<=0;
write_hit_cnt<=0;
write_miss_cnt<=0;
snap_valid_read_hit<=0;
snap_valid_read_miss<=0;
snap_valid_write_hit<=0;
snap_valid_write_miss<=0;
overflow_read_hit<=0;
overflow_read_miss<=0;
overflow_write_hit<=0;
overflow_write_miss<=0;
int_pending<=0;
clear_ack_sticky<=1;
end
else begin
if(read_access)begin
if(access_hit)
read_hit_cnt<=read_hit_cnt+1;
else
read_miss_cnt<=read_miss_cnt+1;
end
if(write_access)begin
if(access_hit)
write_hit_cnt<=write_hit_cnt+1;
else
write_miss_cnt<=write_miss_cnt+1;
end
if(!overflow_read_hit&&(read_hit_cnt>={{(COUNTER_WIDTH-32){1'b0}},thresh_read_hit_low}))begin
overflow_read_hit<=1;
int_out<=1;
int_pending<=1;
end
if(!overflow_read_miss&&(read_miss_cnt>={{(COUNTER_WIDTH-32){1'b0}},thresh_read_miss_low}))begin
overflow_read_miss<=1;
int_out<=1;
int_pending<=1;
end
if(!overflow_write_hit&&(write_hit_cnt>={{(COUNTER_WIDTH-32){1'b0}},thresh_write_hit_low}))begin
overflow_write_hit<=1;
int_out<=1;
int_pending<=1;
end
if(!overflow_write_miss&&(write_miss_cnt>={{(COUNTER_WIDTH-32){1'b0}},thresh_write_miss_low}))begin
overflow_write_miss<=1;
int_out<=1;
int_pending<=1;
end
end
end
end

always@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
snap_read_hit<=0;
snap_read_miss<=0;
snap_write_hit<=0;
snap_write_miss<=0;
snap_valid_read_hit<=0;
snap_valid_read_miss<=0;
snap_valid_write_hit<=0;
snap_valid_write_miss<=0;
end
else begin
if(read_low_0)begin
snap_read_hit<=read_hit_cnt;
snap_valid_read_hit<=1;
end
if(read_low_1)begin
snap_read_miss<=read_miss_cnt;
snap_valid_read_miss<=1;
end
if(read_low_2)begin
snap_write_hit<=write_hit_cnt;
snap_valid_write_hit<=1;
end
if(read_low_3)begin
snap_write_miss<=write_miss_cnt;
snap_valid_write_miss<=1;
end
end
end

always@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
thresh_read_hit_low<=32'hFFFFFFFF;
thresh_read_miss_low<=32'hFFFFFFFF;
thresh_write_hit_low<=32'hFFFFFFFF;
thresh_write_miss_low<=32'hFFFFFFFF;
end
else begin
if(write_thresh_0)
thresh_read_hit_low<=reg_wr_data;
if(write_thresh_1)
thresh_read_miss_low<=reg_wr_data;
if(write_thresh_2)
thresh_write_hit_low<=reg_wr_data;
if(write_thresh_3)
thresh_write_miss_low<=reg_wr_data;
end
end

always@(*)begin
rdata_next=0;
case(reg_addr)
5'd0:rdata_next=read_hit_cnt[DATA_WIDTH-1:0];
5'd1:rdata_next=read_miss_cnt[DATA_WIDTH-1:0];
5'd2:rdata_next=write_hit_cnt[DATA_WIDTH-1:0];
5'd3:rdata_next=write_miss_cnt[DATA_WIDTH-1:0];
5'd4:rdata_next=0;
5'd5:rdata_next=snap_valid_read_hit?snap_read_hit[HIGH_MSB:HIGH_LSB]:(HIGH_MSB<COUNTER_WIDTH?read_hit_cnt[HIGH_MSB:HIGH_LSB]:0);
5'd6:rdata_next=snap_valid_read_miss?snap_read_miss[HIGH_MSB:HIGH_LSB]:(HIGH_MSB<COUNTER_WIDTH?read_miss_cnt[HIGH_MSB:HIGH_LSB]:0);
5'd7:rdata_next=snap_valid_write_hit?snap_write_hit[HIGH_MSB:HIGH_LSB]:(HIGH_MSB<COUNTER_WIDTH?write_hit_cnt[HIGH_MSB:HIGH_LSB]:0);
5'd8:rdata_next=snap_valid_write_miss?snap_write_miss[HIGH_MSB:HIGH_LSB]:(HIGH_MSB<COUNTER_WIDTH?write_miss_cnt[HIGH_MSB:HIGH_LSB]:0);
5'd9:begin
rdata_next=0;
rdata_next[0]=snap_valid_read_hit;
rdata_next[1]=snap_valid_read_miss;
rdata_next[2]=snap_valid_write_hit;
rdata_next[3]=snap_valid_write_miss;
rdata_next[8]=overflow_read_hit;
rdata_next[9]=overflow_read_miss;
rdata_next[10]=overflow_write_hit;
rdata_next[11]=overflow_write_miss;
rdata_next[16]=clear_ack_sticky;
rdata_next[24]=int_pending;
end
5'd10:rdata_next=thresh_read_hit_low;
5'd11:rdata_next=thresh_read_miss_low;
5'd12:rdata_next=thresh_write_hit_low;
5'd13:rdata_next=thresh_write_miss_low;
default:rdata_next=0;
endcase
end

always@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
reg_rd_data<=0;
reg_rd_valid<=0;
clear_ack_sticky<=0;
end
else begin
if(reg_rd_en)begin
reg_rd_data<=rdata_next;
reg_rd_valid<=1;
if(reg_addr==5'd9)begin
int_pending<=0;
clear_ack_sticky<=0;
end
end
else
reg_rd_valid<=0;
end
end
endmodule

