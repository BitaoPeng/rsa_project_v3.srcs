`timescale 1ns / 1ps

`define RESET_TIME 25
`define CLK_PERIOD 10
`define CLK_HALF 5

module tb_montgomery();
    
    reg          clk;
    reg          resetn;
    reg          start;
    reg  [1023:0] in_a;
    reg  [1023:0] in_b;
    reg  [1023:0] in_m;
    wire [1023:0] result;
    wire         done;

    reg  [1023:0] expected;
    reg          result_ok;
    
    //Instantiating montgomery module
    montgomery montgomery_instance( .clk    (clk    ),
                                    .resetn (resetn ),
                                    .start  (start  ),
                                    .in_a   (in_a   ),
                                    .in_b   (in_b   ),
                                    .in_m   (in_m   ),
                                    .result (result ),
                                    .done   (done   ));

    //Generate a clock
    initial begin
        clk = 0;
        forever #`CLK_HALF clk = ~clk;
    end
    
    //Reset
    initial begin
        resetn = 0;
        #`RESET_TIME resetn = 1;
    end
    
    // Test data
    initial begin

        #`RESET_TIME
        
        // You can generate your own with test vector generator python script
        in_a     <= 1024'h993a45a7ccc9834b9775fbbf1be8566199cf3883f29a2846a7357f314b1b6a719edf9b543addb902a023885c72b83d21d6bc2a14ed8adef3566f0da4c541f83c882bc4a1c21cb045d17eb1f773535af04b82a90c5823ac4f3076dbbd37c7019cb84e7b2e21849abd2860ef93d144c8564492ec8036b3d1a51bd98c94c145d8c3;
        in_b     <= 1024'ha21716d123007a82e337ffa9de869fbebb20cd18955897dc2b9e096146b56d5706ee40c1d38b6ab293f1ea65d8d8c98bbaad3ddd301080f3f1e11e02aa5c19b22a62d225bab93a13b629bfb493792fed1b7fa42442888c8e71b6de10dedeaa77a5c8a15bad9380346279ebc55720df62186e222a698a238f472e7d24ad2c6b2f;
        in_m     <= 1024'hc195d759bc8a96f3a59c363f4f4d8b596ce12e0aca41fca232eb07944fc92b2f798a902095c69a1c8c3ecd049169fe7ed2d1ae296658546e5b500edcf935e9a1a11ab841332a7a430f188012e42162703fbfba6be85ada06ec9a4fd80dab436c7a60ef5c1aa0a67c4542049b94dc649e57c56f782498df91c78f7c463cb6329d;
        expected <= 1024'h2029a1aea1321437516fe9dd75d3d95eed38ea38b190c4e4d566d103d4b0831b28a6fc19127e7d92c8913a4b53c8470aadf95fa738eb8908590223f58c0f63939e33bf4eab1f29b7a7742509fa0bc7814f11cd28a1ff05666e47d1c9a32462744257ba69c6165bb158792c4959bc3b874c89b6985a95a13512b98bd72c9db18e;
        
        start<=1;
        #`CLK_PERIOD;
        start<=0;
        
        wait (done==1);
        
        $display("result calculated=%x", result);
        $display("result expected  =%x", expected);
        $display("error            =%x", expected-result);
        result_ok = (expected==result);
        #`CLK_PERIOD;   
        
        $finish;
    end
           
endmodule