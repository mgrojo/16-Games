with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.RenderWindow;
with Sf.Graphics.Color;

with Sf.Window.Window;
with Sf.Window.Event;
with Sf.Window.Mouse;

with Sf.System.Vector2;

with Ada.Numerics.Discrete_Random;
with Ada.Text_IO;

procedure Fifteen_Puzzle is

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   use type Sf.Window.Mouse.sfMouseButton;

   -- As difference to the original C++ version, here image size and side
   -- constant can be adjusted to any value. Image must be a square.
   side : constant := 4;

   t : sfTexture_Ptr := Texture.createFromFile("images/Ada_Mascot_with_slogan.png");
   size : constant Vector2.sfVector2u := Texture.getSize(t);

   nSquares : constant := side * side;
   w : constant Float := Float(size.x) / Float(side);
   width : constant Integer := Integer(w);
   grid : array (1 .. side, 1 .. side) of Integer;
   sprites : array (1 .. nSquares) of sfSprite_Ptr := (others => Sprite.create);

   subtype tSide0 is Integer range 0 .. side - 1;

   app : sfRenderWindow_Ptr := RenderWindow.create((size.x, size.x, 32), "15-Puzzle!");
   e : Event.sfEvent;

   n : Integer := 0;

   pos : Vector2.sfVector2i;
   dx, dy : Integer;
   x, y : Integer;

   procedure animate is
      step : Float := 0.0;
      speed : constant Float := 3.0;
      deltaX : constant Float := Float(dx);
      deltaY : constant Float := Float(dy);
   begin

      Sprite.move(sprites(nSquares), (-deltaX * w, -deltaY * w));

      while step < Float(w) loop
         step := step + speed;
         Sprite.move(sprites(n), (speed * deltaX, speed * deltaY));
         RenderWindow.drawSprite(app, sprites(nSquares));
         RenderWindow.drawSprite(app, sprites(n));
         RenderWindow.display(app);
      end loop;

   end animate;

   function isHole (i, j : tSide0'Base) return Boolean is
      (i in grid'range(1) and then j in grid'range(2) and then grid(i, j) = nSquares);

begin

   if size.x /= size.y then
      Ada.Text_IO.Put_Line("Image must be a square: " &size.x'image & "x"&
                          size.y'image);
      return;
   end if;

   RenderWindow.setFramerateLimit(app, 60);

   for i in tSide0 loop
      for j in tSide0 loop
         n := n + 1;
         Sprite.setTexture(sprites(n), t);
         Sprite.setTextureRect(sprites(n), (i * width, j * width, width, width));
         grid(i+1, j+1) := n;
      end loop;
   end loop;

   -- Draw a hole even if the image doesn't have one by setting the texture off-limits.
   Sprite.setTextureRect(sprites(nSquares), (side * width, side * width, width, width));

   while RenderWindow.isOpen(app) = sfTrue loop

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop

         case e.eventType is
            when Event.sfEvtClosed =>

               RenderWindow.Close (app);

            when Event.sfEvtMouseButtonPressed =>
               if Mouse.sfMouseButton(e.mouseButton.button) = Mouse.sfMouseLeft then

                  pos := RenderWindow.Mouse.getPosition(app);
                  x := Integer(pos.x) / width + 1;
                  y := Integer(pos.y) / width + 1;

                  dx := 0;
                  dy := 0;

                  if isHole(x+1, y) then dx :=  1; dy :=  0; end if;
                  if isHole(x, y+1) then dx :=  0; dy :=  1; end if;
                  if isHole(x, y-1) then dx :=  0; dy := -1; end if;
                  if isHole(x-1, y) then dx := -1; dy :=  0; end if;

                  n := grid(x, y);
                  grid(x, y) := nSquares;
                  grid(x+dx, y+dy) := n;

                  animate;

               end if;

            when others => null;
         end case;

      end loop;

      RenderWindow.clear(app, Color.sfWhite);

      for i in tSide0 loop
         for j in tSide0 loop
            n := grid(i+1, j+1);
            Sprite.setPosition(sprites(n), (Float(i) * w, Float(j) * w));
            RenderWindow.drawSprite(app, sprites(n));
         end loop;
      end loop;

      RenderWindow.display(app);

   end loop;

end Fifteen_Puzzle;
