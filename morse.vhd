-- Laboratorio 7 - Parte IV: Codificador Morse con FSM
-- Entradas : SW(2 downto 0) = letra (000=A ... 111=H)
--            KEY(1) = iniciar (activo en bajo), KEY(0) = reset asincrono (activo en bajo)
-- Salida   : LEDR(0) = codigo Morse (punto = 0.5 s, raya = 1.5 s, pausa = 0.5 s)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity morse is
    generic (HALF_SEC_CYCLES : positive := 25_000_000);  -- 50 MHz * 0.5 s
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(1 downto 0);
        SW       : in  std_logic_vector(2 downto 0);
        LEDR     : out std_logic_vector(0 downto 0)
    );
end morse;

architecture rtl of morse is
    type state_t is (IDLE, LOAD, SYM1, SYM2, SYM3, GAP);
    signal state, nstate : state_t;

    -- Contador de medio segundo
    signal cnt  : integer range 0 to HALF_SEC_CYCLES - 1 := 0;
    signal tick : std_logic;

    -- Registro de desplazamiento (0 = punto, 1 = raya, MSB primero)
    signal shreg  : std_logic_vector(3 downto 0);
    -- Contador de longitud (numero de simbolos restantes)
    signal len    : unsigned(2 downto 0);

    -- Logica de seleccion de letra
    signal pattern : std_logic_vector(3 downto 0);
    signal length  : unsigned(2 downto 0);

    -- Sincronizacion y deteccion de flanco de KEY1
    signal k_s0, k_s1, k_prev : std_logic;
    signal start : std_logic;

    -- Senales de control generadas por la FSM
    signal load_en, shift_en : std_logic;
begin
    ---------------------------------------------------------------
    -- Letter selection logic
    ---------------------------------------------------------------
    process (SW)
    begin
        case SW is
            when "000"  => pattern <= "0100"; length <= to_unsigned(2, 3); -- A  .-
            when "001"  => pattern <= "1000"; length <= to_unsigned(4, 3); -- B  -...
            when "010"  => pattern <= "1010"; length <= to_unsigned(4, 3); -- C  -.-.
            when "011"  => pattern <= "1000"; length <= to_unsigned(3, 3); -- D  -..
            when "100"  => pattern <= "0000"; length <= to_unsigned(1, 3); -- E  .
            when "101"  => pattern <= "0010"; length <= to_unsigned(4, 3); -- F  ..-.
            when "110"  => pattern <= "1100"; length <= to_unsigned(3, 3); -- G  --.
            when others => pattern <= "0000"; length <= to_unsigned(4, 3); -- H  ....
        end case;
    end process;

    ---------------------------------------------------------------
    -- Tick de 0.5 s (solo cuenta mientras se transmite)
    ---------------------------------------------------------------
    tick <= '1' when (cnt = HALF_SEC_CYCLES - 1 and state /= IDLE and state /= LOAD) else '0';

    ---------------------------------------------------------------
    -- FSM: logica del siguiente estado y salidas
    ---------------------------------------------------------------
    process (state, start, tick, shreg, len)
    begin
        nstate   <= state;
        load_en  <= '0';
        shift_en <= '0';
        case state is
            when IDLE =>
                if start = '1' then nstate <= LOAD; end if;
            when LOAD =>
                load_en <= '1';
                nstate <= SYM1;
            when SYM1 =>                       -- primer medio segundo encendido
                if tick = '1' then
                    if shreg(3) = '0' then nstate <= GAP;   -- punto
                    else nstate <= SYM2; end if;            -- raya
                end if;
            when SYM2 =>
                if tick = '1' then nstate <= SYM3; end if;
            when SYM3 =>
                if tick = '1' then nstate <= GAP; end if;
            when GAP =>                        -- pausa de 0.5 s entre simbolos
                if tick = '1' then
                    shift_en <= '1';
                    if len = 1 then nstate <= IDLE;
                    else nstate <= SYM1; end if;
                end if;
        end case;
    end process;

    LEDR(0) <= '1' when (state = SYM1 or state = SYM2 or state = SYM3) else '0';

    ---------------------------------------------------------------
    -- Registros (reset asincrono con KEY0)
    ---------------------------------------------------------------
    start <= '1' when (k_prev = '1' and k_s1 = '0') else '0';

    process (CLOCK_50, KEY(0))
    begin
        if KEY(0) = '0' then
            state  <= IDLE;
            cnt    <= 0;
            shreg  <= (others => '0');
            len    <= (others => '0');
            k_s0   <= '1';
            k_s1   <= '1';
            k_prev <= '1';
        elsif rising_edge(CLOCK_50) then
            state  <= nstate;
            k_s0   <= KEY(1);
            k_s1   <= k_s0;
            k_prev <= k_s1;

            -- contador de medio segundo
            if state = IDLE or state = LOAD or cnt = HALF_SEC_CYCLES - 1 then
                cnt <= 0;
            else
                cnt <= cnt + 1;
            end if;

            -- registro de desplazamiento y contador de longitud
            if load_en = '1' then
                shreg <= pattern;
                len   <= length;
            elsif shift_en = '1' then
                shreg <= shreg(2 downto 0) & '0';
                len   <= len - 1;
            end if;
        end if;
    end process;
end rtl;
