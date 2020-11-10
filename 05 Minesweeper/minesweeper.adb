with Sf.Graphics.RenderWindow;
with Sf.Graphics.Color;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Rect;

with Sf.Window.Window;
with Sf.Window.Event;
with Sf.Window.Mouse;

with Sf.System.Vector2;
with Sf.System.Time;

with Ada.Numerics.Discrete_Random;

procedure Minesweeper is
    use type Sf.Window.Event.sfEventType;

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   -- Side of the minefield. You can change this value to get it bigger.
   Side : constant := 12;
   w : constant := 32;

   Mine : constant := 9;
   Covered : constant := 10;
   Flag : constant := 11;

   subtype tCells is sfInt32 range 0 .. Side - 1;
   subtype tSquares is tCells range 1 .. tCells'Last - 1;

   type tGrid is array (tCells, tCells) of sfInt32;

   type tChances is mod 5;
   package RandomMines is new Ada.Numerics.Discrete_Random (tChances);
   generator : RandomMines.Generator;

   grid : tGrid := (others => (others => 0));
   sgrid : tGrid := (others => (others => Covered)); -- For showing

   app : sfRenderWindow_Ptr := RenderWindow.create((Side * w, Side * w, 32), "Minesweeper!");
   e : Event.sfEvent;
   t : sfTexture_Ptr;
   s : sfSprite_Ptr := Sprite.create;

   pos : Vector2.sfVector2i;
   x, y : sfInt32;
begin

   RandomMines.Reset (generator);

   t := Texture.createFromFile("images/tiles.jpg");
   Sprite.setTexture(s, t);

   for i in tSquares loop
      for j in tSquares loop
         if RandomMines.Random(generator) = 0 then
            grid(i, j) := Mine;
         else
            grid(i, j) := 0;
         end if;
      end loop;
   end loop;

   for i in tSquares loop
      for j in tSquares loop
         if grid(i, j) /= Mine then
         declare
            n : sfInt32 := 0;
            procedure countMines
              (k, l : sfInt32) is
            begin
               if grid(k, l) = Mine then
                  n := n + 1;
               end if;
            end countMines;
         begin
            countMines(i+1, j);
            countMines(i, j+1);
            countMines(i-1, j);
            countMines(i, j-1);
            countMines(i+1, j+1);
            countMines(i-1, j-1);
            countMines(i-1, j+1);
            countMines(i+1, j-1);
            grid(i, j) := n;
         end;
        end if;
      end loop;
   end loop;

   while RenderWindow.isOpen(app) = sfTrue loop

      pos := RenderWindow.Mouse.getPosition(app);
      x := pos.x / w;
      y := pos.y / w;

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop
         case e.eventType is
            when Event.sfEvtClosed =>

               RenderWindow.Close (app);

            when Event.sfEvtMouseButtonPressed =>

               case Mouse.sfMouseButton(e.mouseButton.button) is
                  when Mouse.sfMouseLeft =>
                     sgrid(x, y) := grid(x, y);
                  when Mouse.sfMouseRight =>
                     sgrid(x, y) := Flag;
                  when others => null;
               end case;

            when others => null;
         end case;

         RenderWindow.clear(app, Color.sfWhite);

         if x in grid'range(1) and then y in grid'range(2) and then sgrid(x, y) = Mine then
            sgrid := grid;
         end if;

         for i in tSquares loop
            for j in tSquares loop
               Sprite.setTextureRect(s, (Integer(sgrid(i, j) * w), 0, w, w));
               Sprite.setPosition(s, (Float(i * w), Float(j * w)));
               RenderWindow.drawSprite(app, s);
            end loop;
         end loop;

         RenderWindow.display (app);
      end loop;
   end loop;

   Sprite.destroy(s);
   Texture.destroy(t);
   RenderWindow.destroy(app);

end Minesweeper;
