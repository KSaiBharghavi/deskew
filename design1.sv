/*////////////////////////////////////////////////////////////////////////////
// Version:0.1
// File Name: design.sv
// Description: A module that implements de-skew logic to align tow input
                streams and concatenates the. It detect a specific value ('hA)
                on both input streams within a certain skew and produce a 
                combined output stream starting from the alignment point.
////////////////////////////////////////////////////////////////////////////*/
module deskew_design #(parameter SKEW = 2)(
  				input        i_clk,
  				input  [3:0] i_stream1,
 				input  [3:0] i_stream2,
  				output logic [7:0] o_stream,
  				output logic       o_aligned
			 );

  bit [2:0] flag;					//variable for the detect of specific value
  logic [3:0] stream_mem [SKEW:0];  //mem for the storage of the values
  bit [$clog2(SKEW):0] count=0;     //count to detect which skew is given
 
  //logic to detect a specific value ('hA) 
  always_comb 
  begin
    if((i_stream1 == 4'ha && i_stream2 == 4'ha)
       || (i_stream1 == 4'ha && flag[1]) 
       || (i_stream2 == 4'ha && flag[0])|| flag[2]) flag[2] = 1'b1;
    else if((i_stream1 == 4'ha && !flag[1]) || flag[0]) begin flag[0] = 1'b1; count+=1; end
    else if((i_stream2 == 4'ha && !flag[0]) || flag[1]) begin flag[1] = 1'b1; count+=1; end
    else flag = flag;
  end

  //logic to store the value when deskew is >0.
  always_ff @(posedge i_clk)
  begin
    if(flag[0] && !flag[1]) 
    begin
      stream_mem[0] <= i_stream1; 
      for(int i=1;i<=count;i++)
        stream_mem[i] <= stream_mem[i-1];
    end
    else if(flag[1] && !flag[0])
    begin
      stream_mem[0] <= i_stream2;
      for(int i=1;i<=count;i++)
        stream_mem[i] <= stream_mem[i-1];
    end
  end
 
  //logic to concatenate the o_stream according to the flags.
  always_ff @(posedge i_clk)
  begin
    o_aligned <= flag[2]; 
    if(flag[2] && !flag[0] && !flag[1]) o_stream <= {i_stream1,i_stream2}; 
    else if(flag[0] && !flag[1] && flag[2]) o_stream <= {stream_mem[count-1],i_stream2};
    else if(!flag[0] && flag[1] && flag[2]) o_stream <= {i_stream1,stream_mem[count-1]};
    else o_stream <= o_stream;
  end

endmodule
