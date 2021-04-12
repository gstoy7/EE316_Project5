-----------------
--  Libraries  --
-----------------
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

--------------
--  Entity  --
--------------
entity pwm_driver is
generic
(
  C_CLK_FREQ_MHZ : integer := 125                     -- System clock frequency in MHz
);
port
(
  I_CLK          : in std_logic;                      -- System clk frequency of (C_CLK_FREQ_MHZ)
  I_RESET_N      : in std_logic;                      -- System reset (active low)

  I_PWM_ENABLE   : in std_logic;                      -- Output enable for the module
  I_PWM_DATA     : in std_logic_vector(7 downto 0);   -- Input data to create duty cycle

  O_PWM          : out std_logic                     -- Output PWM waveform
);
end entity pwm_driver;

--------------------------------
--  Architecture Declaration  --
--------------------------------
architecture behavioral of pwm_driver is
begin

  ---------------
  -- Processes --
  ---------------

  ------------------------------------------------------------------------------
  -- Process Name     : PWM_GEN
  -- Sensitivity List : I_CLK            : System clock
  --                    I_RESET_N        : System reset (active low logic)
  -- Useful Outputs   : O_PWM            : Output PWM waveform
  -- Description      : Process to create a PWM signal with a duty cycle
  --                    proportional to an 8-bit data input.
  ------------------------------------------------------------------------------
  PWM_GEN: process(I_CLK, I_RESET_N)
    variable v_pwm_count : integer := 0;    -- Counter for PWM logic
    constant C_MAX_COUNT : integer := 2**8; -- 8-bit input data max count
  begin
    if (I_RESET_N = '0') then
      v_pwm_count     := 0;
      O_PWM           <= '0';

    elsif (rising_edge(I_CLK)) then
      if (I_PWM_ENABLE = '1') then

        -- PWM counter logic
        if (v_pwm_count /= C_MAX_COUNT) then
          v_pwm_count := v_pwm_count + 1;
        else
          v_pwm_count := 0;
        end if;

        -- Output PWM signal
        if (v_pwm_count < to_integer(unsigned(I_PWM_DATA))) then
          O_PWM       <= '1';
        else
          O_PWM       <= '0';
        end if;
      else
        v_pwm_count   := 0;
        O_PWM         <= '0';
      end if;
    end if;
  end process PWM_GEN;
  ------------------------------------------------------------------------------

  end architecture behavioral;
