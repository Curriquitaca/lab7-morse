-- Testbench autoverificable de morse.vhd
-- Usa HALF_SEC_CYCLES = 5 para simular rapido (1 ranura = 5 ciclos = 100 ns).
library ieee;
use ieee.std_logic_1164.all;

entity tb_morse is
end tb_morse;

architecture sim of tb_morse is
    constant HALF : positive := 5;
    constant T    : time := 20 ns;

    signal CLOCK_50 : std_logic := '0';
    signal KEY      : std_logic_vector(1 downto 0) := "11";
    signal SW       : std_logic_vector(2 downto 0) := "000";
    signal LEDR     : std_logic_vector(0 downto 0);
    signal done     : boolean := false;
begin
    dut : entity work.morse
        generic map (HALF_SEC_CYCLES => HALF)
        port map (CLOCK_50 => CLOCK_50, KEY => KEY, SW => SW, LEDR => LEDR);

    CLOCK_50 <= not CLOCK_50 after T / 2 when not done else CLOCK_50;

    stim : process
        -- Cada caracter de "expected" es una ranura de 0.5 s (1 = LED encendido)
        procedure check_letter (sw_val : std_logic_vector(2 downto 0);
                                expected : string) is
        begin
            SW <= sw_val;
            wait for 3 * T;
            KEY(1) <= '0';                                    -- pulsar KEY1
            wait until LEDR(0) = '1' for 100 * HALF * T;      -- el LED enciende al empezar
            assert LEDR(0) = '1' report "La FSM no empezo a transmitir" severity error;
            KEY(1) <= '1';                                    -- soltar KEY1
            wait for (HALF * T) / 2;                          -- centro de la 1a ranura
            for i in expected'range loop
                assert (LEDR(0) = '1') = (expected(i) = '1')
                    report "Error en la ranura " & integer'image(i) & " de " & expected
                    severity error;
                wait for HALF * T;
            end loop;
            wait for 4 * HALF * T;                            -- volver a IDLE
            assert LEDR(0) = '0' report "LED debe quedar apagado" severity error;
        end procedure;
    begin
        -- Reset inicial
        KEY(0) <= '0'; wait for 3 * T; KEY(0) <= '1'; wait for 3 * T;

        check_letter("000", "101110");        -- A  .-
        check_letter("001", "1110101010");    -- B  -...
        check_letter("010", "111010111010");  -- C  -.-.
        check_letter("011", "11101010");      -- D  -..
        check_letter("100", "10");            -- E  .
        check_letter("101", "1010111010");    -- F  ..-.
        check_letter("110", "1110111010");    -- G  --.
        check_letter("111", "10101010");      -- H  ....

        -- Prueba de reset asincrono a mitad de una transmision (letra G)
        SW <= "110";
        wait for 3 * T;
        KEY(1) <= '0';
        wait until LEDR(0) = '1' for 100 * HALF * T;
        KEY(1) <= '1';
        wait for 2 * T;
        KEY(0) <= '0'; wait for T / 4;                        -- reset asincrono (fuera del flanco)
        assert LEDR(0) = '0' report "Reset asincrono fallo" severity error;
        wait for 2 * T; KEY(0) <= '1';
        wait for 10 * HALF * T;
        assert LEDR(0) = '0' report "No debe transmitir tras el reset" severity error;

        report "Simulacion terminada" severity note;
        done <= true;
        wait;
    end process;
end sim;
