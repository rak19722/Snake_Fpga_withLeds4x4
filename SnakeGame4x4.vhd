library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Snake_LED is
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        switches : in  STD_LOGIC_VECTOR(3 downto 0);  -- 0: up, 1: down, 2: left, 3: right
        rows     : out STD_LOGIC_VECTOR(3 downto 0);  -- filas (ánodos)
        cols     : out STD_LOGIC_VECTOR(3 downto 0)   -- columnas (cátodos)
    );
end Snake_LED;

architecture Behavioral of Snake_LED is

    -- Parámetros
    constant BOARD_SIZE       : integer := 4;
    constant MAX_SNAKE_LENGTH : integer := 16;

    -- Tipos
    type position_t is record
        x : integer range 0 to BOARD_SIZE-1;
        y : integer range 0 to BOARD_SIZE-1;
    end record;

    type snake_array_t is array (0 to MAX_SNAKE_LENGTH-1) of position_t;

    -- Señales del juego
    signal snake        : snake_array_t;
    signal snake_length : integer range 1 to MAX_SNAKE_LENGTH := 1;
    signal direction    : integer range 0 to 3 := 0;  -- 0: up, 1: down, 2: left, 3: right
    signal food         : position_t := (x => 2, y => 2);
    signal game_over    : STD_LOGIC := '0';

    -- Timers
    signal move_counter : integer range 0 to 25000000 := 0;  -- ~500ms a 50MHz
    signal mux_counter  : integer range 0 to 50000 := 0;     -- ~1ms entre filas
    signal mux_row      : integer range 0 to 3 := 0;

    -- "Aleatorio" para la comida
    signal random_counter : unsigned(7 downto 0) := (others => '0');

    -- Tablero 4x4 aplanado (fila*4 + columna)
    signal board : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------
    -- Multiplexado de la matriz 4x4
    --------------------------------------------------------------------
    process(clk, reset)
        variable row_vec : STD_LOGIC_VECTOR(3 downto 0);
        variable col_vec : STD_LOGIC_VECTOR(3 downto 0);
    begin
        if reset = '1' then
            mux_counter <= 0;
            mux_row     <= 0;
            rows        <= (others => '0');
            cols        <= (others => '1');  -- todo apagado (cátodos en '1')
        elsif rising_edge(clk) then
            mux_counter <= mux_counter + 1;
            if mux_counter = 50000 then  -- ~1ms
                mux_counter <= 0;

                -- Seleccionar siguiente fila
                mux_row <= (mux_row + 1) mod 4;

                -- Una sola fila activa (ánodo en '1')
                row_vec := (others => '0');
                row_vec(mux_row) := '1';
                rows <= row_vec;

                -- Columnas: '0' en cátodo para encender LED
                col_vec := (others => '1');
                for i in 0 to 3 loop
                    if board(mux_row*4 + i) = '1' then
                        col_vec(i) := '0';
                    end if;
                end loop;
                cols <= col_vec;
            end if;
        end if;
    end process;


    --------------------------------------------------------------------
    -- Lógica del juego (snake, comida, tablero)
    --------------------------------------------------------------------
    process(clk, reset)
        variable new_head  : position_t;
        variable collision : boolean;
        variable b_vec     : STD_LOGIC_VECTOR(15 downto 0);
    begin
        if reset = '1' then
            -- Estado inicial
            snake_length <= 1;
            snake(0)     <= (x => 0, y => 0);
            direction    <= 0;  -- up
            food         <= (x => 2, y => 2);
            game_over    <= '0';
            move_counter <= 0;
            random_counter <= (others => '0');
            board        <= (others => '0');

        elsif rising_edge(clk) then

            ----------------------------------------------------------------
            -- Mientras no haya game_over, se permite cambiar dirección y mover
            ----------------------------------------------------------------
            if game_over = '0' then
                -- Cambiar dirección con switches (uno a la vez)
                if switches(0) = '1' then
                    direction <= 0;  -- up
                elsif switches(1) = '1' then
                    direction <= 1;  -- down
                elsif switches(2) = '1' then
                    direction <= 2;  -- left
                elsif switches(3) = '1' then
                    direction <= 3;  -- right
                end if;

                -- Timer de movimiento
                move_counter <= move_counter + 1;

                if move_counter = 25000000 then  -- ~500ms a 50MHz
                    move_countif move_counter = 25000000 then  -- ~500ms a 50MHz
                    move_counter := 0;  -- variable asignada dentro del ciclo (sólo aquí)
                    move_counter <= 0;  -- y señal para síntesis

                    -- Calcular nueva cabeza (wrap-around manual)
                    new_head := snake(0);er := 0;  -- variable asignada dentro del ciclo (sólo aquí)
                    move_counter <= 0;  -- y señal para síntesis

                    -- Calcular nueva cabeza (wrap-around manual)
                    new_head := snake(0);

                    case direction is
                        when 0 =>  -- up
                            if new_head.y = 0 then
                                new_head.y := BOARD_SIZE - 1;
                            else
                                new_head.y := new_head.y - 1;
                            end if;

                        when 1 =>  -- down
                            if new_head.y = BOARD_SIZE - 1 then
                                new_head.y := 0;
                            else
                                new_head.y := new_head.y + 1;
                            end if;

                        when 2 =>  -- left
                            if new_head.x = 0 then
                                new_head.x := BOARD_SIZE - 1;
                            else
                                new_head.x := new_head.x - 1;
                            end if;

                        when 3 =>  -- right
                            if new_head.x = BOARD_SIZE - 1 then
                                new_head.x := 0;
                            else
                                new_head.x := new_head.x + 1;
                            end if;
                    end case;

                    -- Verificar colisión con el cuerpo
                    collision := false;
                    for i in 0 to MAX_SNAKE_LENGTH-1 loop
                        if i < snake_length then
                            if (new_head.x = snake(i).x) and (new_head.y = snake(i).y) then
                                collision := true;
                            end if;
                        end if;
                    end loop;

                    if collision = true then
                        game_over <= '1';

                    else
                        -- Desplazar cuerpo (de cola a cabeza)
                        for i in MAX_SNAKE_LENGTH-1 downto 1 loop
                            if i < snake_length then
                                snake(i) <= snake(i-1);
                            end if;
                        end loop;
                        snake(0) <= new_head;

                        -- ¿Comió la comida?
                        if (new_head.x = food.x) and (new_head.y = food.y) then
                            -- crecer
                            if snake_length < MAX_SNAKE_LENGTH then
                                snake_length <= snake_length + 1;
                            end if;

                            -- Nueva posición de comida pseudo-aleatoria
                            random_counter <= random_counter + 1;
                            food.x <= to_integer(random_counter(3 downto 2)) mod BOARD_SIZE;
                            food.y <= to_integer(random_counter(1 downto 0)) mod BOARD_SIZE;
                        end if;
                    end if;
                end if; -- fin del if move_counter

            end if; -- fin del if game_over = '0'


            ----------------------------------------------------------------
            -- Actualizar tablero (se dibuja siempre, incluso en game_over)
            ----------------------------------------------------------------
            b_vec := (others => '0');

            -- Cuerpo de la serpiente
            for i in 0 to MAX_SNAKE_LENGTH-1 loop
                if i < snake_length then
                    b_vec(snake(i).y * 4 + snake(i).x) := '1';
                end if;
            end loop;

            -- Comida parpadeando (solo si no hay game_over)
            if game_over = '0' then
                if move_counter < 12500000 then
                    b_vec(food.y * 4 + food.x) := '1';
                end if;
            end if;

            board <= b_vec;

        end if; -- rising_edge
    end process;

end Behavioral;
