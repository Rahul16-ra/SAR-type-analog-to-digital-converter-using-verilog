module sar_adc #(
    parameter N = 10, parameter integer VREF = 5000,parameter integer reso = VREF / (1 << N))(
input  wire clk,input  wire  reset,input  wire  start,input  wire [N-1:0]  vin,output reg  [N-1:0]  dout,output reg  eoc,output reg   busy, output reg  [$clog2(N):0] conv_time
);

    
    localparam IDLE    = 2'd0,
 SAMPLE  = 2'd1,
  CONVERT = 2'd2,
  DONE    = 2'd3;
reg [1:0] state, next_state;
 reg [N-1:0] sar_reg;
 reg [N-1:0] vin_sampled;
 reg [$clog2(N):0] bit_index;
 wire comp_out;

assign comp_out = (vin_sampled >= sar_reg*reso);
 always @(posedge clk or posedge reset) begin
 if (reset)
  state <= IDLE;
 else
    state <= next_state;
    end
 always @(*) begin
 next_state = state;
case (state)
 IDLE:
  if (start)
 next_state = SAMPLE;
 SAMPLE:
  next_state = CONVERT;
 CONVERT:
  if (bit_index == 0)
   next_state = DONE;

    DONE:
    next_state = IDLE;
        endcase
    end

   
    always @(posedge clk or posedge reset) begin
        if (reset) begin
 sar_reg  <= 0;
 vin_sampled <= 0;
 bit_index <= 0;
  dout <= 0;
 busy <= 0;
 eoc <= 0;
 conv_time <= 0;
 end
  else begin
   case (state)
 IDLE: begin
 busy <= 0;
  eoc  <= 0;
   end

 SAMPLE: begin
vin_sampled <= vin;
sar_reg     <= 0;
 sar_reg[N-1] <= 1;   
  bit_index   <= N-1;
  busy <= 1;
   conv_time   <= 0;
  end

 CONVERT: begin
 conv_time <= conv_time + 1;
if (!comp_out)
  sar_reg[bit_index] <= 0;
  if (bit_index != 0) begin
   bit_index <= bit_index - 1;
   sar_reg[bit_index-1] <= 1;
   end
     end

 DONE: begin
  dout <= sar_reg;
  busy <= 0;
   eoc  <= 1;
    end

    endcase
   end
