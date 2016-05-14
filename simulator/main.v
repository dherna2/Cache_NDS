`timescale 1ns / 1ps

module text_read_write;
  reg [7:0] mem [0:4];
  integer m,i;

  initial
    begin
// To read text file into memory
      $readmemh("mem_in.txt", mem);

// To write content of memory to another text file      
      m=$fopen("mem_out.txt");
      for(i=0;i<5;i=i+1)
         begin
           $fdisplay(m,"%h",mem[i]);
         end
      $fclose(m);

    end
endmodule
