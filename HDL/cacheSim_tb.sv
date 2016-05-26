// Stephen Weston
// David H.
// Naser Alshami
// Waleed Alhaddad
// 5/12/2016
// ECE 585, Spring 2016
// Final Project

/*
>> TODO: Add a module description
>> 
>> 
>> 
>> 
*/ 

// Comment this out to disable debug mode
`define DEBUG 1

typedef shortint unsigned u16;
typedef int unsigned u32;
typedef longint unsigned u64;
typedef shortreal float;
typedef real double;

module cacheSim_tb
#(
	parameter u16 ADDRESS_SIZE = 16
)
(	// ports
	output reg rw, clk, reset,
	output reg [ADDRESS_SIZE-1:0] address
);

	// File handles
	integer in, out;
	integer Istatus, Ostatus;

	// DUT Instantiation
	cacheSim #(
		.SETS(16),
		.ASSOC(2),
		.LINESIZE(16),
		.ADDRESS_SIZE(ADDRESS_SIZE)
	)
	C1 (.*);
	
	// Main block
	initial begin
		
		rw = 1'b0;
		address = '0;
		clk = 1'b1;
		
		reset = 1'b1;
		#5;
		reset = 1'b0;
		
		in = $fopen("test_traces.txt", "r");
		out = $fopen("test_results.txt", "w");
		
		// Debug - making sure that the module separates the address into proper fields
		`ifdef DEBUG
			$fwrite(out, "bswidth: %0d\n", C1.bsWidth);
			$fwrite(out, "indexwidth: %0d\n", C1.indexWidth);
			$fwrite(out, "tagwidth: %0d\n\n", C1.tagWidth);
		`endif
		
		// Begin testing...
		while(!$feof(in)) begin
		
			@(negedge clk);	// wait for negative edge to change data
			
			Istatus = $fscanf(in, "%h %h\n", rw, address);	// TODO: add error checking for Istatus
			
			@(posedge clk);
			#1;	// wait for the module's data to settle
			
			// Debug - make sure that important variables are correct
			`ifdef DEBUG
				$fwrite(out, "Address: %h\n", address);
				$fwrite(out, "index: %h\n", C1.cache_index);
				$fwrite(out, "tag: %h\n", C1.cache_tag);
				$fwrite(out, "invalid flag: %h\n", C1.invalid_flag);
				$fwrite(out, "LRU Address: %h\n", C1.LRU_address);
				$fwrite(out, "iLRU Address: %h\n", C1.i_LRU_address);
				$fwrite(out, "LRU Set: %h\n", C1.LRU_set);
				$fwrite(out, "iLRU Set: %h\n", C1.i_LRU_set);
				$fwrite(out, "LRU Evict: %h\n", C1.LRU_evict[$]);
				$fwrite(out, "Queue contains:");
				for (int i = 0; i < C1.LRU_queue.size(); i++)
					$fwrite (out, " %h", C1.LRU_queue[i]);
				$fwrite(out, "\ncache[2]: %h\n", C1.cache[2][C1.cache_index][C1.tagWidth+2:3]);
				$fwrite(out, "cache[1]: %h\n", C1.cache[1][C1.cache_index][C1.tagWidth+2:3]);
				
				// Record the results - moved this block here for debug
				$fwrite(out, "Number of Accesses: %0d\n", C1.cAccesses);
				$fwrite(out, "Number of Reads: %0d\n", C1.cReads);
				$fwrite(out, "Number of Writes: %0d\n", C1.cWrites);
				$fwrite(out, "Number of Hits: %0d\n", C1.cHits);
				$fwrite(out, "Number of Misses: %0d\n", C1.cMisses);
				$fwrite(out, "Number of Evictions: %0d\n", C1.numEvictions);
				$fwrite(out, "Number of Writebacks: %0d\n", C1.numWritebacks);
				$fwrite(out, "Hit Ratio: %.2f%%\n", C1.hitRatio);
				$fwrite(out, "Miss Ratio: %.2f%%\n\n", C1.missRatio);
			`endif
			
		end
		
		@(negedge clk);
		/*
		// Record the results
		$fwrite(out, "Number of Accesses: %0d\n", C1.cAccesses);
		$fwrite(out, "Number of Reads: %0d\n", C1.cReads);
		$fwrite(out, "Number of Writes: %0d\n", C1.cWrites);
		$fwrite(out, "Number of Hits: %0d\n", C1.cHits);
		$fwrite(out, "Number of Misses: %0d\n", C1.cMisses);
		$fwrite(out, "Number of Evictions: %0d\n", C1.numEvictions);
		$fwrite(out, "Number of Writebacks: %0d\n", C1.numWritebacks);
		$fwrite(out, "Hit Ratio: %.2f%%\n", C1.hitRatio);
		$fwrite(out, "Miss Ratio: %.2f%%\n\n", C1.missRatio);
		*/
		$fclose(in);
		$fclose(out);
		$finish;
		
	end

	// Clock generator
	always clk = #5 ~clk;

	
endmodule: cacheSim_tb
