with Sf.Graphics.RenderWindow;
with Sf.Graphics.Color;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;

with Sf.Window.Window;
with Sf.Window.Event;
with Sf.Window.Keyboard;

with Sf.System.Vector2;
with Sf.System.Clock;
with Sf.System.Time;

with Ada.Numerics.Discrete_Random;

procedure Snake is

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   -- Field dimensions
   N : constant := 30;
   M : constant := 20;

   -- Size of the square side in pixels
   Size : constant := 16;

   W : constant := Size * N;
   H : constant := Size * M;

   type tDir is (Down, Left, Right, Up);

   package RandomFruit is new Ada.Numerics.Discrete_Random (sfInt32);
   generator : RandomFruit.Generator;

   app : sfRenderWindow_Ptr := RenderWindow.create((w, h, 32), "Snake Game!");
   e : Event.sfEvent;
   t1, t2 : sfTexture_Ptr;
   sprite1, sprite2 : sfSprite_Ptr := Sprite.create;

   snake : array (sfInt32 range 0 .. 99) of Vector2.sfVector2i := (others => (0, 0));
   fruit : Vector2.sfVector2i := (x => 10, y => 10);

   dir : tDir := Right;

   timer : Float := 0.0;
   tick : Float := 0.1;
   clock1 : sfClock_Ptr := Clock.create;
   num : sfInt32 := 4;

   procedure doTick is
   begin

      for i in reverse 1 .. num loop
         snake(i).x := snake(i-1).x;
         snake(i).y := snake(i-1).y;
      end loop;

      case dir is
         when Down =>
            snake(0).y := snake(0).y + 1;
         when Left =>
            snake(0).x := snake(0).x - 1;
         when Right =>
            snake(0).x := snake(0).x + 1;
         when Up =>
            snake(0).y := snake(0).y - 1;
      end case;

      if Vector2."=" (snake(0), fruit) then
         num := num + 1;
         fruit :=
           (x => randomFruit.Random(generator) mod N,
            y => randomFruit.Random(generator) mod M);
      end if;

      if snake(0).x > N then snake(0).x := 0; end if;
      if snake(0).y > M then snake(0).y := 0; end if;
      if snake(0).x < 0 then snake(0).x := N; end if;
      if snake(0).y < 0 then snake(0).y := M; end if;

      for i in 1 .. num - 1 loop
         if Vector2."=" (snake(0), snake(i)) then
            num := i;
         end if;
      end loop;

   end doTick;


   procedure Draw (spriteX : sfSprite_Ptr;
                   x, y    : sfInt32) is
   begin
      Sprite.setPosition(spriteX, (Float(x * Size), Float (y * Size)));
      RenderWindow.drawSprite(app, spriteX);
   end Draw;

begin

   RandomFruit.Reset (generator);

   RenderWindow.setFramerateLimit(app, 50);

   t1 := Texture.createFromFile("images/white.png");
   t2 := Texture.createFromFile("images/red.png");

   Sprite.setTexture(sprite1, t1);
   Sprite.setTexture(sprite2, t2);

   while RenderWindow.isOpen(app) = sfTrue loop

      timer := timer + Time.asSeconds(Clock.restart(clock1));

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop

         case e.eventType is
            when Event.sfEvtClosed =>

               RenderWindow.Close (app);

            when Event.sfEvtKeyPressed =>

               case e.key.code is
                  when Keyboard.sfKeyUp =>
                     dir := Up;
                  when Keyboard.sfKeyLeft =>
                     dir := Left;
                  when Keyboard.sfKeyRight =>
                     dir := Right;
                  when Keyboard.sfKeyDown =>
                     dir := Down;
                  when others => null;
               end case;

            when others => null;
         end case;

      end loop;


      if timer > tick then
         timer := 0.0;
         doTick;
      end if;

      RenderWindow.clear(app, Color.sfWhite);

      for i in sfInt32 range 0 .. N - 1 loop
         for j in sfInt32 range  0 .. M - 1 loop
            Draw (sprite1, i, j);
         end loop;
      end loop;

      for i in 0 .. num - 1 loop
         Draw (sprite2, snake(i).x, snake(i).y);
      end loop;

      Draw(sprite2, fruit.x, fruit.y);

      RenderWindow.display (app);

   end loop;

end Snake;
