with Sf.Graphics.RenderWindow;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Color;

with Sf.Window.Event;
with Sf.Window.Mouse;

with Sf.System.Vector2;

with Ada.Numerics.Discrete_Random;

procedure Bejeweled is

   use type Sf.Window.Event.sfEventType;
   use type Sf.Window.Mouse.sfMouseButton;

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   Tile_Size : constant sfInt32 := 54;
   Gem_Texture_Size : constant Integer := 49;
   Offset : constant Vector2.sfVector2i := (x => 48, y => 24);

   subtype Board_Index is sfInt32 range 0 .. 9;
   subtype Play_Index is sfInt32 range 1 .. 8;

   type Piece is record
      x, y  : sfInt32 := 0;
      col   : sfInt32 := 0;
      row   : sfInt32 := 0;
      kind  : sfInt32 := 0;
      match : sfInt32 := 0;
      alpha : sfInt32 := 255;
   end record;

   type Grid_Array is array (Board_Index, Board_Index) of Piece;
   grid : Grid_Array := (others => (others => (others => <>)));

   subtype Gem_Init_Range is sfInt32 range 0 .. 2;
   subtype Gem_Kind_Range is sfInt32 range 0 .. 6;
   package Random_Init is new Ada.Numerics.Discrete_Random (Gem_Init_Range);
   package Random_Gem  is new Ada.Numerics.Discrete_Random (Gem_Kind_Range);
   Init_Generator : Random_Init.Generator;
   Gem_Generator  : Random_Gem.Generator;

   app : sfRenderWindow_Ptr := RenderWindow.create ((740, 480, 32), "Match-3 Game!");
   e : Event.sfEvent;

   background_Texture : sfTexture_Ptr := Texture.createFromFile ("images/background.png");
   gems_Texture       : sfTexture_Ptr := Texture.createFromFile ("images/gems.png");

   background_Sprite : sfSprite_Ptr := Sprite.create;
   gems_Sprite       : sfSprite_Ptr := Sprite.create;

   pos : Vector2.sfVector2i := (0, 0);
   x0, y0, x, y : sfInt32 := 0;
   click : Integer := 0;
   isSwap : Boolean := False;
   isMoving : Boolean := False;
   score : sfInt32 := 0;

   function In_Play_Bounds (Value : sfInt32) return Boolean is
   begin
      return Value in Play_Index;
   end In_Play_Bounds;

   function Sign (Value : sfInt32) return sfInt32 is
   begin
      if Value > 0 then
         return 1;
      else
         return -1;
      end if;
   end Sign;

   procedure Swap_Pieces
     (Row1, Col1, Row2, Col2 : sfInt32) is
      P1 : Piece := grid (Row1, Col1);
      P2 : Piece := grid (Row2, Col2);
      Temp_Row : constant sfInt32 := P1.row;
      Temp_Col : constant sfInt32 := P1.col;
   begin
      P1.row := P2.row;
      P1.col := P2.col;
      P2.row := Temp_Row;
      P2.col := Temp_Col;

      grid (Row1, Col1) := P2;
      grid (Row2, Col2) := P1;
   end Swap_Pieces;

begin

   Random_Init.Reset (Init_Generator);
   Random_Gem.Reset (Gem_Generator);

   RenderWindow.setFramerateLimit (app, 60);

   Sprite.setTexture (background_Sprite, background_Texture);
   Sprite.setTexture (gems_Sprite, gems_Texture);

   for i in Play_Index loop
      for j in Play_Index loop
         grid (i, j).kind := Random_Init.Random (Init_Generator);
         grid (i, j).col := j;
         grid (i, j).row := i;
         grid (i, j).x := j * Tile_Size;
         grid (i, j).y := i * Tile_Size;
         grid (i, j).match := 0;
         grid (i, j).alpha := 255;
      end loop;
   end loop;

   while RenderWindow.isOpen (app) = sfTrue loop

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop
         case e.eventType is
            when Event.sfEvtClosed =>
               RenderWindow.close (app);
            when Event.sfEvtMouseButtonPressed =>
               if e.mouseButton.button = Mouse.sfMouseLeft then
                  if not isSwap and then not isMoving then
                     click := click + 1;
                  end if;
                  declare
                     mouse_Pos : constant Vector2.sfVector2i := RenderWindow.Mouse.getPosition (app);
                  begin
                     pos := (x => mouse_Pos.x - Offset.x, y => mouse_Pos.y - Offset.y);
                  end;
               end if;
            when others =>
               null;
         end case;
      end loop;

      if click = 1 then
         x0 := pos.x / Tile_Size + 1;
         y0 := pos.y / Tile_Size + 1;
         if not (In_Play_Bounds (x0) and then In_Play_Bounds (y0)) then
            click := 0;
         end if;
      elsif click = 2 then
         x := pos.x / Tile_Size + 1;
         y := pos.y / Tile_Size + 1;
         if In_Play_Bounds (x) and then In_Play_Bounds (y) and then
           In_Play_Bounds (x0) and then In_Play_Bounds (y0)
         then
            if abs (x - x0) + abs (y - y0) = 1 then
               Swap_Pieces (y0, x0, y, x);
               isSwap := True;
               click := 0;
            else
               click := 1;
            end if;
         else
            click := 1;
         end if;
      end if;

      for i in Play_Index loop
         for j in Play_Index loop
            if grid (i, j).kind = grid (i + 1, j).kind and then
              grid (i, j).kind = grid (i - 1, j).kind
            then
               for n in -1 .. 1 loop
                  grid (i + sfInt32 (n), j).match := grid (i + sfInt32 (n), j).match + 1;
               end loop;
            end if;

            if grid (i, j).kind = grid (i, j + 1).kind and then
              grid (i, j).kind = grid (i, j - 1).kind
            then
               for n in -1 .. 1 loop
                  grid (i, j + sfInt32 (n)).match := grid (i, j + sfInt32 (n)).match + 1;
               end loop;
            end if;
         end loop;
      end loop;

      isMoving := False;
      for i in Play_Index loop
         for j in Play_Index loop
            declare
               P : Piece renames grid (i, j);
               dx, dy : sfInt32 := 0;
            begin
               for step in 1 .. 4 loop
                  dx := P.x - P.col * Tile_Size;
                  dy := P.y - P.row * Tile_Size;
                  if dx /= 0 then
                     P.x := P.x - Sign (dx);
                  end if;
                  if dy /= 0 then
                     P.y := P.y - Sign (dy);
                  end if;
               end loop;
               if dx /= 0 or else dy /= 0 then
                  isMoving := True;
               end if;
            end;
         end loop;
      end loop;

      if not isMoving then
         for i in Play_Index loop
            for j in Play_Index loop
               declare
                  P : Piece renames grid (i, j);
               begin
                  if P.match > 0 and then P.alpha > 10 then
                     P.alpha := P.alpha - 10;
                     isMoving := True;
                  end if;
               end;
            end loop;
         end loop;
      end if;

      score := 0;
      for i in Play_Index loop
         for j in Play_Index loop
            score := score + grid (i, j).match;
         end loop;
      end loop;

      if isSwap and then not isMoving then
         if score = 0 then
            Swap_Pieces (y0, x0, y, x);
         end if;
         isSwap := False;
      end if;

      if not isMoving then
         for i in reverse Play_Index loop
            for j in Play_Index loop
               if grid (i, j).match > 0 then
                  for n in reverse Play_Index'First .. i loop
                     if grid (n, j).match = 0 then
                        Swap_Pieces (n, j, i, j);
                        exit;
                     end if;
                  end loop;
               end if;
            end loop;
         end loop;

         for j in Play_Index loop
            declare
               drop_Count : sfInt32 := 0;
            begin
               for i in reverse Play_Index loop
                  if grid (i, j).match > 0 then
                     grid (i, j).kind := Random_Gem.Random (Gem_Generator);
                     grid (i, j).y := -(Tile_Size * drop_Count);
                     grid (i, j).x := j * Tile_Size;
                     grid (i, j).col := j;
                     grid (i, j).row := i;
                     grid (i, j).match := 0;
                     grid (i, j).alpha := 255;
                     drop_Count := drop_Count + 1;
                  else
                     grid (i, j).match := 0;
                  end if;
               end loop;
            end;
         end loop;
      end if;

      RenderWindow.clear (app, Color => Color.sfBlack);
      RenderWindow.drawSprite (app, background_Sprite);

      for i in Play_Index loop
         for j in Play_Index loop
            declare
               P : Piece := grid (i, j);
               Left : constant Integer := Integer (P.kind) * Gem_Texture_Size;
            begin
               Sprite.setTextureRect (gems_Sprite, (Left, 0, Gem_Texture_Size, Gem_Texture_Size));
                      Sprite.setColor
                         (gems_Sprite,
                           (r => 255,
                            g => 255,
                            b => 255,
                            a => sfUint8 (Integer'Max (0, Integer (P.alpha)))));
               Sprite.setPosition (gems_Sprite, (Float (P.x), Float (P.y)));
               Sprite.move
                 (gems_Sprite,
                  (Float (Offset.x - Tile_Size), Float (Offset.y - Tile_Size)));
               RenderWindow.drawSprite (app, gems_Sprite);
            end;
         end loop;
      end loop;

      RenderWindow.display (app);

   end loop;

   Sprite.destroy (background_Sprite);
   Sprite.destroy (gems_Sprite);
   Texture.destroy (background_Texture);
   Texture.destroy (gems_Texture);
   RenderWindow.destroy (app);

end Bejeweled;
