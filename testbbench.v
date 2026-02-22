module sar_adc_tb;
parameter N = 10;
parameter VREF = 5000;
parameter reso = VREF / (1 << N);
reg clk;
reg reset;
reg start;
reg [N-1:0] vin;
wire [N-1:0] dout;
wire eoc,busy;
wire [$clog2(N):0] conv_time;

sar_adc #(.N(N), .VREF(VREF),.reso(reso)) dut (.clk(clk),.reset(reset),.start(start),.vin(vin), .dout(dout),.eoc(eoc), .busy(busy), .conv_time(conv_time));

    
    always #5 clk = ~clk;

   
    task start_conversion;
    begin
        start = 1;
        #10;
        start = 0;
    end
    endtask
    
    

   
    initial begin

 $display(" SAR ADC TEST STARTED");

clk = 0;
reset = 1;
start = 0;
vin = 0;

 #20;
 reset = 0;

       
vin = 10'd1000;  
start_conversion();

wait(eoc);
#10;

$display("Input = %d | Output = %d | Conv Time = %d",
                  vin, dout, conv_time);

        
 vin = 10'd674;
 start_conversion();

wait(eoc);
 #10;

 $display("Input = %d | Output = %d | Conv Time = %d",
 vin, dout, conv_time);

     
 vin = 10'd336;
  start_conversion();

 wait(eoc);
 #10;

  $display("Input = %d | Output = %d | Conv Time = %d",
  vin, dout, conv_time);

        
  repeat (5) begin
  vin = $random % 32;
  start_conversion();
  wait(eoc);
    #10;
   $display("Random Input = %d | Output = %d",
    vin, dout);
   end

   $display("===== TEST FINISHED =====");
    #50;
  $stop;

  end

endmodule
