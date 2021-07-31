with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.RenderWindow;
with Sf.Graphics.Color;
with Sf.Graphics.ConvexShape;

with Sf.Window.VideoMode;
with Sf.Window.Event;
with Sf.Window.Keyboard;

with Ada.Numerics.Elementary_Functions; use Ada.Numerics.Elementary_Functions;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;

procedure Outrun is

   use Sf.Graphics;
   use Sf.Graphics.Color;
   use Sf.Window;
   use Sf;

   procedure drawQuad
     (w : sfRenderWindow_Ptr;
      c : Color.sfColor;
      x1, y1, w1 : Float;
      x2, y2, w2 : Float)
   is
      shape : sfConvexShape_Ptr := ConvexShape.create;
   begin
      ConvexShape.setPointCount (shape, 4);
      ConvexShape.setFillColor (shape, c);
      ConvexShape.setPoint (shape, 0, (x1-w1, (y1)));
      ConvexShape.setPoint (shape, 1, (x2-w2, (y2)));
      ConvexShape.setPoint (shape, 2, (x2+w2, (y2)));
      ConvexShape.setPoint (shape, 3, (x1+w1, (y1)));
      RenderWindow.drawConvexShape(w, shape);
      ConvexShape.destroy (shape);
   end drawQuad;

   mode : constant VideoMode.sfVideoMode :=
     (width        => 1024,
      height       => 768,
      bitsPerPixel => 32);

   roadW : constant := 2000.0;
   -- Segment length
   segL : constant := 200;
   -- Camera depth
   camD : constant := 0.84;

   nLines : constant := 1600;

   type Line is
      record
         x3d, y3d, z3d : Float := 0.0; -- 3D center of line (x, y, z in C++)
         X, Y, W : Float;
         scale, clip : Float;
         curve, spriteX : Float := 0.0;
         sprite : sfSprite_Ptr;
      end record;

   subtype LineIndex is Natural range 0 .. nLines - 1;

   package LineVectors is new Ada.Containers.Vectors (LineIndex, Line);

   procedure project (self : in out Line;
                      camX : Float; camY : Float; camZ : Float) is
      divisor : constant Float := self.z3d - camZ;
   begin

      self.scale := (if divisor = 0.0 then 1.0
                     else camD / divisor);
      self.X := (1.0 + self.scale*(self.x3d - camX)) * Float (mode.width) / 2.0;
      self.Y := (1.0 - self.scale*(self.y3d - camY)) * Float (mode.height) / 2.0;
      self.W := self.scale * roadW * Float (mode.width) / 2.0;
   end project;


   procedure drawSprite (self : in out Line; app : sfRenderWindow_Ptr) is
      s : sfSprite_Ptr := Sprite.copy (self.sprite);
      w : constant Float := Float (Sprite.getTextureRect (s).width);
      h : constant Float := Float (Sprite.getTextureRect (s).height);
      destX : Float := self.X + self.scale * self.spriteX * Float (mode.width) / 2.0;
      destY : Float := self.Y + 4.0;
      destW : constant Float := w * self.W / 266.0;
      destH : constant Float := h * self.W / 266.0;
      clipH : Float;
   begin

      destX := destX + destW * self.spriteX; -- offsetX
      destY := destY + destH * (-1.0);      -- offsetY

      clipH := destY + destH - self.clip;
      if clipH < 0.0 then
         clipH := 0.0;
      end if;

      if clipH < destH then
         Sprite.setTextureRect (s, rectangle => (0, 0, Integer (w), Integer (h - h*clipH / destH)));
         Sprite.setScale (s, (destW/w, destH/h));
         Sprite.setPosition (s, (destX, destY));
         RenderWindow.drawSprite (app, s);
      end if;

      Sprite.destroy (s);
   end drawSprite;


   bg : sfTexture_Ptr := Texture.createFromFile("images/bg.png");

   sBackground : sfSprite_Ptr := Sprite.create;

   app : sfRenderWindow_Ptr := RenderWindow.create
     (mode => mode, title => "Outrun Racing!");

   lines : LineVectors.Vector;

   e : Event.sfEvent;

   pos, startPos : Integer := 0;
   playerX, x, dx : Float := 0.0;
   camH : Float;
   maxy : Float;

   numObjects : constant := 7;

   t : array (1 .. numObjects) of sfTexture_Ptr;
   object : array (1 .. numObjects) of sfSprite_Ptr;

   H : Integer := 1500;
   speed : Integer := 0;

begin

   RenderWindow.setFramerateLimit(app, 60);

   for i in object'range loop
      t(i) := Texture.createFromFile ("images/" & Ada.Strings.Fixed.Trim
                                        (i'Image, Side => Ada.Strings.Left) & ".png");
      Texture.setSmooth (t(i), True);
      object(i) := Sprite.create;
      Sprite.setTexture (object(i), t(i));
   end loop;

   Texture.setRepeated(bg, true);

   Sprite.setTexture (sBackground, bg);
   Sprite.setTextureRect (sBackground, rectangle => (0, 0, 5000, 411));
   Sprite.setPosition (sBackground, position => (x => -2000.0, y => 0.0));


   for i in LineIndex loop
      declare
         aLine : Line;
      begin
         aLine.z3d := Float(i * segL);
         if i in 301 .. 699 then
            aLine.curve := 0.5;
         elsif i > 1100 then
            aLIne.curve := -0.7;
         end if;
         if i < 300 and i mod 20 = 0 then
            aLine.spriteX := -2.5;
            aLine.sprite := Sprite.copy (object(5));
         end if;
         if i mod 17 = 0 then
            aLine.spriteX := 2.0;
            aLine.sprite := Sprite.copy (object(6));
         end if;
         if i > 300 and i mod 20 = 0 then
            aLine.spriteX := -0.7;
            aLine.sprite := Sprite.copy (object(4));
         end if;
         if i > 800 and i mod 20 = 0 then
            aLine.spriteX := -1.2;
            aLine.sprite := Sprite.copy (object(1));
         end if;
         if i = 400 then
            aLine.spriteX := -1.2;
            aLine.sprite := Sprite.copy (object(7));
         end if;

         if i > 750 then
            aLine.y3d := sin (Float(i) / 30.0) * 1500.0;
         end if;
         lines.append (aLine);
      end;
   end loop;

   while RenderWindow.isOpen(app) = sfTrue loop

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop

         case e.eventType is
            when Event.sfEvtClosed =>

               RenderWindow.Close (app);

            when others => null;
         end case;

      end loop;

      speed := 0;
      if Keyboard.isKeyPressed(Keyboard.sfKeyRight) = sfTrue then
         playerX := playerX + 0.1;
      end if;
      if Keyboard.isKeyPressed(Keyboard.sfKeyLeft) = sfTrue then
         playerX := playerX - 0.1;
      end if;
      if Keyboard.isKeyPressed(Keyboard.sfKeyUp) = sfTrue then
         speed := speed + 200;
      end if;
      if Keyboard.isKeyPressed(Keyboard.sfKeyDown) = sfTrue then
         speed := speed - 200;
      end if;
      if Keyboard.isKeyPressed(Keyboard.sfKeyTab) = sfTrue then
         speed := speed * 3;
      end if;
      if Keyboard.isKeyPressed(Keyboard.sfKeyW) = sfTrue then
         H := H + 100;
      end if;
      if Keyboard.isKeyPressed(Keyboard.sfKeyS) = sfTrue then
         H := H - 100;
      end if;

      pos := pos + speed;
      while pos >= nLines * segL loop
         pos := pos - nLines*segL;
      end loop;
      while pos < 0 loop
         pos := pos + nLines*segL;
      end loop;

      RenderWindow.clear(app, color => (105, 205, 4, 255));
      RenderWindow.drawSprite(app, sBackground);

      startPos := pos / segL;
      x := 0.0;
      dx := 0.0;
      camH := lines.Element (startPos).y3d + Float (H);

      if speed > 0 then
         Sprite.move (sBackground, (-lines.Element (startPos).curve * 2.0, 0.0));
      elsif speed < 0 then
         Sprite.move (sBackground, ( lines.Element (startPos).curve * 2.0, 0.0));
      end if;

      maxy := Float (mode.height);

      -- Draw road
      for n in startPos .. startPos + 299 loop
         declare
            l : Line := lines.Element (n mod nLines);
            isOdd : constant Boolean := n/3 mod 2 /= 0;
            grass : sfColor := (if isOdd then (16, 200, 16, 255) else (0, 154, 0, 255));
            rumble : sfColor := (if isOdd then (255, 255, 255, 255) else (0, 0, 0, 255));
            road : sfColor := (if isOdd then (107, 107, 107, 255) else (105, 105, 105, 255));
            p : Line := lines.Element ((n-1) mod nLines); -- Previous line
            dz : constant Integer := (if n >= nLines then nLines*segL else 0);
         begin

            project(l,
                    camX => playerX * roadW - x,
                    camY => camH,
                    camZ => Float (startPos*segL - dz));

            x := x + dx;
            dx := dx + l.curve;
            l.clip := maxy;
            if n /= 0 and l.Y < maxy then
               maxy := l.Y;
               drawQuad(app, grass, 0.0, p.Y, Float (mode.width), 0.0, l.Y, Float (mode.width));
               drawQuad(app, rumble, p.X, p.Y, p.W * 1.2, l.X, l.Y, l.W * 1.2);
               drawQuad(app, road, p.X, p.Y, p.W, l.X, l.Y, l.W);
            end if;
            lines.Replace_Element(Index => n mod nLines, New_Item => l);
         end;
      end loop;

      -- Draw objects
      for n in reverse startPos + 1 .. startPos + 300 loop
         declare
            l : Line := lines.Element (Index => n mod nLines);
         begin
            if l.sprite /= null then
               drawSprite(l, app);
               lines.Replace_Element(Index => n mod nLines, New_Item => l);
            end if;
         end;
      end loop;

      RenderWindow.display(app);

   end loop;

end Outrun;
