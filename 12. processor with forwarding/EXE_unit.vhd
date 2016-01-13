library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity EXE_unit is
    port (
        clk : in std_logic;
        res_and_stall : in control;
        operands_from_ID: in operand_type;
        decoded_instr_from_ID : in instruction_decoded;
                
        branch_to_IF : out branch;
        load_to_MEM : out std_logic;
        store_to_MEM : out std_logic;
        
        data_to_MEM : out Tdata;
        adr_to_MEM : out Tadr;
        idx_d_to_MEM : out Tidx;
        data_valid_flag_for_WB : out std_logic;
        wb_forwarded_from_EXE : in write_back;          --forwarded data from exe
        wb_forwarded_from_MEM : in write_back          --forwarded data from mem
       -- branch_hazard_exe : out std_logic
            
        );
end entity EXE_unit;

architecture behaviour of EXE_unit is
  component ALU is
    port (
      A : in Tdata;
      B : in Tdata;
      S : in std_logic_vector(2 downto 0);
      
      Q : out Tdata;
      Z_OUT : out std_logic
      
    );
  end component ALU;
  
  signal loadi_result : Tdata;
  
  signal A_internal : Tdata;
  signal B_internal : Tdata;
  signal S_internal : std_logic_vector(2 downto 0);
  signal I_internal : Tdata;
  
  signal Q_internal : Tdata;
  signal Z_OUT_internal : std_logic := '0';
  
  signal load_to_MEM_temp : std_logic := '0';
  signal store_to_MEM_temp : std_logic := '0'; 
  
  signal adr_to_MEM_temp : Tadr;
  signal data_to_MEM_temp : Tdata;
  signal idx_d_to_MEM_temp : Tidx;
  signal data_valid_flag_for_WB_temp : std_logic := '0';

  signal branch_target : Tadr;
  
  signal operands_b, operands_a : Tdata;
  


  
begin
  
  ALU_unit : ALU
    port map (
      A => A_internal,
      B => B_internal,
      S => S_internal,     
      Q => Q_internal,
      Z_OUT => Z_OUT_internal
    );

  loadi_result(31 downto 16) <=  operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' else
                                 operands_a(31 downto 16) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' else
                                 x"0000";
  loadi_result(15 downto 0) <= operands_a(15 downto 0) when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '0' else
                               operands_from_ID.i when decoded_instr_from_ID.loadi = '1' and decoded_instr_from_ID.instr.ir(26) = '1' else
                               x"0000";
  
  A_internal <= operands_a;
  
  operands_a <= wb_forwarded_from_EXE.d when (wb_forwarded_from_EXE.d_valid = '1' and (decoded_instr_from_ID.idx_a = wb_forwarded_from_EXE.idx_d)) else
                        wb_forwarded_from_MEM.d when (wb_forwarded_from_MEM.d_valid = '1' and (decoded_instr_from_ID.idx_a = wb_forwarded_from_MEM.idx_d)) else
                        operands_from_ID.a;            
  operands_b <= wb_forwarded_from_EXE.d when (wb_forwarded_from_EXE.d_valid = '1' and (decoded_instr_from_ID.idx_b = wb_forwarded_from_EXE.idx_d)) else
                        wb_forwarded_from_MEM.d when (wb_forwarded_from_MEM.d_valid = '1' and (decoded_instr_from_ID.idx_b = wb_forwarded_from_MEM.idx_d)) else
                        operands_from_ID.b;
              
  B_internal <= std_logic_vector(signed(I_internal)) when decoded_instr_from_ID.load = '1' or decoded_instr_from_ID.store = '1' else
                --std_logic_vector(shift_left(unsigned(I_internal),2)) when (decoded_instr_from_ID.jmp = '1' or decoded_instr_from_ID.jz = '1' or decoded_instr_from_ID.jnz = '1' or decoded_instr_from_ID.call = '1') else
                std_logic_vector(signed(I_internal)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                std_logic_vector(signed(I_internal)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal)) >= 0 else
                std_logic_vector(signed((not I_internal) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal)) < 0 else
                std_logic_vector(signed((not operands_b) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b)) < 0 else
                std_logic_vector(signed((not operands_b) + 1)) when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b)) < 0 else
                operands_b;
 
  S_internal <= "000" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1111" else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal)) >= 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "1011" and to_integer(signed(I_internal)) < 0 else
                "111" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0110" and to_integer(signed(operands_b)) < 0 else
                "110" when decoded_instr_from_ID.alu = '1' and decoded_instr_from_ID.alu_op = "0111" and to_integer(signed(operands_b)) < 0 else
                decoded_instr_from_ID.alu_op(2 downto 0) when decoded_instr_from_ID.alu = '1' else
                "000";
              
  I_internal <= std_logic_vector( resize(signed(operands_from_ID.i), operands_from_ID.a'length) );

  load_to_MEM_temp <= '1' when decoded_instr_from_ID.load = '1' else
                      '0';
  
  store_to_MEM_temp <= '1' when decoded_instr_from_ID.store = '1' else
                       '0';
  
  adr_to_MEM_temp <= Q_internal when decoded_instr_from_ID.load = '1' or decoded_instr_from_ID.store = '1';
                     
  data_to_MEM_temp <= Q_internal when decoded_instr_from_ID.alu = '1' else
                      operands_b when decoded_instr_from_ID.store = '1' else
                      loadi_result when decoded_instr_from_ID.loadi = '1' else
                      decoded_instr_from_ID.instr.pc + 4 when decoded_instr_from_ID.call = '1' else
                      x"ffffffff";           
  
  idx_d_to_MEM_temp <= decoded_instr_from_ID.idx_d;
                       
  data_valid_flag_for_WB_temp <= '1' when decoded_instr_from_ID.alu = '1' or decoded_instr_from_ID.loadi = '1' or decoded_instr_from_ID.call = '1' else
                                 '0';
                                 
  branch_to_IF.branch <= '1' when (decoded_instr_from_ID.jmp = '1' 
                                  or (decoded_instr_from_ID.jz = '1' and operands_a = x"00000000") 
                                  or (decoded_instr_from_ID.jnz = '1' and operands_a /= x"00000000") 
                                  or decoded_instr_from_ID.call = '1') and decoded_instr_from_ID.instr.valid = '1' else
                         '0';
                         
  branch_target <= decoded_instr_from_ID.instr.pc + std_logic_vector(shift_left(unsigned(I_internal),2)); 
    
  branch_to_IF.target <= branch_target when decoded_instr_from_ID.relative = '1' else
                      operands_a;
   
                
                         
  clocked_process : process(clk)
  begin
    if rising_edge (clk) then 
      if res_and_stall.res = '1' then
          
        load_to_MEM <= '0';
        store_to_MEM <= '0';
        data_valid_flag_for_WB <= '0';
          
      elsif res_and_stall.stall = '0' then
        
        if decoded_instr_from_ID.instr.valid = '1' then
        load_to_MEM <= load_to_MEM_temp;
        store_to_MEM <= store_to_MEM_temp;  
        data_valid_flag_for_WB <= data_valid_flag_for_WB_temp;
        else
        load_to_MEM <= '0';
        store_to_MEM <= '0';  
        data_valid_flag_for_WB <= '0';
        end if;           
         
        adr_to_MEM <= adr_to_MEM_temp;
        data_to_MEM <= data_to_MEM_temp; 
        idx_d_to_MEM <= idx_d_to_MEM_temp; 
             
      end if;
    end if;
  end process;                                                                           
end architecture behaviour;
