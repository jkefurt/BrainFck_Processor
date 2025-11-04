-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2025 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): jmeno <login AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (1) / zapis (0)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_INV  : out std_logic;                      -- pozadavek na aktivaci inverzniho zobrazeni (1)
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
 );
end cpu;

 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --      - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --      - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly.


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

signal ptr : std_logic_vector(12 downto 0); -- datovy pointer
signal pc  : std_logic_vector(12 downto 0); -- programovy counter
signal decoded_value : std_logic_vector(7 downto 0);
signal cnt : std_logic_vector(7 downto 0);  -- pocitadlo
signal ptr_inc, ptr_dec, pc_inc, pc_dec, cnt_set_1, cnt_inc, cnt_dec, data_addr_sel  : std_logic;
signal data_wdata_sel : std_logic_vector(1 downto 0); -- vyber co zapisovat do pameti
type t_fsm is (sinit, sfetch, sptrinc, sptrdec, smeminc, smemdec, swhile, swhilend, sdo, sdoend, sprint, sreturn, sdecode, sread, swrite, swhilecontinue, swhilendcont1, sdoendcontinue, swhilendcont2,sdoendcont2);
signal nstate, pstate : t_fsm;

begin


--CNT
 process (RESET,CLK) is 
  begin
  if RESET = '1' then
      cnt <= (others => '0');
  elsif rising_edge(CLK) then
    if EN = '1' then
      if cnt_set_1 = '1' then
        cnt <= "00000001";
      elsif cnt_inc = '1' then
        cnt <= cnt + 1;
      elsif cnt_dec = '1' then
        cnt <= cnt - 1;     
      end if;
    end if;
  end if;  
end process;



 --PTR
 process (RESET, CLK) is 
  begin
    if RESET = '1' then --reset
      ptr <= (others => '0');
    elsif rising_edge(CLK) then --RESET = 0
      if EN = '1' then 
        if ptr_inc = '1' then
          ptr <= ptr + 1;
        elsif ptr_dec = '1' then
          ptr <= ptr - 1; 
        end if;
      end if;    
    end if;
  end process;

--PC
 process (RESET,CLK) is 
  begin
    if RESET = '1' then
      pc <= (others => '0');
    elsif rising_edge(CLK) then
      if EN = '1' then 
        if pc_inc = '1' then
          pc <= pc + 1;
        elsif pc_dec = '1' then
          pc <= pc - 1; 
        end if;
      end if;
    end if;
  end process;

--DATA_ADDR MUX
with data_addr_sel select
DATA_ADDR <= 
  ptr when '0',
  pc when '1',
  (others => '0') when others;

--DATA_WDATA MUX
with data_wdata_sel select
DATA_WDATA <= IN_DATA when "00",
              DATA_RDATA - 1 when "01",
              DATA_RDATA + 1 when "10",
              decoded_value when "11",
              (others => '0') when others;

--present state logic
process (RESET, CLK) is
  begin
    if RESET = '1' then
      pstate <= sinit;
    elsif rising_edge(CLK) then
      if EN = '1' then 
        pstate <= nstate;
      end if;
    end if;
  end process;

--nextstate
process (pstate, DATA_RDATA, OUT_BUSY, IN_VLD, cnt) is
  begin
    cnt_set_1 <= '0';
    cnt_inc <= '0';
    cnt_dec <= '0';
    ptr_inc <= '0';
    ptr_dec <= '0';
    pc_inc <= '0';
    pc_dec <= '0';
    data_addr_sel <= 'X';
    data_wdata_sel <= "11";
    DATA_RDWR <= '1';
    DATA_EN <= '0';
    IN_REQ <= '0';
    OUT_WE <= '0';
    OUT_INV <= '0';
    OUT_DATA <= (others => '0');
    READY <= '1';
    DONE <= '0';

    case pstate is
      when sinit =>
        DATA_EN <= '1';         
        data_addr_sel <= '0';
        READY <= '0';
        if (DATA_RDATA = x"40") then 
          READY <= '1';
          nstate <= sfetch;   
        else
          ptr_inc <= '1';     
          nstate <= sinit;      
        end if;

      when sfetch => 
        DATA_EN <= '1';
        data_addr_sel <= '1';
        nstate <= sdecode;
      when sdecode =>
        case DATA_RDATA is
          when x"3E" => -- '>'
          nstate <= sptrinc;

          when x"3C" => -- '<'
          nstate <= sptrdec;

          when x"2B" => -- '+'
          DATA_EN <= '1';
          data_addr_sel <= '0'; --select ptr adress
          --DATA_RDWR <= '1';
          nstate <= smeminc;

          when x"2D" => -- '-'
          DATA_EN <= '1';
          data_addr_sel <= '0'; --select ptr adress
          --DATA_RDWR <= '1';
          nstate <= smemdec;

          when x"5B" => -- '['
          pc_inc <= '1';
          DATA_EN <= '1';
          data_addr_sel <= '0';
          nstate <= swhile;

          when x"5D" => -- ']'
          DATA_EN <= '1';
          data_addr_sel <= '0';
          nstate <= swhilend;

          when x"28" => -- '('
          nstate <= sdo;

          when x"29" => -- ')'
          DATA_EN <= '1';
          data_addr_sel <= '0';
          nstate <= sdoend;
 
          when x"2E" => -- '.'
          DATA_EN <= '1';
          data_addr_sel <= '0';
          nstate <= sprint;

          when x"2C" => -- ','
          IN_REQ <= '1';
          nstate <= sread;

          when x"40" =>
          nstate <= sreturn;
          
          when others =>
          if (DATA_RDATA >= x"30" and DATA_RDATA <= x"39") or (DATA_RDATA >= x"41" and DATA_RDATA <= x"46") then
            DATA_EN <= '1';
            data_addr_sel <= '1';
            DATA_RDWR <= '1';
            nstate <= swrite;
          else
          pc_inc <= '1';
          nstate <= sfetch;
          end if;
        end case;
      when sptrinc =>
        DATA_EN <= '1'; 
        data_addr_sel <= '1';
        ptr_inc <= '1'; 
        pc_inc <= '1';
        nstate <= sfetch;

      when sptrdec =>
        DATA_EN <= '1';
        data_addr_sel <= '1';
        ptr_dec <= '1';
        pc_inc <= '1';
        nstate <= sfetch;

      when smeminc => --inc data at ptr
        DATA_EN <= '1';
        data_addr_sel <= '0'; --select ptr adress
        DATA_RDWR <= '0'; --select write
        data_wdata_sel <= "10"; --select data++
        pc_inc <= '1';
        nstate <= sfetch;

      when smemdec => --inc data at ptr
        DATA_EN <= '1';
        data_addr_sel <= '0'; --select ptr adress
        DATA_RDWR <= '0'; --select write
        data_wdata_sel <= "01"; --select data--
        pc_inc <= '1';
        nstate <= sfetch;

      when sprint =>
        if OUT_BUSY = '0' then
    -- Výstup je volný, zapíšeme a přejdeme do sfetch
    OUT_DATA <= DATA_RDATA;
    OUT_WE <= '1';
    pc_inc <= '1';
    nstate <= sfetch;
    -- Připravíme čtení pro sfetch (z PC)
    DATA_EN <= '1';
    data_addr_sel <= '1'; -- <-- OPRAVA
  else
    -- Výstup je zaneprázdněn, čekáme
    nstate <= sprint;
    -- Znovu načteme data z mem[PTR], abychom je měli v DATA_RDATA
    DATA_EN <= '1';
    data_addr_sel <= '0';
  end if;

      when sread =>
        IN_REQ <= '1';
        if IN_VLD = '1' then 
          data_wdata_sel <= "00";
          pc_inc <= '1';
          DATA_EN <= '1';
          data_addr_sel <= '0';
          DATA_RDWR <= '0';
          nstate <= sfetch;
        else
          nstate <= sread;
        end if; 
      
      when swrite =>
        DATA_EN <= '1';
        data_wdata_sel <= "11";
        DATA_RDWR <= '0';
        data_addr_sel <= '0';
        pc_inc <= '1';
        if (DATA_RDATA >= x"30" and DATA_RDATA <= x"39") then
          decoded_value <= DATA_RDATA(3 downto 0) & "0000";
        else
          decoded_value <= (DATA_RDATA(3 downto 0) + 9) & "0000";
        end if;
        nstate <= sfetch;
      
      when swhile =>
        if DATA_RDATA = "00000000" then
          cnt_set_1 <= '1';
          DATA_EN <= '1';
          data_addr_sel <= '1';
          nstate <= swhilecontinue;
        else
          nstate <= sfetch;
        end if;


      when swhilecontinue =>
        DATA_EN <= '1';
        data_addr_sel <= '1';
        if cnt = "00000001" and DATA_RDATA = x"5D" then
          
          nstate <= sfetch;
        else
          if DATA_RDATA = x"5B" then
            cnt_inc <= '1';
          elsif DATA_RDATA = x"5D" then
            cnt_dec <= '1';
          end if;
          pc_inc <= '1';
          nstate <= swhilecontinue;
        end if;

      when swhilend =>
        if DATA_RDATA = "00000000" then
          pc_inc <= '1';
          nstate <= sfetch;
        else
          cnt_set_1 <= '1';
          pc_dec <= '1';
          nstate <= swhilendcont1;
        end if;

      when swhilendcont1 =>
        DATA_EN <= '1';
        data_addr_sel <= '1';
        nstate <= swhilendcont2;

        

      when swhilendcont2 =>
        if cnt = "00000001" and DATA_RDATA = x"5B" then
        
        nstate <= sfetch;
        else
          if DATA_RDATA = x"5D" then
            cnt_inc <= '1';
          elsif DATA_RDATA = x"5B" then
            cnt_dec <= '1';
          end if;
          pc_dec <= '1';
          nstate <= swhilendcont1;
        end if;
      
      when sdo =>
        pc_inc <= '1';
        nstate <= sfetch;
      
      when sdoend =>
        if DATA_RDATA = "00000000" then
          pc_inc <= '1';
          nstate <= sfetch;
        else
          cnt_set_1 <= '1';
          pc_dec <= '1';
          DATA_EN <= '1';
          data_addr_sel <= '1';
        nstate <= sdoendcontinue;
        end if;
      
      when sdoendcontinue =>
        DATA_EN <= '1';
        data_addr_sel <= '1';
      nstate <= sdoendcont2;
        

      when sdoendcont2 =>
        if cnt = "00000001" and DATA_RDATA = x"28" then
        pc_inc <= '1';
        nstate <= sfetch;
        else
          if DATA_RDATA = x"29" then
            cnt_inc <= '1';
          elsif DATA_RDATA = x"28" then
            cnt_dec <= '1';
          end if;
            pc_dec <= '1';
            nstate <= sdoendcontinue;
        end if;
      when sreturn =>
        DONE <= '1';
        nstate <= sreturn;
        
      when others =>
        nstate <= sfetch;
    end case;

  end process;
end behavioral;

