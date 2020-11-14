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

procedure Doodle_Jump is

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   xLimit : constant := 400;
   yLimit : constant := 533;
   
   package RandomInt is new Ada.Numerics.Discrete_Random (sfInt32);
   generator : RandomInt.Generator;

   app : sfRenderWindow_Ptr := RenderWindow.create((xLimit, yLimit, 32), "Doodle Game!");
   e : Event.sfEvent;
   
   t1 : sfTexture_Ptr := Texture.createFromFile("images/background.png");
   t2 : sfTexture_Ptr := Texture.createFromFile("images/platform.png");
   t3 : sfTexture_Ptr := Texture.createFromFile("images/doodle.png");
   sBackground, sPlat, sPers : sfSprite_Ptr := Sprite.create;
   
   -- Dimensions of the sprites for calculating feet on platform.
   platformWidth : constant sfInt32 := sfInt32(Texture.getSize(t2).x);
   platformHeight : constant sfInt32 := sfInt32(Texture.getSize(t2).y);
   persHeight : constant := 70;
   persRight : constant := 50;
   persLeft : constant := 20;
   
   platforms : array (sfInt32 range 0 .. 9) of Vector2.sfVector2i := (others => (0, 0));
   x, y : sfInt32 := 100;
   h : constant := 200;
   dx, dy : Float := 0.0;
   
begin
   
   RandomInt.Reset (generator);

   RenderWindow.setFramerateLimit(app, 60);

   t1 := Texture.createFromFile("images/background.png");
   t2 := Texture.createFromFile("images/platform.png");
   t3 := Texture.createFromFile("images/doodle.png");

   Sprite.setTexture(sBackground, t1);
   Sprite.setTexture(sPlat, t2);
   Sprite.setTexture(sPers, t3);
   
   for eachPlatform of platforms loop
      eachPlatform :=
        (x => randomInt.Random(generator) mod xLimit,
         y => randomInt.Random(generator) mod yLimit);
   end loop;
   
   while RenderWindow.isOpen(app) = sfTrue loop

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop

         case e.eventType is
            when Event.sfEvtClosed =>

               RenderWindow.Close (app);

            when others => null;
         end case;

      end loop;
      
      if Keyboard.isKeyPressed(Keyboard.sfKeyRight) then x := x + 3; end if;
      if Keyboard.isKeyPressed(Keyboard.sfKeyLeft)  then x := x - 3; end if;
      
      dy := dy + 0.2;
      y := y + sfInt32 (dy);
      if y > 500 then
         dy := -10.0;
      end if;
      
      if y < h then
         y := h;
         for eachPlatform of platforms loop
            eachPlatform.y := eachPlatform.y - sfInt32(dy);
            
            if eachPlatform.y > yLimit then
               eachPlatform.y := 0;
               eachPlatform.x := randomInt.Random(generator) mod xLimit;
            end if;
            
         end loop;
      end if;
      
      for eachPlatform of platforms loop
         if x + persRight > eachPlatform.x and then
            x + persLeft < eachPlatform.x + platformWidth and then
            y + persHeight > eachPlatform.y and then
            y + persHeight < eachPlatform.y + platformHeight and then
            dy > 0.0
         then
            dy := -10.0;
         end if;
      end loop;
      
      Sprite.setPosition(sPers, (Float (x), Float (y)));
      
      RenderWindow.drawSprite(app, sBackground);
      
      for eachPlatform of platforms loop
         Sprite.setPosition(sPlat, (Float (eachPlatform.x), Float (eachPlatform.y)));
         RenderWindow.drawSprite(app, sPlat);
      end loop;
      
      RenderWindow.drawSprite(app, sPers);
      
      RenderWindow.display (app);
      
   end loop;
   
end Doodle_Jump;
