with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Color;
with Sf.Window.Event;
with Sf.Window.Keyboard;
with Sf.System.Clock;
with Sf.System.Time;

with Ada.Numerics.Discrete_Random;

procedure Xonix is

   use Sf.Graphics;
   use Sf.Graphics.Color;
   use Sf.Window;
   use Sf.System;
   use Sf;
   use type Sf.Window.Keyboard.sfKeyCode;

   M             : constant := 25;
   N             : constant := 40;
   Tile_Size     : constant sfInt32 := 18;
   Tile_Size_Int : constant Integer := Integer (Tile_Size);

   type Grid_Array is
     array (sfInt32 range 0 .. M - 1, sfInt32 range 0 .. N - 1) of sfInt32;
   grid : Grid_Array := (others => (others => 0));

   type Enemy is record
      x, y   : sfInt32 := 300;
      dx, dy : sfInt32 := 0;
   end record;

   Enemy_Count : constant Positive := 4;
   subtype Enemy_Index is Positive range 1 .. Enemy_Count;
   type Enemy_Array is array (Enemy_Index) of Enemy;

   subtype Speed_Base is Integer range 0 .. 7;
   package Random_Steps is new Ada.Numerics.Discrete_Random (Speed_Base);
   Speed_Generator : Random_Steps.Generator;

   function Tile_Row (Value : sfInt32) return sfInt32 is
      Index : sfInt32 := Value / Tile_Size;
   begin
      if Index < grid'First (1) then
         return grid'First (1);
      elsif Index > grid'Last (1) then
         return grid'Last (1);
      else
         return Index;
      end if;
   end Tile_Row;

   function Tile_Column (Value : sfInt32) return sfInt32 is
      Index : sfInt32 := Value / Tile_Size;
   begin
      if Index < grid'First (2) then
         return grid'First (2);
      elsif Index > grid'Last (2) then
         return grid'Last (2);
      else
         return Index;
      end if;
   end Tile_Column;

   procedure Drop (Row, Column : sfInt32) is
      procedure Try_Drop (Next_Row, Next_Column : sfInt32) is
      begin
         if Next_Row in grid'Range (1) and then Next_Column in grid'Range (2)
         then
            if grid (Next_Row, Next_Column) = 0 then
               Drop (Next_Row, Next_Column);
            end if;
         end if;
      end Try_Drop;
   begin
      if Row not in grid'Range (1) or else Column not in grid'Range (2) then
         return;
      end if;

      if grid (Row, Column) = 0 then
         grid (Row, Column) := -1;
         Try_Drop (Row - 1, Column);
         Try_Drop (Row + 1, Column);
         Try_Drop (Row, Column - 1);
         Try_Drop (Row, Column + 1);
      end if;
   end Drop;

   procedure Move (Self : in out Enemy) is
   begin
      Self.x := Self.x + Self.dx;
      if grid (Tile_Row (Self.y), Tile_Column (Self.x)) = 1 then
         Self.dx := -Self.dx;
         Self.x := Self.x + Self.dx;
      end if;

      Self.y := Self.y + Self.dy;
      if grid (Tile_Row (Self.y), Tile_Column (Self.x)) = 1 then
         Self.dy := -Self.dy;
         Self.y := Self.y + Self.dy;
      end if;
   end Move;

   procedure Initialize_Borders is
   begin
      for Row in grid'Range (1) loop
         for Column in grid'Range (2) loop
            if Row = grid'First (1)
              or else Row = grid'Last (1)
              or else Column = grid'First (2)
              or else Column = grid'Last (2)
            then
               grid (Row, Column) := 1;
            end if;
         end loop;
      end loop;
   end Initialize_Borders;

   procedure Reset_Interior is
   begin
      for Row in grid'First (1) + 1 .. grid'Last (1) - 1 loop
         for Column in grid'First (2) + 1 .. grid'Last (2) - 1 loop
            grid (Row, Column) := 0;
         end loop;
      end loop;
   end Reset_Interior;

   procedure Initialize_Enemy (Self : in out Enemy) is
   begin
      Self.x := 300;
      Self.y := 300;
      Self.dx := 4 - sfInt32 (Random_Steps.Random (Speed_Generator));
      Self.dy := 4 - sfInt32 (Random_Steps.Random (Speed_Generator));
   end Initialize_Enemy;

   app    : sfRenderWindow_Ptr :=
     RenderWindow.create
       ((sfUint32 (N * Tile_Size), sfUint32 (M * Tile_Size), sfUint32 (32)),
        "Xonix Game!");
   e      : Event.sfEvent;
   clock1 : sfClock_Ptr := Clock.create;

   t1, t2, t3               : sfTexture_Ptr;
   sTile, sGameover, sEnemy : sfSprite_Ptr := Sprite.create;

   x, y       : sfInt32 := 0;
   dx, dy     : sfInt32 := 0;
   timer      : Float := 0.0;
   Delay_Time : constant Float := 0.07;
   Game       : Boolean := True;

   Enemies       : Enemy_Array;
   enemyRotation : Float := 0.0;

begin

   Random_Steps.Reset (Speed_Generator);

   RenderWindow.setFramerateLimit (app, 60);

   t1 := Texture.createFromFile ("images/tiles.png");
   t2 := Texture.createFromFile ("images/gameover.png");
   t3 := Texture.createFromFile ("images/enemy.png");

   Sprite.setTexture (sTile, t1);
   Sprite.setTexture (sGameover, t2);
   Sprite.setTexture (sEnemy, t3);
   Sprite.setPosition (sGameover, (100.0, 100.0));
   Sprite.setOrigin (sEnemy, (20.0, 20.0));

   Initialize_Borders;

   for Idx in Enemy_Index loop
      Initialize_Enemy (Enemies (Idx));
   end loop;

   while RenderWindow.isOpen (app) = sfTrue loop

      timer := timer + Time.asSeconds (Clock.restart (clock1));

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop
         case e.eventType is
            when Event.sfEvtClosed =>
               RenderWindow.close (app);

            when Event.sfEvtKeyPressed =>
               if e.key.code = Keyboard.sfKeyEscape then
                  Reset_Interior;
                  x := 10;
                  y := 0;
                  Game := True;
               end if;

            when others =>
               null;
         end case;
      end loop;

      if Keyboard.isKeyPressed (Keyboard.sfKeyLeft) = sfTrue then
         dx := -1;
         dy := 0;
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyRight) = sfTrue then
         dx := 1;
         dy := 0;
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyUp) = sfTrue then
         dx := 0;
         dy := -1;
      end if;
      if Keyboard.isKeyPressed (Keyboard.sfKeyDown) = sfTrue then
         dx := 0;
         dy := 1;
      end if;

      if Game then

         if timer > Delay_Time then
            x := x + dx;
            y := y + dy;

            if x < 0 then
               x := 0;
            elsif x > N - 1 then
               x := N - 1;
            end if;

            if y < 0 then
               y := 0;
            elsif y > M - 1 then
               y := M - 1;
            end if;

            if grid (y, x) = 2 then
               Game := False;
            elsif grid (y, x) = 0 then
               grid (y, x) := 2;
            end if;

            timer := 0.0;
         end if;

         for Idx in Enemy_Index loop
            Move (Enemies (Idx));
         end loop;

         if grid (y, x) = 1 then
            dx := 0;
            dy := 0;

            for Idx in Enemy_Index loop
               Drop
                 (Tile_Row (Enemies (Idx).y), Tile_Column (Enemies (Idx).x));
            end loop;

            for Row in grid'Range (1) loop
               for Column in grid'Range (2) loop
                  if grid (Row, Column) = -1 then
                     grid (Row, Column) := 0;
                  else
                     grid (Row, Column) := 1;
                  end if;
               end loop;
            end loop;
         end if;

         for Idx in Enemy_Index loop
            declare
               Row    : constant sfInt32 := Tile_Row (Enemies (Idx).y);
               Column : constant sfInt32 := Tile_Column (Enemies (Idx).x);
            begin
               if grid (Row, Column) = 2 then
                  Game := False;
               end if;
            end;
         end loop;

      end if;

      RenderWindow.clear (app, Color => Color.sfBlack);

      for Row in grid'Range (1) loop
         for Column in grid'Range (2) loop
            if grid (Row, Column) = 0 then
               null;
            else
               if grid (Row, Column) = 1 then
                  Sprite.setTextureRect
                    (sTile, (0, 0, Tile_Size_Int, Tile_Size_Int));
               else
                  Sprite.setTextureRect
                    (sTile, (54, 0, Tile_Size_Int, Tile_Size_Int));
               end if;
               Sprite.setPosition
                 (sTile,
                  (Float (Column * Tile_Size), Float (Row * Tile_Size)));
               RenderWindow.drawSprite (app, sTile);
            end if;
         end loop;
      end loop;

      Sprite.setTextureRect (sTile, (36, 0, Tile_Size_Int, Tile_Size_Int));
      Sprite.setPosition
        (sTile, (Float (x * Tile_Size), Float (y * Tile_Size)));
      RenderWindow.drawSprite (app, sTile);

      enemyRotation := enemyRotation + 10.0;
      if enemyRotation >= 360.0 then
         enemyRotation := enemyRotation - 360.0;
      end if;
      Sprite.setRotation (sEnemy, enemyRotation);

      for Idx in Enemy_Index loop
         Sprite.setPosition
           (sEnemy, (Float (Enemies (Idx).x), Float (Enemies (Idx).y)));
         RenderWindow.drawSprite (app, sEnemy);
      end loop;

      if not Game then
         RenderWindow.drawSprite (app, sGameover);
      end if;

      RenderWindow.display (app);

   end loop;

end Xonix;
