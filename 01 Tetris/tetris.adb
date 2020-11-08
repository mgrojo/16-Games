with Sf.Graphics.RenderWindow;
with Sf.Graphics.Color;
with Sf.Graphics.Texture;
with Sf.Graphics.Sprite;
with Sf.Graphics.Rect;

with Sf.Window.Window;
with Sf.Window.Event;
with Sf.Window.Keyboard;

with Sf.System.Vector2;
with Sf.System.Clock;
with Sf.System.Time;

with Ada.Numerics.Discrete_Random;

procedure Tetris is
   
   use type Sf.Window.Event.sfEventType;
   
   use Sf.Graphics;
   use Sf.Window;
   use Sf.System;
   use Sf;
   
   M : constant := 20;
   N : constant := 10;
   
   -- Side of the squares in pixels 
   Side : constant := 18;
   
   field : array (sfInt32 range 0 .. M-1, sfInt32 range 0 .. N-1) of sfInt32 :=
     (others => (others => 0));
   
   subtype tSquares is sfInt32 range 0 .. 3;
   subtype tPieces is sfInt32 range 0 .. 6;
   package RandomPiece is new Ada.Numerics.Discrete_Random (tPieces);
   generator : RandomPiece.Generator;

   type tPoints is array (tSquares) of Vector2.sfVector2i;
   a, b : tPoints := (others => (x => 0, y => 0));
   
   figures : array (tPieces, tSquares) of sfInt32 :=
     (
      0 => (1,3,5,7), -- I
      1 => (2,4,5,7), -- Z
      2 => (3,5,4,6), -- S
      3 => (3,5,4,7), -- T
      4 => (2,3,5,7), -- L
      5 => (3,5,7,6), -- J
      6 => (2,3,4,5)  -- O
     );
     
   app : sfRenderWindow_Ptr := RenderWindow.create((320, 480, 32), "Tetris!");
   e : Event.sfEvent;
   t1, t2, t3 : sfTexture_Ptr;
   s, background, frame : sfSprite_Ptr := Sprite.create;

   dx : sfInt32 := 0;
   rotate : Boolean := False;
   colorNum : sfInt32 := 1;
   
   timer : Float := 0.0;
   tick : Float := 0.3;
   
   clock1 : sfClock_Ptr := Clock.create;
   
   procedure fillPiece (piece : tPieces) is
   begin
      for i in tSquares loop
         a(i).x := figures(piece, i) mod 2;
         a(i).y := figures(piece, i) / 2;
      end loop;
   end fillPiece;
   
   function check return Boolean is
   begin
      for i in tSquares loop
         if a(i).x < 0 or else a(i).x >= N or else a(i).y >= M then
            return False;
         elsif field(a(i).y, a(i).x) /= 0 then
            return False;
         end if;
      end loop;

      return True;
   end check;
      
   procedure doRotation is
      x, y : sfInt32;
      
      -- Center of rotation:
      center : Vector2.sfVector2i := a(1);
   begin
      if rotate then
         for i in tSquares loop
            x := a(i).y - center.y;
            y := a(i).x - center.x;
            a(i).x := center.x - x;
            a(i).y := center.y + y;
         end loop;
         if not check then
            a := b;
         end if;
      end if;
      rotate := False;
   end doRotation;
   
   procedure move is
   begin
      b := a;
      for i in tSquares loop
         a(i).x := a(i).x + dx;
      end loop;
      dx := 0;
      if not check then
         a := b;
      end if;
   end move;
   
   procedure doTick is
      piece : tPieces := RandomPiece.Random(generator);
   begin
      if timer > tick then
         timer := 0.0;
         b := a;
         for i in tSquares loop
            a(i).y := a(i).y + 1;
         end loop;
         
         if not check then
            
            for i in tSquares loop
               field(b(i).y, b(i).x) := colorNum;
            end loop;
            
            colorNum := 1 + piece;
            
            fillPiece(piece);
            
         end if;
         
      end if;
      tick := 0.3;
   end doTick;
   
   procedure checkLines is
      k : sfInt32 := M-1;
      count : sfInt32;
   begin
      
      for i in reverse field'range(1) loop
         count := 0;
         for j in field'range(2) loop
            if field(i, j) /= 0 then
               count := count + 1;
            end if;
            field(k, j) := field (i, j);
         end loop;
         if count < N then
            k := k - 1;
         end if;
      end loop;
      
   end checkLines;
   
   procedure drawSquare
     (color : sfInt32; x, y : sfInt32) is
      
      xOffset : constant := 28.0;
      yOffset : constant := 31.0;
   begin
      Sprite.setTextureRect(s, (Integer (color * Side), 0, Side, Side));
      Sprite.setPosition(s, (Float(x * Side), Float (y * Side)));
      Sprite.move(s, (x => xOffset, y => yOffset));
      RenderWindow.drawSprite(app, s);
   end drawSquare;
   
begin
   
   RandomPiece.Reset (generator);
   
   fillPiece(0);
   
   t1 := Texture.createFromFile("images/tiles.png");
   t2 := Texture.createFromFile("images/background.png");
   t3 := Texture.createFromFile("images/frame.png");
   
   Sprite.setTexture(s, t1);
   Sprite.setTextureRect(s, (0, 0, Side, Side));
   
   Sprite.setTexture(background, t2);
   Sprite.setTexture(frame, t3);
   
   while RenderWindow.isOpen(app) = sfTrue loop
      
      timer := timer + Time.asSeconds(Clock.restart(clock1));

      while RenderWindow.PollEvent (app, event => e) = sfTrue loop
         
         case e.eventType is
            when Event.sfEvtClosed =>
               
               RenderWindow.Close (app);
               
            when Event.sfEvtKeyPressed =>

               case e.key.code is
                  when Keyboard.sfKeyUp =>
                     rotate := True;
                  when Keyboard.sfKeyLeft =>
                     dx := -1;
                  when Keyboard.sfKeyRight =>
                     dx := 1;
                  when Keyboard.sfKeyDown =>
                     tick := 0.05;
                  when others => null;
               end case;
               
            when others => null;
         end case;
               
      end loop;
      
      move;
      doRotation;
      doTick;
      checkLines;
      
      RenderWindow.clear(app, Color.sfWhite);
      RenderWindow.drawSprite(app, background);
      
      for i in field'range(1) loop
         for j in field'range(2) loop
            if field(i, j) /= 0 then
               drawSquare(color => field(i, j), x => j, y => i);
            end if;
               
         end loop;
      end loop;

      for eachSquare of a loop
         drawSquare(color => colorNum, x => eachSquare.x, y => eachSquare.y);
      end loop;
      
      RenderWindow.drawSprite(app, frame);
      RenderWindow.display (app);
      
      delay 0.01;
   end loop;
   
   Sprite.destroy(s);
   Sprite.destroy(background);
   Sprite.destroy(frame);
   Texture.destroy(t1);
   Texture.destroy(t2);
   Texture.destroy(t3);
   RenderWindow.destroy(app);
   Clock.destroy(clock1);
   
end Tetris;


