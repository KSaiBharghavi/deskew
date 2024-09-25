////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	version					:	0.1
//	file name				:	tb_design.sv
//	description			:	This module consists the instance of de_skew design rtl and the data will be driven to the dut through this test bench and also
//										the same data is utilized by the reference model, it is also consisting the functional coverage to check whether all the
//										scenarios have been covered or not and an self checking to cross check the functionality of the de_skew design.
//
//	parameters used	:	DATA_WIDTH	-> This parameter is used to define the data width of each stream data.
//										CLK_PERIOD	-> This parameter is used to define the clock period of the de_skew design.
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

`ifndef TB_DESIGN
`define TB_DESIGN

parameter DATA_WIDTH 	= 4;
parameter	CLK_PERIOD	=	10;

module tb_design;

  // Declare inputs as reg and outputs as wire
  reg 				i_clk;
  reg 	[3:0] i_stream1;
  reg 	[3:0] i_stream2;
  wire	[7:0]	o_stream;
  wire 				o_aligned;

  // Instantiate the design under test (DUT)
  deskew_design	dut (
    .i_clk(i_clk),
    .i_stream1(i_stream1),
    .i_stream2(i_stream2),
    .o_stream(o_stream),
    .o_aligned(o_aligned));

  // Clock generation
  initial begin
    i_clk = 0;
    forever #(CLK_PERIOD/2) i_clk = ~i_clk; // 10 time units clock period
  end

	//Internal Variables used inside of an initial block to generate the stream data.
  int seed;
  int skew;
  int pos1, pos2;
  int stream_choice; // Variable to determine whether A appears first on i_stream1 or i_stream2

  // Define the input sequences
  reg [3:0] stream1_sequence[0:19];
  reg [3:0] stream2_sequence[0:19];

  // Stimulus generation
  initial begin
    seed = $urandom; // Seed for random number generation
    skew = $urandom_range(0,2); // Random skew of 0, 1, or 2 clock cycles
    pos2 = $urandom_range(0,7 - skew); // Random position for A in the first stream
    pos1 = pos2 + skew; // Position for A in the second stream with skew
    stream_choice = $urandom_range(0, 1); // Randomly choose which stream gets A first


    // Generate random values for the sequences
    foreach (stream1_sequence[i]) begin
      stream1_sequence[i] = $urandom_range(0, 15) & 4'hF;
      // Ensure 'A' does not appear more than once on i_stream1
      while (stream1_sequence[i] == 4'hA) begin
        stream1_sequence[i] = $urandom_range(0, 15) & 4'hF;
      end

      stream2_sequence[i] = $urandom_range(0, 15) & 4'hF;
      // Ensure 'A' does not appear more than once on i_stream2
      while (stream2_sequence[i] == 4'hA) begin
        stream2_sequence[i] = $urandom_range(0, 15) & 4'hF;
      end
    end

    // Insert value 'A' at the calculated positions
    if (stream_choice == 0) begin
      stream1_sequence[pos1] = 4'hA;
      stream2_sequence[pos2] = 4'hA;
    end else begin
      stream1_sequence[pos2] = 4'hA;
      stream2_sequence[pos1] = 4'hA;
    end

    // Apply stimulus
    for (int i = 0; i < 20; i++) begin
      #10;
      i_stream1 = stream1_sequence[i];
      i_stream2 = stream2_sequence[i];
    end

    // End simulation
    #10ns;
    $finish;
//		$stop;
  end

  // Monitor signals
  initial begin
    $monitor("Time: %0t | i_clk: %b | i_stream1: %h | i_stream2: %h | o_stream: %h | o_aligned: %b",
             $time, i_clk, i_stream1, i_stream2, o_stream, o_aligned);
  end


	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//Reference Model Logic	:	This logic does the same functionality as like an de_skew design and it will be used to verify the correctness of actual
	//rtl design.
	///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	//These 2 queues are used to store the data temporarily until an data alignment happens.
	logic [DATA_WIDTH-1:0] 			data1[$:2];
	logic [DATA_WIDTH-1:0] 			data2[$:2];

	//These bits are used to indicate the stream key is arrived in the particular stream.
	bit										 			st1_en,st2_en;

	//These bits are used to store the stream key values obtained in the previous clock cycle.
	bit													st1_prev,st2_prev;

	//These variables will be used to make the data synchronous to the clock, so that reduces the conficts between the combinational and sequential
	//circuits.
	logic [DATA_WIDTH-1:0] 			d1,d2;

	//These variables are used to store final stream values in each cycles right from the point data stream alignment is happens.
	logic 								 			str1,str2;
	
	//This is the variable reprsents the data_aligned flag for the reference model.
	logic 											ref_aligned;

	//This variable represents the reference model output stream data. 
	logic [(2*DATA_WIDTH)-1:0]	ref_stream;

	//This even is used to sample the covergroup when this event is called.
	event 											data_sample;

	//This internal variable is used as an flag to display the status the rtl design whether it is behaving as per functionality or not.
	bit													error_flag;

	//This logic consists the functionality of reference model de_skew design, at every positive edge of the clock it checks for the stream key in each
	//stream and then if the stream key is arrived in any stream, stream enable corresponding to that stream will be enable for whole circuit operation.
	//Such that d1,d2 are data values that are synchronized with the clock. And the st1_prev,st2_prev variables will be assigned with the previous
	//values of the stream enable value until the data alignment happens.
	always_ff@(posedge i_clk)
	begin
		if(i_stream1 == 4'ha)	st1_en	<= 1'b1;
		if(i_stream2 == 4'ha)	st2_en	<= 1'b1;
		d1				<= i_stream1;
		d2				<= i_stream2;
		if(!ref_aligned)
		begin
			st1_prev	<= st1_en;
			st2_prev	<= st2_en;
		end
	end

	//This logic will represent the storage unit of the data for the entire operation. Once the stream key is arrived in the particular stream, then at
	//each cycles the data will be stored into the queue and once it reaches the limit, immediately an pop operation will be performed. And, once the
	//stream key's are arrived in both the streams then the data from the each queue is popped and then depending on arrival of each key, the data
	//concatenation will be happened and sent as an out stream value by asserting the ref_aligned bit. Until alignment the ref_aligned bit will be set
	//to zero.
	always_comb
	begin
		if(st1_en)
		begin
			data1.push_back(d1);
			if((data1.size() > 3))	void'(data1.pop_front());
		end
		if(st2_en)
		begin
			data2.push_back(d2);
			if((data2.size() > 3))	void'(data2.pop_front());
		end
		if(st1_en & st2_en)
		begin
			ref_aligned	=	1'b1;
			ref_stream	=	data_order((st1_prev | (~st2_prev)),data1.pop_front(),data2.pop_front());
		end
		else	ref_aligned	=	1'b0;
	end

	//This function will order the input data stream's according to the enable provided to the function call.
	function logic [(2*DATA_WIDTH)-1:0] data_order;
		input logic en;
		input logic [DATA_WIDTH-1:0]	s1,s2;
		if(en)	data_order	=	{s2,s1};
		else		data_order	=	{s1,s2};
	endfunction : data_order

	//This block will be used to trigger the event data_sample at every posedge of the clk to sample the data for the functional coverage.
	always_ff@(posedge i_clk)
	begin
			->data_sample;
	end
	
	//This logic will be used for the funcitional coverage purpose, so that it will be an easier to create the scenario's. It will be asserted when the
	//stream key is appeared in the stream else it will be de-asserted.
	always_comb
	begin
		str1	=	(i_stream1=='hA);
		str2	=	(i_stream2=='hA);
	end

	//Functional Coverage	:	This covergroup created the scenarios that the design need to be covered, as the st1 and str2 bits denote the stream key
	//arrival in both the streams, along with them o_aligned is used to create the scenarios. The scenarios will be like the arrival of the stream keys
	//are at different times and also it checks whether the o_aligned is being asserted, after stream key's are arrived.
	covergroup de_skew_cg@(posedge i_clk);
		ST1:	coverpoint	{o_aligned,str1,str2}{																				//Seeds for the each scenario.
															wildcard bins s1	=	(3'b010=>3'b0x1=>3'b1xx);					//3634114009
															wildcard bins s2	=	(3'b010=>3'b000=>3'b001=>3'b1xx);	//985414590
															wildcard bins s3	=	(3'b001=>3'b01x=>3'b1xx);					//2805894361
															wildcard bins s4	=	(3'b001=>3'b000=>3'b010=>3'b1xx);	//1849449789
															wildcard bins s5	=	(3'b0xx=>3'b011=>3'b1xx);					//2686216663
															}
	endgroup	: de_skew_cg

	//Covergroup instance declaration and creation.
	de_skew_cg cg=new();
	
	//Self Checking logic : After alignment if any data mismatch happens the actual and expected data will be displayed and the $finish system task will
	//be called.
	always_ff@(posedge i_clk)
	begin
		if(ref_aligned)
		begin
			if(o_stream	!= ref_stream)
			begin
				$display("Data Mismatch Happens at %0tns time slot",$time);			
				$display("Expected Data	:	%h",ref_stream);
				$display("Actual Data		:	%h",o_stream);
				error_flag	=	1'b1;
				//$finish;
			end
		end
	end

	final begin
		if(error_flag)	$display("The De_skew is not working as per the functionality");
		else						$display("The De_skew is working as per the functionality");
	end
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////

endmodule

`endif	//TB_DESIGN
