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

typedef shortint unsigned u16;
typedef int unsigned u32;
typedef longint unsigned u64;
typedef shortreal float;
typedef real double;

module cacheSim
#(	// parameters
	parameter u32 SETS = 1028,	 	// assuming this is sets per way
	parameter u32 ASSOC = 2,
	parameter u32 LINESIZE = 16,	// in bytes
	parameter u16 ADDRESS_SIZE = 16
)
(	// ports
	input rw, clk, reset,
	input [ADDRESS_SIZE-1:0] address
);

	// Determining our address bits variables
	localparam u16 bsWidth = $clog2( LINESIZE );				// Byteselect Width (number of bits)
	localparam u16 indexWidth = $clog2( SETS );						// Index Width
	localparam u16 tagWidth = ADDRESS_SIZE - bsWidth - indexWidth;	// Tag Width
	localparam u16 assocWidth = $clog2( ASSOC );					// Associativity Width

	// Internal nets
	logic [indexWidth:1] cache_index;
	logic [tagWidth:1]   cache_tag;
	
	// Internal Statistics Variables
	u32 cAccesses, cReads, cWrites, cHits, cMisses;
	u32 numEvictions, numWritebacks;
	float hitRatio, missRatio;
	
	// Comparator Variables
	reg [ASSOC:1] temp_hit;
	reg hit;
	
	// LRU Policy will be using queues
	u32 t1[$];
	u32 t2[$];
	u32 t3[$];
	u32 temp_LRU_index[$];
	u32 temp_LRU_set[$];
	reg [assocWidth:0] LRU_set, i_LRU_set;
	u32 LRU_address, i_LRU_address;
	u32 LRU_queue[$];
	u32 LRU_update[$];
	reg LRU_dirty, invalid_flag;
	u32 LRU_evict[$];
	
	// Our Cache Model
	// There are two extra bits for valid and dirty bits, which are the two lsb's: {tag, dirty, valid}
	typedef reg [(tagWidth + 2):1] singlecache [SETS:1];
	
	// Create more for all the "ways"
	singlecache cache[ASSOC:1];

	// CAS statements for ease of editing
	assign cache_tag = address[(bsWidth + indexWidth + tagWidth) : (bsWidth + indexWidth)];
	assign cache_index = address[(bsWidth + indexWidth) : bsWidth];
	
	// error check the parameters
	initial begin
	
		if(SETS < 1 || SETS > 2**28 || SETS % 2 != 0)
			$fatal("The SETS parameter is incorrect. Please choose a value between 2 and 2**28 that is a multiple of 2.\n");
			
		if(ASSOC < 2 || ASSOC % 2 != 0)
			$fatal("The ASSOC parameter is incorrect. Please choose a value that is a multiple of 2.\n");

		if(LINESIZE < 8 || LINESIZE > 128 || LINESIZE % 2 != 0)
			$fatal("The LINESIZE parameter is incorrect. Please choose a value between 8 and 128 that is a multiple of 2.\n");			
		
	end
	
	// Take the next step, write tags and valid / dirty bits if need be
	always_ff @(posedge clk or posedge reset) begin : Sequential
		
		// Reset our Variables
		// Asynchronous, active-high reset
		if(reset === 1'b1) begin
			
			cAccesses <= '0;
			cReads <= '0;
			cWrites <= '0;
			cHits <= '0;
			cMisses <= '0;
			numEvictions <= '0;
			numWritebacks <= '0;
			
			foreach(cache[i,j])
				cache[i][j] <= '0;
			
		end
		
		else begin
			
			// Parse the input
			if(rw === 1'b0) begin // This is a read
				
				cAccesses <= cAccesses + 1'b1;
				cReads <= cReads + 1'b1;
				
				// READ HIT
				if(hit === 1'b1) begin
				
					cHits <= cHits + 1'b1;
					LRU_queue.delete(LRU_update[$]);					// pop out the old location
					LRU_queue.push_front(address[ADDRESS_SIZE-1:bsWidth]);	// put this address at the most recently used
				
				end
				
				// READ MISS
				else begin
				
					cMisses <= cMisses + 1'b1;
					
					if(invalid_flag === 1'b1) begin
					
						// Write new "data" (only writing the tag, dirty, and valid bits)
						cache[i_LRU_set][cache_index] <= {cache_tag, 1'b0, 1'b1};
					
					end
					
					else begin
					
						numEvictions <= numEvictions + 1;
						
						LRU_queue.delete(LRU_evict[$]);		// delete evicted address from LRU queue
						
						if(LRU_dirty === 1'b1)
							numWritebacks <= numWritebacks + 1;
							
						// Write new "data" (only writing the tag, dirty, and valid bits)
						cache[LRU_set][cache_index] <= {cache_tag, 1'b0, 1'b1};
					
					end
						
					LRU_queue.push_front(address[ADDRESS_SIZE-1:bsWidth]);	// put this address at the most recently used
				
				end
				
			end
			
			else begin // This is a write
				
				cAccesses <= cAccesses + 1'b1;
				cWrites <= cWrites + 1'b1;
				
				// WRITE HIT
				if(hit === 1'b1) begin
				
					cHits <= cHits + 1'b1;
					
					LRU_queue.delete(LRU_update[$]);							// delete the old location
					LRU_queue.push_front(address[ADDRESS_SIZE-1:bsWidth]);		// put this address at the most recently used
				
				end
				
				// WRITE MISS
				else begin
				
					cMisses <= cMisses + 1'b1;
					
					if(invalid_flag === 1'b1) begin
					
						// Write new "data" (only writing the tag, dirty, and valid bits)
						cache[i_LRU_set][cache_index] <= {cache_tag, 1'b1, 1'b1};
					
					end
					
					else begin
					
						numEvictions <= numEvictions + 1;
						
						LRU_queue.delete(LRU_evict[$]);		// delete evicted address from LRU queue
						
						if(LRU_dirty === 1'b1)
							numWritebacks <= numWritebacks + 1;
							
						// Write new "data" (only writing the tag, dirty, and valid bits)
						cache[LRU_set][cache_index] <= {cache_tag, 1'b1, 1'b1};
					
					end
					
					LRU_queue.push_front(address[ADDRESS_SIZE-1:bsWidth]);	// put this address at the most recently used
					
				end
				
			end
			
		end
		
	end : Sequential

	// Comparator - finds hits and misses
	// Also the LRU - finds least recently used if replacement is needed
	always_comb begin : Comparator
		
		// initialize these to empty
		temp_LRU_index = {};
		temp_LRU_set = {};
		LRU_dirty = 1'b0;
		invalid_flag = 1'b0;
		i_LRU_set = '0;
		i_LRU_address = '0;
		LRU_set = '0;
		LRU_address = '0;
		
		if(rw === 1'b0) begin // READ
		
			// Look through all associative ways
			for(int i = 1; i <= ASSOC; i++) begin
			
				// go to cache i, index from address, and read the tag
				// also check validity
				if( cache[i] [cache_index][(tagWidth + 2): 3] === cache_tag && cache[i][cache_index][1] === 1'b1) begin
					
					// If tag matches and data is valid, the read is a hit
					temp_hit[i] = 1'b1;
					LRU_update = unsigned'(LRU_queue.find_first_index with (item == address[ADDRESS_SIZE-1:bsWidth]));
					
				end
				
				else begin	// Otherwise, we have a miss
				
					temp_hit[i] = 1'b0;
					
					// If invalid, we want to load data in here
					if (cache[i][cache_index][1] === 1'b0) begin
						
						invalid_flag = 1'b1;
						i_LRU_set = i;					// Save the set number
						i_LRU_address = {cache[i][cache_index][(tagWidth + 2):3], cache_index};
						
					end
					
					else begin  // Valid data that may need to be evicted
					
						// Save this index for comparison in our LRU later
						t1 = unsigned'(LRU_queue.find_last_index with (item == {cache[i][cache_index][(tagWidth + 2):3], cache_index}));
						if ($size(t1) !== 0) begin
						
							temp_LRU_index.push_front(t1[$]);
							temp_LRU_set.push_front(i);
						
						end
					
					end
						
				end
				
			end
			
		end
		
		else begin // WRITE
		
			// Look through all associative ways
			for(int i = 1; i <= ASSOC; i++) begin
			
				// go to cache i, index from address, and read the tag
				if( cache[i] [cache_index][(tagWidth + 2):3] !== cache_tag ) begin
					
					// If there is no tag match, the write is a miss
					temp_hit[i] = 1'b0;
					
					// If invalid, we want to write data to here
					if (cache[i] [cache_index] [ 1 ] === 1'b0) begin
						
						invalid_flag = 1'b1;
						i_LRU_set = i;	// Save the set number
						i_LRU_address = {cache[i][cache_index][(tagWidth + 2):3], cache_index};
						
					end
					
					else begin // Valid data that may need to be evicted
					
						// Save this index for comparison in our LRU later
						t1 = unsigned'(LRU_queue.find_last_index with (item == {cache[i][cache_index][(tagWidth + 2):3], cache_index}));
						if ($size(t1) !== 0) begin
						
							temp_LRU_index.push_front(t1[$]);
							temp_LRU_set.push_front(i);
						
						end
					
					end
					
				end
				
				else begin	// Otherwise, we have a hit
				
					temp_hit[i] = 1'b1;
					
					LRU_update = unsigned'(LRU_queue.find_first_index with (item == address[ADDRESS_SIZE-1:bsWidth]));
					
				end
				
			end
		
		end
		
		// Save our final numbers to add to the queue
		if ($size(temp_LRU_index) !== 0) begin

			t2 = temp_LRU_index.max();									// The max index found from the main queue is the LRU cacheline
			t3 = unsigned'(temp_LRU_index.find_first_index with (item == t2[$]));	// Here, we find out where the max is located so we can save the address to replace
			LRU_set = temp_LRU_set[t3[$]];								//   as well as the set number
			LRU_address = {cache[LRU_set][cache_index][(tagWidth + 2):3], cache_index};
			LRU_dirty = cache[LRU_set][cache_index][2];
			LRU_evict = unsigned'(LRU_queue.find_first_index with (item == LRU_address));

		end
		
		hit = |temp_hit;
		
	end : Comparator
	
	
	// Ratio Calculator
	always_comb begin : Ratios
	
		if(cAccesses !== 0) begin
		
			hitRatio = float'(cHits) / float'(cAccesses) * float'(100);
			missRatio = float'(cMisses) / float'(cAccesses) * float'(100);
			
		end
			
		else begin
		
			hitRatio = 100;
			missRatio = 0;
			
		end
	
	end : Ratios
	
endmodule : cacheSim
