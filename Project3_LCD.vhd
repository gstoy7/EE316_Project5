--dataIn and dataOut allocations are what get changed
--For dataOut, figure out how states change, and go from there
--dataOut will be what determines the characters getting sent to the LCD (I think)

----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 03/02/2021 04:01:50 PM
-- Design Name: 
-- Module Name: i2c_user_logic - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
--LIFTED DIRECTLY FROM PREVIOUS PROJECT
--Contributor(s): Garrett Stoyell
--Last modification: 3/11/21 05:10:32 AM

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity lcd_i2c_user_logic is
	PORT(
			clock			: in std_logic;
			clkGEN          : in std_logic;
--			dataIn			: in std_logic_vector(23 downto 0);
			config          : in std_logic_vector(1 downto 0);
--			byteSel		: inout integer := 0;
--			data_wr		: out std_logic_vector(7 downto 0);
			outSCL			: inout std_logic;
			outSDA			: inout std_logic
--			en				: in std_logic;
--			busy 			: in std_logic
	);
end lcd_i2c_user_logic;

architecture behavioral of lcd_i2c_user_logic is

component LCD_i2c_master is
  GENERIC(
    input_clk : INTEGER := 125_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 400_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
END component LCD_i2c_master;

signal busyReg, busySig, reset, init_lcd, enable, r_w, ackSig : std_logic;
signal regData	: std_logic_vector(15 downto 0);
signal dataOut	: std_logic_vector(7 downto 0);
signal byteSel	: integer := 0;
type state_type is (start,write_data, counting, pause, repeat);
signal state : state_type := start;
signal address : std_logic_vector(6 downto 0);
signal Cont 	: integer := 1875000;
signal lcd_pos  : integer := 0;
signal pauseCNT	 : integer;
signal configSig   : std_logic_vector (1 downto 0);
signal byteBounds    : integer := 0;
signal placeSig : std_logic_vector (1 downto 0);

begin	

output: LCD_i2c_master
port map(
	clk=>clock,
	reset_n=>reset,
	ena=>enable,
	addr=>address,
	rw=>r_w,
	data_wr=>dataOut,
	busy=>busySig,
	data_rd=>OPEN,
	ack_error=>ackSig,
	sda=>outSDA,
	scl=>outSCL
);

process(clock)
begin
if rising_edge(clock) then
--    regData <= dataIn;
    busyReg <= busySig;
end if;
end process;

process(clock)
begin
	if(clock'EVENT AND clock = '1')then
		CASE state is
		when start =>
			if cont /= 0 THEN
				cont <= cont-1;
				reset <= '0';
				state <= start;
				enable <= '0';
			ELSE	
				reset <= '1';
				enable <= '1';
				byteSel <= 0;
				byteBounds <= 41;
				address <= "0100111";
				r_w <= '0';
				dataOut <= dataOut;
				state <= write_data;
			END IF;
			
		when write_data =>
		if busySig = '0' and busySig/=busyReg then
		      if(byteSel /= byteBounds) then
			     byteSel<=byteSel+1;
		      else
		          if(config = "00" and clkGEN = '0')then
		               byteSel <= 42;
		               byteBounds <= 60;
		               placeSig <= "00";
                  elsif(config = "00" and clkGEN = '1')then
                       byteSel <= 114;
                       byteBounds <= 180;
                       placeSig <= "00";
                  elsif(config = "01" and clkGEN = '0')then
                        byteSel <= 60;
                        byteBounds <= 78;
                        placeSig <= "01";
                  elsif(config = "01" and clkGEN = '1')then
                        byteSel <= 180;
                        byteBounds <= 246;
                        placeSig <= "01";
                  elsif(config <= "10" and clkGEN = '0')then
                        byteSel <= 96;
                        byteBounds <= 114;
                        placeSig <= "10";
                  elsif(config <= "10" and clkGEN = '1')then
                        byteSel <= 246;
                        byteBounds <= 312;
                        placeSig <= "10";
                  elsif(config <= "11" and clkGEN = '0')then
                        byteSel <= 78;
                        byteBounds <= 96;
                        placeSig <= "11";
                  elsif(config <= "11" and clkGEN = '1')then
                        byteSel <= 312;
                        byteBounds <= 378;
                        placeSig <= "11";
                  end if;
              end if;
              state <= counting;
              enable <= '0';
              cont <= 5000;
        end if;
        
	when pause=>	
		if pauseCNT /= 0 then
			pauseCNT<= pauseCNT-1;
		else
			enable <= '1';
			state <=write_data;
		end if;
        when counting =>
            if cont /= 0 THEN 
                cont <= cont-1;
            elsif(placeSig <= "00" AND byteSel /= byteBounds) then
		    		 pauseCNT <= 250000;
		state<=pause;
		enable <= '0';
               -- state<=write_data;    
                --enable <= '1';
            elsif(placeSig <= "01" AND byteSel /= byteBounds) then
               --state<=write_data;
		    		 pauseCNT <= 250000;
		state<=pause;
		enable <= '0';
               --enable <= '1';  
            elsif(placeSig <= "10" AND byteSel /= byteBounds) then
                --state<=write_data; 
		    pauseCNT <= 250000;
		    state<=pause;
		
			enable <= '0';
                --enable <= '1';  
            elsif(placeSig <= "11" AND byteSel /= byteBounds) then
                --state<=write_data;
		 		 pauseCNT <= 250000;
		   state<=pause;
		 --pauseCNT <= 250000;
		 enable <= '0';
                --enable <= '1';   
            else
                state<=repeat;
            end if;                            
		when repeat=>
		  enable<='0';
    	  if configSig/=config then
			state<=start;
		else
			state<=repeat;
		end if;
	end case;
	end if;
end process;
			

ChangeState: process(byteSel,clock)
	begin	
           case byteSel is
                --INITIALIZATION SEQUENCE
                --3
                    when 0  => dataOut <= "0011"&"1000";
                    when 1  => dataOut <= "0011"&"1100";
                    when 2  => dataOut <= "0011"&"1000";
                --3	
                    when 3  => dataOut <= "0011"&"1000";
                    when 4  => dataOut <= "0011"&"1100";
                    when 5  => dataOut <= "0011"&"1000";
                --3	
                    when 6  => dataOut <= "0011"&"1000";
                    when 7  => dataOut <= "0011"&"1100";
                    when 8  => dataOut <= "0011"&"1000";
                --2
                    when 9  => dataOut <= "0010"&"1000";			
                    when 10  => dataOut <= "0010"&"1100";
                    when 11  => dataOut <= "0010"&"1000";
                --2	
                    when 12  => dataOut <= "0010"&"1000";
                    when 13  => dataOut <= "0010"&"1100";
                    when 14  => dataOut <= "0010"&"1000";
                --C
                    when 15  => dataOut <= "1100"&"1000";
                    when 16  => dataOut <= "1100"&"1100";
                    when 17  => dataOut <= "1100"&"1000";
                --0
                    when 18  => dataOut <= "0000"&"1000";
                    when 19  => dataOut <= "0000"&"1100";
                    when 20  => dataOut <= "0000"&"1000";
                --8	
                    when 21  => dataOut <= "1000"&"1000";			
                    when 22  => dataOut <= "1000"&"1100";
                    when 23  => dataOut <= "1000"&"1000";
                --0				
                    when 24  => dataOut <= "0000"&"1000";
                    when 25  => dataOut <= "0000"&"1100";
                    when 26  => dataOut <= "0000"&"1000";
                --1			
                    when 27  => dataOut <= "0001"&"1000";
                    when 28  => dataOut <= "0001"&"1100";
                    when 29  => dataOut <= "0001"&"1000";
                --0	
                    when 30  => dataOut <= "0000"&"1000";
                    when 31  => dataOut <= "0000"&"1100";
                    when 32  => dataOut <= "0000"&"1000";
                --3	
                    when 33  => dataOut <= "0011"&"1000";
                    when 34  => dataOut <= "0011"&"1100";
                    when 35  => dataOut <= "0011"&"1000";
                --0	
                    when 36  => dataOut <= "0000"&"1000";
                    when 37  => dataOut <= "0000"&"1100";
                    when 38  => dataOut <= "0000"&"1000";
                --F	
                    when 39  => dataOut <= "1111"&"1000";
                    when 40  => dataOut <= "1111"&"1100";
                    when 41  => dataOut <= "1111"&"1000";
                --END OF INITIALIZATION	

                --LDR   NO CLK
                    when 42 => dataOut <= X"49";
                    when 43 => dataOut <= X"4D";
                    when 44 => dataOut <= X"49";
                    when 45 => dataOut <= X"C9";
                    when 46 => dataOut <= X"CD";
                    when 47 => dataOut <= X"C9";
                    when 48 => dataOut <= X"49";
                    when 49 => dataOut <= X"4D";
                    when 50 => dataOut <= X"49";
                    when 51 => dataOut <= X"49";
                    when 52 => dataOut <= X"4D";
                    when 53 => dataOut <= X"49";
                    when 54 => dataOut <= X"59";
                    when 55 => dataOut <= X"5D";
                    when 56 => dataOut <= X"59";
                    when 57 => dataOut <= X"29";
                    when 58 => dataOut <= X"2D";
                    when 59 => dataOut <= X"29";
                    
                --TMP (NO CLK)
                    when 60 => dataOut <= X"59";
                    when 61 => dataOut <= X"5D";
                    when 62 => dataOut <= X"59";
                    when 63 => dataOut <= X"49";
                    when 64 => dataOut <= X"4D";
                    when 65 => dataOut <= X"49";
                    when 66 => dataOut <= X"49";
                    when 67 => dataOut <= X"4D";
                    when 68 => dataOut <= X"49";
                    when 69 => dataOut <= X"D9";
                    when 70 => dataOut <= X"DD";
                    when 71 => dataOut <= X"D9";
                    when 72 => dataOut <= X"59";
                    when 73 => dataOut <= X"5D";
                    when 74 => dataOut <= X"59";
                    when 75 => dataOut <= X"09";
                    when 76 => dataOut <= X"0D";
                    when 77 => dataOut <= X"09";
                
                --POT (NO CLK)
                    when 78 => dataOut <= X"59";
                    when 79 => dataOut <= X"5D";
                    when 80 => dataOut <= X"59";
                    when 81 => dataOut <= X"09";
                    when 82 => dataOut <= X"0D";
                    when 83 => dataOut <= X"09";
                    when 84 => dataOut <= X"49";
                    when 85 => dataOut <= X"4D";
                    when 86 => dataOut <= X"49";
                    when 87 => dataOut <= X"F9";
                    when 88 => dataOut <= X"FD";
                    when 89 => dataOut <= X"F9";
                    when 90 => dataOut <= X"59";
                    when 91 => dataOut <= X"5D";
                    when 92 => dataOut <= X"59";
                    when 93 => dataOut <= X"49";
                    when 94 => dataOut <= X"4D";
                    when 95 => dataOut <= X"49";
               
                --AMP (NO CLK)
                    when 96 => dataOut <= X"49";
                    when 97 => dataOut <= X"4D";
                    when 98 => dataOut <= X"49";
                    when 99 => dataOut <= X"19";
                    when 100 => dataOut <= X"1D";
                    when 101 => dataOut <= X"19";
                    when 102 => dataOut <= X"49";
                    when 103 => dataOut <= X"4D";
                    when 104 => dataOut <= X"49";
                    when 105 => dataOut <= X"D9";
                    when 106 => dataOut <= X"DD";
                    when 107 => dataOut <= X"D9";
                    when 108 => dataOut <= X"59";
                    when 109 => dataOut <= X"5D";
                    when 110 => dataOut <= X"59";
                    when 111 => dataOut <= X"09";
                    when 112 => dataOut <= X"0D";
                    when 113 => dataOut <= X"09";                       
                    
                 --LDR CLK GEN
                    when 114 => dataOut <= X"49";
                    when 115 => dataOut <= X"4D";
                    when 116 => dataOut <= X"49";
                    when 117 => dataOut <= X"C9";
                    when 118 => dataOut <= X"CD";
                    when 119 => dataOut <= X"C9";
                    when 120=> dataOut <= X"49";
                    when 121 => dataOut <= X"4D";
                    when 122 => dataOut <= X"49";
                    when 123 => dataOut <= X"49";
                    when 124 => dataOut <= X"4D";
                    when 125 => dataOut <= X"49";
                    when 126 => dataOut <= X"59";
                    when 127 => dataOut <= X"5D";
                    when 128 => dataOut <= X"59";
                    when 129 => dataOut <= X"29";
                    when 130 => dataOut <= X"2D";
                    when 131 => dataOut <= X"29";
                    when 132 => dataOut <= X"C8";
                    when 133 => dataOut <= X"CC";
                    when 134 => dataOut <= X"C8";
                    when 135 => dataOut <= X"08";
                    when 136 => dataOut <= X"0C";
                    when 137 => dataOut <= X"08";
                    when 138 => dataOut <= X"49";
                    when 139 => dataOut <= X"4D";
                    when 140 => dataOut <= X"49";
                    when 141 => dataOut <= X"39";
                    when 142 => dataOut <= X"3D";
                    when 143 => dataOut <= X"39";
                    when 144 => dataOut <= X"49";
                    when 145 => dataOut <= X"4D";
                    when 146 => dataOut <= X"49";
                    when 147 => dataOut <= X"C9";
                    when 148 => dataOut <= X"CD";
                    when 149 => dataOut <= X"C9";
                    when 150 => dataOut <= X"49";
                    when 151 => dataOut <= X"4D";
                    when 152 => dataOut <= X"49";
                    when 153 => dataOut <= X"B9";
                    when 154 => dataOut <= X"BD";
                    when 155 => dataOut <= X"B9";
                    when 156 => dataOut <= X"29";
                    when 157 => dataOut <= X"2D";
                    when 158 => dataOut <= X"29";    
                    when 159 => dataOut <= X"09";
                    when 160 => dataOut <= X"0D";
                    when 161 => dataOut <= X"09";
                    when 162 => dataOut <= X"49";
                    when 163 => dataOut <= X"4D";
                    when 164 => dataOut <= X"49";
                    when 165 => dataOut <= X"79";
                    when 166 => dataOut <= X"7D";
                    when 167 => dataOut <= X"79";  
                    when 168 => dataOut <= X"49";
                    when 169 => dataOut <= X"4D";
                    when 170 => dataOut <= X"49";
                    when 171 => dataOut <= X"59";
                    when 172 => dataOut <= X"5D";
                    when 173 => dataOut <= X"59";
                    when 174 => dataOut <= X"49";
                    when 175 => dataOut <= X"4D";
                    when 176 => dataOut <= X"49";
                    when 177 => dataOut <= X"E9";
                    when 178 => dataOut <= X"ED";
                    when 179 => dataOut <= X"E9";   
                --TMP CLK GEN
                    when 180 => dataOut <= X"59";
                    when 181 => dataOut <= X"5D";
                    when 182 => dataOut <= X"59";
                    when 183 => dataOut <= X"49";
                    when 184 => dataOut <= X"4D";
                    when 185 => dataOut <= X"49";
                    when 186 => dataOut <= X"49";
                    when 187 => dataOut <= X"4D";
                    when 188 => dataOut <= X"49";
                    when 189 => dataOut <= X"D9";
                    when 190 => dataOut <= X"DD";
                    when 191 => dataOut <= X"D9";
                    when 192 => dataOut <= X"59";
                    when 193 => dataOut <= X"5D";
                    when 194 => dataOut <= X"59";
                    when 195 => dataOut <= X"09";
                    when 196 => dataOut <= X"0D";
                    when 197 => dataOut <= X"09";
                    when 198 => dataOut <= X"C8";
                    when 199 => dataOut <= X"CC";
                    when 200 => dataOut <= X"C8";
                    when 201 => dataOut <= X"08";
                    when 202 => dataOut <= X"0C";
                    when 203 => dataOut <= X"08";
                    when 204 => dataOut <= X"49";
                    when 205 => dataOut <= X"4D";
                    when 206 => dataOut <= X"49";
                    when 207 => dataOut <= X"39";
                    when 208 => dataOut <= X"3D";
                    when 209 => dataOut <= X"39";
                    when 210 => dataOut <= X"49";
                    when 211 => dataOut <= X"4D";
                    when 212 => dataOut <= X"49";
                    when 213 => dataOut <= X"C9";
                    when 214 => dataOut <= X"CD";
                    when 215 => dataOut <= X"C9";
                    when 216 => dataOut <= X"49";
                    when 217 => dataOut <= X"4D";
                    when 218 => dataOut <= X"49";
                    when 219 => dataOut <= X"B9";
                    when 220 => dataOut <= X"BD";
                    when 221 => dataOut <= X"B9";
                    when 222 => dataOut <= X"29";
                    when 223 => dataOut <= X"2D";
                    when 224 => dataOut <= X"29";    
                    when 225 => dataOut <= X"09";
                    when 226 => dataOut <= X"0D";
                    when 227 => dataOut <= X"09";
                    when 228 => dataOut <= X"49";
                    when 229 => dataOut <= X"4D";
                    when 230 => dataOut <= X"49";
                    when 231 => dataOut <= X"79";
                    when 232 => dataOut <= X"7D";
                    when 233 => dataOut <= X"79";  
                    when 234 => dataOut <= X"49";
                    when 235 => dataOut <= X"4D";
                    when 236 => dataOut <= X"49";
                    when 237 => dataOut <= X"59";
                    when 238 => dataOut <= X"5D";
                    when 239 => dataOut <= X"59";
                    when 240 => dataOut <= X"49";
                    when 241 => dataOut <= X"4D";
                    when 242 => dataOut <= X"49";
                    when 243 => dataOut <= X"E9";
                    when 244 => dataOut <= X"ED";
                    when 245 => dataOut <= X"E9";  
                    
               --AMP CLK GEN
                    when 246 => dataOut <= X"49";
                    when 247 => dataOut <= X"4D";
                    when 248 => dataOut <= X"49";
                    when 249 => dataOut <= X"19";
                    when 250 => dataOut <= X"1D";
                    when 251 => dataOut <= X"19";
                    when 252 => dataOut <= X"49";
                    when 253 => dataOut <= X"4D";
                    when 254 => dataOut <= X"49";
                    when 255 => dataOut <= X"D9";
                    when 256 => dataOut <= X"DD";
                    when 257 => dataOut <= X"D9";
                    when 258 => dataOut <= X"59";
                    when 259 => dataOut <= X"5D";
                    when 260 => dataOut <= X"59";
                    when 261 => dataOut <= X"09";
                    when 262 => dataOut <= X"0D";
                    when 263 => dataOut <= X"09";
                    when 264 => dataOut <= X"C8";
                    when 265 => dataOut <= X"CC";
                    when 266 => dataOut <= X"C8";
                    when 267 => dataOut <= X"08";
                    when 268 => dataOut <= X"0C";
                    when 269 => dataOut <= X"08";
                    when 270 => dataOut <= X"49";
                    when 271 => dataOut <= X"4D";
                    when 272 => dataOut <= X"49";
                    when 273 => dataOut <= X"39";
                    when 274 => dataOut <= X"3D";
                    when 275 => dataOut <= X"39";
                    when 276 => dataOut <= X"49";
                    when 277 => dataOut <= X"4D";
                    when 278 => dataOut <= X"49";
                    when 279 => dataOut <= X"C9";
                    when 280 => dataOut <= X"CD";
                    when 281 => dataOut <= X"C9";
                    when 282 => dataOut <= X"49";
                    when 283 => dataOut <= X"4D";
                    when 284 => dataOut <= X"49";
                    when 285 => dataOut <= X"B9";
                    when 286 => dataOut <= X"BD";
                    when 287 => dataOut <= X"B9";
                    when 288 => dataOut <= X"29";
                    when 289 => dataOut <= X"2D";
                    when 290 => dataOut <= X"29";    
                    when 291 => dataOut <= X"09";
                    when 292 => dataOut <= X"0D";
                    when 293 => dataOut <= X"09";
                    when 294 => dataOut <= X"49";
                    when 295 => dataOut <= X"4D";
                    when 296 => dataOut <= X"49";
                    when 297 => dataOut <= X"79";
                    when 298 => dataOut <= X"7D";
                    when 299 => dataOut <= X"79";  
                    when 300 => dataOut <= X"49";
                    when 301 => dataOut <= X"4D";
                    when 302 => dataOut <= X"49";
                    when 303 => dataOut <= X"59";
                    when 304 => dataOut <= X"5D";
                    when 305 => dataOut <= X"59";
                    when 306 => dataOut <= X"49";
                    when 307 => dataOut <= X"4D";
                    when 308 => dataOut <= X"49";
                    when 309 => dataOut <= X"E9";
                    when 310 => dataOut <= X"ED";
                    when 311 => dataOut <= X"E9"; 
                      
                 --POT CLK GEN
                    when 312 => dataOut <= X"59";
                    when 313 => dataOut <= X"5D";
                    when 314 => dataOut <= X"59";
                    when 315 => dataOut <= X"09";
                    when 316 => dataOut <= X"0D";
                    when 317 => dataOut <= X"09";
                    when 318 => dataOut <= X"49";
                    when 319 => dataOut <= X"4D";
                    when 320 => dataOut <= X"49";
                    when 321 => dataOut <= X"F9";
                    when 322 => dataOut <= X"FD";
                    when 323 => dataOut <= X"F9";
                    when 324 => dataOut <= X"59";
                    when 325 => dataOut <= X"5D";
                    when 326 => dataOut <= X"59";
                    when 327 => dataOut <= X"49";
                    when 328 => dataOut <= X"4D";
                    when 329 => dataOut <= X"49";
                    when 330 => dataOut <= X"C8";
                    when 331 => dataOut <= X"CC";
                    when 332 => dataOut <= X"C8";
                    when 333 => dataOut <= X"08";
                    when 334 => dataOut <= X"0C";
                    when 335 => dataOut <= X"08";
                    when 336 => dataOut <= X"49";
                    when 337 => dataOut <= X"4D";
                    when 338 => dataOut <= X"49";
                    when 339 => dataOut <= X"39";
                    when 340 => dataOut <= X"3D";
                    when 341 => dataOut <= X"39";
                    when 342 => dataOut <= X"49";
                    when 343 => dataOut <= X"4D";
                    when 344 => dataOut <= X"49";
                    when 345 => dataOut <= X"C9";
                    when 346 => dataOut <= X"CD";
                    when 347 => dataOut <= X"C9";
                    when 348 => dataOut <= X"49";
                    when 349 => dataOut <= X"4D";
                    when 350 => dataOut <= X"49";
                    when 351 => dataOut <= X"B9";
                    when 352 => dataOut <= X"BD";
                    when 353 => dataOut <= X"B9";
                    when 354 => dataOut <= X"29";
                    when 355 => dataOut <= X"2D";
                    when 356 => dataOut <= X"29";    
                    when 357 => dataOut <= X"09";
                    when 358 => dataOut <= X"0D";
                    when 359 => dataOut <= X"09";
                    when 360 => dataOut <= X"49";
                    when 361 => dataOut <= X"4D";
                    when 362 => dataOut <= X"49";
                    when 363 => dataOut <= X"79";
                    when 364 => dataOut <= X"7D";
                    when 365 => dataOut <= X"79";  
                    when 366 => dataOut <= X"49";
                    when 367 => dataOut <= X"4D";
                    when 368 => dataOut <= X"49";
                    when 369 => dataOut <= X"59";
                    when 370 => dataOut <= X"5D";
                    when 371 => dataOut <= X"59";
                    when 372 => dataOut <= X"49";
                    when 373 => dataOut <= X"4D";
                    when 374 => dataOut <= X"49";
                    when 375 => dataOut <= X"E9";
                    when 376 => dataOut <= X"ED";
                    when 377 => dataOut <= X"E9";
                    
                    when others =>                                                                                                          
                end case;
end process;

end behavioral;
