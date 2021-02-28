with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.RenderWindow;
with Sf.Graphics.Color;

with Sf.Window.Window;
with Sf.Window.VideoMode;
with Sf.Window.Event;
with Sf.Window.Mouse;
with Sf.Window.Keyboard;

with Sf.System.Vector2;

with Ada.Numerics.Discrete_Random;
with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Text_IO;

procedure Racing is

   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;

   num : constant := 8;
   dim : constant := 2;

   points : array (0 .. num - 1, 0 .. dim - 1) of Float :=
     ((300.0,   610.0),
      (1270.0,  430.0),
      (1380.0, 2380.0),
      (1900.0, 2460.0),
      (1970.0, 1700.0),
      (2550.0, 1680.0),
      (2560.0, 3150.0),
      (500.0,  3300.0));

   type Car is
      record
         x, y : Float;
         speed : Float;
         angle : Float;
         n : Integer;
      end record;

   procedure move (self : in out Car) is
   begin
      self.x := self.x + Sin(self.angle) * self.speed;
      self.y := self.y - Cos(self.angle) * self.speed;
   end move;

   procedure findTarget (self : in out Car) is
      x : Float renames self.x;
      y : Float renames self.y;
      tx : Float renames points(self.n, 0);
      ty : Float renames points(self.n, 1);
      beta : constant Float := self.angle - ArcTan(tx - x, -ty + y);
      speedFactor : constant := 0.005;
   begin
      if Sin(beta) < 0.0 then
         self.angle := self.angle + speedFactor * self.speed;
      else
         self.angle := self.angle - speedFactor * self.speed;
      end if;

      if (x - tx)**2 + (y - ty)**2 < 25.0**2 then
         self.n := (self.n + 1) rem num;
      end if;
   end findTarget;


   t1 : sfTexture_Ptr := Texture.createFromFile("images/background.png");
   t2 : sfTexture_Ptr := Texture.createFromFile("images/car.png");

   sBackground, sCar : sfSprite_Ptr := Sprite.create;

   mode : constant VideoMode.sfVideoMode :=
     (width        => 640,
      height       => 480,
      bitsPerPixel => 32);

   app : sfRenderWindow_Ptr := RenderWindow.create
     (mode => mode, title => "Car Racing Game!");

   maxXoffset : constant Float := Float(mode.width) / 2.0;
   maxYoffset : constant Float := Float(mode.height) / 2.0;

   e : Event.sfEvent;

   speed, angle : Float := 0.0;
   maxSpeed : constant := 12.0;
   acc : constant := 0.2;
   dec : constant := 0.3;
   turnSpeed : constant := 0.08;
   R : constant := 22;

   offset : Vector2.sfVector2f := (x => 0.0, y => 0.0);
   Up, Right, Down, Left : Boolean := False;

   numCars : constant := 5;
   cars : array (0 .. numCars - 1) of Car;
   colors : array (cars'range) of Color.sfColor :=
     (Color.sfRed, Color.sfGreen, Color.sfMagenta, Color.sfBlue, Color.sfWhite);

begin

   RenderWindow.setFramerateLimit(app, 60);

   Texture.setSmooth(t1, true);
   Texture.setSmooth(t2, true);

   Sprite.setTexture(sBackground, t1);
   Sprite.setTexture(sCar, t2);
   sprite.scale(sBackground, (2.0, 2.0));
   Sprite.setOrigin(sCar, (x => 22.0, y => 22.0));

   for i in cars'range loop
      cars(i) :=
        (x     => 300.0 + Float(i) * 50.0,
         y     => 1700.0 + Float(i) * 80.0,
         speed => 7.0 + Float(i),
         angle => 0.0,
         n     => 0);
   end loop;

   while RenderWindow.isOpen(app) = sfTrue loop

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop

         case e.eventType is
            when Event.sfEvtClosed =>

               RenderWindow.Close (app);

            when others => null;
         end case;

      end loop;

      Up := Keyboard.isKeyPressed(Keyboard.sfKeyUp) = sfTrue;
      Right := Keyboard.isKeyPressed(Keyboard.sfKeyRight) = sfTrue;
      Down := Keyboard.isKeyPressed(Keyboard.sfKeyDown) = sfTrue;
      Left := Keyboard.isKeyPressed(Keyboard.sfKeyLeft) = sfTrue;


      -- Car movement
      if Up and then speed < maxSpeed then
         if speed < 0.0 then
            speed := speed + dec;
         else
            speed := speed + acc;
         end if;
      end if;

      if Down and then speed > -maxSpeed then
         if speed > 0.0 then
            speed := speed - dec;
         else
            speed := speed - acc;
         end if;
      end if;

      if not Up and not Down then
         if speed - dec > 0.0 then
            speed := speed - dec;
         elsif speed + dec < 0.0 then
            speed := speed + dec;
         else
            speed := 0.0;
         end if;
      end if;

      if Right and speed /= 0.0 then
         angle := angle + turnSpeed * speed / maxSpeed;
      end if;

      if Left and speed /= 0.0 then
         angle := angle - turnSpeed * speed / maxSpeed;
      end if;

      cars(0).speed := speed;
      cars(0).angle := angle;

      for eachCar of cars loop
         move (eachCar);
      end loop;

      for i in 1 .. cars'last loop
         findTarget(cars(i));
      end loop;

      -- Collision
      for i in cars'range loop
         for j in cars'range loop
            declare
               dx, dy : Integer := 0;
            begin
               while dx**2 + dy**2 < 4 * R**2 loop
                  cars(i).x := cars(i).x + Float (dx / 10);
                  cars(i).y := cars(i).y + Float (dy / 10);
                  cars(j).x := cars(j).x - Float (dx / 10);
                  cars(j).y := cars(j).y - Float (dy / 10);
                  dx := Integer (cars(i).x - cars(j).x);
                  dy := Integer (cars(i).y - cars(j).y);
                  exit when dx = 0 and dy = 0;
               end loop;
            end;
         end loop;
      end loop;

      if cars(0).x > maxXoffset then
         offset.x := cars(0).x - maxXoffset;
      end if;

      if cars(0).y > maxYoffset then
         offset.y := cars(0).y - maxYoffset;
      end if;

      RenderWindow.clear(app, Color.sfWhite);
      Sprite.setPosition(sBackground, (-offset.x, -offset.y));
      RenderWindow.drawSprite(app, sBackground);

      for i in cars'range loop
         Sprite.setPosition(sCar, (cars(i).x - offset.x, cars(i).y - offset.y));
         Sprite.setRotation(sCar, cars(i).angle * 180.0 / Ada.Numerics.Pi);
         Sprite.setColor(sCar, colors(i));
         RenderWindow.drawSprite(app, sCar);
      end loop;

      RenderWindow.display(app);

   end loop;

end Racing;
